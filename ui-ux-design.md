# StrideQuest — UI/UX Design Specification

**Related docs:** PRD.md, architecture.md, build-prompt.md

---

## 1. Design Principles

1. **One glance, one feeling.** Opening the app should feel *good* in under 2 seconds. Progress ring plus companion equals instant feedback.
2. **Delight in motion.** Every meaningful action animates. Level-ups feel like a tiny celebration.
3. **No guilt.** Missing a goal means encouragement, never shame. No red "you failed" states, anywhere.
4. **Thumb-first.** All primary actions are reachable one-handed.
5. **Calm color, warm accents.** Muted backgrounds so the companion and progress pop.

Our stance: this is a small game that happens to count steps. If a design decision makes it feel more like a dashboard, we make the other choice.

## 2. Design System

### 2.1 Color

| Role | Hex | Notes |
|---|---|---|
| Primary (Progress) | `#6C5CE7` | Soft indigo |
| Accent (Reward) | `#FFB84D` | Warm amber |
| Success | `#00B894` | Mint |
| Background (Light) | `#F7F7FB` | |
| Surface | `#FFFFFF` | Cards |
| Text Primary | `#1A1A2E` | |
| Text Secondary | `#6B6B80` | |
| Streak Flame | `#FF6B6B` | Reserved for the streak flame only; never used for error or failure states |

Dark mode:

| Role | Hex |
|---|---|
| Background | `#12121A` |
| Surface | `#1C1C28` |
| Text Primary | `#F2F2F7` |

<!-- ASSUMPTION: Dark-mode Text Secondary is `#A0A0B8`, and dark-mode Primary is lightened to `#8C7FF0` so contrast against `#1C1C28` stays above 4.5:1. Verify both with a contrast checker before implementation. -->
<!-- ASSUMPTION: `#6B6B80` on `#F7F7FB` is about 4.9:1, which passes 4.5:1. Amber `#FFB84D` on white fails for text; use amber only for fills and icons, with dark text on top of it. -->

### 2.2 Typography

- **Display:** Poppins (Nunito acceptable alternative): rounded, friendly
- **Body:** Inter: clean, legible
- **Numbers:** tabular figures for step counts so digits do not jitter as they tick up

| Style | Size | Weight |
|---|---|---|
| Display | 40 | 700 |
| H1 | 28 | 700 |
| H2 | 22 | 600 |
| Body | 16 | 400 |
| Caption | 13 | 400 |

All text scales with the system setting up to 200% without layout break.

### 2.3 Spacing and Shape

- Spacing scale: 4 / 8 / 12 / 16 / 24 / 32
- Corner radius: 20 (cards), 999 (pills), 16 (buttons)
- Soft shadows only. No harsh borders.
- Cards float on the background with 8-12% opacity shadows.

<!-- ASSUMPTION: Shadow spec: blur 24, offset (0, 8), black at 10% opacity in light mode. In dark mode, shadows are barely visible, so cards separate by surface color alone; do not add borders. -->

## 3. Core Components

| Component | Description |
|---|---|
| **Progress Ring** | Thick, animated, gradient fill (indigo to amber as the goal approaches). Center shows steps and goal. Tap flips to a detailed breakdown. |
| **Companion Card** | The star. Large, centered, subtle breathing animation. Shows name, level and XP bar. Tap triggers a reaction and a light haptic. |
| **Stat Pill** | Small rounded chip: distance, calories (rough estimate), and steps where needed. Icon plus label so color is never the only signal. |
| **Streak Badge** | Flame icon plus day count. Scales and glows on increment. |
| **Milestone Node** | Map node with locked (dimmed, padlock) and unlocked (lit) states; ripple on unlock. |
| **Celebration Modal** | Full-screen overlay used for level-up and milestone unlock. |
| **Bar Chart** | `fl_chart` bars; goal line; met = indigo, missed = light gray. |

## 4. Navigation Structure

Bottom navigation, 4 tabs:

```
[ Home ]   [ Journey ]   [ Stats ]   [ Settings ]
   🏠          🗺️           📊            ⚙️
```

- **Home**: the daily loop (ring, companion, streak)
- **Journey**: map and long-term progress
- **Stats**: charts and history
- **Settings**: goal, units, rename, privacy

Modal flows: Onboarding, Level-Up Celebration, Milestone Unlock.

Tab switching preserves each tab's scroll position. The bar sits in the thumb zone; all targets are at least 48dp.

## 5. Screen Specifications

### 5.1 Onboarding (3 steps plus permission, under 60 seconds)

*Call made: the spec lists "3 steps" then four items. Treat it as three setup screens followed by the permission ask.*

1. **Welcome.** One line: "Turn your steps into a journey." One button: "Let's go".
2. **Pick your companion.** Three options, each animated: Fox, Sprout, Axolotl. Tap to select; the selected one hops. Below, a name field pre-filled with a default name (Fern for the fox). <!-- ASSUMPTION: Default names: Fox = Fern, Sprout = Sprig, Axolotl = Axel. Name is editable here and later in Settings. -->
3. **Set your goal.** Slider with presets: Casual 4k / Active 8k / Ambitious 12k. Default 6k. Caption: "You can change this anytime."
4. **Permission ask.** Friendly copy: "StrideQuest needs to count your steps. Everything stays on your phone." The button triggers the system prompt. If denied, continue to Home with the permission-denied state (see §9).

Micro-delight: the companion reacts (blinks, hops) when tapped. Progress dots at the top; Back is always available.

### 5.2 Home

```
┌─────────────────────────────────┐
│  Good morning ☀️       🔥 12    │  ← streak badge
│                                 │
│        ╭───────────╮            │
│        │   RING    │            │  ← animated progress ring
│        │  4,320    │            │
│        │  / 6,000  │            │
│        ╰───────────╯            │
│                                 │
│   [ 2.9 km ] [ 210 kcal ]       │  ← stat pills
│                                 │
│  ┌───────────────────────────┐  │
│  │      🦊  (companion)      │  │  ← companion card
│  │   Fern · Lv 7             │  │
│  │   ▓▓▓▓▓▓░░░  680/900 XP   │  │
│  └───────────────────────────┘  │
│                                 │
│  Next milestone: 1.1 km away →  │
└─────────────────────────────────┘
```

Interactions:
- Tap ring: flips to a detailed breakdown (steps, distance, estimated kcal, steps remaining to goal).
- Tap companion: reaction animation plus a small "pet" haptic.
- Pull down: refresh from sensor (triggers a reconcile).
- Tap "Next milestone": jumps to the Journey tab, scrolled to that node.

Greeting changes by time of day. The streak badge is hidden in the first-ever session until streak is at least 1. <!-- ASSUMPTION: Hiding a zero streak avoids showing "0" on day one, which reads as failure. -->

States: see §9 for 0 steps, goal met, and permission denied.

### 5.3 Journey

- Vertical scrolling path, illustrated.
- Nodes light up as you unlock them.
- Locked nodes dimmed with a padlock.
- Tapping a node opens a milestone detail sheet (name, lore, reward coins, distance).
- Progress bar at top: "Coastal Path · 42% complete".
- A "you are here" marker sits between the last unlocked node and the next, positioned proportionally to progress.

<!-- ASSUMPTION: MVP illustration is a simple drawn path with node icons (SVG or CustomPainter) over a gradient sky; full illustrated art is deferred until the art-style decision (PRD §12). -->

Trail completion: the final node's celebration shows the trail's `completedText`.

### 5.4 Stats

- Bar chart: last 7 days by default, toggle to 30 / 365.
- Goal line highlighted across the chart.
- Summary cards: average steps, best day, total distance, current streak.
- Color-coded bars: met goal = indigo, missed = light gray. **Never red.**
- Tapping a bar shows the day's steps in a tooltip. In the 365 view, bars aggregate by week. <!-- ASSUMPTION: The 365 view aggregates weekly to keep bars readable. -->

### 5.5 Settings

- Daily goal (slider; min 1,000, max 30,000, step 500)
- Units (metric / imperial)
- Companion name (text field, max 16 characters)
- Notifications (toggle plus reminder time)
- Privacy (static page: "Your data never leaves your phone.")
- About / version

### 5.6 Modal: Level-Up / Evolution

- Full-screen, confetti burst, companion transforms.
- "+1 Level" scales in with spring physics.
- Single "Nice!" button.
- Haptic: heavy impact plus success pattern.

When the new level crosses an evolution stage (levels 5, 10, 15, 20), the companion visibly transforms. This is the emotional payoff and it must feel great. If several levels were gained while the app was closed, show one celebration for the highest level reached ("+3 Levels"), not a stack.
<!-- ASSUMPTION: Collapsing multiple level-ups into one modal avoids a frustrating queue after a long walk. -->

### 5.7 Modal: Milestone Unlock

- Triggered by crossing a trail milestone.
- The map node expands with a ripple; the sheet shows name, lore text and "+N coins".
- Single "Continue" button. Multiple unlocks queue in order.

## 6. Motion and Delight

| Moment | Animation |
|---|---|
| App open | Ring fills from 0 with ease-out, companion waves |
| Step milestone (every 1000) | Ring pulses, subtle haptic |
| Goal met | Full ring glow plus confetti plus companion celebrates |
| Level up | Full-screen celebration, companion evolves |
| Milestone unlock | Map node expands with ripple |
| Streak increment | Flame badge scales plus glows |
| Tab switch | Cross-fade plus slight vertical slide |

Rules: nothing over 400ms (the full-screen level-up is the only exception, where confetti may continue after the 400ms entrance); spring physics for character motion; ease-out for UI; haptics on every reward moment.
<!-- ASSUMPTION: "Nothing over 400ms" applies to individual transitions; ambient loops (companion breathing) and confetti particles are exempt. -->

## 7. Copy and Tone Rules

- Warm, second-person, never preachy.
- Say "Nice — 1,800 to go." Do not say "You have not met your goal."
- Say "Fern is proud of you." Do not say "Keep exercising to lose weight."
- **No calorie-shaming, no weight-loss framing, ever.** Calories appear only as a small rough estimate pill; never as a target, a "burned off" comparison, or food equivalent.

More examples:

| Situation | Use | Avoid |
|---|---|---|
| Goal met | "Goal reached. Fern is doing a happy dance." | "Target achieved." |
| Streak broken | "New streak starts today." | "You lost your streak." |
| Low steps late in day | "A short stroll still counts." | "You're behind today." |
| Permission denied | "No problem — you can turn this on whenever you're ready." | "Permission required." |
| Reminder notification | "Fern would love a walk today." | "You haven't hit your goal!" |

Reminder notifications are sent only once per day, at the user's chosen time, and are skipped if the goal is already met.

## 8. Accessibility Requirements

- Minimum contrast ratio 4.5:1 for text.
- All interactive elements at least 48dp.
- Full TalkBack / VoiceOver labels on ring ("4,320 of 6,000 steps, 72 percent"), companion ("Fern, level 7, tap to pet") and streak ("12 day streak").
- Respect system "reduce motion": swap celebrations for fades and skip confetti.
- No information conveyed by color alone (icons and text too): goal-met bars carry a check marker; locked nodes carry a padlock.
- Scalable text up to 200% without layout break.
- Haptics must be skippable when system haptics are disabled.

## 9. Empty and Edge States

| State | Behavior |
|---|---|
| No steps yet | Ring is empty. Copy: "Your day starts here. Take a few steps!" |
| Sensor permission denied | Friendly explainer card on Home plus "Open Settings" button. Rest of the app stays usable. |
| First-ever open | Onboarding, never an empty dashboard |
| Broken streak | "New streak starts today. 🌱" No guilt |
| Goal met | Ring glow, confetti once per day, copy "Goal reached" |
| Goal exceeded | Ring stays full; counter keeps counting; no extra celebration |
| Trail complete | Final celebration; Journey shows "Trail complete" and a placeholder "More trails coming" card |
| Notifications denied | Settings toggle shows an "Open Settings" hint; no repeated prompts |

## 10. Design References

Tonal inspiration only; do not copy.

- **Walkr:** proof that walking plus a story world can carry a whole product.
- **Finch:** the benchmark for a warm, guilt-free companion; what gentle, supportive copy feels like.
- **Duolingo:** the benchmark for celebratory motion and streak psychology. We borrow the sense of reward and take none of the pressure.