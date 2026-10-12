const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const DAY_MS = 24 * 60 * 60 * 1000;

/** Parse 'YYYY-MM-DD' to a UTC-midnight Date (what Prisma @db.Date stores). */
export function parseDateOnly(value: string): Date | null {
  if (!DATE_RE.test(value)) return null;
  const d = new Date(`${value}T00:00:00.000Z`);
  return Number.isNaN(d.getTime()) ? null : d;
}

export function toDateOnlyString(d: Date): string {
  return d.toISOString().slice(0, 10);
}

/** Whole days from a to b (both UTC-midnight dates). */
export function daysBetween(a: Date, b: Date): number {
  return Math.round((b.getTime() - a.getTime()) / DAY_MS);
}

/** Today's date (UTC midnight) on the server. */
export function serverToday(): Date {
  const n = new Date();
  return new Date(Date.UTC(n.getUTCFullYear(), n.getUTCMonth(), n.getUTCDate()));
}

/**
 * The client sends its own local calendar date. Accept it only if it is within
 * ±1 day of the server's UTC date, which covers every real timezone offset.
 */
export function isPlausibleClientDate(d: Date): boolean {
  return Math.abs(daysBetween(serverToday(), d)) <= 1;
}
