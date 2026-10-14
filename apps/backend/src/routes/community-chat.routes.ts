import type { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { authenticate } from '../plugins/authenticate';
import { prisma } from '../utils/db';
import { sendPush } from '../utils/firebase';
import {
  createReadUrl,
  createUploadUrl,
  isMediaConfigured,
  mediaKindFor,
  MEDIA_LIMITS,
} from '../utils/media';
import { fail, requireMember, validationError } from '../services/community-access';

const idParam = z.object({ id: z.string().min(1) });
const msgParams = z.object({ id: z.string().min(1), mid: z.string().min(1) });

const postSchema = z
  .object({
    kind: z.enum(['text', 'update', 'media']),
    body: z.string().trim().max(4000).optional(),
    replyToId: z.string().min(1).optional(),
    mediaPath: z.string().min(1).max(300).optional(),
    mediaType: z.enum(['image', 'video', 'document']).optional(),
    mediaName: z.string().max(200).optional(),
  })
  .refine((v) => v.kind === 'media' ? Boolean(v.mediaPath && v.mediaType) : Boolean(v.body), {
    message: 'text/update need a body; media needs mediaPath and mediaType',
  });

const uploadSchema = z.object({
  contentType: z.string().min(3).max(100),
  sizeBytes: z.number().int().positive(),
});

const listSchema = z.object({
  before: z.string().datetime().optional(),
  after: z.string().datetime().optional(),
  limit: z.coerce.number().int().min(1).max(100).default(50),
});

const reportSchema = z
  .object({
    messageId: z.string().min(1).optional(),
    communityId: z.string().min(1).optional(),
    userId: z.string().min(1).optional(),
    reason: z.enum(['spam', 'harassment', 'inappropriate', 'other']),
  })
  .refine((v) => v.messageId || v.communityId || v.userId, 'a target is required');

const NOTIFY_LIMIT = 500;

export const communityChatRoutes: FastifyPluginAsync = async (fastify) => {
  fastify.addHook('preHandler', authenticate);

  // GET /community/:id/messages?before=&after=&limit=
  // Initial load: latest N. Polling: pass `after` = newest createdAt you have.
  fastify.get('/:id/messages', async (request, reply) => {
    const { id } = idParam.parse(request.params);
    const q = listSchema.safeParse(request.query);
    if (!q.success) return validationError(reply, q.error.flatten());
    const userId = request.user.userId;
    if (!(await requireMember(reply, id, userId))) return;

    const blocked = await prisma.communityBlock.findMany({
      where: { blockerId: userId },
      select: { blockedId: true },
    });

    const { before, after, limit } = q.data;
    const rows = await prisma.communityMessage.findMany({
      where: {
        communityId: id,
        authorId: { notIn: blocked.map((b) => b.blockedId) },
        ...(before ? { createdAt: { lt: new Date(before) } } : {}),
        ...(after ? { createdAt: { gt: new Date(after) } } : {}),
      },
      include: { author: { select: { id: true, name: true } } },
      orderBy: { createdAt: after ? 'asc' : 'desc' },
      take: limit,
    });
    if (!after) rows.reverse();

    const replyIds = [...new Set(rows.map((r) => r.replyToId).filter((v): v is string => !!v))];
    const replies = replyIds.length
      ? await prisma.communityMessage.findMany({
          where: { id: { in: replyIds }, communityId: id },
          select: { id: true, body: true, deletedAt: true, author: { select: { name: true } } },
        })
      : [];
    const replyMap = new Map(replies.map((r) => [r.id, r]));

    const data = await Promise.all(
      rows.map(async (m) => {
        const deleted = m.deletedAt !== null;
        const rt = m.replyToId ? replyMap.get(m.replyToId) : undefined;
        return {
          id: m.id,
          kind: m.kind,
          author: m.author,
          createdAt: m.createdAt,
          deleted,
          body: deleted ? null : m.body,
          mediaType: deleted ? null : m.mediaType,
          mediaName: deleted ? null : m.mediaName,
          mediaUrl: deleted || !m.mediaPath ? null : await createReadUrl(m.mediaPath),
          payload: deleted ? null : m.payload,
          replyTo: rt
            ? { id: rt.id, authorName: rt.author.name, body: rt.deletedAt ? null : rt.body }
            : null,
        };
      }),
    );
    return reply.send({ success: true, data });
  });

  // POST /community/:id/messages
  fastify.post(
    '/:id/messages',
    { config: { rateLimit: { max: 40, timeWindow: '1 minute' } } },
    async (request, reply) => {
      const { id } = idParam.parse(request.params);
      const parsed = postSchema.safeParse(request.body);
      if (!parsed.success) return validationError(reply, parsed.error.flatten());
      const me = await requireMember(reply, id, request.user.userId);
      if (!me) return;

      const isAdminUser = me.role === 'admin';
      if (parsed.data.kind === 'update' && !isAdminUser) {
        return fail(reply, 403, 'FORBIDDEN', 'Only the admin can post updates');
      }
      if (!isAdminUser && !me.community.membersCanChat) {
        return fail(reply, 403, 'CHAT_DISABLED', 'Only the admin can post in this community');
      }
      const d = parsed.data;
      if (d.mediaPath && !d.mediaPath.startsWith(`community/${id}/`)) {
        return fail(reply, 400, 'INVALID_MEDIA', 'Invalid media path');
      }
      if (d.replyToId) {
        const target = await prisma.communityMessage.findFirst({
          where: { id: d.replyToId, communityId: id },
          select: { id: true },
        });
        if (!target) return fail(reply, 400, 'INVALID_REPLY', 'Reply target not found');
      }

      const msg = await prisma.communityMessage.create({
        data: {
          communityId: id,
          authorId: me.userId,
          kind: d.kind,
          body: d.body,
          replyToId: d.replyToId,
          mediaPath: d.mediaPath,
          mediaType: d.mediaType,
          mediaName: d.mediaName,
        },
        include: { author: { select: { id: true, name: true } } },
      });

      void notifyMembers(id, me.userId, me.community.name, msg.author.name, d.body ?? 'sent an attachment');

      return reply.status(201).send({
        success: true,
        data: {
          id: msg.id,
          kind: msg.kind,
          author: msg.author,
          createdAt: msg.createdAt,
          deleted: false,
          body: msg.body,
          mediaType: msg.mediaType,
          mediaName: msg.mediaName,
          mediaUrl: msg.mediaPath ? await createReadUrl(msg.mediaPath) : null,
          payload: null,
          replyTo: null,
        },
      });
    },
  );

  // DELETE /community/:id/messages/:mid — author or admin
  fastify.delete('/:id/messages/:mid', async (request, reply) => {
    const { id, mid } = msgParams.parse(request.params);
    const me = await requireMember(reply, id, request.user.userId);
    if (!me) return;
    const msg = await prisma.communityMessage.findFirst({ where: { id: mid, communityId: id } });
    if (!msg) return fail(reply, 404, 'NOT_FOUND', 'Message not found');
    if (msg.authorId !== me.userId && me.role !== 'admin') {
      return fail(reply, 403, 'FORBIDDEN', 'You cannot delete this message');
    }
    await prisma.communityMessage.update({
      where: { id: mid },
      data: { deletedAt: new Date(), body: null, mediaPath: null, payload: undefined },
    });
    return reply.send({ success: true, data: { deleted: true } });
  });

  // POST /community/:id/media/upload-url — signed PUT URL for direct upload
  fastify.post(
    '/:id/media/upload-url',
    { config: { rateLimit: { max: 20, timeWindow: '1 minute' } } },
    async (request, reply) => {
      const { id } = idParam.parse(request.params);
      const parsed = uploadSchema.safeParse(request.body);
      if (!parsed.success) return validationError(reply, parsed.error.flatten());
      const me = await requireMember(reply, id, request.user.userId);
      if (!me) return;
      if (me.role !== 'admin' && !me.community.membersCanChat) {
        return fail(reply, 403, 'CHAT_DISABLED', 'Only the admin can post in this community');
      }
      if (!isMediaConfigured()) {
        return fail(reply, 503, 'MEDIA_UNAVAILABLE', 'Media uploads are not available right now');
      }
      const kind = mediaKindFor(parsed.data.contentType);
      if (!kind) return fail(reply, 400, 'UNSUPPORTED_TYPE', 'This file type is not allowed');
      if (parsed.data.sizeBytes > MEDIA_LIMITS[kind]) {
        return fail(reply, 413, 'TOO_LARGE', `Max size for ${kind} is ${MEDIA_LIMITS[kind] / (1024 * 1024)} MB`);
      }
      const { uploadUrl, objectPath } = await createUploadUrl(id, parsed.data.contentType);
      return reply.send({
        success: true,
        data: { uploadUrl, objectPath, mediaType: kind, contentType: parsed.data.contentType },
      });
    },
  );
};

// ─── Helpers ──────────────────────────────────────────────────────────────────

async function notifyMembers(
  communityId: string,
  authorId: string,
  communityName: string,
  authorName: string,
  preview: string,
): Promise<void> {
  try {
    const recipients = await prisma.communityMember.findMany({
      where: {
        communityId,
        status: { in: ['active', 'on_hold'] },
        userId: { not: authorId },
        user: {
          fcmToken: { not: null },
          blocksMade: { none: { blockedId: authorId } },
        },
      },
      select: { user: { select: { fcmToken: true } } },
      take: NOTIFY_LIMIT,
    });
    const body = `${authorName}: ${preview.slice(0, 100)}`;
    await Promise.allSettled(
      recipients.map((r) =>
        r.user.fcmToken
          ? sendPush(r.user.fcmToken, communityName, body, { type: 'community', communityId })
          : Promise.resolve(false),
      ),
    );
  } catch {
    // Push is best-effort; never fail a message post because of it.
  }
}

// Exported separately so report/block live with other user-safety routes.
export const communitySafetyRoutes: FastifyPluginAsync = async (fastify) => {
  fastify.addHook('preHandler', authenticate);

  // POST /community/report — flag a message, community or user (Play UGC policy)
  fastify.post('/report', async (request, reply) => {
    const parsed = reportSchema.safeParse(request.body);
    if (!parsed.success) return validationError(reply, parsed.error.flatten());
    const row = await prisma.communityReport.create({
      data: { reporterId: request.user.userId, ...parsed.data },
    });
    request.log.warn({ communityReport: row }, '[community report] content flagged');
    return reply.status(201).send({ success: true, data: { received: true } });
  });

  // POST /community/block   { userId }
  fastify.post('/block', async (request, reply) => {
    const parsed = z.object({ userId: z.string().min(1) }).safeParse(request.body);
    if (!parsed.success) return validationError(reply, parsed.error.flatten());
    const me = request.user.userId;
    if (parsed.data.userId === me) return fail(reply, 400, 'INVALID', 'You cannot block yourself');
    await prisma.communityBlock.upsert({
      where: { blockerId_blockedId: { blockerId: me, blockedId: parsed.data.userId } },
      create: { blockerId: me, blockedId: parsed.data.userId },
      update: {},
    });
    return reply.send({ success: true, data: { blocked: true } });
  });

  // DELETE /community/block/:userId
  fastify.delete('/block/:userId', async (request, reply) => {
    const { userId } = request.params as { userId: string };
    await prisma.communityBlock.deleteMany({
      where: { blockerId: request.user.userId, blockedId: userId },
    });
    return reply.send({ success: true, data: { blocked: false } });
  });
};
