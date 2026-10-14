import type { FastifyPluginAsync, FastifyReply } from 'fastify';
import { z } from 'zod';
import { authenticate } from '../plugins/authenticate';
import { prisma } from '../utils/db';
import { daysBetween, isPlausibleClientDate, parseDateOnly } from '../utils/dates';
import {
  fail,
  getMembership,
  canParticipate,
  requireMember,
  validationError,
} from '../services/community-access';

const idParam = z.object({ id: z.string().min(1) });
const cidParam = z.object({ cid: z.string().min(1) });
const dayParam = z.object({ cid: z.string().min(1), day: z.coerce.number().int().min(1).max(365) });

const dateSchema = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/)
  .refine((v) => {
    const d = parseDateOnly(v);
    return d !== null && isPlausibleClientDate(d);
  }, 'date must be today in your local calendar');

const createSchema = z.object({
  kind: z.enum(['personal', 'group']),
  title: z.string().trim().min(2).max(80),
  description: z.string().trim().max(2000).optional(),
  totalDays: z.number().int().min(1).max(365),
  notes: z.string().max(20000).optional(),
  clientDate: dateSchema,
});

/** Loads a challenge and verifies the caller may see it. Replies on failure. */
async function loadChallenge(reply: FastifyReply, cid: string, userId: string) {
  const challenge = await prisma.challenge.findUnique({ where: { id: cid } });
  if (!challenge) {
    await fail(reply, 404, 'NOT_FOUND', 'Challenge not found');
    return null;
  }
  // Community-less challenges are personal: visible to their creator only.
  if (challenge.communityId === null) {
    if (challenge.creatorId !== userId) {
      await fail(reply, 404, 'NOT_FOUND', 'Challenge not found');
      return null;
    }
    return { challenge, member: null };
  }
  const member = await getMembership(challenge.communityId, userId);
  if (!canParticipate(member)) {
    await fail(reply, 403, 'NOT_A_MEMBER', 'You are not a member of this community');
    return null;
  }
  // Personal challenges are visible to their owner only (admin sees them
  // through the consented report, never through this endpoint).
  if (challenge.kind === 'personal' && challenge.creatorId !== userId) {
    await fail(reply, 404, 'NOT_FOUND', 'Challenge not found');
    return null;
  }
  return { challenge, member };
}

function progress(
  p: { startDate: Date; status: string; _count?: { checkins: number } } | null,
  total: number,
) {
  if (!p) return null;
  return {
    startDate: p.startDate,
    status: p.status,
    completedDays: p._count?.checkins ?? 0,
    totalDays: total,
  };
}

export const challengeRoutes: FastifyPluginAsync = async (fastify) => {
  fastify.addHook('preHandler', authenticate);

  // GET /community/personal-challenges — my community-less personal challenges
  fastify.get('/personal-challenges', async (request, reply) => {
    const userId = request.user.userId;
    const rows = await prisma.challenge.findMany({
      where: { communityId: null, creatorId: userId },
      include: {
        creator: { select: { id: true, name: true } },
        _count: { select: { participants: true } },
        participants: {
          where: { userId },
          include: { _count: { select: { checkins: true } } },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
    return reply.send({
      success: true,
      data: rows.map((c) => ({
        id: c.id,
        kind: c.kind,
        title: c.title,
        description: c.description,
        totalDays: c.totalDays,
        status: c.status,
        creator: c.creator,
        participantCount: c._count.participants,
        createdAt: c.createdAt,
        mine: progress(c.participants[0] ?? null, c.totalDays),
      })),
    });
  });

  // POST /community/personal-challenges — personal challenge, no community
  fastify.post('/personal-challenges', async (request, reply) => {
    const parsed = createSchema.omit({ kind: true }).safeParse(request.body);
    if (!parsed.success) return validationError(reply, parsed.error.flatten());
    const userId = request.user.userId;
    const d = parsed.data;

    const active = await prisma.challengeParticipant.count({
      where: { userId, status: 'active', challenge: { communityId: null } },
    });
    if (active >= 20) {
      return fail(reply, 409, 'LIMIT_REACHED', 'Finish or leave a challenge before starting another');
    }
    const challenge = await prisma.challenge.create({
      data: {
        communityId: null,
        creatorId: userId,
        kind: 'personal',
        title: d.title,
        description: d.description ?? '',
        totalDays: d.totalDays,
        participants: {
          create: {
            userId,
            startDate: parseDateOnly(d.clientDate)!,
            ...(d.notes?.trim() ? { dayNotes: { create: { dayNumber: 1, notes: d.notes } } } : {}),
          },
        },
      },
    });
    return reply.status(201).send({ success: true, data: challenge });
  });

  // GET /community/:id/challenges — group challenges + my personal ones
  fastify.get('/:id/challenges', async (request, reply) => {
    const { id } = idParam.parse(request.params);
    const userId = request.user.userId;
    if (!(await requireMember(reply, id, userId))) return;

    const rows = await prisma.challenge.findMany({
      where: {
        communityId: id,
        OR: [{ kind: 'group' }, { kind: 'personal', creatorId: userId }],
      },
      include: {
        creator: { select: { id: true, name: true } },
        _count: { select: { participants: true } },
        participants: {
          where: { userId },
          include: { _count: { select: { checkins: true } } },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
    return reply.send({
      success: true,
      data: rows.map((c) => ({
        id: c.id,
        kind: c.kind,
        title: c.title,
        description: c.description,
        totalDays: c.totalDays,
        status: c.status,
        creator: c.creator,
        participantCount: c._count.participants,
        createdAt: c.createdAt,
        mine: progress(c.participants[0] ?? null, c.totalDays),
      })),
    });
  });

  // POST /community/:id/challenges
  fastify.post('/:id/challenges', async (request, reply) => {
    const { id } = idParam.parse(request.params);
    const parsed = createSchema.safeParse(request.body);
    if (!parsed.success) return validationError(reply, parsed.error.flatten());
    if (parsed.data.kind !== 'group') {
      return fail(reply, 400, 'USE_PERSONAL', 'Personal challenges are created without a community');
    }
    const me = await requireMember(reply, id, request.user.userId);
    if (!me) return;
    const d = parsed.data;

    const active = await prisma.challengeParticipant.count({
      where: { userId: me.userId, status: 'active', challenge: { communityId: id } },
    });
    if (active >= 20) {
      return fail(reply, 409, 'LIMIT_REACHED', 'Finish or leave a challenge before starting another');
    }

    const challenge = await prisma.challenge.create({
      data: {
        communityId: id,
        creatorId: me.userId,
        kind: d.kind,
        title: d.title,
        description: d.description ?? '',
        totalDays: d.totalDays,
        participants: {
          create: {
            userId: me.userId,
            startDate: parseDateOnly(d.clientDate)!,
            ...(d.notes?.trim() ? { dayNotes: { create: { dayNumber: 1, notes: d.notes } } } : {}),
          },
        },
      },
    });

    if (d.kind === 'group') {
      await prisma.communityMessage.create({
        data: {
          communityId: id,
          authorId: me.userId,
          kind: 'challenge_event',
          body: `started a ${d.totalDays}-day challenge: ${d.title}`,
          payload: { challengeId: challenge.id, title: d.title, totalDays: d.totalDays },
        },
      });
    }
    return reply.status(201).send({ success: true, data: challenge });
  });

  // GET /community/challenges/:cid
  fastify.get('/challenges/:cid', async (request, reply) => {
    const { cid } = cidParam.parse(request.params);
    const userId = request.user.userId;
    const ctx = await loadChallenge(reply, cid, userId);
    if (!ctx) return;
    const { challenge } = ctx;

    const [mine, participants] = await Promise.all([
      prisma.challengeParticipant.findUnique({
        where: { challengeId_userId: { challengeId: cid, userId } },
        include: {
          checkins: { select: { dayNumber: true, date: true }, orderBy: { dayNumber: 'asc' } },
          dayNotes: { select: { dayNumber: true, notes: true }, orderBy: { dayNumber: 'asc' } },
        },
      }),
      challenge.kind === 'group'
        ? prisma.challengeParticipant.findMany({
            where: { challengeId: cid },
            include: {
              user: { select: { id: true, name: true, avatarUrl: true } },
              _count: { select: { checkins: true } },
            },
            orderBy: { startDate: 'asc' },
          })
        : Promise.resolve([]),
    ]);

    return reply.send({
      success: true,
      data: {
        id: challenge.id,
        communityId: challenge.communityId,
        kind: challenge.kind,
        title: challenge.title,
        description: challenge.description,
        totalDays: challenge.totalDays,
        status: challenge.status,
        creatorId: challenge.creatorId,
        mine: mine
          ? {
              startDate: mine.startDate,
              status: mine.status,
              dayNotes: mine.dayNotes.filter((n) => n.notes.trim() !== ''),
              checkins: mine.checkins,
              completedDays: mine.checkins.length,
            }
          : null,
        // Other people's notepads are never included — only what they shared.
        participants: participants.map((p) => ({
          userId: p.userId,
          name: p.user.name,
          avatarUrl: p.user.avatarUrl,
          startDate: p.startDate,
          status: p.status,
          completedDays: p._count.checkins,
        })),
      },
    });
  });

  // POST /community/challenges/:cid/join  { clientDate }
  fastify.post('/challenges/:cid/join', async (request, reply) => {
    const { cid } = cidParam.parse(request.params);
    const parsed = z.object({ clientDate: dateSchema }).safeParse(request.body);
    if (!parsed.success) return validationError(reply, parsed.error.flatten());
    const ctx = await loadChallenge(reply, cid, request.user.userId);
    if (!ctx) return;
    if (ctx.challenge.kind !== 'group' || ctx.challenge.status !== 'open') {
      return fail(reply, 409, 'NOT_JOINABLE', 'This challenge is not open to join');
    }
    const p = await prisma.challengeParticipant.upsert({
      where: { challengeId_userId: { challengeId: cid, userId: request.user.userId } },
      create: {
        challengeId: cid,
        userId: request.user.userId,
        startDate: parseDateOnly(parsed.data.clientDate)!,
      },
      update: {},
    });
    return reply.status(201).send({ success: true, data: { startDate: p.startDate, status: p.status } });
  });

  // POST /community/challenges/:cid/leave
  fastify.post('/challenges/:cid/leave', async (request, reply) => {
    const { cid } = cidParam.parse(request.params);
    const ctx = await loadChallenge(reply, cid, request.user.userId);
    if (!ctx) return;
    await prisma.challengeParticipant.updateMany({
      where: { challengeId: cid, userId: request.user.userId, status: 'active' },
      data: { status: 'abandoned' },
    });
    return reply.send({ success: true, data: { left: true } });
  });

  // POST /community/challenges/:cid/checkins  { date }
  fastify.post('/challenges/:cid/checkins', async (request, reply) => {
    const { cid } = cidParam.parse(request.params);
    const parsed = z.object({ date: dateSchema }).safeParse(request.body);
    if (!parsed.success) return validationError(reply, parsed.error.flatten());
    const userId = request.user.userId;
    const ctx = await loadChallenge(reply, cid, userId);
    if (!ctx) return;

    const p = await prisma.challengeParticipant.findUnique({
      where: { challengeId_userId: { challengeId: cid, userId } },
    });
    if (!p || p.status !== 'active') {
      return fail(reply, 409, 'NOT_ACTIVE', 'You are not actively doing this challenge');
    }
    const date = parseDateOnly(parsed.data.date)!;
    const dayNumber = daysBetween(p.startDate, date) + 1;
    if (dayNumber < 1 || dayNumber > ctx.challenge.totalDays) {
      return fail(reply, 400, 'OUT_OF_RANGE', 'That date is outside this challenge');
    }

    await prisma.challengeCheckin.upsert({
      where: { participantId_dayNumber: { participantId: p.id, dayNumber } },
      create: { participantId: p.id, dayNumber, date },
      update: {},
    });
    const completed = await prisma.challengeCheckin.count({ where: { participantId: p.id } });
    const finished = completed >= ctx.challenge.totalDays;
    if (finished) {
      await prisma.challengeParticipant.update({ where: { id: p.id }, data: { status: 'completed' } });
    }
    return reply.send({
      success: true,
      data: { dayNumber, completedDays: completed, totalDays: ctx.challenge.totalDays, finished },
    });
  });

  // DELETE /community/challenges/:cid/checkins/:day — undo (same-day mistake)
  fastify.delete('/challenges/:cid/checkins/:day', async (request, reply) => {
    const { cid, day } = dayParam.parse(request.params);
    const userId = request.user.userId;
    const ctx = await loadChallenge(reply, cid, userId);
    if (!ctx) return;
    const p = await prisma.challengeParticipant.findUnique({
      where: { challengeId_userId: { challengeId: cid, userId } },
    });
    if (!p) return fail(reply, 404, 'NOT_FOUND', 'Not participating');
    const checkin = await prisma.challengeCheckin.findUnique({
      where: { participantId_dayNumber: { participantId: p.id, dayNumber: day } },
    });
    if (!checkin) return reply.send({ success: true, data: { removed: false } });
    if (!isPlausibleClientDate(checkin.date)) {
      return fail(reply, 400, 'TOO_LATE', 'Only today\'s check-in can be undone');
    }
    await prisma.$transaction([
      prisma.challengeCheckin.delete({ where: { id: checkin.id } }),
      prisma.challengeParticipant.update({ where: { id: p.id }, data: { status: 'active' } }),
    ]);
    return reply.send({ success: true, data: { removed: true } });
  });

  // PATCH /community/challenges/:cid/notes/:day  { notes } — one day's sheet
  fastify.patch('/challenges/:cid/notes/:day', async (request, reply) => {
    const { cid, day } = dayParam.parse(request.params);
    const parsed = z.object({ notes: z.string().max(20000) }).safeParse(request.body);
    if (!parsed.success) return validationError(reply, parsed.error.flatten());
    const userId = request.user.userId;
    const ctx = await loadChallenge(reply, cid, userId);
    if (!ctx) return;
    if (day > ctx.challenge.totalDays) {
      return fail(reply, 400, 'OUT_OF_RANGE', 'That day is outside this challenge');
    }
    const p = await prisma.challengeParticipant.findUnique({
      where: { challengeId_userId: { challengeId: cid, userId } },
    });
    if (!p) return fail(reply, 404, 'NOT_FOUND', 'Not participating');
    await prisma.challengeDayNote.upsert({
      where: { participantId_dayNumber: { participantId: p.id, dayNumber: day } },
      create: { participantId: p.id, dayNumber: day, notes: parsed.data.notes },
      update: { notes: parsed.data.notes },
    });
    return reply.send({ success: true, data: { saved: true } });
  });

  // PATCH /community/challenges/:cid/notes  { notes } — legacy: day 1 sheet
  fastify.patch('/challenges/:cid/notes', async (request, reply) => {
    const { cid } = cidParam.parse(request.params);
    const parsed = z.object({ notes: z.string().max(20000) }).safeParse(request.body);
    if (!parsed.success) return validationError(reply, parsed.error.flatten());
    const userId = request.user.userId;
    if (!(await loadChallenge(reply, cid, userId))) return;
    const p = await prisma.challengeParticipant.findUnique({
      where: { challengeId_userId: { challengeId: cid, userId } },
    });
    if (!p) return fail(reply, 404, 'NOT_FOUND', 'Not participating');
    await prisma.challengeDayNote.upsert({
      where: { participantId_dayNumber: { participantId: p.id, dayNumber: 1 } },
      create: { participantId: p.id, dayNumber: 1, notes: parsed.data.notes },
      update: { notes: parsed.data.notes },
    });
    return reply.send({ success: true, data: { saved: true } });
  });

  // POST /community/challenges/:cid/share — post a snapshot of my notepad
  fastify.post(
    '/challenges/:cid/share',
    { config: { rateLimit: { max: 10, timeWindow: '1 minute' } } },
    async (request, reply) => {
      const { cid } = cidParam.parse(request.params);
      const userId = request.user.userId;
      const ctx = await loadChallenge(reply, cid, userId);
      if (!ctx) return;
      const { challenge, member } = ctx;
      if (!member || challenge.communityId === null) {
        return fail(reply, 400, 'NO_COMMUNITY', 'Personal challenges cannot be shared to a community');
      }
      if (member.role !== 'admin' && !member.community.membersCanChat) {
        return fail(reply, 403, 'CHAT_DISABLED', 'Only the admin can post in this community');
      }
      const body = z.object({ day: z.number().int().min(1).max(365).optional() }).safeParse(request.body ?? {});
      const p = await prisma.challengeParticipant.findUnique({
        where: { challengeId_userId: { challengeId: cid, userId } },
        include: {
          _count: { select: { checkins: true } },
          dayNotes: { orderBy: { dayNumber: 'desc' } },
        },
      });
      const sheet = p?.dayNotes.find(
        (n) => n.notes.trim() !== '' && (!body.success || body.data.day === undefined || n.dayNumber === body.data.day),
      );
      if (!p || !sheet) {
        return fail(reply, 400, 'EMPTY', 'Your notepad is empty');
      }
      const msg = await prisma.communityMessage.create({
        data: {
          communityId: challenge.communityId,
          authorId: userId,
          kind: 'notepad_share',
          body: sheet.notes.slice(0, 4000),
          payload: {
            challengeId: cid,
            title: challenge.title,
            day: sheet.dayNumber,
            completedDays: p._count.checkins,
            totalDays: challenge.totalDays,
          },
        },
      });
      return reply.status(201).send({ success: true, data: { messageId: msg.id } });
    },
  );

  // PATCH /community/challenges/:cid  { status: 'closed' }  — creator or admin
  fastify.patch('/challenges/:cid', async (request, reply) => {
    const { cid } = cidParam.parse(request.params);
    const userId = request.user.userId;
    const ctx = await loadChallenge(reply, cid, userId);
    if (!ctx) return;
    if (ctx.challenge.creatorId !== userId && ctx.member?.role !== 'admin') {
      return fail(reply, 403, 'FORBIDDEN', 'Only the creator or admin can close this');
    }
    await prisma.challenge.update({ where: { id: cid }, data: { status: 'closed' } });
    return reply.send({ success: true, data: { status: 'closed' } });
  });

  // DELETE /community/challenges/:cid — creator or admin
  fastify.delete('/challenges/:cid', async (request, reply) => {
    const { cid } = cidParam.parse(request.params);
    const userId = request.user.userId;
    const ctx = await loadChallenge(reply, cid, userId);
    if (!ctx) return;
    if (ctx.challenge.creatorId !== userId && ctx.member?.role !== 'admin') {
      return fail(reply, 403, 'FORBIDDEN', 'Only the creator or admin can delete this');
    }
    await prisma.challenge.delete({ where: { id: cid } });
    return reply.send({ success: true, data: { deleted: true } });
  });
};
