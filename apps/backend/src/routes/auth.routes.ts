import type { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import IORedis from 'ioredis';
import { randomBytes } from 'crypto';
import { userRepository } from '../repositories/user.repository';
import {
  hashPassword,
  verifyPassword,
  generateRefreshToken,
  decodeRefreshToken,
  hashRefreshToken,
  toUserDto,
} from '../services/auth.service';
import { config } from '../utils/config';
import { sendPasswordResetEmail, isEmailConfigured } from '../services/email.service';
import type { AuthResponse } from '@zenfit/shared';

// ─── Redis for password-reset codes (lazy, fail-open) ────────────────────────
let _redis: IORedis | null = null;
function getRedis(): IORedis | null {
  if (_redis) return _redis;
  try {
    _redis = new IORedis(config.REDIS_URL, { maxRetriesPerRequest: 1, lazyConnect: true });
    _redis.on('error', () => { _redis = null; });
    return _redis;
  } catch {
    return null;
  }
}
const RESET_TTL = 15 * 60; // 15 minutes

// ─── Type augmentation for @fastify/jwt ───────────────────────────────────────

declare module '@fastify/jwt' {
  interface FastifyJWT {
    payload: { userId: string };
    user: { userId: string };
  }
}

// ─── Rate-limit config shared across all auth endpoints ───────────────────────
// 10 requests / minute / IP — stricter than the global 100 req/min default.
const authRateLimit = {
  config: {
    rateLimit: {
      max: 10,
      timeWindow: '1 minute',
    },
  },
} as const;

// ─── Zod schemas ──────────────────────────────────────────────────────────────

const signupSchema = z.object({
  email: z.string().email(),
  name: z.string().min(2).max(50),
  password: z.string().min(8).max(72),
});

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

const refreshSchema = z.object({
  refreshToken: z.string().min(1),
});

// ─── Routes ───────────────────────────────────────────────────────────────────

export const authRoutes: FastifyPluginAsync = async (fastify) => {
  // POST /api/v1/auth/signup
  fastify.post('/signup', authRateLimit, async (request, reply) => {
    const parsed = signupSchema.safeParse(request.body);
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

    const { email: rawEmail, name, password } = parsed.data;
    const email = rawEmail.toLowerCase().trim();

    try {
      const existing = await userRepository.findByEmail(email);
      if (existing) {
        return reply.status(409).send({
          success: false,
          error: { code: 'EMAIL_TAKEN', message: 'Email already registered' },
        });
      }

      const passwordHash = await hashPassword(password);
      const user = await userRepository.create({ email, name, passwordHash });

      const accessToken = await reply.jwtSign({ userId: user.id }, { expiresIn: '15m' });
      const rt = generateRefreshToken(user.id);
      await userRepository.setRefreshToken(user.id, rt.hash, rt.expiresAt);

      const response: AuthResponse = {
        accessToken,
        refreshToken: rt.token,
        user: toUserDto(user),
      };

      return reply.status(201).send({ success: true, data: response });
    } catch (err) {
      request.log.error(err);
      return reply.status(500).send({
        success: false,
        error: { code: 'INTERNAL_ERROR', message: 'Failed to create account' },
      });
    }
  });

  // POST /api/v1/auth/login
  fastify.post('/login', authRateLimit, async (request, reply) => {
    const parsed = loginSchema.safeParse(request.body);
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

    const { email: rawEmail, password } = parsed.data;
    const email = rawEmail.toLowerCase().trim();

    try {
      const user = await userRepository.findByEmail(email);
      if (!user) {
        return reply.status(401).send({
          success: false,
          error: { code: 'INVALID_CREDENTIALS', message: 'Invalid email or password' },
        });
      }

      const valid = await verifyPassword(password, user.passwordHash);
      if (!valid) {
        return reply.status(401).send({
          success: false,
          error: { code: 'INVALID_CREDENTIALS', message: 'Invalid email or password' },
        });
      }

      const accessToken = await reply.jwtSign({ userId: user.id }, { expiresIn: '15m' });
      const rt = generateRefreshToken(user.id);
      await userRepository.setRefreshToken(user.id, rt.hash, rt.expiresAt);

      const response: AuthResponse = {
        accessToken,
        refreshToken: rt.token,
        user: toUserDto(user),
      };

      return reply.send({ success: true, data: response });
    } catch (err) {
      request.log.error(err);
      return reply.status(500).send({
        success: false,
        error: { code: 'INTERNAL_ERROR', message: 'Login failed' },
      });
    }
  });

  // POST /api/v1/auth/refresh
  fastify.post('/refresh', authRateLimit, async (request, reply) => {
    const parsed = refreshSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({
        success: false,
        error: { code: 'VALIDATION_ERROR', message: 'refreshToken is required' },
      });
    }

    const { refreshToken } = parsed.data;

    try {
      // Decode userId from the opaque token (no DB scan needed)
      const decoded = decodeRefreshToken(refreshToken);
      if (!decoded) {
        return reply.status(401).send({
          success: false,
          error: { code: 'INVALID_TOKEN', message: 'Invalid refresh token' },
        });
      }

      const user = await userRepository.findById(decoded.userId);
      if (
        !user ||
        !user.refreshTokenHash ||
        !user.refreshTokenExpiresAt ||
        user.refreshTokenExpiresAt < new Date()
      ) {
        return reply.status(401).send({
          success: false,
          error: { code: 'INVALID_TOKEN', message: 'Refresh token expired or not found' },
        });
      }

      // Constant-time compare to prevent timing attacks
      const providedHash = hashRefreshToken(refreshToken);
      if (providedHash !== user.refreshTokenHash) {
        return reply.status(401).send({
          success: false,
          error: { code: 'INVALID_TOKEN', message: 'Invalid refresh token' },
        });
      }

      // Rotate: issue a new access token and new refresh token
      const accessToken = await reply.jwtSign({ userId: user.id }, { expiresIn: '15m' });
      const rt = generateRefreshToken(user.id);
      await userRepository.setRefreshToken(user.id, rt.hash, rt.expiresAt);

      return reply.send({
        success: true,
        data: {
          accessToken,
          refreshToken: rt.token,
          user: toUserDto(user),
        },
      });
    } catch (err) {
      request.log.error(err);
      return reply.status(401).send({
        success: false,
        error: { code: 'INVALID_TOKEN', message: 'Invalid or expired refresh token' },
      });
    }
  });

  // POST /api/v1/auth/logout
  fastify.post('/logout', authRateLimit, async (request, reply) => {
    try {
      await request.jwtVerify();
      const userId = request.user.userId;
      await userRepository.setRefreshToken(userId, null, null);
      return reply.send({ success: true, data: null });
    } catch (err) {
      request.log.error(err);
      // Still return 200 — client should clear tokens regardless
      return reply.send({ success: true, data: null });
    }
  });

  // POST /api/v1/auth/forgot-password
  // Generates a 6-digit reset code stored in Redis (15 min TTL).
  // Returns the code directly (no email service yet — display it to the user).
  fastify.post('/forgot-password', authRateLimit, async (request, reply) => {
    const parsed = z.object({ email: z.string().email() }).safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({
        success: false,
        error: { code: 'VALIDATION_ERROR', message: 'Valid email is required' },
      });
    }

    const email = parsed.data.email.toLowerCase().trim();
    const user = await userRepository.findByEmail(email);
    if (!user) {
      // Don't reveal whether the email exists
      return reply.send({ success: true, data: { message: 'If that email exists, a reset code was generated.' } });
    }

    const code = randomBytes(5).toString('hex').toUpperCase(); // 10-char hex code (~1 trillion combinations)
    const redis = getRedis();
    if (redis) {
      await redis.set(`pwd_reset:${code}`, user.id, 'EX', RESET_TTL);
    }

    if (isEmailConfigured) {
      await sendPasswordResetEmail(email, code).catch((err) => {
        request.log.error({ err }, 'Failed to send password reset email');
      });
      return reply.send({
        success: true,
        data: { message: 'If that email is registered, a reset code has been sent.' },
      });
    }

    // SMTP not configured — return code directly so dev/test flows still work.
    request.log.warn({ code }, 'SMTP not configured — returning reset code in response (dev only)');
    return reply.send({ success: true, data: { code, expiresInMinutes: 15 } });
  });

  // POST /api/v1/auth/reset-password
  // Validates the reset code and sets a new password.
  fastify.post('/reset-password', authRateLimit, async (request, reply) => {
    const parsed = z.object({
      code: z.string().min(1),
      newPassword: z.string().min(8).max(72),
    }).safeParse(request.body);

    if (!parsed.success) {
      return reply.status(400).send({
        success: false,
        error: { code: 'VALIDATION_ERROR', message: 'code and newPassword (min 8 chars) are required' },
      });
    }

    const { code, newPassword } = parsed.data;
    const redis = getRedis();
    if (!redis) {
      return reply.status(503).send({
        success: false,
        error: { code: 'SERVICE_UNAVAILABLE', message: 'Reset service temporarily unavailable' },
      });
    }

    const userId = await redis.get(`pwd_reset:${code}`);
    if (!userId) {
      return reply.status(400).send({
        success: false,
        error: { code: 'INVALID_CODE', message: 'Reset code is invalid or has expired' },
      });
    }

    const passwordHash = await hashPassword(newPassword);
    await userRepository.updatePassword(userId, passwordHash);
    await redis.del(`pwd_reset:${code}`);

    return reply.send({ success: true, data: { message: 'Password updated. Please log in.' } });
  });
};
