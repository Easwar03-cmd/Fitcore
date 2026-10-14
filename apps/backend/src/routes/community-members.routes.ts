import type { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { authenticate } from '../plugins/authenticate';
import { communityRepository } from '../repositories/community.repository';
import { prisma } from '../utils/db';
import {
  fail,
  getMembership,
  requireAdmin,
  requireMember,
  validationError,
} from '../services/community-access';
import { buildMemberReport, trackingWindow } from '../services/community-report.service';

const memberParams = z.object({ id: z.string().min(1), uid: z.string().min(1) });
const idParam = z.object({ id: z.string().min(1) });

export const communityMemberRoutes: FastifyPluginAsync = async (fastify) => {
  fastify.addHook('preHandler', authenticate);

  // GET /community/:id/members
  fastify.get('/:id/members', async (request, reply) => {
    const { id } = idParam.parse(request.params);
    const me = await requireMember(reply, id, request.user.userId);
    if (!me) return;
    const asAdmin = me.role === 'admin';
    const rows = await communityRepository.listMembers(id, asAdmin);
    return reply.send({
      success: true,
      data: rows.map((m) => ({
        userId: m.userId,
        name: m.user.name,
        role: m.role,
        status: m.status,
        joinedAt: m.joinedAt,
        // Admin sees consent state; members only see their own.
        ...(asAdmin || m.userId === me.userId
          ? { shareReport: m.shareReport, heldAt: m.heldAt, leftAt: m.leftAt }
          : {}),
      })),
    });
  });

  // PATCH /community/:id/members/me/consent — allow / stop admin tracking
  fastify.patch('/:id/members/me/consent', async (request, reply) => {
    const { id } = idParam.parse(request.params);
    const parsed = z.object({ share: z.boolean() }).safeParse(request.body);
    if (!parsed.success) return validationError(reply, parsed.error.flatten());
    const me = await requireMember(reply, id, request.user.userId);
    if (!me) return;
    if (me.role === 'admin') {
      return fail(reply, 400, 'NOT_APPLICABLE', 'Admins are not tracked');
    }
    // Granting starts a fresh window from now; revoking hides everything at once.
    const updated = await prisma.communityMember.update({
      where: { id: me.id },
      data: parsed.data.share
        ? { shareReport: true, consentAt: new Date() }
        : { shareReport: false, consentAt: null },
    });
    return reply.send({
      success: true,
      data: { shareReport: updated.shareReport, consentAt: updated.consentAt },
    });
  });

  // POST /community/:id/members/:uid/approve
  fastify.post('/:id/members/:uid/approve', async (request, reply) => {
    const { id, uid } = memberParams.parse(request.params);
    if (!(await requireAdmin(reply, id, request.user.userId))) return;
    const target = await getMembership(id, uid);
    if (!target || target.status !== 'pending') {
      return fail(reply, 404, 'NOT_FOUND', 'No pending request from this user');
    }
    await prisma.communityMember.update({ where: { id: target.id }, data: { status: 'active' } });
    return reply.send({ success: true, data: { approved: true } });
  });

  // POST /community/:id/members/:uid/hold — pause tracking, keep data until now
  fastify.post('/:id/members/:uid/hold', async (request, reply) => {
    const { id, uid } = memberParams.parse(request.params);
    if (!(await requireAdmin(reply, id, request.user.userId))) return;
    const target = await getMembership(id, uid);
    if (!target || target.role === 'admin' || target.status !== 'active') {
      return fail(reply, 409, 'INVALID_STATE', 'Only active members can be put on hold');
    }
    await prisma.communityMember.update({
      where: { id: target.id },
      data: { status: 'on_hold', heldAt: new Date() },
    });
    return reply.send({ success: true, data: { status: 'on_hold' } });
  });

  // POST /community/:id/members/:uid/resume — tracking restarts from today
  fastify.post('/:id/members/:uid/resume', async (request, reply) => {
    const { id, uid } = memberParams.parse(request.params);
    if (!(await requireAdmin(reply, id, request.user.userId))) return;
    const target = await getMembership(id, uid);
    if (!target || target.status !== 'on_hold') {
      return fail(reply, 409, 'INVALID_STATE', 'Member is not on hold');
    }
    await prisma.communityMember.update({
      where: { id: target.id },
      data: {
        status: 'active',
        heldAt: null,
        // Data from the held period is never exposed: a new window begins now.
        consentAt: target.shareReport ? new Date() : null,
      },
    });
    return reply.send({ success: true, data: { status: 'active' } });
  });

  // DELETE /community/:id/members/:uid — remove from community
  fastify.delete('/:id/members/:uid', async (request, reply) => {
    const { id, uid } = memberParams.parse(request.params);
    const admin = await requireAdmin(reply, id, request.user.userId);
    if (!admin) return;
    if (uid === admin.userId) {
      return fail(reply, 400, 'INVALID', 'Use delete community to remove yourself');
    }
    await prisma.$transaction([
      prisma.challengeParticipant.deleteMany({
        where: { userId: uid, challenge: { communityId: id, kind: 'personal' } },
      }),
      prisma.challengeParticipant.updateMany({
        where: { userId: uid, challenge: { communityId: id } },
        data: { status: 'abandoned' },
      }),
      prisma.communityMember.deleteMany({ where: { communityId: id, userId: uid } }),
    ]);
    return reply.send({ success: true, data: { removed: true } });
  });

  // DELETE /community/:id/members/:uid/record — permanently erase the tracking record
  fastify.delete('/:id/members/:uid/record', async (request, reply) => {
    const { id, uid } = memberParams.parse(request.params);
    if (!(await requireAdmin(reply, id, request.user.userId))) return;
    const target = await getMembership(id, uid);
    if (!target || target.role === 'admin') {
      return fail(reply, 404, 'NOT_FOUND', 'Member not found');
    }
    if (target.status === 'left') {
      await prisma.$transaction([
        prisma.challengeParticipant.deleteMany({
          where: { userId: uid, challenge: { communityId: id, kind: 'personal' } },
        }),
        prisma.communityMember.delete({ where: { id: target.id } }),
      ]);
    } else {
      await prisma.communityMember.update({
        where: { id: target.id },
        data: {
          shareReport: false,
          consentAt: null,
          heldAt: null,
          status: target.status === 'on_hold' ? 'active' : target.status,
        },
      });
    }
    return reply.send({ success: true, data: { deleted: true } });
  });

  // GET /community/:id/members/:uid/report?days=30
  fastify.get('/:id/members/:uid/report', async (request, reply) => {
    const { id, uid } = memberParams.parse(request.params);
    const admin = await requireAdmin(reply, id, request.user.userId);
    if (!admin) return;
    if (uid === admin.userId) {
      return fail(reply, 400, 'INVALID', 'Admins are not tracked');
    }
    const days = z.coerce
      .number()
      .int()
      .min(1)
      .max(90)
      .catch(30)
      .parse((request.query as { days?: string }).days);

    const target = await getMembership(id, uid);
    if (!target) return fail(reply, 404, 'NOT_FOUND', 'Member not found');

    const win = trackingWindow(target, days);
    if (!win) {
      return fail(reply, 403, 'NOT_SHARING', 'This member is not sharing their report with you');
    }
    const user = await prisma.user.findUnique({
      where: { id: uid },
      select: { id: true, name: true },
    });
    const report = await buildMemberReport(target, win, id);
    return reply.send({
      success: true,
      data: { member: { ...user, status: target.status }, ...report },
    });
  });
};
