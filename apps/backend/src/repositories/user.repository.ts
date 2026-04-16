import { prisma } from '../utils/db';
import type { Prisma } from '@prisma/client';

export type CreateUserData = {
  email: string;
  name: string;
  passwordHash: string;
};

export type CreateProfileData = {
  userId: string;
  fitnessGoal: string;
  activityLevel: string;
  targetWeightKg?: number | null;
  tdee: number;
};

export type UpdateUserStatsData = {
  heightCm?: number | null;
  dateOfBirth?: Date | null;
  gender?: string | null;
};

// Include profile in all user lookups so toUserDto can set hasProfile accurately.
const withProfile = { profile: true } satisfies Prisma.UserInclude;

export const userRepository = {
  findByEmail: (email: string) =>
    prisma.user.findUnique({ where: { email }, include: withProfile }),

  findById: (id: string) =>
    prisma.user.findUnique({ where: { id }, include: withProfile }),

  create: (data: CreateUserData) =>
    prisma.user.create({ data, include: withProfile }),

  setRefreshToken: (
    id: string,
    refreshTokenHash: string | null,
    refreshTokenExpiresAt: Date | null,
  ) =>
    prisma.user.update({
      where: { id },
      data: { refreshTokenHash, refreshTokenExpiresAt },
    }),

  updateStats: (id: string, data: UpdateUserStatsData) =>
    prisma.user.update({ where: { id }, data }),

  saveFcmToken: (id: string, fcmToken: string | null) =>
    prisma.user.update({ where: { id }, data: { fcmToken } }),

  updatePassword: (id: string, passwordHash: string) =>
    prisma.user.update({ where: { id }, data: { passwordHash } }),

  /** Returns all users that have a non-null FCM token. Used for push broadcasts. */
  findAllWithFcmToken: () =>
    prisma.user.findMany({
      where: { fcmToken: { not: null } },
      select: { id: true, name: true, fcmToken: true },
    }),

  upsertProfile: (data: CreateProfileData) =>
    prisma.userProfile.upsert({
      where: { userId: data.userId },
      create: data,
      update: {
        fitnessGoal: data.fitnessGoal,
        activityLevel: data.activityLevel,
        targetWeightKg: data.targetWeightKg ?? null,
        tdee: data.tdee,
      },
    }),

  createBodyStat: (userId: string, weightKg: number) =>
    prisma.bodyStat.create({ data: { userId, weightKg } }),
};
