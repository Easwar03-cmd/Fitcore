import admin from 'firebase-admin';
import { config } from './config';

// ─── Lazy-initialised Firebase Admin app ─────────────────────────────────────
// Call getFirebaseAdmin() whenever you need the messaging instance.
// Returns null if FIREBASE_SERVICE_ACCOUNT is not set (graceful degradation —
// the app still runs; push notifications are simply skipped).

let _app: admin.app.App | null = null;

export function getFirebaseMessaging(): admin.messaging.Messaging | null {
  if (!config.FIREBASE_SERVICE_ACCOUNT) return null;

  if (!_app) {
    try {
      const serviceAccount = JSON.parse(config.FIREBASE_SERVICE_ACCOUNT) as admin.ServiceAccount;
      _app = admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
    } catch (err) {
      console.error('[firebase] Failed to parse FIREBASE_SERVICE_ACCOUNT JSON:', err);
      return null;
    }
  }

  return admin.messaging(_app);
}

/**
 * Send a data+notification push to a single FCM token.
 * Returns true on success, false on any error.
 */
export async function sendPush(
  fcmToken: string,
  title: string,
  body: string,
  data: Record<string, string> = {},
): Promise<boolean> {
  const messaging = getFirebaseMessaging();
  if (!messaging) return false;

  try {
    await messaging.send({
      token: fcmToken,
      notification: { title, body },
      data,
      android: {
        priority: 'normal',
        notification: { channelId: 'zenfit_default' },
      },
      apns: {
        payload: { aps: { sound: 'default' } },
      },
    });
    return true;
  } catch (err: unknown) {
    // Log but don't throw — stale tokens are common; just return false.
    const code = (err as { code?: string }).code ?? 'unknown';
    console.warn(`[firebase] Push failed for token (${code})`);
    return false;
  }
}
