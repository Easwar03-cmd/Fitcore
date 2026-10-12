import type { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { authenticate } from '../plugins/authenticate';
import { prisma } from '../utils/db';
import { parseDateOnly } from '../utils/dates';
import { fail, validationError } from '../services/community-access';

// Private to-do list. EVERY query below is scoped by request.user.userId and no
// other module reads this table — it is never part of any admin/report path.

const dateStr = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);
const idParam = z.object({ id: z.string().min(1) });

const createSchema = z.object({
  title: z.string().trim().min(1).max(200),
  date: dateStr,
  repeatDaily: z.boolean().default(false),
});

const updateSchema = z
  .object({ title: z.string().trim().min(1).max(200), done: z.boolean() })
  .partial();

export const todoRoutes: FastifyPluginAsync = async (fastify) => {
  fastify.addHook('preHandler', authenticate);

  // GET /todo?date=YYYY-MM-DD — items for the day (repeating items are
  // materialised into per-day copies the first time a day is opened).
  fastify.get('/', async (request, reply) => {
    const userId = request.user.userId;
    const q = z.object({ date: dateStr }).safeParse(request.query);
    if (!q.success) return validationError(reply, 'date=YYYY-MM-DD is required');
    const date = parseDateOnly(q.data.date)!;

    const roots = await prisma.todoItem.findMany({
      where: { userId, repeatDaily: true, forDate: { lt: date } },
      select: { id: true, title: true },
    });
    if (roots.length > 0) {
      await prisma.todoItem.createMany({
        data: roots.map((r) => ({ userId, title: r.title, templateId: r.id, forDate: date })),
        skipDuplicates: true,
      });
    }

    const items = await prisma.todoItem.findMany({
      where: { userId, forDate: date, hidden: false },
      orderBy: { createdAt: 'asc' },
    });
    return reply.send({ success: true, data: items });
  });

  // POST /todo
  fastify.post('/', async (request, reply) => {
    const parsed = createSchema.safeParse(request.body);
    if (!parsed.success) return validationError(reply, parsed.error.flatten());
    const userId = request.user.userId;
    const count = await prisma.todoItem.count({ where: { userId } });
    if (count >= 2000) return fail(reply, 409, 'LIMIT_REACHED', 'Too many to-do items');
    const item = await prisma.todoItem.create({
      data: {
        userId,
        title: parsed.data.title,
        repeatDaily: parsed.data.repeatDaily,
        forDate: parseDateOnly(parsed.data.date)!,
      },
    });
    return reply.status(201).send({ success: true, data: item });
  });

  // PATCH /todo/:id
  fastify.patch('/:id', async (request, reply) => {
    const { id } = idParam.parse(request.params);
    const parsed = updateSchema.safeParse(request.body);
    if (!parsed.success) return validationError(reply, parsed.error.flatten());
    const r = await prisma.todoItem.updateMany({
      where: { id, userId: request.user.userId },
      data: parsed.data,
    });
    if (r.count === 0) return fail(reply, 404, 'NOT_FOUND', 'Item not found');
    return reply.send({ success: true, data: { updated: true } });
  });

  // DELETE /todo/:id — deleting a repeating root also stops future copies
  fastify.delete('/:id', async (request, reply) => {
    const { id } = idParam.parse(request.params);
    const userId = request.user.userId;
    const item = await prisma.todoItem.findFirst({ where: { id, userId } });
    if (!item) return fail(reply, 404, 'NOT_FOUND', 'Item not found');
    // A per-day copy of a repeating item is hidden, not deleted, so it is not
    // re-created the next time that day is opened.
    if (item.templateId) {
      await prisma.todoItem.update({ where: { id }, data: { hidden: true } });
      return reply.send({ success: true, data: { deleted: true } });
    }
    await prisma.$transaction([
      // Remove untouched copies of a repeating item.
      ...(item.repeatDaily
        ? [prisma.todoItem.deleteMany({ where: { userId, templateId: id, done: false } })]
        : []),
      prisma.todoItem.delete({ where: { id } }),
    ]);
    return reply.send({ success: true, data: { deleted: true } });
  });
};
