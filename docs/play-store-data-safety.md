# Play Store — Data Safety Form Answers

Use this as a reference when filling out the Data Safety section in Google Play Console.
Each answer maps directly to a question in the form.

---

## Does your app collect or share any of the required user data types?
**Yes**

---

## Is all of the user data collected by your app encrypted in transit?
**Yes** — all data uses TLS 1.2+

---

## Do you provide a way for users to request that their data is deleted?
**Yes** — Settings → Profile → Delete Account (deletes all data within 30 days)

---

## Data Types Collected

### Personal info
| Sub-type | Collected | Shared | Required or optional | Processing purpose |
|---|---|---|---|---|
| Name | Yes | No | Required | App functionality |
| Email address | Yes | No | Required | Account management |
| User IDs | Yes | No | Required | App functionality |
| Other personal info (date of birth, biological sex) | Yes | No | Optional | App functionality (calorie calculation) |

### Financial info
| Sub-type | Collected | Shared | Required or optional | Processing purpose |
|---|---|---|---|---|
| Purchase history | Yes | No | Required | App functionality (subscription management — handled by Google Play) |

> Note: No payment card data is collected by the app. All payment processing is done by Google Play Billing.

### Health and fitness
| Sub-type | Collected | Shared | Required or optional | Processing purpose |
|---|---|---|---|---|
| Health info (weight, height, body fat, BMI) | Yes | No — unless the user turns on "Share my fitness report with admin" in a community, in which case a summary is visible to that community's admin | Optional | App functionality (dashboard, community tracking chosen by the user) |
| Fitness info (workouts, steps, calorie logs, GPS routes) | Yes | No | Required | App functionality |

> Health data is **not** used for advertising or shared with third parties for their independent use.

### Location
| Sub-type | Collected | Shared | Required or optional | Processing purpose |
|---|---|---|---|---|
| Precise location | Yes | No | Optional | App functionality (GPS workout tracking only) |

> Location is collected only during an active outdoor workout session. It is not collected in the background.

### Photos and videos
| Sub-type | Collected | Shared | Required or optional | Processing purpose |
|---|---|---|---|---|
| Photos (meal photos for nutritional analysis) | Yes | Yes — Google Gemini API (transient, not stored) | Optional | App functionality (food photo logging) |
| Photos and videos (attached to community messages) | Yes | Yes — visible to members of that community | Optional | App functionality (community chat) |
| Files and docs (PDF/text attached to community messages) | Yes | Yes — visible to members of that community | Optional | App functionality (community chat) |

### Camera
| Sub-type | Collected | Shared | Required or optional | Processing purpose |
|---|---|---|---|---|
| Photos and videos (live camera frames for barcode scanning) | No — processed on-device, never stored or transmitted | No | Optional | App functionality |

### App activity
| Sub-type | Collected | Shared | Required or optional | Processing purpose |
|---|---|---|---|---|
| App interactions | Yes | Yes — Firebase Analytics, Amplitude (anonymised) | Required | Analytics |
| In-app search history (food search queries) | No — not stored | No | — | — |
| Crash logs | Yes | Yes — Firebase Crashlytics, Sentry | Required | App functionality (crash reporting) |

### Device or other IDs
| Sub-type | Collected | Shared | Required or optional | Processing purpose |
|---|---|---|---|---|
| Device or other IDs (Firebase installation ID, advertising ID) | Yes | Yes — Firebase, AdMob (with consent) | Required | Analytics, advertising |

---

## Data Sharing Details

### Is health and fitness data shared with any third parties?
**Yes — Google Gemini API only**, for the purpose of generating meal plans, workout recommendations and food-photo analysis. This data is not shared for advertising or sold.

### Is location data shared with any third parties?
**No.**

### Is personal info (name, email) shared with any third parties?
**No.**

---

## Security practices

- **Data encrypted in transit:** Yes (TLS 1.2+)
- **Data encrypted at rest:** Yes (AES-256 on Google Cloud SQL)
- **Users can request data deletion:** Yes (in-app + email to privacy@revivefit.app)
- **Independent security review:** No (not yet — consider adding before scaling)

---

## Notes for form submission

- Under **Health and fitness → Health info**: select "Collected" and set purpose to "App functionality". Uncheck "Shared".
- Under **Photos → Photos**: select "Collected" AND "Shared" — shared with Google Gemini API for food analysis. Ephemeral (not stored on our servers). Set purpose to "App functionality".
- Under **Location → Precise location**: select "Collected". Set to "Optional". Purpose: "App functionality". Background access: **No**.
- The "Advertising ID" row: mark as collected and shared with Google AdMob. Note that AdMob personalisation requires user consent (your app uses `GADDelayAppMeasurementInit = true` to wait for consent).

---

## Other Play Console declarations (added 2026-09-28)

### App content → Data deletion
- **Delete account URL:** `https://easwar03-cmd.github.io/Fitcore/delete-account.html`
- In-app path: Home → avatar → Profile → Delete Account

### Data safety addition — user-generated content
- **Messages → Other in-app messages:** Collected, shared with the other members of the community the user posts in, optional. Purpose: App functionality.
- **App activity → Other user-generated content:** Collected (challenge titles, notepad notes, private to-do items, reports), optional. Purpose: App functionality. To-do items are never shared. When a user reports AI output or community content, the report and user ID are logged for review.
- **Audio → Voice or sound recordings:** Voice dictation in the challenge notepad uses the device speech-recognition service. Revive does not record or store audio; declare as processed ephemerally / not collected by Revive and re-verify against the final `speech_to_text` behaviour on Android before submitting.

### App content → Health apps / Health Connect
Declared Health Connect permissions and justification (must match `AndroidManifest.xml`):
| Permission | Why |
|---|---|
| READ_STEPS | Daily step count on the Home dashboard and streaks |
| WRITE_ACTIVE_CALORIES_BURNED | Saves calories burned in a logged workout back to Health Connect |

### Microphone (`RECORD_AUDIO`)
Requested only for voice-to-text in the challenge notepad (user taps "Dictate"). Camera features never record audio.

### Permissions the app intentionally does NOT request
- Photos/videos (`READ_MEDIA_*`) — gallery uses the Android system photo picker
- Exact alarms (`SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`) — reminders use inexact scheduling
- Background location — GPS is only used while an outdoor workout is active

### App content → Target audience
- Select **18 and over** (health data, AI coaching, ads, subscriptions)

### Generative AI
- AI meal plans, workout recommendations and food-photo analysis show a flag button that reports the result (`POST /api/v1/ai/report`)

### User-generated content (community)
- In-app: report message / report community / block user, admin can delete messages and remove members
- Terms of Service section on community content; delete-account URL covers community data
- Required moderation answers: users are told how to report; reports are logged and reviewed (`[community report]` log entries in Cloud Logging)
