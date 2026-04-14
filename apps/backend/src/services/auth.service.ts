import { scrypt, randomBytes, timingSafeEqual, createHash } from 'crypto';
import { promisify } from 'util';
import type { Prisma } from '@prisma/client';
import type { UserDto } from '@fitcore/shared';

type UserWithProfile = Prisma.UserGetPayload<{ include: { profile: true } }>;

const scryptAsync = promisify(scrypt);

// ─── Password hashing (scrypt, NIST-recommended) ──────────────────────────────

export async function hashPassword(password: string): Promise<string> {
  const salt = randomBytes(16).toString('hex');
  const buf = (await scryptAsync(password, salt, 64)) as Buffer;
  return `${salt}:${buf.toString('hex')}`;
}

export async function verifyPassword(
  password: string,
  stored: string,
): Promise<boolean> {
  const [salt, hash] = stored.split(':');
  if (!salt || !hash) return false;
  const hashBuf = Buffer.from(hash, 'hex');
  const derivedBuf = (await scryptAsync(password, salt, 64)) as Buffer;
  return timingSafeEqual(hashBuf, derivedBuf);
}

// ─── Opaque refresh tokens (randomBytes, stored hashed in DB) ─────────────────
// Format: base64url( userId + ':' + 128-hex-random )
// The userId prefix lets us find the user on refresh without a full-table scan.

const REFRESH_TOKEN_TTL_MS = 30 * 24 * 60 * 60 * 1000; // 30 days

export function generateRefreshToken(userId: string): {
  token: string;
  hash: string;
  expiresAt: Date;
} {
  const random = randomBytes(64).toString('hex');
  const token = Buffer.from(`${userId}:${random}`).toString('base64url');
  const hash = createHash('sha256').update(token).digest('hex');
  const expiresAt = new Date(Date.now() + REFRESH_TOKEN_TTL_MS);
  return { token, hash, expiresAt };
}

export function decodeRefreshToken(token: string): { userId: string } | null {
  try {
    const decoded = Buffer.from(token, 'base64url').toString('utf-8');
    const colonIndex = decoded.indexOf(':');
    if (colonIndex === -1) return null;
    const userId = decoded.slice(0, colonIndex);
    if (!userId) return null;
    return { userId };
  } catch {
    return null;
  }
}

export function hashRefreshToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

// ─── DTO mapper ───────────────────────────────────────────────────────────────

export function toUserDto(user: UserWithProfile): UserDto {
  return {
    id: user.id,
    email: user.email,
    name: user.name,
    avatarUrl: user.avatarUrl,
    dateOfBirth: user.dateOfBirth?.toISOString() ?? null,
    gender: user.gender,
    heightCm: user.heightCm,
    hasProfile: user.profile !== null,
    createdAt: user.createdAt.toISOString(),
  };
}
