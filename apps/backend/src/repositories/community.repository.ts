import { randomBytes } from 'crypto';
import { prisma } from '../utils/db';

// No 0/O/1/I to keep codes easy to read out loud.
const CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

export function generateInviteCode(): string {
  const bytes = randomBytes(8);
  return Array.from(bytes, (b) => CODE_ALPHABET[b % CODE_ALPHABET.length]).join('');
}

export type CommunitySettings = {
  name?: string;
  description?: string | null;
  isPublic?: boolean;
  requireApproval?: boolean;
  membersCanChat?: boolean;
  membersCanInvite?: boolean;
};

export const communityRepository = {
  create: (adminId: string, data: { name: string; description?: string; isPublic: boolean }) =>
    prisma.community.create({
      data: {
        name: data.name,
        nameLower: data.name.toLowerCase(),
        description: data.description,
        isPublic: data.isPublic,
        adminId,
        inviteCode: generateInviteCode(),
        members: {
          create: { userId: adminId, role: 'admin', status: 'active' },
        },
      },
    }),

  listForUser: async (userId: string) => {
    const rows = await prisma.communityMember.findMany({
      where: { userId, status: { in: ['active', 'on_hold', 'pending'] } },
      include: {
        community: {
          include: {
            _count: { select: { members: { where: { status: { in: ['active', 'on_hold'] } } } } },
            messages: {
              where: { deletedAt: null },
              orderBy: { createdAt: 'desc' },
              take: 1,
              select: { body: true, kind: true, createdAt: true },
            },
          },
        },
      },
      orderBy: { joinedAt: 'desc' },
    });
    return rows.map((m) => ({
      id: m.community.id,
      name: m.community.name,
      description: m.community.description,
      avatarUrl: m.community.avatarUrl,
      role: m.role,
      status: m.status,
      shareReport: m.shareReport,
      memberCount: m.community._count.members,
      lastMessage: m.community.messages[0] ?? null,
    }));
  },

  search: (q: string, take = 20) =>
    prisma.community.findMany({
      where: { isPublic: true, nameLower: { contains: q.toLowerCase() } },
      take,
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        name: true,
        description: true,
        avatarUrl: true,
        requireApproval: true,
        _count: { select: { members: { where: { status: { in: ['active', 'on_hold'] } } } } },
      },
    }),

  findByCode: (code: string) =>
    prisma.community.findUnique({
      where: { inviteCode: code },
      select: {
        id: true,
        name: true,
        description: true,
        avatarUrl: true,
        requireApproval: true,
        _count: { select: { members: { where: { status: { in: ['active', 'on_hold'] } } } } },
      },
    }),

  findPublicById: (id: string) =>
    prisma.community.findFirst({ where: { id, isPublic: true } }),

  /** Creates or reactivates a membership. Re-joining always starts untracked. */
  join: (communityId: string, userId: string, needsApproval: boolean) =>
    prisma.communityMember.upsert({
      where: { communityId_userId: { communityId, userId } },
      create: {
        communityId,
        userId,
        status: needsApproval ? 'pending' : 'active',
      },
      update: {
        status: needsApproval ? 'pending' : 'active',
        shareReport: false,
        consentAt: null,
        heldAt: null,
        leftAt: null,
        joinedAt: new Date(),
      },
    }),

  update: (id: string, data: CommunitySettings) =>
    prisma.community.update({
      where: { id },
      data: {
        ...data,
        ...(data.name ? { nameLower: data.name.toLowerCase() } : {}),
      },
    }),

  regenerateInvite: (id: string) =>
    prisma.community.update({ where: { id }, data: { inviteCode: generateInviteCode() } }),

  remove: (id: string) => prisma.community.delete({ where: { id } }),

  /** Admins also see pending requests and members who left holding a frozen report. */
  listMembers: (communityId: string, asAdmin: boolean) =>
    prisma.communityMember.findMany({
      where: {
        communityId,
        OR: [
          { status: { in: ['active', 'on_hold'] } },
          ...(asAdmin ? [{ status: 'pending' }, { status: 'left', shareReport: true }] : []),
        ],
      },
      include: { user: { select: { id: true, name: true, avatarUrl: true } } },
      orderBy: [{ role: 'asc' }, { joinedAt: 'asc' }],
    }),
};
