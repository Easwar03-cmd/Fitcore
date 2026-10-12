import { test } from 'node:test';
import assert from 'node:assert/strict';
import type { CommunityMember } from '@prisma/client';
import { trackingWindow } from '../services/community-report.service';
import { daysBetween, parseDateOnly } from '../utils/dates';

const DAY = 24 * 60 * 60 * 1000;
const now = new Date('2026-10-12T12:00:00Z');

function member(over: Partial<CommunityMember>): CommunityMember {
  return {
    id: 'm1',
    communityId: 'c1',
    userId: 'u1',
    role: 'member',
    status: 'active',
    shareReport: true,
    consentAt: new Date(now.getTime() - 10 * DAY),
    heldAt: null,
    leftAt: null,
    joinedAt: new Date(now.getTime() - 20 * DAY),
    ...over,
  };
}

test('no consent -> admin sees nothing', () => {
  assert.equal(trackingWindow(member({ shareReport: false, consentAt: null }), 30, now), null);
  assert.equal(trackingWindow(member({ shareReport: true, consentAt: null }), 30, now), null);
});

test('active + consent -> window starts at consent, ends now', () => {
  const w = trackingWindow(member({}), 30, now)!;
  assert.equal(w.frozen, false);
  assert.equal(w.to.getTime(), now.getTime());
  assert.equal(w.from.getTime(), now.getTime() - 10 * DAY);
});

test('days param can narrow but never widen past consent', () => {
  const narrow = trackingWindow(member({}), 3, now)!;
  assert.equal(narrow.from.getTime(), now.getTime() - 3 * DAY);
  const wide = trackingWindow(member({}), 90, now)!;
  assert.equal(wide.from.getTime(), now.getTime() - 10 * DAY);
});

test('on hold -> frozen at hold date', () => {
  const heldAt = new Date(now.getTime() - 2 * DAY);
  const w = trackingWindow(member({ status: 'on_hold', heldAt }), 30, now)!;
  assert.equal(w.frozen, true);
  assert.equal(w.to.getTime(), heldAt.getTime());
});

test('left -> frozen at leave date; pending/other -> nothing', () => {
  const leftAt = new Date(now.getTime() - 4 * DAY);
  const w = trackingWindow(member({ status: 'left', leftAt }), 30, now)!;
  assert.equal(w.to.getTime(), leftAt.getTime());
  assert.equal(trackingWindow(member({ status: 'pending' }), 30, now), null);
});

test('consent given after the hold date yields no window', () => {
  const heldAt = new Date(now.getTime() - 5 * DAY);
  const consentAt = new Date(now.getTime() - 1 * DAY);
  assert.equal(trackingWindow(member({ status: 'on_hold', heldAt, consentAt }), 30, now), null);
});

test('challenge day numbering is startDate-relative and 1-based', () => {
  const start = parseDateOnly('2026-10-01')!;
  assert.equal(daysBetween(start, parseDateOnly('2026-10-01')!) + 1, 1);
  assert.equal(daysBetween(start, parseDateOnly('2026-10-21')!) + 1, 21);
  assert.equal(parseDateOnly('2026-13-40'), null);
});
