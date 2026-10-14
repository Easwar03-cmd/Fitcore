# Revive 1.2.0 (build 10) — production checklist

Branch: `redesign/pastel-bento`. Backend is already deployed (Cloud Run revision `zenfit-api-00038-dxc`
at the time of writing) and its migrations are applied. This list is what is left to ship the app.

## Verified in this repo
- [x] `flutter analyze` — no issues; `flutter test` — 32 pass
- [x] Backend `tsc --noEmit` clean; `yarn workspace @zenfit/backend test` — 7 pass
- [x] Version `1.2.0+10` (`apps/mobile/pubspec.yaml`)
- [x] Release signing configured (`android/key.properties` + `app/fitcore-release.jks`, both git-ignored)
- [x] R8 minify + resource shrink on, ProGuard rules present
- [x] API base URL defaults to the Cloud Run production URL
- [x] AdMob uses real unit IDs only in release builds (test IDs otherwise)
- [x] Privacy policy, terms, delete-account page and Data Safety notes updated (`docs/`)

## Owner actions (cannot be done from the repo)
1. **Back up the keystore** `apps/mobile/android/app/fitcore-release.jks` and its passwords
   somewhere safe. Losing it means you can never update the app (unless Play App Signing holds it).
2. **Publish `docs/`** (GitHub Pages) so the privacy-policy URL matches this release.
3. **Play Console → App content**
   - Privacy policy URL, Data safety (see `docs/play-store-data-safety.md`, section "Update 2026-10-14")
   - Health apps / Health Connect permission declaration (steps, heart rate, resting HR, HRV, sleep read; active calories write)
   - Target audience 18+, ads declaration (AdMob), user-generated content moderation answers
   - Generative-AI disclosure (flag button on AI results)
4. **GCS media bucket** (`revive-community-media`): confirm the Cloud Run service account has
   `roles/storage.objectAdmin` on it and `roles/iam.serviceAccountTokenCreator` on itself
   (needed to sign community media URLs). Test one photo upload in a community.
5. **Cloud Build logging**: grant the build service account `roles/logging.logWriter` (builds currently
   warn they cannot write logs).
6. **Merge to `main`** so the push-to-main Cloud Build trigger and the repo match production
   (the last deploys were manual `gcloud builds submit` from this branch).
7. **Old app versions**: installs older than this release still call removed endpoints (AI coach,
   form monitor, wellness) and will error until updated. Consider a staged rollout (10% → 50% → 100%).
8. **Coach tier pricing** is unchanged (kept as-is by request).

## Smoke test on a release build before rollout
Install the signed release (`flutter build apk --release`, uninstall the debug build first — signatures differ), then:
- [ ] Sign up / log in / log out; delete-account flow reaches the confirmation
- [ ] Log food from the Indian breakfast/lunch/dinner menus; amount stepper minimum 10 g
- [ ] Back button: any tab → Home → exits
- [ ] Community: create, post a message with a photo, create a personal and a group challenge, open a past day's notes
- [ ] Profile: change photo and name
- [ ] Notifications: set different reminder times, kill and reopen the app, times persist
- [ ] Wearables: Bluetooth scan; a watch without the standard heart-rate service shows the Health Connect card
- [ ] Subscription / paywall opens; ads load on Home for a free user

## Known limitations (not blockers)
- Several screens exceed the 300-line guideline (paywall, home, food photo, active workout, …)
- Third-party wearable OAuth connectors are not implemented (Bluetooth + Health Connect only)
- Free users cannot use food-photo logging (server returns `UPGRADE_REQUIRED`); enabling it needs a per-user daily cap
- No automated end-to-end tests against a database
