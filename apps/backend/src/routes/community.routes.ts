import type { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { Prisma } from '@prisma/client';
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

const nameSchema = z.string().trim().min(3).max(50);

const createSchema = z.object({
  name: nameSchema,
  description: z.string().trim().max(500).optional(),
  isPublic: z.boolean().default(true),
});

const updateSchema = z
  .object({
    name: nameSchema,
    description: z.string().trim().max(500).nullable(),
    isPublic: z.boolean(),
    requireApproval: z.boolean(),
    membersCanChat: z.boolean(),
    membersCanInvite: z.boolean(),
  })
  .partial();

const joinSchema = z
  .object({ code: z.string().trim().min(4).max(16), communityId: z.string().min(1) })
  .partial()
  .refine((v) => v.code || v.communityId, 'code or communityId is required');

const idParam = z.object({ id: z.string().min(1) });

function isUniqueViolation(e: unknown): boolean {
  return e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002';
}

export const communityRoutes: FastifyPluginAsync = async (fastify) => {
  fastify.addHook('preHandler', authenticate);

  // POST /community — create (caller becomes the admin)
  fastify.post('/', async (request, reply) => {
    const parsed = createSchema.safeParse(request.body);
    if (!parsed.success) return validationError(reply, parsed.error.flatten());
    const userId = request.user.userId;

    const owned = await prisma.community.count({ where: { adminId: userId } });
    if (owned >= 10) {
      return fail(reply, 409, 'LIMIT_REACHED', 'You can administer up to 10 communities');
    }
    try {
      const community = await communityRepository.create(userId, parsed.data);
      return reply.status(201).send({ success: true, data: community });
    } catch (e) {
      if (isUniqueViolation(e)) {
        return fail(reply, 409, 'NAME_TAKEN', 'A community with this name already exists');
      }
      throw e;
    }
  });

  // GET /community/mine
  fastify.get('/mine', async (request, reply) => {
    const data = await communityRepository.listForUser(request.user.userId);
    return reply.send({ success: true, data });
  });

  // GET /community/search?q=
  fastify.get('/search', async (request, reply) => {
    const q = z.string().trim().min(2).max(50).safeParse((request.query as { q?: string }).q);
    if (!q.success) return validationError(reply, 'q must be 2-50 characters');
    const data = await communityRepository.search(q.data);
    return reply.send({ success: true, data });
  });

  // GET /community/invite/:code — preview before joining
  fastify.get('/invite/:code', async (request, reply) => {
    const { code } = request.params as { code: string };
    const c = await communityRepository.findByCode(code.toUpperCase());
    if (!c) return fail(reply, 404, 'NOT_FOUND', 'Invite code not found');
    return reply.send({ success: true, data: c });
  });

  // POST /community/join — by invite code, or by id for public communities
  fastify.post('/join', async (request, reply) => {
    const parsed = joinSchema.safeParse(request.body);
    if (!parsed.success) return validationError(reply, parsed.error.flatten());
    const userId = request.user.userId;

    const community = parsed.data.code
      ? await prisma.community.findUnique({ where: { inviteCode: parsed.data.code.toUpperCase() } })
      : await communityRepository.findPublicById(parsed.data.communityId!);
    if (!community) return fail(reply, 404, 'NOT_FOUND', 'Community not found');

    const existing = await getMembership(community.id, userId);
    if (existing && (existing.status === 'active' || existing.status === 'on_hold')) {
      return reply.send({ success: true, data: { communityId: community.id, status: existing.status } });
    }
    const m = await communityRepository.join(community.id, userId, community.requireApproval);
    return reply.status(201).send({
      success: true,
      data: { communityId: community.id, status: m.status },
    });
  });

  // GET /community/:id
  fastify.get('/:id', async (request, reply) => {
    const { id } = idParam.parse(request.params);
    const m = await requireMember(reply, id, request.user.userId);
    if (!m) return;
    const c = m.community;
    const memberCount = await prisma.communityMember.count({
      where: { communityId: id, status: { in: ['active', 'on_hold'] } },
    });
    const admin = m.role === 'admin';
    return reply.send({
      success: true,
      data: {
        id: c.id,
        name: c.name,
        description: c.description,
        avatarUrl: c.avatarUrl,
        isPublic: c.isPublic,
        requireApproval: c.requireApproval,
        membersCanChat: c.membersCanChat,
        membersCanInvite: c.membersCanInvite,
        adminId: c.adminId,
        memberCount,
        inviteCode: admin || c.membersCanInvite ? c.inviteCode : null,
        me: {
          role: m.role,
          status: m.status,
          shareReport: m.shareReport,
          consentAt: m.consentAt,
        },
      },
    });
  });

  // PATCH /community/:id — admin settings
  fastify.patch('/:id', async (request, reply) => {
    const { id } = idParam.parse(request.params);
    const parsed = updateSchema.safeParse(request.body);
    if (!parsed.success) return validationError(reply, parsed.error.flatten());
    if (!(await requireAdmin(reply, id, request.user.userId))) return;
    try {
      const c = await communityRepository.update(id, parsed.data);
      return reply.send({ success: true, data: c });
    } catch (e) {
      if (isUniqueViolation(e)) {
        return fail(reply, 409, 'NAME_TAKEN', 'A community with this name already exists');
      }
      throw e;
    }
  });

  // POST /community/:id/invite/regenerate
  fastify.post('/:id/invite/regenerate', async (request, reply) => {
    const { id } = idParam.parse(request.params);
    if (!(await requireAdmin(reply, id, request.user.userId))) return;
    const c = await communityRepository.regenerateInvite(id);
    return reply.send({ success: true, data: { inviteCode: c.inviteCode } });
  });

  // POST /community/:id/leave — member leaves; tracking stops immediately
  fastify.post('/:id/leave', async (request, reply) => {
    const { id } = idParam.parse(request.params);
    const m = await requireMember(reply, id, request.user.userId);
    if (!m) return;
    if (m.role === 'admin') {
      return fail(reply, 409, 'ADMIN_CANNOT_LEAVE', 'Admins must delete the community instead of leaving it');
    }
    await prisma.$transaction([
      prisma.communityMember.update({
        where: { id: m.id },
        data: { status: 'left', leftAt: new Date(), heldAt: null },
      }),
      // Their challenges in this community stop with their membership.
      prisma.challengeParticipant.updateMany({
        where: { userId: m.userId, status: 'active', challenge: { communityId: id } },
        data: { status: 'abandoned' },
      }),
    ]);
    return reply.send({ success: true, data: { left: true } });
  });

  // DELETE /community/:id — admin deletes the whole community
  fastify.delete('/:id', async (request, reply) => {
    const { id } = idParam.parse(request.params);
    if (!(await requireAdmin(reply, id, request.user.userId))) return;
    await communityRepository.remove(id);
    return reply.send({ success: true, data: { deleted: true } });
  });
};
