import { prisma } from '../utils/db';

export type UpsertWearableData = {
  provider: string;
  accessToken: string;
  refreshToken?: string;
  expiresAt?: Date;
};

export const integrationsRepository = {
  /** Return all wearable connections for a user (tokens excluded from response). */
  getStatus: (userId: string) =>
    prisma.wearableConnection.findMany({
      where: { userId },
      select: {
        provider: true,
        connectedAt: true,
        updatedAt: true,
        // Never expose tokens to the client
        accessToken: false,
        refreshToken: false,
      },
    }),

  /** Upsert a wearable connection (called after OAuth exchange on backend). */
  upsert: (userId: string, data: UpsertWearableData) =>
    prisma.wearableConnection.upsert({
      where: { userId_provider: { userId, provider: data.provider } },
      create: {
        userId,
        provider: data.provider,
        accessToken: data.accessToken,
        refreshToken: data.refreshToken,
        expiresAt: data.expiresAt,
      },
      update: {
        accessToken: data.accessToken,
        refreshToken: data.refreshToken,
        expiresAt: data.expiresAt,
      },
      select: { provider: true, connectedAt: true, updatedAt: true },
    }),

  /** Remove a wearable connection (disconnect). */
  disconnect: (userId: string, provider: string) =>
    prisma.wearableConnection.deleteMany({
      where: { userId, provider },
    }),

  /** Retrieve the stored tokens for a provider (backend use only — sync jobs). */
  getTokens: (userId: string, provider: string) =>
    prisma.wearableConnection.findUnique({
      where: { userId_provider: { userId, provider } },
      select: { accessToken: true, refreshToken: true, expiresAt: true },
    }),
};
