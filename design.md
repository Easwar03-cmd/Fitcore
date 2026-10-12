# Revive — UI/UX Redesign Spec (`design.md`)

**Status:** APPROVED — implementation in progress on branch `redesign/pastel-bento` (see §12 build status).
**Source of truth:** the 6-screen reference image (`images/1.jpg`). This document turns it into a tokenised design system and maps every Revive screen onto it.
**Rule:** features, data and copy stay the same. Only layout, cards, navigation, icons, charts and imagery change.

---

## 0. Read this first

| # | What | Why it matters |
|---|---|---|
| 1 | **Colours below are sampled from the image pixels**, not from a Figma file. They are within a few RGB points of the original. | Good enough for 1:1 visual match; can be re-tuned if you have the source file. |
| 2 | **The reference uses photographs and 3D renders** (athlete with battle ropes, runner, anatomical heart, smart-band, wrist photo, muscle illustrations). These are third-party assets (the image carries a Xiaohongshu watermark). **I cannot lift them into the app.** | "3D images match 100%" requires you to supply or commission equivalent assets — see §7 for the exact list and sizes. Until then screens ship with neutral placeholders in the same shapes. |
| 3 | **The reference is light-theme only.** Revive currently has light / dark / auto. | Decision **U1** (§12): keep dark with a derived palette, or go light-only. |
| 4 | **The reference nav has 4 icon-only tabs; Revive has 5 tabs.** | Spec in §5 extends the same pill to 5 slots, keeps it icon-only, adds screen-reader labels. |
| 5 | **Reference text colours fail WCAG in places** (grey captions 2.8:1, white on teal 3.3:1). | §10 lists the minimal darkening needed. Visual difference is imperceptible; compliance is kept. |

---

## 1. Reference analysis — what is actually in the image

Six phone screens, two rows. Backdrop (presentation only, not part of the UI): dusty rose `#DACBC6` on top, soft grey wave on bottom.

### Screen A — "Hello, Sophia" (top-left) → home / workout-picker pattern
```
┌──────────────────────────────┐
│ (avatar) Hello, Sophia   (🔔) │  header: 40 avatar · greeting · 44 circle bell
│ ┌──────────────────────────┐ │
│ │[🏆 Challenge]      ╭────╮│ │  hero card, sky blue, r28
│ │Challenge With      │ 3D ││ │  title 2 lines bold
│ │Pro Coach           │man ││ │  athlete cut-out BREAKS OUT of the card edge
│ │Get Started (▶)     ╰────╯│ │  white circle play button
│ └──────────────────────────┘ │
│ Select exercise type          │  grey 12
│ (⏱ coral) (○) (○) (○) (○ …)  │  56 circles, 1 selected = coral, scrolls horizontally
│ ┌──────────────────────────┐ │
│ │Muscles workload           │ │  white card r28
│ │Select muscles type…       │ │
│ │ ┌────────┐ ┌────────┐     │ │  2 tiles r20, selected = teal 1.5px outline
│ │ │ body   │ │ body   │     │ │  anatomy illustration, muscle group in red
│ │ │Shoulders│ │ Back   │     │ │
└──────────────────────────────┘
```
### Screen B — "Daily Challenge / Today's Activity" (top-middle) → stats summary pattern
- Header: **circle back button** (white, 44) · centred small title · **circle edit button**.
- Big title "Today's Activity" (26, regular) + grey date line.
- **Three stat rows**, each = coloured value pill (left) + grey label (right), hairline divider between:
  lime `10 th` / "Time in General" · sky `28m 45s` / "Today's routine" · salmon `10 min` / "Points earned". Each pill has a small leading icon.
- White card containing **two half-donut gauges**: title + grey subtitle, big % (28), gauge arc (teal / coral-red) with grey track, tiny delta ("+5%", "−5%") at the arc end.

### Screen C — "Set Timer / 10km Marathon" (top-right) → live workout pattern
- Header: circle back · centred "Set Timer" · circle "⋯".
- Title row: **black circle with orange ring + run icon**, then "10km Marathon" (26, medium).
- **Ruler-style line chart**: two smooth lines (blue lower, red rising), value tags above points ("320kcal", "654kcal", "1,233kcal"), x-axis is a row of vertical tick marks labelled 2km…10km.
- **Sky metric card** (r28): label/value list — Steps `14,233`, ♥ `112`, ⏱ `00:32` — each with a small coloured icon; teal "PRO" pill with trophy at top-right; **runner cut-out** with green motion swoosh, overflowing the card.

### Screen D — "Tracking your heart" (bottom-left) → device / hub bento pattern
- Header: avatar + greeting + bell (**orange unread dot**).
- Display headline "Tracking your heart" (30, bold, tight).
- **Bento grid:** tall lime card (left) "86% battery" with large battery glyph · grey photo card (right, wrist/band) · wide sky card "Customize your device" with product photo + two circle icon buttons.
- **Slide-to-connect bar** (butter yellow, r28): circle icon · "Connect ›››" · circle icon.

### Screen E — "Heart Health" (bottom-middle) → detail + contact pattern
- Header as D. Title "Heart Health" (24, medium).
- Large **lime feature card** r28: white circle icon + "Health" + grey caption + white pill button "Diagnostic"; right half is a framed **3D anatomical heart** with pin dots.
- Two **grey metric cards** side by side: "Heart pressure 123 / 80", "Heart rhythm 67 / min" (icon top-left, value 20 bold, unit grey).
- **Butter contact row** r24: avatar · name · role · two white circle buttons (chat, call).
- **Bottom nav:** 4 icons, no labels, the active one sits in a **solid black circle** with a white glyph.

### Screen F — "Diagnostics" (bottom-right) → data detail pattern
- Header: plain back chevron · two white rounded-square icon buttons (doc, share).
- **Sky hero metric card:** icon circle + label + "⋯"; number `82` (44) + "bpm"; ECG waveform with a **translucent vertical pill highlight**, cursor line and "80 bpm" tooltip.
- **Lime card:** "851 ms · R-R interval" + a ruler row of four values with ticks.
- **Result card** (white/grey): concentric-ring disc graphic, "Results", "You are calm and ready!", two dot-chips (Stress blue, Recovery green), ⓘ top-right.

---

## 2. Design language (the rules that make it look like the reference)

1. **Pastel bento.** Content lives in big, soft-coloured rounded cards (sky / lime / butter / grey / white). One strong colour per card, never gradients.
2. **Circles for every control.** Back, bell, edit, more, play, chat, call, settings, category pickers — all are white (or tinted) **circles**, outline icon inside.
3. **Pills for state.** Chips, status tags and value badges are fully-rounded pills.
4. **Big quiet type.** Screen titles 24–30, numbers 28–44, everything else 11–14. Lots of whitespace; no borders on cards.
5. **Imagery breaks the frame.** Hero cut-outs overflow the card's top/side edge; they are the only thing that breaks the grid.
6. **Data is drawn, not tabulated.** Half-donut gauges, ruler axes, ECG strips, concentric rings.
7. **Flat.** No card shadows. Depth comes from colour blocks and the black "active" circle.
8. **Near-black ink `#111`** for text and the active nav; never pure grey text on pastel.

---

## 3. Design tokens

### 3.1 Colour
| Token | Hex | Used for |
|---|---|---|
| `bg` | `#F2F2F2` | Scaffold background (screens A–C use `#E8E8E8`–`#F2F2F2`; D–F use white) |
| `bgAlt` | `#FFFFFF` | Alternate screen background (detail / data screens), white cards |
| `surface` | `#FFFFFF` | White cards, circle buttons |
| `surfaceMuted` | `#EFEFEF` | Grey metric cards, unselected tiles, input fill |
| `sky` | `#B8E3EE` | Hero cards, primary metric cards, info tint |
| `lime` | `#CFE8B8` | Health / success / "done" cards and pills |
| `butter` | `#FBE28C` | Action rows (connect, contact), warnings |
| `salmon` | `#E1A38A` | Selected category circle, points/energy pills |
| `ink` | `#111111` | Primary text, active nav circle, "play" glyph |
| `inkMuted` | `#6B6B6B` | Captions, units, axis labels (AA on white and `bg`) |
| `teal` | `#2F7E94` | Chips, "PRO" pill, positive gauge, selected outline (reference `#4C98B0`, darkened for AA) |
| `tealBright` | `#4C98B0` | Large graphics only (gauge arc, outlines) |
| `coral` | `#E26A5E` | Negative gauge, rising chart line, "calories" |
| `coralText` | `#C94A3F` | Coral used as small text |
| `alertDot` | `#F28C28` | Unread dot on bell |
| `hairline` | `#00000014` | Divider lines (8% ink) |
| `track` | `#E6E6E6` | Gauge / progress track |

Semantic mapping: success → `lime`+`ink`, info → `sky`, warning → `butter`, error → `coral`, selected → `ink` circle or `teal` outline.
Macro colours (protein / carbs / fat) are re-expressed as `sky` / `butter` / `salmon` fills with ink labels.

### 3.2 Typography
Reference face is a geometric grotesk (similar to *Satoshi / General Sans / Plus Jakarta Sans*). **Recommendation: Plus Jakarta Sans** (free, OFL, Flutter-bundleable), weights 400/500/700. *(Today `Inter` is referenced in code but not bundled, so devices fall back to system font — this fixes that too.)*

| Token | Size / weight / height | Tracking | Use |
|---|---|---|---|
| `display` | 30 / 700 / 1.1 | −0.5 | Hub headlines ("Tracking your heart") |
| `title` | 24–26 / 500 / 1.15 | −0.3 | Screen titles ("Today's Activity") |
| `metricXL` | 44 / 500 / 1.0 | −0.5 | Hero numbers ("82") |
| `metricL` | 28 / 500 / 1.0 | 0 | Gauge %, card values |
| `metricM` | 20 / 700 / 1.1 | 0 | Small card values ("123 / 80") |
| `heading` | 16–17 / 700 / 1.25 | 0 | Card titles |
| `body` | 14 / 400 / 1.4 | 0 | Body text |
| `caption` | 12 / 400 / 1.3 | 0 | Subtitles, labels (`inkMuted`) |
| `micro` | 11 / 500 / 1.2 | 0.1 | Axis labels, chips |

Numbers use tabular figures. Minimum text size 11. Honour system font scale up to 1.3 (cards grow, never clip).

### 3.3 Spacing, radius, size
| Token | Value |
|---|---|
| Spacing scale | 4 · 8 · 12 · 16 · 20 · 24 · 32 |
| Screen gutter | 16 (cards) / 20 (headline text) |
| Card gap (bento) | 12 |
| Section gap | 24 |
| `rCard` | 28 (hero/feature), 24 (standard), 20 (tiles) |
| `rPill` | 999 |
| `rInput` | 16 |
| Circle button | 44 (header), 56 (category), 36 (inline in cards), 40 (avatar) |
| Min touch target | 44 × 44 |
| Bottom nav | height 72, circle 48, bar radius 36 |

### 3.4 Elevation
No card shadows. Only: bottom nav bar `0 6 24 #00000014`; floating hero image none; modal sheets r28 top corners.

### 3.5 Icons
Outline icons, **1.5 px stroke, rounded caps/joins, 24 px grid**, ink colour. Recommended set: **Phosphor (Regular)** or **Solar (Linear)** — both match the reference stroke. Filled variants only for the active nav glyph and tiny status icons.

### 3.6 Motion
| Element | Animation | Duration / curve |
|---|---|---|
| Screen enter | cards fade + 12px rise, 40 ms stagger | 320 ms `easeOutCubic` |
| Gauge / ring / bar | sweep from 0 | 700 ms `easeOutCubic` |
| Chart lines | draw-on left→right | 600 ms |
| Category select | circle fill cross-fade + scale 1→1.06→1 | 200 ms |
| Nav select | black circle slides to new slot | 220 ms `easeInOut` |
| Hero cut-out | subtle parallax with scroll (max 12 px) | — |
| Slide-to-connect | thumb drag, release ≥ 85 % triggers | spring |
Respect "reduce motion": replace with 100 ms fades.

---

## 4. Component catalogue

Every component is **dumb** (props + callbacks), lives in `core/widgets/`, and reads colours only from tokens.

| Component | Spec (from reference) | Variants / states |
|---|---|---|
| `AppHeader` | 56 tall; left `CircleIconButton` or avatar+greeting; right `CircleIconButton`s; centred 13/500 title optional | `home` (avatar+greeting+bell), `detail` (back · title · action), `plain` (chevron + square icon buttons — screen F) |
| `CircleIconButton` | 44 circle, `surface`, 1.5 outline icon 22, no border | default · pressed (`surfaceMuted`) · selected (`ink` fill, white icon) · badge dot |
| `Avatar` | 40 circle, photo or initial on `sky` | with status dot |
| `HeroCard` | r28, tint `sky`, padding 16; left: chip, title 17/700 (2 lines), CTA row; right: **cut-out image overflowing top** (−24 px) | tint: sky · lime · butter; CTA: `PlayButton` |
| `Chip` | pill, 28 tall, 11/500; `teal` fill + white text + 14 icon; or `surface` + ink | filled · outline · with leading dot (blue/green) |
| `PlayButton` | 40 white circle, ink ▶ 16 | pressed |
| `CategoryRow` | horizontal list of 56 circles; selected = `salmon` fill + ink icon | scrollable, snap-less |
| `FeatureCard` | white card r28, title 16/700 + caption, content slot | — |
| `SelectableTile` | r20, `surfaceMuted`, illustration + centred label; selected = 1.5 `tealBright` outline | default · selected |
| `StatRow` | `ValuePill` (tint, r999, 44 tall, icon + value 14/500) + caption 14 `inkMuted`, hairline below | tint: lime/sky/salmon |
| `GaugeCard` | white r28; two `HalfDonutGauge`: title 12 bold, subtitle 11 muted, % `metricL`, arc 10 px stroke, delta text | positive `tealBright` · negative `coral` |
| `HalfDonutGauge` | CustomPainter 180° arc, round caps, track `track` | animated |
| `RulerLineChart` | smooth cubic lines (2 px), value tags in small rounded labels, **x-axis = tick ruler** (vertical 8 px ticks, labels 11 muted), no grid, no Y axis | series colours sky-blue / `coral` |
| `MetricListCard` | `sky` r28; rows: 20 coloured icon + label 12 muted + value 20/700; `PRO` chip top-right; image slot right (overflow) | — |
| `BentoGrid` | 2 columns, 12 gap; cards may span 1×2 | tall / wide / square |
| `StatCard` | `surfaceMuted` r24, 16 padding: icon (24) top-left, value `metricM` + unit muted | tint overrides |
| `BatteryCard` / `ProgressCard` | `lime`, big vertical battery/ring glyph, value `metricL` + caption | — |
| `SlideAction` | `butter` r28, 56 tall; left/right circle slots; centred "Label ›››"; draggable thumb | idle · dragging · complete |
| `ContactRow` | `butter` r24; avatar 40, name 14/700, role 11 muted, two 36 circle buttons | — |
| `ValueHeroCard` | `sky` r28: icon circle + label + "⋯", `metricXL` + unit, waveform slot with highlight pill + tooltip | — |
| `ResultCard` | `surfaceMuted` r28: concentric-ring graphic left, title 16/700, caption, dot-chips, ⓘ | — |
| `FloatingNav` | white pill bar r36, h72, margin 16 from edges & safe-area; N circles 48; active = `ink` circle + white filled glyph | see §5 |
| `PrimaryButton` | pill 52, `ink` fill / white text (replaces purple) | primary · secondary (`surface`, ink text) · ghost · loading · disabled (`surfaceMuted`) |
| `TextField` | `surfaceMuted`, r16, no border, 16 padding; focus = 1.5 `ink` outline | default · focus · error (`coral`) · disabled |
| `ListRow` | 64 tall, leading 40 circle (tint), title 14/700, subtitle 12 muted, trailing chevron/value | — |
| `Sheet` | r28 top, handle 36×4, `bgAlt` | — |
| `Snackbar` | `ink` r16, white text, floats above nav | — |
| `EmptyState` | 3D/illustration 120 + title 16/700 + caption + pill CTA | — |

---

## 5. Navigation & footer

**Bottom nav = `FloatingNav`** (reference screen E):
- White bar, r36, height 72, 16 px side margin, sits 12 px above the safe area, soft shadow `0 6 24 #00000014`.
- **Icons only.** 5 slots evenly spaced for Revive: **Home · Nutrition · Workout · Progress · Community**.
- Inactive: outline glyph 24, `ink` at 100 % (reference icons are full black, not grey).
- Active: 48 **black circle**, white **filled** glyph; circle animates between slots.
- Accessibility: each slot has `Semantics(label: 'Nutrition', selected: …)` and a long-press tooltip, since there are no visible labels.
- Hidden on full-screen flows (chat, active workout, forms) exactly as today.

| Tab | Icon (Phosphor) |
|---|---|
| Home | `house` |
| Nutrition | `fork-knife` |
| Workout | `barbell` |
| Progress | `chart-line-up` |
| Community | `users-three` |

**Top navigation:** header per §4 `AppHeader`. System back gesture unchanged. Profile is opened from the home avatar (as today).

---

## 6. Screen-by-screen mapping (Revive → reference pattern)

Content, data and actions are unchanged; only arrangement changes.

### 6.1 Home dashboard → pattern **A + D**
```
AppHeader(home): avatar · "Hi, {name}" · bell(dot if reminders)
HeroCard(sky):  chip "Today"  · "{kcal left} kcal left" · CTA "Log food ▶"   [3D plate/apple cut-out]
CategoryRow:    Log food · Water · Workout · Weight · Scan   (circles; selected → salmon)
BentoGrid:
  ┌ CalorieRing card (lime, tall, 1×2) ┐ ┌ Steps StatCard (grey) ┐
  │ ring + "1,240 / 2,100 kcal"         │ ├ Streak StatCard (grey) ┤
  └─────────────────────────────────────┘ └────────────────────────┘
  Macros card (white, 3 pills protein sky / carbs butter / fat salmon with bars)
  Water card (sky, glass fill + "+250 ml" circle button)
  "+X kcal from workout" → Chip(lime)
SyncBanner → Chip(butter) pinned under header
Ad slot → white card r24, "Ad" chip
```
### 6.2 Nutrition → **B + E**
- Header detail ("Nutrition", edit/add circle).
- Title "Today's Nutrition" + date; **three StatRows** (Calories / Protein / Water) like screen B.
- **GaugeCard**: "Calorie goal" % and "Macro balance" %.
- Meal sections become **butter / sky / lime / grey cards** (Breakfast / Lunch / Dinner / Snack): emoji → circle icon, kcal pill, `+` circle button, horizontal food chips.
- Camera / barcode / search become **3 circle buttons** in the header row.
### 6.3 Food search / barcode / photo / log sheet / meal plan
- Search: `TextField` in a white r28 header card; results as `ListRow`s; local results get a lime "Local" chip.
- Log sheet: r28 sheet; serving chips = `Chip`s; macro preview = 3 `StatCard`s; primary = `PrimaryButton`.
- Food photo: full-bleed camera in an r28 frame, shutter = 72 circle; detected items = `ListRow`s in a white card.
- Meal plan: day selector = `CategoryRow` circles (M T W…); planned meals = tinted cards.
### 6.4 Workout hub → **A**
```
Header · HeroCard(sky) "Resume workout" / "Start a workout"
CategoryRow: Gym · Home · Outdoor · History
Muscles workload FeatureCard: 2 SelectableTiles (front/back) with anatomy illustration
DeloadBanner → butter/lime Chip-card
```
- Gym / Home lists: exercise = `ListRow` with 40 circle (tint by muscle group); filters = `Chip`s; AI recommendation = `MetricListCard` (sky) with `Report` flag circle.
### 6.5 Active workout → **C**
- Header detail: back · exercise name · "⋯".
- Title row with ink circle + icon and elapsed timer (metricXL).
- **RulerLineChart** for pace/kcal when outdoor; **MetricListCard** (sky) for sets / reps / HR/kcal; rest timer = `SlideAction`-style butter bar with countdown ring.
- Set logger = grey `StatCard`s with ± circle buttons; "Finish" = black `PrimaryButton`.
- Summary = pattern **B** (3 StatRows + GaugeCard) + route map in a r28 card.
### 6.6 Progress → **B + F**
- Title "Progress"; **ValueHeroCard** (sky) for current weight with trend line; lime card "Streak"; **RulerLineChart** for weight/calories; strength curve in white card; muscle heat-map in `SelectableTile`s (front/back like A).
- Body log: white FeatureCard + two `TextField`s + `PrimaryButton`.
### 6.7 Community → **D + E**
- **Home:** header "Community" + search circle; "Create community" = **pill button directly under header, left-aligned** (as specified); communities = `ListRow` cards (tinted avatar circle, last-message preview, Admin chip); empty text "Not joined community yet" in `inkMuted` 40 %; To-do = butter card row.
- **Chat:** header detail (back · community name + members · challenges & info circle buttons). Own bubbles `sky`, others `surfaceMuted`, admin updates = `lime` card with 📣 chip. Composer = white pill with attach / text / send(ink circle).
- **Info / admin:** `ListRow` groups in white r28 cards; consent switch in a lime card; invite code in a butter card with copy/share circles.
- **Member report:** pattern **F** — header with member avatar; ValueHeroCard (sky) = workouts; lime card = streak; StatCards = avg kcal / protein / weight; challenge rows = `ListRow` + progress bar.
- **Challenges:** HeroCard "New challenge"; list = tinted cards with progress bars; **Challenge detail:** day grid in a white card (done = ink circle with ✓, today = teal outline), notepad in `surfaceMuted` r28 with mic circle, participants = `ListRow`.
- **To-do:** header detail; checklist rows in white card with circle checkboxes; "Repeat every day" `Chip`.
### 6.8 Profile / settings / notifications
- Header with big avatar block (sky card, name + email, edit circle).
- Groups = white r28 cards of `ListRow`s with tinted circle icons; Appearance = segmented pill; Logout = coral ghost.
### 6.9 Subscription / paywall
- Tier cards = tinted: Free (grey), Pro (sky + "Most popular" Chip), Coach (butter). Feature rows with check circles (lime). CTA = black `PrimaryButton`. Prices `metricL`.
### 6.10 Auth + onboarding + splash
- Splash: white, logo + sky blob.
- Login / signup / forgot: display headline left-aligned, `TextField`s, black pill CTA, a sky `HeroCard` illustration on top.
- Onboarding goal: 4 big `SelectableTile`s (2×2) with 3D icon; body stats: stat cards with steppers; activity: vertical `ListRow` tiles with selected teal outline. Progress = dotted pill indicator.

---

## 7. Imagery & "3D" assets

The reference's depth comes from **cut-out photos and 3D renders overflowing cards**. Revive needs its own equivalents.

> I will not copy the photographs from the reference screenshot into the app. Use the images you own / have licensed.

### 7.1 File contract (already wired in code)

Drop files into `apps/mobile/assets/images/`. Until a file exists the card shows a white disc with an icon in the same position, so nothing breaks.
**Format:** transparent PNG or WebP · subject cut out · soft contact shadow optional · keep < 150 KB each.

| File name | Where it shows | Card tint behind it | Subject to supply | Size (px) | Status in code |
|---|---|---|---|---|---|
| `hero_home_plate.png` | Home → top hero card (right side, overflows top) | sky | Healthy plate / bowl / apple, 3D-render or photo cut-out | 900 × 900 | ✅ wired |
| `hero_gym_athlete.png` | Workout → "Gym Workout" hero | sky | Person lifting / battle ropes (like reference A) | 900 × 1000 | ✅ wired |
| `hero_home_workout.png` | Workout → "Home Workout" hero | lime | Person doing bodyweight / yoga / push-up | 900 × 1000 | ✅ wired |
| `workout_runner.png` | Active workout → outdoor GPS metric card | sky | Runner mid-stride (like reference C) | 700 × 900 | ✅ wired |
| `hero_progress.png` | Progress → top value card | sky | Scale / body-measure render or athlete | 800 × 800 | step 5 |
| `hero_community.png` | Community → create/empty states | lime | Group of people / friends high-five | 900 × 700 | step 5 |
| `challenge_trophy.png` | Challenges → hero + "completed" | butter | 3D trophy / medal | 600 × 600 | step 5 |
| `empty_workout.png`, `empty_food.png`, `empty_chat.png` | Empty states | sky | Simple 3D object (dumbbell / apple / chat bubble) | 512 × 512 | step 5 |
| `onboarding_goal.png`, `onboarding_body.png`, `onboarding_activity.png` | Onboarding screens | sky / lime / butter | One subject each | 900 × 900 | step 6 |
| `auth_hero.png` | Login / signup header | sky | Athlete or abstract 3D | 1000 × 800 | step 6 |
| `anatomy_front.svg`, `anatomy_back.svg` | Muscle tiles (Progress heat-map) | grey | Body outline with separable muscle paths (chest, back, shoulders, arms, legs, core) | vector | step 5 |

### 7.2 What I can do with your photos
- Remove backgrounds → transparent PNG (I'll use `rembg`/Pillow locally; you review each result).
- Crop, resize, compress, rename to the file names above.
- Tint-match edges to the pastel card colours.
I **cannot** invent photographic assets; if a photo is missing the placeholder stays.

### 7.3 How to hand them over
Put the originals in `apps/mobile/assets/images/source/` (any names) **or** re-attach them in chat. Tell me which photo is for which row above (or leave it to me and I will propose a mapping for your approval).

---

## 8. Charts & data-viz specs

| Chart | Spec |
|---|---|
| Half-donut gauge | 180° arc, stroke 10, round caps, track `track`; value arc `tealBright` (positive) / `coral` (negative); centre `metricL`; delta text 11 at arc end; animate 700 ms. Semantics: "Level activity 38 percent, up 5". |
| Ruler line chart | `fl_chart` for lines (curved, 2 px, no dots except last), **custom axis painter** for tick ruler; value tags = r8 white labels with 11/500 text; touch shows tooltip like screen F. |
| ECG / waveform | `CustomPainter` polyline 1.5 px ink, highlight band r999 `white @ 45 %`, cursor 1 px. Used for heart-rate if wearable data exists, otherwise for workout intensity. |
| Concentric rings | 3 rings stroke 8, `sky / lime / salmon`, gap 6; used for macros and "Results" card. |
| Linear bars | height 8, r999, track `track`, fill tint; label above. |
| Day grid (challenge) | 36 circles; done = `ink` + white ✓; missed = `coral @ 20 %`; today = `tealBright` 2 px outline. |

---

## 9. States (all components)

| State | Treatment |
|---|---|
| Loading | Skeleton blocks in `surfaceMuted` with 1.2 s shimmer; same radius as final card |
| Empty | `EmptyState` (3D object + sentence + pill CTA) |
| Error | `coral @ 12 %` card, message, "Retry" ghost pill |
| Offline | `butter` chip under header ("Offline — will sync") (replaces current sync banner) |
| Disabled | 40 % opacity, no ripple |
| Pressed | scale 0.97 + `surfaceMuted` overlay, 80 ms |
| Focus (keyboard / TalkBack) | 2 px `ink` outline, 2 px offset |

---

## 10. Accessibility review of the reference (WCAG 2.1 AA)

| Item | Reference | Result | Fix in Revive |
|---|---|---|---|
| Ink `#111` on sky / lime / butter / salmon | 13.7 / 14.3 / 14.7 / 8.8 : 1 | ✅ | — |
| Grey caption ≈ `#9A9A9A` on white | 2.8 : 1 | ❌ 1.4.3 | `inkMuted #6B6B6B` → 5.3 : 1 |
| White text on `#4C98B0` chip | 3.3 : 1 | ❌ (11 px text) | chip fill `teal #2F7E94` → 4.6 : 1 |
| Coral `#E26A5E` as text on white | 3.25 : 1 | ❌ | `coralText #C94A3F` → 4.6 : 1; coral only for graphics (3:1 OK) |
| Colour-only gauge meaning (teal vs red) | — | ❌ 1.4.1 | Always print `+5%` / `−5%` and an ▲/▼ glyph |
| Icon-only bottom nav | no labels | ⚠ 4.1.2 | `Semantics` labels + tooltips; selected state announced |
| Touch targets | 44 circles | ✅ | keep ≥ 44; 36 inline buttons get 44 hit area |
| Text scaling | fixed sizes | ⚠ 1.4.4 | cards use min-height not height; test at 1.3× |
| Motion | decorative | ✅ | respect reduce-motion |
| Images | decorative | ✅ | `excludeSemantics` on cut-outs; meaningful charts get summary labels |

---

## 11. Implementation plan

Branch `redesign/pastel-bento`, one commit per step, `flutter analyze` + tests green at each.

| Step | Work | Files |
|---|---|---|
| 1 | Tokens: `app_colors.dart`, `app_text_styles.dart`, `app_spacing.dart`, `app_radius.dart`; `ThemeData` rewrite (cards flat, inputs, buttons ink pill, nav theme); bundle Plus Jakarta Sans | `core/theme/*`, `pubspec.yaml`, `assets/fonts/` |
| 2 | Shared components (§4): header, circle button, chips, cards, bento, gauge, ruler chart, slide action, floating nav, buttons, text field, skeletons | `core/widgets/*` (each < 300 lines) |
| 3 | Shell: replace `BottomNavigationBar` with `FloatingNav` in `main_shell.dart`; keep PopScope behaviour | `router/main_shell.dart` |
| 4 | Home → Nutrition → Workout (hub, lists, active, summary) | `features/home`, `nutrition`, `workout` |
| 5 | Progress, Community (all 12 screens), Profile / settings, Subscription | `features/*` |
| 6 | Auth, onboarding, splash | `features/auth`, `onboarding` |
| 7 | Asset drop-in (when delivered), golden tests for 6 key screens, accessibility pass (TalkBack), 1.3× text-scale test | `test/`, `assets/` |

**Constraints kept:** no feature, route, provider or API changes; Riverpod state untouched; widgets stay pure; files < 300 lines (several large screens get split as they are restyled).
**New packages:** `phosphor_flutter` (icons), optionally `shimmer`; no others (charts reuse `fl_chart` + `CustomPainter`).
**Risk:** high volume of UI files (~70) → mitigated by shared components first; visual regressions caught by goldens.

---

## 12. Decisions (resolved)

| ID | Decision |
|---|---|
| U1 | **Light-only.** Dark theme and the Appearance toggle were removed. |
| U2 | **Plus Jakarta Sans**, bundled as a variable font (`assets/fonts/`, OFL). |
| U3 | **Phosphor Regular** (`phosphor_flutter`), Fill variant for the active nav glyph and tiny status icons. |
| U4 | Real photos/3D images: user supplies; wiring is done with placeholders (see §7.1). |
| U5 | **Icon-only** bottom nav with screen-reader labels + tooltips. |
| U6 | Accessibility colour adjustments **applied** (§10). |
| U7 | First pass = steps 1–4 (tokens, components, nav, Home / Nutrition / Workout). |

### Build status
| Step | Status |
|---|---|
| 1 Tokens, theme, font | ✅ |
| 2 Shared components | ✅ (`core/widgets/*`) |
| 3 Floating nav shell | ✅ |
| 4 Home, Nutrition, Workout (hub, lists, picker, active, summary, history) | ✅ |
| 4b Nutrition sub-screens (search, barcode, photo, meal plan, log sheet) | ⏳ themed by global theme only — full restyle in step 5 |
| 5 Progress, Community, Profile, Subscription | ⏳ |
| 6 Auth, onboarding, splash | ⏳ |
| 7 Assets drop-in, goldens, TalkBack pass | ⏳ |

### Deliberate deviations (feature parity wins over pixel parity)
- Reference screen A's **"Muscles workload" body-tile picker** is not added to the Workout hub: Revive has no feature behind it (it would be a new feature). The anatomy tiles are used where Revive already has a muscle heat-map (Progress).
- Reference screen D/E **heart / battery / ECG** content has no Revive equivalent; the layouts (bento grid, slide action, value-hero card, ruler chart) are reused for calories, steps, water and workout metrics.

---

## 13. Fidelity checklist ("matches the reference")

- [ ] Header = avatar + greeting + circle bell with orange dot; detail screens = circle back + centred title + circle action
- [ ] Hero card sky r28 with chip, 2-line title, ▶ circle, cut-out overflowing
- [ ] Category circles 56, selected = salmon
- [ ] Pastel bento cards sky / lime / butter / grey, **no shadows, no borders**
- [ ] Stat rows with tinted value pills + hairline dividers
- [ ] Half-donut gauges with deltas
- [ ] Ruler-axis line chart with value tags
- [ ] Metric list card with PRO chip + overflow image
- [ ] Slide-to-connect style action bar
- [ ] Contact-style row with two circle actions
- [ ] Floating white nav, icon-only, active = black circle
- [ ] Display headline 30 bold tight on hub screens
- [ ] Outline 1.5 px icons everywhere
- [ ] 3D / cut-out imagery present on hero cards (placeholder → real asset)
