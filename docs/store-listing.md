# Store Listing Copy — Revive

Copy-paste ready text for Google Play Console and App Store Connect.
Character limits are noted for each field.

---

## Google Play Console

### App name (≤ 30 chars)
```
Revive: AI Fitness & Nutrition
```

### Short description (≤ 80 chars)
```
Calorie tracking, workouts, AI meal plans & fitness communities.
```

### Full description (≤ 4000 chars)

```
Revive is your all-in-one fitness companion — powered by AI, built for real results.

Whether your goal is losing weight, building muscle, improving endurance, or just staying consistent, Revive gives you every tool you need in a single app.

─── SMART CALORIE & NUTRITION TRACKING ───
• Log meals instantly by scanning a barcode, photographing your food, or searching a database of millions of items (Open Food Facts + USDA)
• Get personalised daily calorie and macro targets calculated from your body stats and fitness goal
• Track breakfast, lunch, dinner, and snacks with a beautiful meal dashboard
• Your calorie target automatically adjusts after you log a workout

─── AI MEAL PLANS & WORKOUT IDEAS ───
• Receive a personalised weekly meal plan generated just for you (powered by Gemini)
• AI workout recommendations tailored to your goal and available equipment (gym or home)

─── WORKOUT TRACKING ───
• Log strength, cardio, and bodyweight workouts with an intuitive set/rep/weight logger
• Built-in rest timer keeps your rest periods on point
• Track outdoor runs and cycling with live GPS — see your route, pace, and distance in real time

─── COMMUNITIES & CHALLENGES ───
• Create or join communities by invite code or by searching the name
• WhatsApp-style group chat with updates from the admin, photos, videos and documents
• Start a 7, 21, 30, 60 or 90-day challenge — personal or with the whole group — and mark each day complete
• Notepad for every challenge with voice-to-text dictation, shareable with your community
• Community admins can follow members' fitness reports and challenges — only if the member chooses to share
• A private daily to-do list for your routines, visible only to you
• Rest score from sleep, resting heart rate and HRV
• Deload week detection — the app flags when your training volume suggests you need a lighter week

─── PROGRESS & ANALYTICS ───
• Weight trend, calorie trend, and strength curves
• Muscle group volume heat map — see which muscles are trained, undertrained, or at risk of overtraining
• Body stats log (weight, body fat %, BMI, muscle mass)

─── WEARABLE & HEALTH SYNC ───
• Syncs with Apple Health (iOS) and Google Fit (Android)
• Reads steps, heart rate, resting heart rate, HRV and sleep (with your permission)
• Connect a smartwatch or band over Bluetooth for live heart rate
• Writes workout energy back to your health platform

─── STREAKS & MOTIVATION ───
• Daily streak tracks your consistency — log a meal, complete a workout, or hit 7,500 steps to keep it alive
• Streak shields protect your streak for one missed day per week

─── FREE & PRO TIERS ───
Free: calorie tracking, workout logging, basic charts, communities & challenges
Pro ($9.99/mo): personalised meal plans, advanced analytics, full wearable sync, food photo logging

Download Revive and start your transformation today.
```

### Tags / Category
- Primary: **Health & Fitness**
- Secondary: N/A (Play only has one category)

### Content rating
- Everyone (no violence, no adult content, no user-generated public content)
- Complete the IARC questionnaire — select: Fitness app, no social features requiring moderation, no gambling, no ads shown to children (AdMob consent required)

---

## App Store Connect

### App name (≤ 30 chars)
```
Revive: AI Fitness & Nutrition
```

### Subtitle (≤ 30 chars)
```
Calories · Workouts · Community
```

### Description (≤ 4000 chars)
*(Use the same full description as Google Play above — identical copy is fine)*

### Keywords (≤ 100 chars total, comma-separated, no spaces after commas)
```
fitness,calorie tracker,workout log,community,challenge,macro tracker,nutrition,weight loss,gym
```
> 97 chars — within limit.

> Tips:
> - Do NOT repeat words already in the app name or subtitle (Apple ignores them).
> - Change keywords after 2–3 weeks based on Search Ads impression data.

### Promotional text (≤ 170 chars — can be updated without a new submission)
```
New: Communities — create or join groups, run 21 or 90-day challenges together, and keep a private daily to-do.
```

### Primary category
**Health & Fitness**

### Secondary category
**Lifestyle**

### Age rating
**4+** (no objectionable content; complete the age rating questionnaire — answer "No" to all)

### App privacy — Data Used to Track You
- Identifiers (Advertising ID) — only with consent via AdMob

### App privacy — Data Linked to You
- Contact info: Email Address
- Health & Fitness: Health, Fitness
- Location: Precise Location (optional, workout only)
- Identifiers: User ID

### App privacy — Data Not Linked to You
- Diagnostics (crash logs via Crashlytics/Sentry)
- Usage data (anonymised analytics via Firebase/Amplitude)

---

## Support & Review Notes

### Support URL
```
https://Easwar03-cmd.github.io/<repo-name>/
```
*(Update with actual repo name after GitHub Pages is live)*

### Privacy Policy URL
```
https://Easwar03-cmd.github.io/<repo-name>/privacy-policy.html
```

### Marketing URL (optional but recommended)
*(Same as Support URL for now)*

### Notes for App Review (Apple — add in "Notes" field during submission)
```
Test account credentials:
  Email: easwarnani098@gmail.com
  Password: [add your test password here before submitting]

The app requires an account to use core features.
AI features use Google Gemini API — responses may take 2–4 seconds on first load.
Communities let users chat, share photos and run challenges. Create a community from Community → Create community; join with an invite code or by searching its name. Voice dictation in a challenge notepad needs microphone permission.
GPS workout tracking requires location permission and works best outdoors.
HealthKit integration requires Health permission — grant during the onboarding prompt.
Stripe payment code exists in the backend but is not active; payments are processed via Google Play / StoreKit only.
```

---

## What's New (first release)
```
Welcome to Revive 1.0!

• Communities with group chat, admin updates and shareable challenge notepads
• Calorie & macro tracking with barcode scanner and food photo logging
• Workout logger with GPS tracking and rest timer
• 7 to 90-day personal and group challenges with daily check-ins
• Private daily to-do list
• Apple Health & Google Fit sync
• Weekly AI-generated meal plans (Pro)
```

---

## Brand assets
- **Play Store icon (512×512):** `apps/mobile/assets/icons/play_store_icon_512.png`
- **iOS App Store icon (1024×1024):** `apps/mobile/assets/icons/revive_icon.png`
- Source / regenerate: `python apps/mobile/assets/icons/gen_revive_logo.py`, then `dart run flutter_launcher_icons` in `apps/mobile`.
- Palette: sky `#B8E3EE`, lime `#CFE8B8`, butter `#FBE28C`, salmon `#E1A38A`, ink `#111111`.
