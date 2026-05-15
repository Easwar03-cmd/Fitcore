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
| Health info (weight, height, body fat, BMI, heart rate, HRV, sleep) | Yes | No | Optional | App functionality (dashboard, recovery score) |
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

### Camera
| Sub-type | Collected | Shared | Required or optional | Processing purpose |
|---|---|---|---|---|
| Photos and videos (live camera frames for barcode/form monitor) | No — processed on-device, never stored or transmitted | No | Optional | App functionality |

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
**Yes — Google Gemini API only**, for the purpose of generating AI coach responses, meal plans, and workout recommendations. This data is not shared for advertising or sold.

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
