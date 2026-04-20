import type { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';

import { integrationsRepository } from '../repositories/integrations.repository';

// Supported third-party wearable providers.
const kProviders = ['fitbit', 'garmin', 'whoop', 'oura'] as const;
type Provider = (typeof kProviders)[number];

const providerSchema = z.enum(kProviders);

// OAuth callback body — sent by the mobile app after the user authorises.
// The mobile app opens the provider's OAuth URL in a browser, the provider
// redirects to a deep link (zenfit://oauth/callback?provider=fitbit&code=XXX),
// and the app forwards the code here for server-side token exchange.
const oauthCallbackSchema = z.object({
  provider: providerSchema,
  code: z.string().min(1),
  redirectUri: z.string().url(),
});

// ── OAuth client IDs / secrets (set in backend .env) ─────────────────────────
// FITBIT_CLIENT_ID, FITBIT_CLIENT_SECRET
// GARMIN_CONSUMER_KEY, GARMIN_CONSUMER_SECRET
// WHOOP_CLIENT_ID, WHOOP_CLIENT_SECRET
// OURA_CLIENT_ID, OURA_CLIENT_SECRET
// Each provider's token endpoint URL is also needed — see their developer docs.

async function exchangeCodeForTokens(
  provider: Provider,
  code: string,
  redirectUri: string,
): Promise<{ accessToken: string; refreshToken?: string; expiresAt?: Date }> {
  // Stub: replace each branch with a real fetch() to the provider's token endpoint.
  // Example for Fitbit:
  //   POST https://api.fitbit.com/oauth2/token
  //   Authorization: Basic base64(clientId:clientSecret)
  //   Body: grant_type=authorization_code&code=CODE&redirect_uri=REDIRECT_URI
  void provider; void code; void redirectUri;
  throw new Error(
    `OAuth token exchange for ${provider} is not yet configured. ` +
    `Set ${provider.toUpperCase()}_CLIENT_ID and ${provider.toUpperCase()}_CLIENT_SECRET in .env ` +
    `and implement the token exchange in integrations.routes.ts.`,
  );
}

// ─── Routes ───────────────────────────────────────────────────────────────────

export const integrationsRoutes: FastifyPluginAsync = async (fastify) => {
  // GET /api/v1/integrations/status — list connected wearables for the user
  fastify.get('/status', async (request, reply) => {
    try { await request.jwtVerify(); } catch {
      return reply.status(401).send({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Not authenticated' },
      });
    }
    const userId = request.user.userId;
    const connections = await integrationsRepository.getStatus(userId);
    // Return as map { provider → { connectedAt, updatedAt } } for easy lookup.
    const statusMap: Record<string, { connectedAt: string; updatedAt: string }> = {};
    for (const c of connections) {
      statusMap[c.provider] = {
        connectedAt: (c.connectedAt as Date).toISOString(),
        updatedAt: (c.updatedAt as Date).toISOString(),
      };
    }
    return reply.send({ success: true, data: statusMap });
  });

  // POST /api/v1/integrations/oauth/callback — exchange OAuth code for tokens
  fastify.post('/oauth/callback', async (request, reply) => {
    try { await request.jwtVerify(); } catch {
      return reply.status(401).send({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Not authenticated' },
      });
    }
    const userId = request.user.userId;

    const parsed = oauthCallbackSchema.safeParse(request.body);
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

    const { provider, code, redirectUri } = parsed.data;

    try {
      const tokens = await exchangeCodeForTokens(provider, code, redirectUri);
      const connection = await integrationsRepository.upsert(userId, {
        provider,
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        expiresAt: tokens.expiresAt,
      });
      return reply.status(201).send({ success: true, data: connection });
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'Token exchange failed';
      return reply.status(502).send({
        success: false,
        error: { code: 'OAUTH_ERROR', message: msg },
      });
    }
  });

  // DELETE /api/v1/integrations/:provider — disconnect a wearable
  fastify.delete('/:provider', async (request, reply) => {
    try { await request.jwtVerify(); } catch {
      return reply.status(401).send({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Not authenticated' },
      });
    }
    const userId = request.user.userId;
    const { provider } = request.params as { provider: string };

    const parsed = providerSchema.safeParse(provider);
    if (!parsed.success) {
      return reply.status(400).send({
        success: false,
        error: { code: 'INVALID_PROVIDER', message: `Unknown provider: ${provider}` },
      });
    }

    await integrationsRepository.disconnect(userId, parsed.data);
    return reply.send({ success: true, data: null });
  });
};
