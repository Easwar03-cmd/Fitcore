# Architecture Decisions

## ADR-001: Flutter over React Native
**Decision:** Flutter 3.22+ / Dart for the mobile app
**Reason:** Opinionated structure, strong typing, identical rendering on iOS/Android
**Trade-off:** Smaller plugin ecosystem for some niche integrations

## ADR-002: GoRouter for navigation
**Decision:** GoRouter, with Riverpod auth state driving redirects
**Reason:** Declarative, deep-link ready, Flutter team's recommended solution

## ADR-003: Drift for local DB
**Decision:** Drift (SQLite) with a sync queue for offline mode
**Reason:** Type-safe SQL, reactive streams, migrations; last-write-wins for logs, server-wins for settings/profile

## ADR-004: GCP Cloud Run over Railway / AWS
**Date:** 2026-04-24
**Decision:** Backend on Cloud Run + Cloud SQL (Postgres 15) + Upstash Redis; Cloud Build deploys on push to `main`; migrations run via `prisma migrate deploy` in the container CMD
**Reason:** Scale-to-zero cost, managed secrets, no VPC needed for Redis
**Trade-off:** Diverges from the AWS plan in CLAUDE.md

## ADR-005: Google Play Billing on Android, Stripe kept for iOS/web
**Date:** 2026-05-15
**Decision:** `in_app_purchase` with server-side verification (`/payments/google-play/verify`); product IDs `revive_pro_monthly` / `revive_coach_monthly`. Stripe code kept.
**Note:** Apple requires StoreKit for digital subscriptions — the Stripe web checkout on iOS will be rejected by App Review. iOS needs StoreKit before an App Store launch.

## ADR-006: Play purchase tokens are bound to one account
**Date:** 2026-09-28
**Decision:** `Subscription.googlePlayToken` is unique; verifying a token already bound to another user returns 409. Lapsed subscriptions are detected by `validUntil` (no Play RTDN webhook yet).

## ADR-007: No password-reset codes in API responses in production
**Date:** 2026-09-28
**Decision:** Without SMTP configured, `/auth/forgot-password` returns 503 in production instead of echoing the code. SMTP is required for launch.

## ADR-008: AdMob test units outside release builds
**Date:** 2026-09-28
**Decision:** All ad unit IDs live in `lib/constants/ad_units.dart`, switched on `kReleaseMode`, to avoid AdMob invalid-traffic suspensions during development.

## ADR-009: Community chat uses polling + FCM, not websockets
**Decision:** Chat clients poll `GET /community/:id/messages?after=` every ~3 s while a chat is open; new messages also trigger an FCM push.
**Reason:** Cloud Run scales to several stateless instances; Socket.io would need a Redis adapter and sticky behaviour. Polling is simple and good enough at this scale.
**Trade-off:** Up to ~3 s latency and some wasted requests; revisit with SSE/websockets if communities get large.

## ADR-010: Admin tracking is live-queried, never copied
**Decision:** Admins never receive stored copies of a member's data. The report is computed on request from the member's own data inside a window (`consentAt` → now / hold date / leave date), computed only by `trackingWindow()`.
**Reason:** "Hold" and "delete record" then have exact meaning (end-date vs. removal), and consent revocation is instant.
**Trade-off:** Resuming a hold restarts the window from the resume date so data produced during the hold is never exposed.

## ADR-011: To-do list lives on the backend, owner-only
**Decision:** `TodoItem` is stored server-side and every query is filtered by the authenticated user; no admin/report code path touches it.
**Reason:** Must survive device loss and be readable from another device.

## ADR-012: Group and personal challenges share one model
**Decision:** `Challenge` (+ `kind`) with a `ChallengeParticipant` row per person; personal = exactly one participant. Each participant has their own start date, notes and check-ins.

