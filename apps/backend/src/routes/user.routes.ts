import type { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { userRepository } from '../repositories/user.repository';
import { toUserDto } from '../services/auth.service';
import { prisma } from '../utils/db';
import type { UserProfileDto } from '@zenfit/shared';

// ─── TDEE calculation (Mifflin-St Jeor, matches CLAUDE.md spec) ──────────────

function ageFromDob(dateOfBirth: Date): number {
  const now = new Date();
  let age = now.getFullYear() - dateOfBirth.getFullYear();
  const m = now.getMonth() - dateOfBirth.getMonth();
  if (m < 0 || (m === 0 && now.getDate() < dateOfBirth.getDate())) age--;
  return age;
}

const ACTIVITY_MULTIPLIERS: Record<string, number> = {
  sedentary: 1.2,
  light: 1.375,
  moderate: 1.55,
  active: 1.725,
  very_active: 1.9,
};

function calculateTdee(
  weightKg: number,
  heightCm: number,
  ageYears: number,
  gender: string,
  activityLevel: string,
): number {
  const base = 10 * weightKg + 6.25 * heightCm - 5 * ageYears;
  // Use male formula only for 'male'; everything else uses female formula
  const bmr = gender === 'male' ? base + 5 : base - 161;
  const multiplier = ACTIVITY_MULTIPLIERS[activityLevel] ?? 1.55;
  return Math.round(bmr * multiplier);
}

// ─── Zod schemas ──────────────────────────────────────────────────────────────

const createProfileSchema = z.object({
  fitnessGoal: z.enum(['lose_weight', 'build_muscle', 'maintain', 'endurance']),
  activityLevel: z.enum(['sedentary', 'light', 'moderate', 'active', 'very_active']),
  heightCm: z.number().min(50).max(300),
  weightKg: z.number().min(20).max(500),
  dateOfBirth: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Must be YYYY-MM-DD'),
  gender: z.enum(['male', 'female', 'other', 'prefer_not_to_say']),
});

// ─── Routes ───────────────────────────────────────────────────────────────────

export const userRoutes: FastifyPluginAsync = async (fastify) => {
  // GET /api/v1/user/profile
  fastify.get('/profile', async (request, reply) => {
    try {
      await request.jwtVerify();
      const user = await userRepository.findById(request.user.userId);
      if (!user) {
        return reply.status(404).send({
          success: false,
          error: { code: 'NOT_FOUND', message: 'User not found' },
        });
      }
      if (!user.profile) {
        return reply.status(404).send({
          success: false,
          error: { code: 'NO_PROFILE', message: 'Profile not yet created' },
        });
      }
      const profile: UserProfileDto = {
        fitnessGoal: user.profile.fitnessGoal as UserProfileDto['fitnessGoal'],
        activityLevel: user.profile.activityLevel as UserProfileDto['activityLevel'],
        targetWeightKg: user.profile.targetWeightKg,
        tdee: user.profile.tdee,
      };
      return reply.send({ success: true, data: { user: toUserDto(user), profile } });
    } catch (err) {
      request.log.error(err);
      return reply.status(401).send({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Not authenticated' },
      });
    }
  });

  // POST /api/v1/user/profile
  fastify.post('/profile', async (request, reply) => {
    try {
      await request.jwtVerify();
    } catch {
      return reply.status(401).send({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Not authenticated' },
      });
    }

    const parsed = createProfileSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({
        success: false,
        error: {
          code: 'VALIDATION_ERROR',
          message: 'Invalid request body',
          details: parsed.error.flatten(),
        },
      });
    }

    const { fitnessGoal, activityLevel, heightCm, weightKg, dateOfBirth, gender } = parsed.data;
    const userId = request.user.userId;

    try {
      const dob = new Date(dateOfBirth);
      const age = ageFromDob(dob);
      const tdee = calculateTdee(weightKg, heightCm, age, gender, activityLevel);

      // Run all mutations in a transaction so they succeed or fail together
      await prisma.$transaction([
        prisma.user.update({
          where: { id: userId },
          data: { heightCm, dateOfBirth: dob, gender },
        }),
        prisma.userProfile.upsert({
          where: { userId },
          create: { userId, fitnessGoal, activityLevel, tdee },
          update: { fitnessGoal, activityLevel, tdee },
        }),
        prisma.bodyStat.create({ data: { userId, weightKg } }),
      ]);

      // Re-fetch updated user with profile for the response
      const updatedUser = await userRepository.findById(userId);
      if (!updatedUser) throw new Error('User disappeared after update');

      const profile: UserProfileDto = {
        fitnessGoal: updatedUser.profile!.fitnessGoal as UserProfileDto['fitnessGoal'],
        activityLevel: updatedUser.profile!.activityLevel as UserProfileDto['activityLevel'],
        targetWeightKg: updatedUser.profile!.targetWeightKg,
        tdee: updatedUser.profile!.tdee,
      };

      return reply.status(201).send({
        success: true,
        data: { user: toUserDto(updatedUser), profile },
      });
    } catch (err) {
      request.log.error(err);
      return reply.status(500).send({
        success: false,
        error: { code: 'INTERNAL_ERROR', message: 'Failed to save profile' },
      });
    }
  });

  // POST /api/v1/user/fcm-token
  // Stores or clears the device's FCM push token for server-sent notifications.
  const fcmTokenSchema = z.object({
    token: z.string().min(1).max(4096).nullable(),
  });

  fastify.post('/fcm-token', async (request, reply) => {
    try {
      await request.jwtVerify();
    } catch {
      return reply.status(401).send({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Not authenticated' },
      });
    }

    const parsed = fcmTokenSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({
        success: false,
        error: {
          code: 'VALIDATION_ERROR',
          message: 'Invalid request body',
          details: parsed.error.flatten(),
        },
      });
    }

    try {
      await userRepository.saveFcmToken(request.user.userId, parsed.data.token);
      return reply.send({ success: true, data: { ok: true } });
    } catch (err) {
      request.log.error(err);
      return reply.status(500).send({
        success: false,
        error: { code: 'INTERNAL_ERROR', message: 'Failed to save FCM token' },
      });
    }
  });

  // GET /api/v1/user/stats
  fastify.get('/stats', async (_request, reply) => {
    return reply.status(501).send({
      success: false,
      error: { code: 'NOT_IMPLEMENTED', message: 'Coming soon' },
    });
  });
};
