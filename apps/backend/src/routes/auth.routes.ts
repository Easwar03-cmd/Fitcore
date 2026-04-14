import type { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { userRepository } from '../repositories/user.repository';
import {
  hashPassword,
  verifyPassword,
  generateRefreshToken,
  decodeRefreshToken,
  hashRefreshToken,
  toUserDto,
} from '../services/auth.service';
import type { AuthResponse } from '@fitcore/shared';

// ─── Type augmentation for @fastify/jwt ───────────────────────────────────────

declare module '@fastify/jwt' {
  interface FastifyJWT {
    payload: { userId: string };
    user: { userId: string };
  }
}

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
  fastify.post('/signup', async (request, reply) => {
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

    const { email, name, password } = parsed.data;

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
  fastify.post('/login', async (request, reply) => {
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

    const { email, password } = parsed.data;

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
  fastify.post('/refresh', async (request, reply) => {
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
  fastify.post('/logout', async (request, reply) => {
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
};
