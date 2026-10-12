# Revive — Major Change Plan (for review & approval)

**Status:** DRAFT — no code has been changed. Nothing below is executed until you approve it.
**Scope:** (1) audit, (2) remove AI Coach, (3) remove AI Form Monitor, (4) replace Wellness with Community.
**Verified baseline:** `flutter analyze` → 0 issues. Backend `tsc --noEmit` → clean. So the findings below are wiring/structure/product issues, not compile errors.

---

## Decision log (updated after your reply)

| ID | Decision | Source |
|---|---|---|
| D1 | **Polling (~3 s while chat is open) + FCM push** for new messages. Reason: stateless on Cloud Run, no Redis adapter, works with multiple instances; Socket.io is unused today. | "use what's correct" → ★ |
| D2 | **To-do stored on the backend**, strictly user-scoped, restored on login from any device. Never exposed by any admin/other-user endpoint. | you |
| D5 | **Keep `/ai/report`** and add "Report" on remaining AI outputs. | you ("Yes") |
| D6 | **Coach tier untouched for now.** I only remove the AI-coach / Form-Monitor feature *rows* from paywall + subscription screens; tier IDs, prices, Stripe/Play products and gating logic stay. You will set pricing/plans later. | you |
| D12 | **Both personal and group challenges are supported** (see 5.5 and model in section 6). | you |

**Still open — I will use the ★ default unless you say otherwise:** D3 media storage (★ Google Cloud Storage), D4 drop MoodLog/SleepLog (★ drop), D7 server-side gating of AI workout recs (★ same rule the UI uses today: Coach tier — unchanged because of D6), D8 hide wearables screen (★ hide), D9 admin account deletion (★ transfer to longest-standing member, else delete community), D10 missed days (★ no auto-reset), D11 leaving member's frozen report (★ admin keeps until deleted), D13 one consent toggle (★), D14 members can post media (★).

---

## 0. How I propose to execute (once approved)

Branch `refactor/community`, one commit per phase, so each phase can be reviewed or reverted on its own.

| Phase | Work | Risk |
|---|---|---|
| A | Remove AI Coach (mobile + backend) | Low |
| B | Remove AI Form Monitor (mobile + backend + deps + permissions) | Low |
| C | Remove Wellness (mobile + backend, tab swapped for a Community placeholder) | Medium (DB, health permissions) |
| D | Audit fixes (section 1) | Low–Medium |
| E | Community backend (schema, migration, routes, repositories) | High |
| F | Community mobile (feed, chat, challenges, notepad, todo, admin) | High |
| G | Docs/policy updates (CLAUDE.md, PROGRESS.md, privacy policy, Play data-safety, store listing) | Low |

Phases A–C are deletions and are done first so Community is built on a clean base.

---

## 1. App audit — findings

Severity: 🔴 fix before release · 🟠 should fix · 🟡 cleanup

### 1.1 Unfinished wiring / dead features
| # | Sev | Finding | Where | Proposed action |
|---|---|---|---|---|
| 1 | 🔴 | **Social is entirely placeholder and unreachable.** 4 screens say "placeholder"; home `AppBar` has `actions: const []`, so no UI path leads to `/social`. Backend `social.routes.ts` is 4 × HTTP 501. | `features/social/*`, `routes/social.routes.ts` | Delete. Community replaces it (friends/feed/leaderboard are not rebuilt unless you ask). |
| 2 | 🟠 | `Friendship` model is a half-built relation (`friendId` has no relation) and is only touched by account deletion. | `schema.prisma` | Drop with Social (migration). |
| 3 | 🟠 | Three backend routes return 501: `PATCH /workout/logs/:id`, `GET /workout/exercises`, `GET /workout/templates`, plus `GET /user/stats`. Mobile does not call them. | `workout.routes.ts`, `user.routes.ts` | Delete the stubs (re-add when built). |
| 4 | 🟠 | `core/services/coach_service.dart` throws `UnimplementedError` and is unused (real coach code lives in `features/coach`). | `core/services/` | Removed with AI Coach. |
| 5 | 🟠 | `settings_screen.dart` has **0 importers** (replaced by `ProfileScreen`). `core/widgets/app_input.dart` has **0 importers**. | `features/settings`, `core/widgets` | Delete. |
| 6 | 🟠 | Unused mobile deps: `google_mlkit_text_recognition`, `google_mlkit_image_labeling` (0 imports). They bloat the APK and are part of the recent 16 KB-page-size problem class. | `pubspec.yaml` | Remove. |
| 7 | 🟠 | Unused backend deps: `socket.io`, `cloudinary`, `@fastify/swagger` (0 imports). | `apps/backend/package.json` | Remove (or use — see Community decision D3). |
| 8 | 🔴 | **`CLOUDINARY_URL` is *required* by the env schema** (`z.string().url()`) though Cloudinary is never used → server refuses to boot without it. | `utils/config.ts` | Make optional / replace with the media-storage choice (D3). |
| 9 | 🟡 | `ADMIN_EMAILS` is declared "to bypass AI coach rate limit" but is never read anywhere. | `utils/config.ts` | Remove. |
| 10 | 🟠 | `coach.repository.ts` (`getCoachContext`) and `CoachContext` in `packages/shared` have **no callers**. | `repositories/`, `packages/shared` | Removed with AI Coach. |
| 11 | 🟡 | Ads: home banner/popup are still "placeholder" slots (`ad_placeholders.dart`) with TODOs. | `features/home/widgets` | Out of scope; flag only. |
| 12 | 🟠 | Wearable integrations (Fitbit/WHOOP/Oura) use placeholder OAuth client IDs; screen warns about it. Copy references "Wellness tab". | `wearable_integrations_screen.dart` | Keep file; fix copy. **Decision D8:** hide the screen until real client IDs exist? |

### 1.2 Inconsistencies between docs, backend and UI
| # | Sev | Finding | Action |
|---|---|---|---|
| 13 | 🟠 | **Food photo logging:** CLAUDE.md says "available all tiers"; backend returns 403 unless Pro/Coach; UI says "requires Pro or Coach". | Pick one (D7). Plan assumes backend is the truth (Pro/Coach). |
| 14 | 🟠 | **AI workout recommendations** are gated to *Coach tier only* in UI (`canUseAiWorkoutFeatures => isCoach`) but the backend route has **no tier check at all** → anyone can call it directly. | Add server-side gate matching the UI (D7). |
| 15 | 🟠 | **Form Monitor privacy claim is wrong:** docs/store listing say "fully on-device, no data sent", but `GeminiTipCard` → `POST /ai/form-analysis` sends exercise name, angle & feedback to Gemini. | Moot after removal; fixes the store listing. |
| 16 | 🟡 | CLAUDE.md says AI coach uses Claude API/`ANTHROPIC_API_KEY`; code uses Gemini. Folder structure says `zenfit/`; app is "Revive"; code mixes Zenfit/Revive. PROGRESS.md still contains React-Native/Expo/WatermelonDB history. | Rewrite CLAUDE.md + PROGRESS.md in phase G. |
| 17 | 🟠 | **"Coach" subscription tier loses its meaning** once AI Coach/Form Monitor go (it sold "Unlimited AI coach", "Form Monitor", "Coach marketplace" — marketplace was already dropped by a migration). | **Decision D6** — see below. |

### 1.3 Structure / quality
| # | Sev | Finding | Action |
|---|---|---|---|
| 18 | 🟠 | `request.jwtVerify()` + 401 block is **copy-pasted 37×** across route files. | Add one `authenticate` preHandler (Fastify `onRequest` hook per plugin). Mechanical, low risk. Done as part of Community routes first; then back-port. |
| 19 | 🟠 | `ai.service.ts` is **800 lines** mixing Redis rate limiting, request queue, 5 AI features. | After coach removal, split into `gemini.client.ts` (queue/retry) + one file per feature. |
| 20 | 🟠 | CLAUDE.md rule "files < 300 lines" violated: `paywall_screen` 613, `exercise_monitor_screen` 591 (deleted), `food_photo_screen` 552, `active_workout_screen` 543, `home_screen` 529, `wearable_integrations_screen` 486, `home_workout_list_screen` 480, `profile_screen` 429, `meal_plan_screen` 403, `forgot_password_screen` 395, `workout_summary_screen` 373, `subscription_screen` 333, `progress_screen` 311. | Split the ones I touch (home, paywall, subscription, workout_screen). Others listed, not changed unless you say so. |
| 21 | 🟠 | Tests: only 4 test files (calorie calc, streak, api error, coach actions). No backend tests at all. `widget_test.dart` is the default template. | Add tests for new Community logic (challenge day-counting, consent/visibility rules). Delete the coach test. |
| 22 | 🟡 | Password reset: if Redis is down, `/forgot-password` stores nothing but still replies "code sent". | Return 503 in that case, same as `/reset-password`. |
| 23 | 🟡 | `/user/account` delete is a hand-maintained list of tables; every new table must be added or deletion breaks on FK errors. | Community adds many tables → I'll make deletion explicit & covered by a test. |
| 24 | 🟡 | Every JSON request stores a `rawBody` copy (only Stripe webhook needs it). | Scope to webhook route. |

### 1.4 Things I did **not** find
No analyzer errors, no TS errors, no references to removed routes from the remaining screens beyond those listed in sections 2–4.

---

## 2. Remove AI Coach

### Mobile
| Action | Item |
|---|---|
| Delete | `lib/features/coach/` (screen, provider + `.g.dart`, models, 3 widgets) |
| Delete | `lib/core/services/coach_service.dart` |
| Delete | `test/features/coach/coach_message_actions_test.dart` |
| Edit | `home_screen.dart` — remove "AI Coach" FAB |
| Edit | `app_router.dart`, `app_routes.dart` — remove `/coach` |
| Edit | `paywall_screen.dart`, `subscription_screen.dart` — remove "AI coach (5 msg/day)" / "Unlimited AI coach" rows |
| Edit | `test/core/api/api_error_message_test.dart`, `test/widget_test.dart` — fix any coach references |
| Run | `build_runner` to regenerate `*.g.dart` |

### Backend
| Action | Item |
|---|---|
| Delete routes | `POST /ai/coach`, `POST /ai/chat` |
| Delete from `ai.service.ts` | `COACH_SYSTEM_PROMPT`, `sendCoachMessage`, `retrieveContext` + context caches (`_nutritionCache` etc.), `CASUAL_RE`/`detectTopics`, `checkCoachRateLimit`, `getFreeTierMessageCount`, `incrementFreeTierCount`, the Redis client in that file, `GEMINI_CHAT_RETRY_DELAYS_MS`, `ChatMessage` type |
| Delete | `repositories/coach.repository.ts`, `CoachContext` in `packages/shared` |
| Edit | `config.ts` — drop `ADMIN_EMAILS` |
| Keep | Gemini queue/retry, meal plan, food photo, workout recommendation, deload check |
| ⚠ Keep | `POST /ai/report` — Google Play's generative-AI policy requires in-app reporting of AI output, and meal plans / workout recs / food photo are still AI. **D5:** keep endpoint and add a "Report" action to those outputs (recommended). |

### Not touched
Stripe/Play "coach" **tier** string — see D6. Pro/Coach tier IDs in IAP stay so existing subscribers aren't broken.

---

## 3. Remove AI Form Monitor

### Mobile
| Action | Item |
|---|---|
| Delete | `exercise_monitor_screen.dart`, `exercise_monitor_provider.dart`, `pose_analyzer.dart`, `pose_smoother.dart`, `pose_overlay_painter.dart`, `form_feedback_card.dart`, `gemini_tip_card.dart`, `pose_feedback.dart` |
| Edit | `workout_screen.dart` — remove the "AI Form Monitor" card (and its lock/paywall branch) |
| Edit | router/routes — remove `/workout/monitor` |
| Edit | paywall/subscription — remove "AI Form Monitor" rows |
| `pubspec.yaml` | remove `google_mlkit_pose_detection`, `camera` (verify nothing else imports `camera`; barcode uses `mobile_scanner`, food photo uses `image_picker`) |
| Android manifest | **keep** `CAMERA` (barcode + food photo still need it) |

### Backend
| Action | Item |
|---|---|
| Delete | `POST /ai/form-analysis`, `analyzeExerciseForm`, `ExerciseFormAnalysis` |

---

## 4. Remove Wellness

### Mobile
| Action | Item |
|---|---|
| Delete | `lib/features/wellness/` (screen, provider, state, 4 widgets) |
| Edit | `main_shell.dart` — 5th tab becomes **Community**; `AppRoutes.wellness` removed |
| Edit | `HealthService` — remove sleep, sleep stages, HRV, heart-rate-history methods that only wellness used (`getLastNightSleep`, `getSleepStages`, `getSleepHistoryDays`, `getTodayHRV`, `getTodayHeartRate`, `getHeartRateHistoryDays`) |
| Edit | `home_screen.dart` permission dialog — drop "Sleep" row |
| Android manifest | remove `READ_SLEEP`, `READ_HEART_RATE` health permissions (less to justify in Play's Health Connect declaration). Keep steps, weight, active-calories write |
| Edit | `wearable_integrations_screen.dart` copy ("Wellness and Progress tabs" → "Progress"); drop `read:sleep` scopes |

### Backend
| Action | Item |
|---|---|
| Delete | `routes/wellness.routes.ts`, `repositories/wellness.repository.ts`, route registration in `index.ts` |
| Schema | **D4:** drop `MoodLog` and `SleepLog` tables, or keep dormant? (Dropping deletes real users' mood/sleep rows.) Recommend: **drop**, since the feature is gone and the privacy policy would otherwise have to keep describing it. |
| Edit | `user.routes.ts` account-delete list |

---

## 5. Community — design

### 5.1 Navigation
- 5th bottom tab `Community` (icon `groups`), route `/community`.
- Wellness code and tab are gone; Social AppBar entry never existed, so nothing else to rewire.

```
/community                         Community home (list, create, search, todo entry)
/community/search                  search by name
/community/join/:code              invite landing (also reachable by deep link)
/community/create                  create form
/community/todo                    private todo list
/community/:id                     chat / updates feed
/community/:id/info                members + settings entry
/community/:id/admin               admin settings
/community/:id/members/:userId     member report (admin only)
/community/:id/challenges          list + create
/community/:id/challenges/:cid     detail: day grid, mark today, notepad
```

### 5.2 Community home screen (your points 1–2, 12)
```
┌ AppBar: Community              [search icon] ┐
│ [＋ Create community]   ← under header, left │
│ ── Joined communities ──                     │
│  (avatar) Name · last message · unread       │
│  …                                           │
│  or faded text: "Not joined community yet"   │
│ ── Join with code [______] [Join] ──         │
│ ── My daily to-do (private) ▸ ──             │
└──────────────────────────────────────────────┘
```
Search by name opens `/community/search`. Join with invite code or deep link.

### 5.3 Roles & permissions (point 3)
| Capability | Member | Admin (creator) |
|---|---|---|
| Read feed | ✓ | ✓ |
| Post updates (announcement style) | — | ✓ |
| Send messages | ✓ if admin allows ("members can chat" toggle) | ✓ |
| Create challenges | ✓ | ✓ |
| Share own notepad | ✓ | ✓ |
| Invite (show code/link) | ✓ if admin allows | ✓ |
| Edit name/description/avatar/privacy | — | ✓ |
| Regenerate / disable invite code | — | ✓ |
| Remove member, delete any message | — | ✓ |
| View member report (consented) | — | ✓ |
| Hold / delete tracking record | — | ✓ |
| Delete community | — | ✓ |

One admin per community (the creator). Co-admins and ownership transfer are **not** in your spec — listed as D9.

### 5.4 Chat UI (point 4) — WhatsApp-style
- Bubbles (own right / others left), sender name + avatar in groups, date separators, timestamps.
- Admin "Update" posts rendered as highlighted cards (pinned-style) in the same stream.
- Composer: text, **attach** (photo from gallery, camera, video, document), emoji, reply-to, long-press menu (reply / copy / report / delete).
- Shared notepad and challenge-created events appear as rich cards in the stream.
- Out of scope unless you want them: voice notes, read receipts, typing indicator, message editing, reactions.

### 5.5 Challenges (points 5–7)
- "Challenges" button on the community page → list (mine + group ones, with progress `7/21`) + "New challenge".
- **Two types, chosen on the create form:**
  - **Personal** — only the creator does it; visible to the admin only if the creator consented to tracking.
  - **Group** — creator publishes it to the community; any member can **Join**. Each participant has their *own* day-by-day check-ins and their own start date (date they joined), so a 21-day group challenge always means 21 days for each person. A leaderboard-style participant list (name + `X/N`) is shown inside the challenge; members who have not consented to tracking appear by name and progress only inside the group challenge they chose to join (joining a group challenge counts as opting in to show *that challenge's* progress to the group — not the fitness report).
  - Creator/admin can close a group challenge; participants can leave it.
- **Create form:** title, type, **duration in days** (presets 7/21/30/60/90 + custom), start = creation date (recorded), notepad text.
- **Tracking:** day *N* = `startDate + N − 1`. A day counts **only** when the user taps "Mark today complete". No auto-completion.
- Status: `active → completed` (all days marked) or `abandoned` (user ends it) ; `expired` if the end date passes with unmarked days (**D10**).
- Dates are the user's local calendar date, sent as `YYYY-MM-DD`; server accepts only today (±1 day to tolerate timezone/offline sync). Offline mark-complete goes through the existing Drift sync queue.

### 5.6 Notepad (points 6, 8)
- One notepad per challenge, autosaved, multi-line.
- **Auto-correction:** enable the platform keyboard's autocorrect/suggestions (`autocorrect: true`, `enableSuggestions: true`, `textCapitalization: sentences`) — real correction comes from the OS keyboard; no custom model.
- **Voice-to-text mic:** `speech_to_text` package, appends transcribed text at the cursor, language follows device locale.
  - ⚠ Requires the **`RECORD_AUDIO`** permission, which is currently *explicitly removed* in `AndroidManifest.xml` and promised "never" in the Play data-safety doc. Both must change (phase G). On-device recognition by default; some devices route audio to Google's service.
- **Share to community:** posts a *snapshot* of the notepad as a message card; later edits to the notepad don't alter what was shared. User picks which community if they are in several.

### 5.7 Admin tracking, consent, hold, leave (points 9–11)
**Consent (point 9).** Per member, per community, one toggle: *"Allow this community's admin to see my fitness report and challenge progress."* Default **OFF**. Asked on join and changeable any time in the community's info page. Without consent the admin sees the member in the list with "Not sharing" and nothing else.

**Report content** (computed live from the member's own data, within the tracking window):
workouts completed & minutes, calories logged vs target (7/30-day averages), weight change, streak, steps (if synced), muscle-group volume summary, and all that member's challenges in this community with progress.

**Member lifecycle**
| State | Admin sees | Data window | Reversible |
|---|---|---|---|
| `active` + consent | live report | from consent date → now | — |
| `active`, no consent | name only | none | user can consent |
| `on_hold` (admin action, point 11) | frozen report, read-only | consent date → hold date | admin can resume |
| `left` (user action, point 11) | frozen report until admin deletes it (**D11**) | consent date → leave date | user can re-join as new member |
| `deleted` (admin permanent delete, point 11) | nothing | none — record fully removed | no |

- Leaving never affects the user's own app data; they keep using the app normally.
- Revoking consent = same as `left` for tracking purposes but keeps membership.
- Admin "delete permanently" hard-deletes the membership tracking record (and any frozen snapshot); I will implement it as a real `DELETE`, not a soft flag.
- No copies of fitness data are stored for the admin. "Frozen" is just an end-date on the live query window, so a delete truly removes access and nothing lingers.

**Server enforcement:** every report endpoint checks *caller is admin of this community* **and** *target membership is active/on_hold* **and** *consent = true* **and** clamps the query to the window above. There is no admin endpoint that returns todo items, ever.

### 5.8 Private to-do (point 12)
Daily-routine checklist: add/edit/delete items, check off, optional "repeat daily" flag, resets each day. **Never shared**: no API returns it to anyone but its owner. Stored on the backend (`TodoItem`, every query filtered by the authenticated `userId`), so it is restored when the user logs in on another device. Cached locally via the existing offline sync queue so it works offline. Deleted with the account; excluded from every community/admin/report code path (covered by a test).

### 5.9 Invites & search (point 1)
- Each community has a short invite code + link (`https://…/join/CODE`, app deep link via GoRouter).
- `public` communities appear in name search; `private` ones are invite-only and hidden from search. Admin sets this.
- Join approval (admin must accept) — optional toggle, off by default.

### 5.10 Moderation & safety (required for Play)
Because users now post text/media to each other, Google Play's **User-Generated Content policy** requires: in-app **report** content/user, **block** user, and a way for admin to remove content/members, plus terms covering UGC. Included in this plan:
- Report message / report community, block user, admin delete message / remove member.
- Terms of Service + Privacy Policy updated (UGC, media, voice input, consented health-data sharing).
- Media uploads: size limits (image 10 MB, video 50 MB), type allow-list, signed URLs, rate limit per user.

---

## 6. Community — data model (Prisma, new migration)

```prisma
model Community {
  id            String   @id @default(cuid())
  name          String
  nameLower     String   @unique        // case-insensitive uniqueness + search
  description   String?
  avatarUrl     String?
  adminId       String                   // creator
  isPublic      Boolean  @default(true)  // searchable?
  requireApproval Boolean @default(false)
  membersCanChat  Boolean @default(true)
  membersCanInvite Boolean @default(true)
  inviteCode    String   @unique
  createdAt     DateTime @default(now())
  admin         User     @relation("CommunityAdmin", fields: [adminId], references: [id])
  members       CommunityMember[]
  messages      CommunityMessage[]
  challenges    Challenge[]
}

model CommunityMember {
  id           String    @id @default(cuid())
  communityId  String
  userId       String
  role         String    @default("member")   // admin | member
  status       String    @default("active")   // pending | active | on_hold | left
  shareReport  Boolean   @default(false)      // consent
  consentAt    DateTime?
  heldAt       DateTime?
  leftAt       DateTime?
  joinedAt     DateTime  @default(now())
  @@unique([communityId, userId])
  @@index([userId])
}

model CommunityMessage {
  id          String   @id @default(cuid())
  communityId String
  authorId    String
  kind        String   // text | update | media | notepad_share | challenge_event
  body        String?
  mediaUrl    String?
  mediaType   String?  // image | video | document
  replyToId   String?
  payload     Json?    // notepad snapshot / challenge card
  createdAt   DateTime @default(now())
  deletedAt   DateTime?
  @@index([communityId, createdAt])
}

model Challenge {
  id          String   @id @default(cuid())
  communityId String
  creatorId   String
  kind        String   // personal | group
  title       String
  description String   @default("")   // creator's notepad / rules
  totalDays   Int
  status      String   @default("open") // open | closed
  createdAt   DateTime @default(now())
  participants ChallengeParticipant[]
  @@index([communityId])
}

// One row per person doing a challenge (personal challenge = exactly 1 row).
model ChallengeParticipant {
  id          String   @id @default(cuid())
  challengeId String
  userId      String
  startDate   DateTime @db.Date       // date this person started (user-local)
  notes       String   @default("")   // this person's own notepad
  status      String   @default("active") // active | completed | abandoned
  checkins    ChallengeCheckin[]
  @@unique([challengeId, userId])
  @@index([userId])
}

model ChallengeCheckin {
  id            String   @id @default(cuid())
  participantId String
  dayNumber     Int
  date          DateTime @db.Date
  completedAt   DateTime @default(now())
  @@unique([participantId, dayNumber])
}

model TodoItem {
  id          String   @id @default(cuid())
  userId      String
  title       String
  done        Boolean  @default(false)
  repeatDaily Boolean  @default(false)
  forDate     DateTime @db.Date
  createdAt   DateTime @default(now())
  @@index([userId, forDate])
}

model CommunityBlock   { id String @id @default(cuid()); blockerId String; blockedId String; @@unique([blockerId, blockedId]) }
model CommunityReport  { id String @id @default(cuid()); reporterId String; messageId String?; communityId String?; userId String?; reason String; createdAt DateTime @default(now()) }
```
(Final field types, relations and `onDelete` rules will be fully specified in the migration; the above is the shape.)
New API additions: `GET/POST/PATCH/DELETE /api/v1/todo` (owner-only); `POST /challenges/:cid/join`, `POST /challenges/:cid/leave`, `GET /challenges/:cid/participants`. Notepad `notes` and check-ins now live on the participant row. In 5.6 "share notepad" uses the participant's notes.

**Account deletion:** extends to memberships, messages, challenges, reports, blocks. If the deleting user is an **admin** of communities → D9 (transfer to the longest-standing member, or delete the community). Must be decided before building.

**API (new, all under `/api/v1/community`, Zod-validated, `authenticate` preHandler):**
`POST /` create · `GET /mine` · `GET /search?q=` · `POST /join` (code or id) · `POST /:id/leave` · `GET/PATCH/DELETE /:id` · `POST /:id/invite/regenerate` · `GET /:id/members` · `PATCH /:id/members/me/consent` · `POST /:id/members/:uid/hold|resume` · `DELETE /:id/members/:uid` (remove) · `DELETE /:id/members/:uid/record` (permanent tracking delete) · `GET /:id/members/:uid/report` · `GET/POST /:id/messages` · `DELETE /:id/messages/:mid` · `POST /:id/media` · `GET/POST /:id/challenges` · `GET/PATCH /challenges/:cid` · `POST /challenges/:cid/checkins` · `POST /challenges/:cid/share` · `POST /report` · `POST /block`.

---

## 7. Decisions I need from you

Recommendation is marked ★.

| ID | Question | Options |
|---|---|---|
| **D1** | **Chat transport.** | ★ **Polling (every ~3 s while chat open) + FCM push** for new messages — simplest, works across multiple Cloud Run instances. / Socket.io (already in stack but needs a Redis adapter on Cloud Run; more moving parts). |
| **D2** | **Where does the private to-do live?** | ★ **On-device only (Drift)** — physically cannot be seen by anyone, works offline; lost on reinstall/new phone. / Backend, user-scoped — survives device change, but data sits on your server. |
| **D3** | **Media storage.** | ★ **Google Cloud Storage** with signed URLs (you're already on GCP/Cloud Run). / Cloudinary (the env var exists but is unused). |
| **D4** | **Mood/sleep tables.** | ★ Drop `MoodLog`, `SleepLog` (deletes existing rows). / Keep dormant. |
| **D5** | **Keep `/ai/report` + add "Report" on remaining AI outputs** (meal plan, workout rec, food photo)? | ★ Yes (Play policy). / No. |
| **D6** | **What is the "Coach" tier now?** Pro $9.99 and Coach $19.99 differ only by AI workout recs/Form Monitor/Coach chat, which are being removed/merged. | ★ Collapse to **Free + Pro** in the UI (keep `coach` product ID server-side so existing subscribers map to Pro). / Keep Coach tier and move AI workout recs to it only. / Keep as-is (3 tiers with thin difference — not recommended). |
| **D7** | **Tier gating truth:** food photo = Pro+; AI workout recs = Pro+ (not Coach-only) — and enforce on the server. | ★ As stated. / Tell me different. |
| **D8** | Hide wearable-integrations screen until real OAuth client IDs exist? | ★ Hide. / Keep. |
| **D9** | **Admin edge cases:** when an admin deletes their account → ? | ★ Transfer to longest-standing active member; if none, delete the community. Co-admins / manual ownership transfer: not in v1. / Delete community always. |
| **D10** | **Missed challenge days.** | ★ Challenge continues; progress shows `X/N` completed and misses stay visible (no auto-reset). / Strict: a missed day ends or restarts the challenge. |
| **D11** | **Leaving member's frozen report:** | ★ Admin keeps the frozen report (up to leave date) until they delete it, per your "tracking stopped" wording. / Purge immediately on leave (most private). |
| **D12** | **Are challenges personal (each member makes their own, admin can see) or group (one challenge others can join)?** I read your spec as *personal*, shown inside the community. | ★ Personal. / Group-join challenges as well. |
| **D13** | **Consent granularity** — one toggle for report + challenges, or two? | ★ One toggle. / Two toggles. |
| **D14** | **Should members be able to post media/files, or only admin?** | ★ Members can if "members can chat" is on. / Admin only. |

---

## 8. New dependencies & permissions

| Item | Why | Notes |
|---|---|---|
| `speech_to_text` | notepad mic | adds `RECORD_AUDIO` (+ iOS `NSSpeechRecognitionUsageDescription`, `NSMicrophoneUsageDescription`) |
| `file_picker` | attach documents | images/video already via `image_picker` |
| `share_plus` | share invite link | |
| `app_links` (or GoRouter deep links) | `/join/CODE` | Android intent filter + iOS associated domains |
| `cached_network_image` | chat media | optional |
| Removed | `camera`, `google_mlkit_pose_detection`, `google_mlkit_text_recognition`, `google_mlkit_image_labeling` | smaller APK |

---

## 9. Out of scope / not changing

Auth, onboarding, nutrition logging, workout logging, progress charts, Stripe/Play billing plumbing, notifications, themes, GPS tracking, ads. Friends list, activity feed and leaderboard from the old Social plan are **not** rebuilt (Community replaces them) — say if you want them.

---

## 10. Risks

1. **Play Store review:** new UGC + microphone + health-data sharing → Data-safety form, privacy policy and a UGC moderation story must be updated in the same release.
2. **Health-data sharing is sensitive.** Consent-default-OFF, server-side enforcement and window clamping are non-negotiable and will be covered by tests.
3. **Destructive migration** (drops Mood/Sleep/Friendship, adds ~8 tables) runs against the live Cloud SQL DB. I will write it as a separate migration and give you the exact SQL to review before any deploy; I won't run anything against production.
4. Version bump: this will be `1.1.0+9` or later; it changes permissions, so Play will treat it as a significant update.

---

## 11. Approval checklist

Reply with either "approved as recommended (★)" or your changes per decision ID (D1–D14). I will also want a yes/no on:

- [ ] Section 1 audit fixes (all, or pick by #)
- [ ] Sections 2–4 removals
- [ ] Section 5–6 Community design
- [ ] Branch/commit workflow in section 0
