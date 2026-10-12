import { randomBytes } from 'crypto';
import { Storage } from '@google-cloud/storage';
import { config } from './config';

export const MEDIA_LIMITS = {
  image: 10 * 1024 * 1024,
  video: 50 * 1024 * 1024,
  document: 20 * 1024 * 1024,
} as const;

export type MediaKind = keyof typeof MEDIA_LIMITS;

const ALLOWED: Record<string, MediaKind> = {
  'image/jpeg': 'image',
  'image/png': 'image',
  'image/webp': 'image',
  'image/heic': 'image',
  'video/mp4': 'video',
  'video/quicktime': 'video',
  'video/3gpp': 'video',
  'application/pdf': 'document',
  'text/plain': 'document',
};

let _storage: Storage | null = null;
function storage(): Storage {
  if (!_storage) _storage = new Storage();
  return _storage;
}

export function mediaKindFor(contentType: string): MediaKind | null {
  return ALLOWED[contentType] ?? null;
}

export function isMediaConfigured(): boolean {
  return Boolean(config.GCS_MEDIA_BUCKET);
}

/** V4 signed PUT URL (10 min) for a new object under the community prefix. */
export async function createUploadUrl(
  communityId: string,
  contentType: string,
): Promise<{ uploadUrl: string; objectPath: string }> {
  const bucket = config.GCS_MEDIA_BUCKET!;
  const objectPath = `community/${communityId}/${randomBytes(16).toString('hex')}`;
  const [uploadUrl] = await storage()
    .bucket(bucket)
    .file(objectPath)
    .getSignedUrl({
      version: 'v4',
      action: 'write',
      expires: Date.now() + 10 * 60 * 1000,
      contentType,
    });
  return { uploadUrl, objectPath };
}

/** V4 signed GET URL (1 h) so the bucket can stay private. */
export async function createReadUrl(objectPath: string): Promise<string | null> {
  if (!isMediaConfigured()) return null;
  try {
    const [url] = await storage()
      .bucket(config.GCS_MEDIA_BUCKET!)
      .file(objectPath)
      .getSignedUrl({ version: 'v4', action: 'read', expires: Date.now() + 60 * 60 * 1000 });
    return url;
  } catch {
    return null;
  }
}
