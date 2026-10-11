# StrideQuest — Agent Build Prompt

Paste this whole file into your coding agent (Cursor, Claude Code, etc.). It is self-contained. Companion docs (PRD.md, architecture.md, ui-ux-design.md, game-config.md, testing-plan.md) give more detail if present in the repo.

---

## 1. Goal

Build **StrideQuest**, a Flutter Android app (APK for testing; iOS later from the same codebase) that:

1. Counts steps in the background using the device step sensor, even when the app is closed.
2. Awards XP to a companion creature (1 XP per step), levels and evolves it.
3. Advances the user along one trail (Coastal Path, 10 milestones).
4. Tracks a daily goal and a streak.
5. Persists everything locally and works fully offline.

No backend. No accounts. No network calls. No ads. Tagline: "Turn your steps into a journey."

## 2. Tech Stack (LOCKED, do not deviate)

| Concern | Package |
|---|---|
| Framework | Flutter (latest stable), Dart |
| State | `flutter_riverpod` |
| Local DB | `isar` (+ `isar_flutter_libs`, `isar_generator`, `build_runner`) |
| Step source (MVP) | `pedometer` |
| Background | `flutter_background_service` |
| Charts | `fl_chart` |
| Notifications | `flutter_local_notifications` |
| Permissions | `permission_handler` |
| Routing | `go_router` |
| Fonts | `google_fonts` (bundle Poppins + Inter as assets; disable runtime fetching) |
| Animation | `flutter_animate` |

Not in MVP: `health`, `rive`, Supabase, any analytics or crash SDK.

## 3. Folder Structure (exact)

```
lib/
├── main.dart
├── app.dart                       # MaterialApp, router, theme
├── core/
│   ├── config/game_config.dart
│   ├── theme/
│   ├── router/
│   └── utils/
├── data/
│   ├── models/                    # Isar collections
│   ├── repositories/              # interfaces + impls
│   └── sources/
│       ├── step_source.dart
│       └── pedometer_source.dart
├── domain/
│   ├── entities/
│   └── usecases/
│       ├── record_steps.dart
│       ├── award_xp.dart
│       ├── advance_journey.dart
│       ├── update_streak.dart
│       └── evaluate_goals.dart
├── presentation/
│   ├── onboarding/
│   ├── home/
│   ├── journey/
│   ├── stats/
│   ├── settings/
│   └── widgets/
assets/                            # project root, declared in pubspec.yaml
├── trails/coastal_path.json
├── fonts/
└── images/
```

## 4. Domain Rules

```
XP per step            = 1
XP to complete level N = round(100 * pow(N, 1.5))   // cost to go from N to N+1
Level starts at 1; companion.xp = progress within the current level
Level cap              = 50
Evolution stage        = min(4, level ~/ 5)
Distance per step      = 0.0007 km (0.7 m), tunable
Streak increment       = when today's steps >= dailyGoal (once per day)
Streak break           = full day < goal AND no freeze used (no freezes in MVP)
Coins per goal met     = 10
Coins per milestone    = rewardCoins in trail JSON
Default daily goal     = 6000
```

Put ALL tunables in `lib/core/config/game_config.dart` (full file in §9). Never hardcode a gameplay number elsewhere.

Behavior details:
- A batch of steps can pass several levels: loop while `xp >= cost(level)` and `level < cap`.
- A batch can unlock several milestones: unlock and reward each, in order. Clamp journey progress to the trail's total distance.
- The daily goal reward and streak increment happen once per day (guard with `StepLog.goalAwarded`).
- On app open and at day rollover: if `lastGoalMetOn` is before yesterday, set `streakCurrent = 0`.
- Store distances in meters; convert to miles for display only.

## 5. Data Models (Isar)

Each collection has `Id isarId = Isar.autoIncrement` and a unique-indexed `String uuid`.

```dart
import 'package:isar/isar.dart';
part 'models.g.dart';

enum UnitSystem { metric, imperial }
enum Species { fox, sprout, axolotl }

@collection
class UserDoc {
  Id isarId = Isar.autoIncrement;
  @Index(unique: true) late String uuid;
  int dailyGoal = 6000;
  @Enumerated(EnumType.name) UnitSystem unit = UnitSystem.metric;
  late DateTime createdAt;
  int streakCurrent = 0;
  int streakLongest = 0;
  DateTime? lastGoalMetOn;       // date-only, local
  int coins = 0;
  bool onboardingComplete = false;
  bool notificationsEnabled = false;
  int reminderMinuteOfDay = 1200; // 20:00
}

@collection
class CompanionDoc {
  Id isarId = Isar.autoIncrement;
  @Index(unique: true) late String uuid;
  @Index() late String userId;
  late String name;
  @Enumerated(EnumType.name) Species species = Species.fox;
  int level = 1;
  int xp = 0;                    // progress within current level
  int stage = 0;                 // 0-4
  String? equippedSkin;
  int celebratedLevel = 1;
}

@collection
class StepLogDoc {
  Id isarId = Isar.autoIncrement;
  @Index(unique: true) late String uuid;
  @Index(composite: [CompositeIndex('date')], unique: true, replace: true)
  late String userId;
  late DateTime date;            // date-only, local
  int steps = 0;
  double distanceM = 0;
  late DateTime updatedAt;
  bool goalAwarded = false;
}

@collection
class JourneyDoc {
  Id isarId = Isar.autoIncrement;
  @Index(unique: true) late String uuid;
  @Index(composite: [CompositeIndex('trailId')]) late String userId;
  late String trailId;
  double progressM = 0;
  int unlockedMile = -1;         // -1 = none
  int celebratedMile = -1;
  DateTime? completedAt;
}

@collection
class SensorCheckpointDoc {
  Id isarId = Isar.autoIncrement;
  int lastSensorValue = 0;
  late DateTime lastReadAt;
}
```

Trail definitions are NOT in the DB; load `assets/trails/coastal_path.json` into plain Dart classes (`TrailDefinition`, `Milestone`).

<!-- ASSUMPTION: The collection class names carry a "Doc" suffix to avoid clashing with domain entities named User, Companion, etc. Domain entities in `domain/entities/` are plain Dart classes mapped from the docs by the repositories. -->

## 6. Step Tracking Implementation (in order)

1. **Abstraction.** Create `StepSource` (`stepStream`, `getTodayTotal()`, `requestPermission()`) and `PedometerStepSource`. `stepStream` emits cumulative-since-boot values.
2. **Permission.** Request `ACTIVITY_RECOGNITION` (and `POST_NOTIFICATIONS` on Android 13+) with `permission_handler`. Handle denied and permanently-denied states.
3. **StepIngestor.** Implement the delta algorithm:
```
   if checkpoint == null:        delta = 0 (baseline); save checkpoint
   elif current >= last:         delta = current - last
   else:                         delta = current   // counter reset after reboot
   save checkpoint(current); if delta > 0 -> RecordSteps(delta, now)
```
4. **Batching.** Buffer deltas; flush when 25 steps accumulate or 30 seconds pass. No per-step DB writes.
5. **RecordSteps use case.** Upsert today's `StepLog` (date-only local key); `steps += delta`; `distanceM += delta * strideM`. Then call, in order: `AwardXp`, `AdvanceJourney`, `EvaluateGoals` (which calls `UpdateStreak`). Each use case takes repositories and a clock via constructor.
6. **Foreground service.** Configure `flutter_background_service` with a persistent notification "StrideQuest — Counting your steps 👟". The service entry point initializes Isar (same instance name as the UI), repositories, `StepSource` and `StepIngestor`. No UI imports in the service isolate.
7. **Boot and restart.** Handle `RECEIVE_BOOT_COMPLETED` so the service restarts after reboot.
8. **App-open reconcile.** On app resume and pull-to-refresh, read the sensor and run the ingestor so the UI is accurate even if the service was killed.
9. **Spike first.** Before building UI on top, verify with a log-only prototype: the service survives swiping the app away, and Isar writes from the service isolate appear in UI-isolate watchers.

## 7. Screens to Build (MVP)

| Screen | Priority | Notes |
|---|---|---|
| Onboarding (welcome, companion, goal, permission) | P0 | Under 60 seconds; routes to Home when complete |
| Home | P0 | Ring, steps, distance and kcal pills, companion card, streak badge, next milestone link |
| Level-Up modal | P0 | Full-screen, confetti, "+N Level", "Nice!" button |
| Journey | P0 | Vertical path, 10 nodes, locked/unlocked, detail sheet, progress bar |
| Milestone Unlock modal | P0 | Node ripple, lore, coins |
| Stats | P1 | 7/30/365 bar chart, goal line, 4 summary cards |
| Settings | P1 | Goal, units, name, notifications, privacy page, about |

Navigation: bottom nav, 4 tabs (Home, Journey, Stats, Settings), via `go_router` `StatefulShellRoute`. Redirect to onboarding until `onboardingComplete`.

Home layout (follow this):

```
┌─────────────────────────────────┐
│  Good morning ☀️       🔥 12    │
│        ╭───────────╮            │
│        │   RING    │            │
│        │  4,320    │            │
│        │  / 6,000  │            │
│        ╰───────────╯            │
│   [ 2.9 km ] [ 210 kcal ]       │
│  ┌───────────────────────────┐  │
│  │      🦊  (companion)      │  │
│  │   Fern · Lv 7             │  │
│  │   ▓▓▓▓▓▓░░░  680/900 XP   │  │
│  └───────────────────────────┘  │
│  Next milestone: 1.1 km away →  │
└─────────────────────────────────┘
```

Celebrations: on Home resume, compare `companion.level` with `celebratedLevel` and `journey.unlockedMile` with `celebratedMile`; enqueue modals for anything un-shown, then update the celebrated fields. Collapse multiple level-ups into one modal.

## 8. Assets Needed

- **Trail:** `assets/trails/coastal_path.json` (provided separately; do not edit its values).
- **Fonts:** Poppins (700, 600) and Inter (400, 500) as bundled font assets.
- **Companion art:** use **placeholders**. Fox = 🦊, Sprout = 🌱, Axolotl = 🦎 rendered large as emoji text, or simple SVG shapes. Evolution stage is shown by size scale (1.0 to 1.4) plus an accessory badge (e.g. star count) until real art exists. Keep art behind a `CompanionAvatar` widget so it can be swapped for real assets or Rive later.
- **Map art:** a `CustomPainter` path with node icons over a gradient; no illustrated assets in MVP.
- **App icon:** simple placeholder.

## 9. Design Tokens and Game Config (Dart)

```dart
// lib/core/theme/tokens.dart
import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF6C5CE7);
  static const accent = Color(0xFFFFB84D);
  static const success = Color(0xFF00B894);
  static const streakFlame = Color(0xFFFF6B6B);
  static const bgLight = Color(0xFFF7F7FB);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const textPrimaryLight = Color(0xFF1A1A2E);
  static const textSecondaryLight = Color(0xFF6B6B80);
  static const bgDark = Color(0xFF12121A);
  static const surfaceDark = Color(0xFF1C1C28);
  static const textPrimaryDark = Color(0xFFF2F2F7);
  static const textSecondaryDark = Color(0xFFA0A0B8); // assumption
  static const barMissed = Color(0xFFD9D9E3);          // light gray, never red
}

class AppSpacing {
  static const double xs = 4, s = 8, m = 12, l = 16, xl = 24, xxl = 32;
}

class AppRadius {
  static const double card = 20, pill = 999, button = 16;
}

class AppText {
  static const double display = 40, h1 = 28, h2 = 22, body = 16, caption = 13;
  // weights: display 700, h1 700, h2 600, body 400, caption 400
  // use FontFeature.tabularFigures() on step counts
}

class AppMotion {
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration standard = Duration(milliseconds: 300);
  static const Duration max = Duration(milliseconds: 400);
  static const Curve ui = Curves.easeOut;
}
```

```dart
// lib/core/config/game_config.dart
import 'dart:math';

class GameConfig {
  const GameConfig._();

  // XP
  static const int xpPerStep = 1;
  static const double xpCurveBase = 100;
  static const double xpCurveExponent = 1.5;
  static const int levelCap = 50;
  static int xpToCompleteLevel(int level) =>
      (xpCurveBase * pow(level, xpCurveExponent)).round();

  // Evolution
  static const int levelsPerStage = 5;
  static const int maxStage = 4;
  static int stageForLevel(int level) => min(maxStage, level ~/ levelsPerStage);

  // Distance and display
  static const double strideKm = 0.0007;
  static const double strideM = strideKm * 1000;
  static const double kmToMiles = 0.621371;
  static const double kcalPerStep = 0.04; // rough estimate, display only

  // Goals
  static const int defaultDailyGoal = 6000;
  static const int goalCasual = 4000;
  static const int goalActive = 8000;
  static const int goalAmbitious = 12000;
  static const int goalMin = 1000;
  static const int goalMax = 30000;
  static const int goalStepSize = 500;

  // Coins
  static const int coinsPerGoalMet = 10;

  // Tracking
  static const int batchStepThreshold = 25;
  static const Duration batchFlushInterval = Duration(seconds: 30);
  static const int stepPulseInterval = 1000;
}
```

## 10. Motion Requirements

| Moment | Animation |
|---|---|
| App open | Ring fills from 0, ease-out; companion waves |
| Every 1,000 steps | Ring pulses; subtle haptic |
| Goal met | Ring glow, confetti, companion celebrates |
| Level up | Full-screen celebration; companion transforms; heavy haptic plus success pattern |
| Milestone unlock | Node expands with ripple |
| Streak increment | Flame scales and glows |
| Tab switch | Cross-fade plus slight vertical slide |

Rules: nothing over 400ms per transition; spring physics for character motion; ease-out for UI; haptics on every reward moment. **Respect reduce-motion:** when `MediaQuery.disableAnimations` is true, replace celebrations with fades and skip confetti.

## 11. Riverpod Providers to Create

`isarProvider`, `clockProvider`, `stepSourceProvider`, `stepIngestorProvider`, `userRepositoryProvider`, `companionRepositoryProvider`, `journeyRepositoryProvider`, `stepRepositoryProvider`, `trailDefinitionProvider`, `userProvider`, `companionProvider`, `todayStepsProvider`, `journeyProvider`, `statsProvider` (family by range), `streakProvider`, `nextMilestoneProvider`, `celebrationQueueProvider`, `settingsControllerProvider`, `permissionStatusProvider`, `themeModeProvider`, `reduceMotionProvider`, `routerProvider`.

UI watches Isar-backed `StreamProvider`s. Widgets contain no business logic.

## 12. Android Permissions

```xml
<uses-permission android:name="android.permission.ACTIVITY_RECOGNITION"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_HEALTH"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

Also declare the background service with `android:foregroundServiceType="health"`. Set `minSdkVersion 28`. The release build must not declare `INTERNET`.

## 13. What NOT to Build

- Ads, subscriptions, in-app purchases
- Login, accounts, cloud sync, any network call (including runtime font fetching)
- Analytics or crash-reporting SDKs
- Social features, leaderboards
- Health Connect / HealthKit
- GPS or location permissions
- Weight tracking, calorie goals, or any weight-loss framing
- Coin shop, skins, streak freezes, daily quests (V1)
- More than one trail
- iOS-specific code
- Red error or "failure" states for missed goals

## 14. Definition of Done

- [ ] `flutter build apk --release` succeeds with no errors
- [ ] Onboarding completes in under 60 seconds and routes to Home
- [ ] Steps are counted with the app swiped away (verified on a real device)
- [ ] After a device reboot, tracking resumes and no steps are double-counted
- [ ] Home shows ring, steps, distance, kcal pill, companion, streak and next milestone
- [ ] Level-up modal appears for levels gained while the app was closed
- [ ] Journey shows 10 milestones; unlocking awards the correct coins exactly once
- [ ] Goal met awards 10 coins and increments the streak exactly once per day
- [ ] Missed day shows "New streak starts today", with no red anywhere
- [ ] Stats show 7/30/365 views with goal line; missed bars are gray
- [ ] Settings changes (goal, units, name, notifications) persist across restarts
- [ ] Permission-denied state shows the friendly explainer and "Open Settings"
- [ ] Unit tests for XP, evolution, distance, streaks, journey and coins pass
- [ ] All interactive elements are at least 48dp; semantics labels on ring, companion, streak
- [ ] Reduce-motion respected; text scale 200% does not break layouts
- [ ] Release manifest has no `INTERNET` permission

## 15. Recommended Build Order (11 steps)

1. Project scaffold: pubspec, folders, theme tokens, `game_config.dart`, router shell with 4 tabs.
2. Isar models, code generation, repositories (interfaces and implementations), in-memory test setup.
3. **Spike:** foreground service plus `pedometer` plus Isar write from the service isolate, observed from the UI isolate (log-only).
4. Domain use cases (`RecordSteps`, `AwardXp`, `AdvanceJourney`, `UpdateStreak`, `EvaluateGoals`) with unit tests written alongside.
5. `StepIngestor` (delta, reboot reset, batching) wired to the service and to app-open reconcile.
6. Onboarding flow and permission handling (including denied states).
7. Home screen: ring, pills, companion card, streak badge, states for 0 / mid / goal met.
8. Celebrations: level-up modal and milestone-unlock modal, with the celebrated-field queue logic.
9. Journey screen: trail loading, path painter, node sheet, progress bar.
10. Stats and Settings screens; notifications (daily reminder, skipped when goal met).
11. Polish and verification: accessibility pass, reduce-motion, OEM device testing, battery test, release APK, Definition of Done walkthrough.

## 16. When Unsure

- Prefer **simple over clever**.
- Prefer **local over remote**. If something seems to need the network, it is out of scope.
- Prefer **shipping over perfecting**.
- **If a feature is not specified here, do not build it.** Ask or leave a clearly marked `// TODO(scope)` and move on.
- Never put gameplay numbers outside `game_config.dart`.
- Never block the UI on the sensor; show the last known value immediately and update.