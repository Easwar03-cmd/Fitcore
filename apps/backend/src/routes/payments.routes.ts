import type { FastifyPluginAsync } from 'fastify';
import { GoogleAuth } from 'google-auth-library';
import Stripe from 'stripe';
import { z } from 'zod';
import { config } from '../utils/config';
import { prisma } from '../utils/db';

const stripe = new Stripe(config.STRIPE_SECRET_KEY);

const PRICE_IDS: Record<string, string | undefined> = {
  pro: config.STRIPE_PRO_PRICE_ID,
  coach: config.STRIPE_COACH_PRICE_ID,
};

const BASE_URL = 'https://zenfit-api-122167595419.us-central1.run.app';

// ─── Helpers ──────────────────────────────────────────────────────────────────

async function getOrCreateCustomer(userId: string, email: string): Promise<string> {
  const sub = await prisma.subscription.findUnique({ where: { userId } });
  if (sub?.stripeCustomerId) return sub.stripeCustomerId;

  const customer = await stripe.customers.create({ email, metadata: { userId } });

  await prisma.subscription.upsert({
    where: { userId },
    create: { userId, tier: 'free', stripeCustomerId: customer.id },
    update: { stripeCustomerId: customer.id },
  });

  return customer.id;
}

function tierFromPriceId(priceId: string): 'pro' | 'coach' | 'free' {
  if (priceId === config.STRIPE_PRO_PRICE_ID) return 'pro';
  if (priceId === config.STRIPE_COACH_PRICE_ID) return 'coach';
  return 'free';
}

// ─── Google Play helpers ──────────────────────────────────────────────────────

const GOOGLE_PLAY_PRODUCT_TIERS: Record<string, 'pro' | 'coach'> = {
  zenfit_pro_monthly: 'pro',
  zenfit_coach_monthly: 'coach',
};

interface GooglePlaySubscriptionResponse {
  expiryTimeMillis?: string;
  cancelReason?: number;
  paymentState?: number;
  autoRenewing?: boolean;
  kind?: string;
}

async function verifyGooglePlayPurchase(
  packageName: string,
  subscriptionId: string,
  purchaseToken: string,
): Promise<GooglePlaySubscriptionResponse> {
  const serviceAccountJson = config.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON;
  if (!serviceAccountJson) throw new Error('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON not configured');

  const auth = new GoogleAuth({
    credentials: JSON.parse(serviceAccountJson),
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  });
  const client = await auth.getClient();
  const tokenResponse = await client.getAccessToken();
  const accessToken = tokenResponse.token;

  const url =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications` +
    `/${packageName}/purchases/subscriptions/${subscriptionId}/tokens/${purchaseToken}`;

  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  if (!res.ok) {
    const body = await res.text();
    throw new Error(`Google Play API error ${res.status}: ${body}`);
  }

  return res.json() as Promise<GooglePlaySubscriptionResponse>;
}

// ─── Routes ───────────────────────────────────────────────────────────────────

export const paymentsRoutes: FastifyPluginAsync = async (fastify) => {
  // ── GET /api/v1/payments/subscription ────────────────────────────────────────
  fastify.get('/subscription', async (request, reply) => {
    try {
      await request.jwtVerify();
    } catch {
      return reply.status(401).send({ success: false, error: { code: 'UNAUTHORIZED', message: 'Not authenticated' } });
    }

    const { userId } = request.user;

    if (config.BETA_MODE === 'true') {
      return reply.send({
        success: true,
        data: { tier: 'pro', validUntil: null, stripeId: null },
      });
    }

    const sub = await prisma.subscription.findUnique({ where: { userId } });

    return reply.send({
      success: true,
      data: {
        tier: sub?.tier ?? 'free',
        validUntil: sub?.validUntil?.toISOString() ?? null,
        stripeId: sub?.stripeId ?? null,
      },
    });
  });

  // ── POST /api/v1/payments/checkout ───────────────────────────────────────────
  fastify.post('/checkout', async (request, reply) => {
    try {
      await request.jwtVerify();
    } catch {
      return reply.status(401).send({ success: false, error: { code: 'UNAUTHORIZED', message: 'Not authenticated' } });
    }

    const { userId } = request.user;
    const parsed = z.object({ tier: z.enum(['pro', 'coach']) }).safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({ success: false, error: { code: 'VALIDATION_ERROR', message: 'tier must be pro or coach' } });
    }

    const priceId = PRICE_IDS[parsed.data.tier];
    if (!priceId) {
      return reply.status(503).send({
        success: false,
        error: { code: 'NOT_CONFIGURED', message: `${parsed.data.tier.toUpperCase()} price ID not configured on server` },
      });
    }

    const user = await prisma.user.findUnique({ where: { id: userId }, select: { email: true } });
    if (!user) return reply.status(404).send({ success: false, error: { code: 'NOT_FOUND', message: 'User not found' } });

    try {
      const customerId = await getOrCreateCustomer(userId, user.email);

      const session = await stripe.checkout.sessions.create({
        customer: customerId,
        mode: 'subscription',
        line_items: [{ price: priceId, quantity: 1 }],
        success_url: `${BASE_URL}/payment/success?session_id={CHECKOUT_SESSION_ID}`,
        cancel_url: `${BASE_URL}/payment/cancel`,
        metadata: { userId, tier: parsed.data.tier },
        subscription_data: { metadata: { userId } },
      });

      return reply.send({ success: true, data: { url: session.url } });
    } catch (err) {
      request.log.error({ err }, '[Stripe] checkout error');
      return reply.status(502).send({ success: false, error: { code: 'STRIPE_ERROR', message: 'Failed to create checkout session' } });
    }
  });

  // ── POST /api/v1/payments/portal ─────────────────────────────────────────────
  fastify.post('/portal', async (request, reply) => {
    try {
      await request.jwtVerify();
    } catch {
      return reply.status(401).send({ success: false, error: { code: 'UNAUTHORIZED', message: 'Not authenticated' } });
    }

    const { userId } = request.user;
    const sub = await prisma.subscription.findUnique({ where: { userId }, select: { stripeCustomerId: true } });

    if (!sub?.stripeCustomerId) {
      return reply.status(400).send({ success: false, error: { code: 'NO_SUBSCRIPTION', message: 'No active Stripe subscription found' } });
    }

    try {
      const session = await stripe.billingPortal.sessions.create({
        customer: sub.stripeCustomerId,
        return_url: `${BASE_URL}/payment/success`,
      });
      return reply.send({ success: true, data: { url: session.url } });
    } catch (err) {
      request.log.error({ err }, '[Stripe] portal error');
      return reply.status(502).send({ success: false, error: { code: 'STRIPE_ERROR', message: 'Failed to create portal session' } });
    }
  });

  // ── POST /api/v1/payments/google-play/verify ─────────────────────────────────
  // Called by the Flutter app immediately after a successful Google Play purchase.
  // Verifies the purchase token with the Google Play Developer API and updates
  // the user's subscription tier in the database.
  fastify.post('/google-play/verify', async (request, reply) => {
    try {
      await request.jwtVerify();
    } catch {
      return reply.status(401).send({ success: false, error: { code: 'UNAUTHORIZED', message: 'Not authenticated' } });
    }

    if (!config.GOOGLE_PLAY_PACKAGE_NAME || !config.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON) {
      return reply.status(503).send({
        success: false,
        error: { code: 'NOT_CONFIGURED', message: 'Google Play verification not configured on server' },
      });
    }

    const { userId } = request.user;
    const parsed = z.object({
      purchaseToken: z.string().min(1),
      productId: z.enum(['zenfit_pro_monthly', 'zenfit_coach_monthly']),
    }).safeParse(request.body);

    if (!parsed.success) {
      return reply.status(400).send({
        success: false,
        error: { code: 'VALIDATION_ERROR', message: 'purchaseToken and productId are required' },
      });
    }

    const { purchaseToken, productId } = parsed.data;

    let purchaseData: GooglePlaySubscriptionResponse;
    try {
      purchaseData = await verifyGooglePlayPurchase(
        config.GOOGLE_PLAY_PACKAGE_NAME,
        productId,
        purchaseToken,
      );
    } catch (err) {
      request.log.error({ err }, '[Google Play] verification error');
      return reply.status(502).send({
        success: false,
        error: { code: 'GOOGLE_PLAY_ERROR', message: 'Could not verify purchase with Google Play' },
      });
    }

    // paymentState 1 = payment received, 2 = free trial. Anything else is invalid.
    const isValid =
      purchaseData.expiryTimeMillis != null &&
      (purchaseData.paymentState === 1 || purchaseData.paymentState === 2) &&
      purchaseData.cancelReason === undefined;

    if (!isValid) {
      return reply.status(400).send({
        success: false,
        error: { code: 'INVALID_PURCHASE', message: 'Purchase is not active or has been cancelled' },
      });
    }

    const tier = GOOGLE_PLAY_PRODUCT_TIERS[productId] ?? 'free';
    const validUntil = new Date(parseInt(purchaseData.expiryTimeMillis!, 10));

    await prisma.subscription.upsert({
      where: { userId },
      create: { userId, tier, validUntil },
      update: { tier, validUntil },
    });

    request.log.info(`[Google Play] user ${userId} activated ${tier} until ${validUntil.toISOString()}`);
    return reply.send({ success: true, data: { tier, validUntil: validUntil.toISOString() } });
  });

  // ── POST /api/v1/payments/webhook ────────────────────────────────────────────
  fastify.post('/webhook', async (request, reply) => {
    const sig = request.headers['stripe-signature'];
    if (!sig || typeof sig !== 'string') {
      return reply.status(400).send({ error: 'Missing stripe-signature header' });
    }

    // rawBody is the unparsed JSON string saved by the global content-type parser.
    const rawBody = (request as unknown as Record<string, unknown>).rawBody as string ?? '';

    let event: Stripe.Event;
    try {
      event = stripe.webhooks.constructEvent(
        rawBody,
        sig,
        config.STRIPE_WEBHOOK_SECRET,
      );
    } catch (err) {
      request.log.error({ err }, '[Stripe webhook] signature verification failed');
      return reply.status(400).send({ error: 'Invalid webhook signature' });
    }

    try {
      await handleWebhookEvent(event, request.log);
    } catch (err) {
      request.log.error({ err }, '[Stripe webhook] handler error');
      return reply.status(500).send({ error: 'Webhook handler failed' });
    }

    return reply.send({ received: true });
  });
};

// ─── Webhook event handler ────────────────────────────────────────────────────

async function handleWebhookEvent(
  event: Stripe.Event,
  log: { info: (...a: unknown[]) => void; error: (...a: unknown[]) => void },
): Promise<void> {
  switch (event.type) {
    case 'checkout.session.completed': {
      const session = event.data.object as Stripe.Checkout.Session;
      if (session.mode !== 'subscription') break;

      const userId = session.metadata?.userId;
      const tier = session.metadata?.tier as 'pro' | 'coach' | undefined;
      const subscriptionId = session.subscription as string | null;

      if (!userId || !tier || !subscriptionId) {
        log.error('[Stripe webhook] checkout.session.completed missing metadata', session.metadata);
        break;
      }

      // Fetch subscription to get period end
      const stripeSub = await stripe.subscriptions.retrieve(subscriptionId);
      const validUntil = new Date(stripeSub.current_period_end * 1000);

      await prisma.subscription.upsert({
        where: { userId },
        create: {
          userId,
          tier,
          stripeId: subscriptionId,
          stripeCustomerId: session.customer as string,
          stripePriceId: stripeSub.items.data[0]?.price.id ?? null,
          validUntil,
        },
        update: {
          tier,
          stripeId: subscriptionId,
          stripeCustomerId: session.customer as string,
          stripePriceId: stripeSub.items.data[0]?.price.id ?? null,
          validUntil,
        },
      });

      log.info(`[Stripe] user ${userId} upgraded to ${tier} until ${validUntil.toISOString()}`);
      break;
    }

    case 'customer.subscription.updated': {
      const sub = event.data.object as Stripe.Subscription;
      const userId = sub.metadata?.userId;
      if (!userId) break;

      const priceId = sub.items.data[0]?.price.id ?? '';
      const tier = tierFromPriceId(priceId);
      const validUntil = new Date(sub.current_period_end * 1000);
      const isActive = sub.status === 'active' || sub.status === 'trialing';

      await prisma.subscription.upsert({
        where: { userId },
        create: { userId, tier: isActive ? tier : 'free', stripeId: sub.id, stripePriceId: priceId, validUntil: isActive ? validUntil : null },
        update: { tier: isActive ? tier : 'free', stripeId: sub.id, stripePriceId: priceId, validUntil: isActive ? validUntil : null },
      });

      log.info(`[Stripe] subscription updated for user ${userId}: ${sub.status} → ${tier}`);
      break;
    }

    case 'customer.subscription.deleted': {
      const sub = event.data.object as Stripe.Subscription;
      const userId = sub.metadata?.userId;
      if (!userId) break;

      await prisma.subscription.upsert({
        where: { userId },
        create: { userId, tier: 'free', stripeId: sub.id, validUntil: null },
        update: { tier: 'free', validUntil: null },
      });

      log.info(`[Stripe] subscription cancelled for user ${userId}`);
      break;
    }

    case 'invoice.payment_failed': {
      const invoice = event.data.object as Stripe.Invoice;
      const customerId = invoice.customer as string;
      const dbSub = await prisma.subscription.findFirst({ where: { stripeCustomerId: customerId } });
      if (dbSub) {
        log.error(`[Stripe] payment failed for user ${dbSub.userId}, customer ${customerId}`);
      }
      break;
    }

    default:
      break;
  }
}
