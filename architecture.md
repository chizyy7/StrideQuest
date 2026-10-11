# StrideQuest — Technical Architecture

**Related docs:** PRD.md, build-prompt.md, game-config.md, testing-plan.md

---

## 1. Guiding Principles

1. **Local-first.** The app works fully offline. No account required.
2. **Battery-respectful.** No GPS, no polling loops, no excess wake locks.
3. **One codebase.** Flutter for Android and iOS from day one.
4. **Ship an APK fast.** MVP avoids backend, auth and cloud sync entirely.
5. **Swappable data source.** Step data comes through an interface so `pedometer` can be swapped for Health Connect or HealthKit without touching UI.

## 2. High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      UI LAYER (Flutter)                 │
│  Onboarding · Home · Journey · Stats · Settings         │
│  (Widgets + Riverpod providers, no business logic)      │
└───────────────────────────┬─────────────────────────────┘
                            │ watches / calls
┌───────────────────────────▼─────────────────────────────┐
│                   DOMAIN LAYER (Dart)                   │
│  UseCases: RecordSteps · AwardXP · AdvanceJourney ·     │
│            UpdateStreak · EvaluateGoals                 │
│  Entities: User · Companion · Journey · StepLog · Goal  │
└───────────────────────────┬─────────────────────────────┘
                            │ depends on
┌───────────────────────────▼─────────────────────────────┐
│                    DATA LAYER (Dart)                    │
│  Repositories (interfaces)                              │
│    ├── StepRepository                                   │
│    ├── CompanionRepository                              │
│    ├── JourneyRepository                                │
│    └── UserRepository                                   │
│  Implementations:                                       │
│    ├── Local DB (Isar)                                  │
│    └── StepSource (pedometer / Health Connect)          │
└───────────────────────────┬─────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────┐
│              PLATFORM LAYER (Android / iOS)             │
│  Step Sensor · Foreground Service · Notifications ·     │
│  Health Connect (later) · HealthKit (later)             │
└─────────────────────────────────────────────────────────┘
```

Dependency rule: arrows point downward only. Domain depends on repository *interfaces*, never on Isar or `pedometer` directly. UI never calls the data layer; it goes through Riverpod providers that call use cases.

*Call made: two isolates.* The foreground service runs in its own Dart isolate; the UI runs in the main isolate. Both open the same Isar instance by name. The service is the only writer of step-derived state; the UI watches Isar streams and writes only user settings.
<!-- ASSUMPTION: Isar supports opening the same named instance from multiple isolates and cross-isolate watchers. Verify with a spike in build step 3 (build-prompt.md §15) before depending on it. -->

## 3. Tech Stack (locked)

| Concern | Choice | Why |
|---|---|---|
| Framework | Flutter (latest stable) | One codebase, fast APK builds, great animation |
| Language | Dart | n/a |
| State management | Riverpod | Testable, no BuildContext coupling, async-friendly |
| Local DB | Isar | Fast, typed, no SQL boilerplate, great for time-series |
| Step source (MVP) | `pedometer` | Direct sensor access, fastest path to APK |
| Step source (V1) | `health` + Health Connect | Unified, survives reinstall, system-of-truth |
| Background | `flutter_background_service` | Keeps foreground service alive for sensor events |
| Charts | `fl_chart` | Flexible, good-looking bar/line charts |
| Notifications | `flutter_local_notifications` | Reminders and milestone alerts |
| Permissions | `permission_handler` | Activity recognition, notifications |
| Routing | `go_router` | Declarative, deep-link ready |
| Fonts | `google_fonts` | Poppins (display), Inter (body) |
| Micro-animation | `flutter_animate` | Quick wins |
| Companion animation (optional V1) | `rive` | Richer character motion |

**No backend in MVP.** Supabase in V2 only if social features require it.

<!-- ASSUMPTION: `google_fonts` fetches fonts over the network at runtime by default, which would violate "no network calls". Bundle Poppins and Inter as asset fonts and disable runtime fetching (`GoogleFonts.config.allowRuntimeFetching = false`). -->
<!-- ASSUMPTION: Isar 3.x's upstream maintenance has slowed. Verify the current maintained package (a community fork exists) at project start; model definitions below are the same either way. -->
<!-- ASSUMPTION: minSdk 28 (Android 9) to match the Android 9 backward-compat test target in testing-plan.md. -->

## 4. Step Tracking Strategy

### 4.1 MVP: `pedometer` on Android

- `pedometer` reads the `TYPE_STEP_COUNTER` sensor.
- The sensor reports **cumulative steps since boot**.
- We persist the last known sensor value and compute **deltas**.
- Tracking runs inside a **foreground service** so Android does not kill it.
- On app open, reconcile with the sensor's current value.

```
Boot → Foreground service starts → Listens to step events
  → On each batch: compute delta, write StepLog to Isar
  → Trigger domain: AwardXP, AdvanceJourney, UpdateStreak
```

**Delta algorithm** (runs in the service and on app-open reconcile):

```
checkpoint = load SensorCheckpoint (lastSensorValue, lastReadAt)
current    = sensor cumulative value

if checkpoint is null:
    delta = 0                                  // first run: establish baseline
    save checkpoint(current)
elif current >= checkpoint.lastSensorValue:
    delta = current - checkpoint.lastSensorValue
else:
    delta = current                            // counter reset => device rebooted
save checkpoint(current)

if delta > 0: RecordSteps(delta, now)
```

*Call made: first-run baseline is zero.* Steps taken before the app was ever installed are not credited, avoiding a giant bogus first delta.
<!-- ASSUMPTION: After a reboot, steps taken between boot and the service restarting are credited via the "current counter value as delta" rule. Slight over-count is possible if the service restarts long after boot; accepted for MVP. -->

**Day bucketing:** each delta is attributed to the local calendar date at the time of the event. Date keys are date-only (year, month, day) to avoid DST arithmetic issues.

**Batching:** sensor events are buffered and flushed when either 25 steps accumulate or 30 seconds elapse (see game-config.md). No per-step DB writes.

### 4.2 V1: Health Connect

Prefer **Health Connect** as source of truth (deduplicates with Fitbit and Samsung Health, survives reinstall, handles OEM quirks). Keep `pedometer` as fallback if Health Connect is unavailable.

### 4.3 Data source abstraction

```dart
abstract class StepSource {
  Stream<int> get stepStream;        // cumulative or delta
  Future<int> getTodayTotal();
  Future<bool> requestPermission();
}
```

Implementations: `PedometerStepSource`, `HealthConnectStepSource`, `HealthKitStepSource`. Swap via a Riverpod provider.

<!-- ASSUMPTION: `stepStream` semantics must be fixed per implementation. `PedometerStepSource` emits cumulative-since-boot values; the delta algorithm above lives in `RecordSteps`'s caller (a `StepIngestor` class), not in the source, so Health Connect (which returns per-interval totals) can be adapted without changing use cases. Document the semantics in each source's class comment. -->

## 5. Data Model Definitions (Isar collections)

All distances are stored in **meters**. All timestamps are local-time `DateTime` (day buckets are local).

*Call made: ids.* Isar collections require an integer `Id`. Each collection has `Id isarId = Isar.autoIncrement` plus a `String uuid` with a unique index, preserving the spec's "local UUID" semantic and keeping V2 sync possible.

### User (single row in MVP)

| Field | Type | Notes |
|---|---|---|
| isarId | Id | auto-increment |
| uuid | String | unique index |
| dailyGoal | int | default 6000 |
| unit | enum (metric, imperial) | stored by name |
| createdAt | DateTime | |
| streakCurrent | int | |
| streakLongest | int | |
| lastGoalMetOn | DateTime? | date-only |
| coins | int | |
| onboardingComplete | bool | |
| notificationsEnabled | bool | |
| reminderMinuteOfDay | int | default 1200 (20:00) |

<!-- ASSUMPTION: The last three fields are not in the original spec but are required by onboarding routing and the notifications setting. -->

### Companion

| Field | Type | Notes |
|---|---|---|
| isarId | Id | |
| uuid | String | unique |
| userId | String | index |
| name | String | |
| species | enum (fox, sprout, axolotl) | |
| level | int | starts at 1 |
| xp | int | XP within the current level |
| stage | int | 0-4 |
| equippedSkin | String? | unused in MVP |
| celebratedLevel | int | highest level whose celebration was shown |

<!-- ASSUMPTION: `celebratedLevel` is added so the UI isolate can detect an un-shown level-up after the service (a different isolate) awarded it, including while the app was closed. -->

### StepLog

| Field | Type | Notes |
|---|---|---|
| isarId | Id | |
| uuid | String | unique |
| userId | String | |
| date | DateTime | date-only, local |
| steps | int | |
| distanceM | double | |
| updatedAt | DateTime | |
| goalAwarded | bool | true once the daily goal reward was granted for this date |

Index: **composite unique on (userId, date)**, so there is exactly one row per day and a lookup is O(log n).
<!-- ASSUMPTION: `goalAwarded` is added so EvaluateGoals is idempotent (a day's 10 coins and streak increment can never be granted twice). -->

### Journey

| Field | Type | Notes |
|---|---|---|
| isarId | Id | |
| uuid | String | unique |
| userId | String | |
| trailId | String | e.g. `coastal_path` |
| progressM | double | meters traveled on this trail |
| unlockedMile | int | last unlocked milestone index; -1 if none |
| celebratedMile | int | last milestone whose celebration was shown; -1 if none |
| completedAt | DateTime? | |

Index: (userId, trailId).
<!-- ASSUMPTION: `unlockedMile` uses -1 for "none unlocked" because milestone indexes start at 0. `celebratedMile` is added for the same reason as `celebratedLevel`. -->

### SensorCheckpoint (single row)

| Field | Type | Notes |
|---|---|---|
| isarId | Id | |
| lastSensorValue | int | cumulative counter at last read |
| lastReadAt | DateTime | |

<!-- ASSUMPTION: Added; the spec requires "store last known value" but defines no collection for it. -->

### TrailDefinition (static JSON asset, not in DB)

`id, name, theme, totalDistanceM, milestones[], completedText`. See `trails/coastal_path.json`. Loaded once at startup into memory by `trailDefinitionProvider`.

## 6. Domain Logic Rules

All tunables live in `lib/core/config/game_config.dart` (documented in game-config.md).

| Rule | Definition |
|---|---|
| XP per step | 1 |
| XP to complete level N | `round(100 * pow(N, 1.5))` |
| Level state | `level` (starts 1) and `xp` (progress within level). When `xp >= cost(level)` and `level < cap`: `xp -= cost(level); level++` (loop; several levels can pass in one batch) |
| Level cap | 50 <!-- ASSUMPTION: cap not specified; 50 is about 115 days at 6,000 steps/day --> |
| Evolution stage | `min(4, level ~/ 5)` |
| Distance per step | 0.0007 km (0.7 m), tunable |
| Imperial display | km x 0.621371, display only; storage stays metric |
| Streak increment | When today's steps >= dailyGoal, once per day |
| Streak break | A full day with steps < goal and no freeze used (no freezes in MVP) |
| Coins per goal met | 10 |
| Coins per milestone | Defined per milestone in trail JSON |
| Default daily goal | 6000 |

*Call made: reading "XP to reach level N".* Interpreted as the XP cost to complete level N (advance from N to N+1), with `xp` stored as within-level progress. This matches the Home UI's "680/900 XP" display and keeps the Companion `xp` field small. Cost of level 1 is 100; level 5 is 1,118; level 10 is 3,162.

**Streak evaluation:**

```
onStepsRecorded(today):
    if today.steps >= goal and not today.goalAwarded:
        coins += 10; today.goalAwarded = true
        if lastGoalMetOn == yesterday: streakCurrent += 1
        else:                           streakCurrent = 1
        streakLongest = max(streakLongest, streakCurrent)
        lastGoalMetOn = today

onDayRollover / onAppOpen:
    if lastGoalMetOn is before yesterday: streakCurrent = 0
```

Display rule: show `streakCurrent` if `lastGoalMetOn` is today or yesterday; otherwise show 0 with the "New streak starts today" copy.

**Journey advancement:**

```
progressM = min(totalDistanceM, progressM + deltaSteps * strideM)
for each milestone i > unlockedMile where progressM >= milestone.distanceM:
    unlockedMile = i; coins += milestone.rewardCoins
if progressM >= totalDistanceM: completedAt = now
```

Overshoot: progress clamps at trail length; a single batch may unlock several milestones, each awarded and queued for celebration in order.
<!-- ASSUMPTION: After trail completion in MVP, extra distance is discarded (only one trail exists). V1 should carry overflow into the next trail. -->

## 7. Background Processing Plan

- Android: `flutter_background_service` runs a **foreground service** with a persistent notification ("StrideQuest — Counting your steps 👟").
- Service type: `health`. Android 14+ requires the manifest declaration plus the `ACTIVITY_RECOGNITION` runtime permission to be granted before starting.
- The service isolate initializes Isar, repositories and the `StepIngestor`; it does **not** use Flutter UI or BuildContext.
- Battery: batch sensor events; write to Isar in chunks (25 steps or 30 s); no per-step DB writes; no GPS; no wake locks beyond what the foreground service implies.
- Restart: `RECEIVE_BOOT_COMPLETED` starts the service after reboot; the service re-reads the sensor and the delta algorithm handles the counter reset.
- On app open: the UI isolate triggers a reconcile (read sensor, compute delta) so the home screen is accurate even if the service was killed.
- iOS (later): CoreMotion `CMPedometer`; no foreground service needed.

**Required manifest additions:**

```xml
<uses-permission android:name="android.permission.ACTIVITY_RECOGNITION"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_HEALTH"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

<!-- ASSUMPTION: The service element needs `android:foregroundServiceType="health"` in AndroidManifest.xml (via the plugin's service entry override) for Android 14+. Confirm against the installed `flutter_background_service` version's docs. -->

**OEM caveat:** Xiaomi/MIUI and some Samsung configurations aggressively kill background work. Onboarding or Settings should show a friendly "keep StrideQuest running" help page with battery-optimization steps. <!-- ASSUMPTION: This help page is a small static screen under Settings; it is in MVP scope only if manual OEM testing shows kills. -->

## 8. Folder Structure

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
│       └── update_streak.dart
├── presentation/
│   ├── onboarding/
│   ├── home/
│   ├── journey/
│   ├── stats/
│   ├── settings/
│   └── widgets/                   # shared UI
└── assets/
    ├── trails/*.json
    └── images/
```

<!-- ASSUMPTION: `evaluate_goals.dart` (listed as a use case in the architecture diagram) is added to `domain/usecases/`. Flutter convention places `assets/` at the project root, not in `lib/`; keep it at root and declare in pubspec.yaml. -->

## 9. Testing Strategy

Full detail in testing-plan.md. Summary:

| Level | Scope | Tooling |
|---|---|---|
| Unit | XP, evolution, distance, streaks, journey, coins (pure Dart, no Flutter) | `flutter_test`, fake repositories |
| Widget | Home at 0 / mid / goal-met; ring value; XP bar | `flutter_test`, provider overrides |
| Integration | Simulated step stream to DB to UI; restart; reboot simulation | `integration_test`, in-memory Isar |
| Manual | Real sensors, OEM devices, battery, background kill, permissions | Device matrix |

Principle: **test the domain, smoke the UI, manual the sensors.** Use cases take a clock and repositories as constructor arguments so tests never depend on wall time.

## 10. Security and Privacy

- No network calls in MVP, so no data leaves the device.
- No account, so no PII is collected.
- App store privacy label: "Data not collected."
- No analytics or crash-reporting SDKs in MVP (V1 adds Sentry; evaluate its effect on the privacy label first).
- Verification: a release-checklist step greps the dependency tree and manifest for `INTERNET` permission usage; the release APK should declare none. <!-- ASSUMPTION: Debug builds add INTERNET automatically for tooling; the release build must not. -->

This is a **marketing asset.** Say it loudly.

## 11. Future Backend Plan (V2 only)

If and when social ships:

- Supabase (Postgres + auth + realtime).
- Sync only: user profile, streaks, journey progress, friend graph.
- Step logs stay local; only aggregates sync.
- Opt-in. Never required.
- The `uuid` fields on every collection are the sync keys.

## 12. Riverpod Provider List

| Provider | Type | Responsibility |
|---|---|---|
| `isarProvider` | `FutureProvider<Isar>` | Opens the Isar instance |
| `clockProvider` | `Provider<DateTime Function()>` | Injectable clock for testing |
| `stepSourceProvider` | `Provider<StepSource>` | Returns `PedometerStepSource` (swap point for V1) |
| `userRepositoryProvider` | `Provider<UserRepository>` | |
| `companionRepositoryProvider` | `Provider<CompanionRepository>` | |
| `journeyRepositoryProvider` | `Provider<JourneyRepository>` | |
| `stepRepositoryProvider` | `Provider<StepRepository>` | |
| `trailDefinitionProvider` | `FutureProvider<TrailDefinition>` | Loads trail JSON asset |
| `userProvider` | `StreamProvider<User>` | Watches the user row |
| `companionProvider` | `StreamProvider<Companion>` | Watches companion; exposes XP-to-next |
| `todayStepsProvider` | `StreamProvider<StepLog?>` | Watches today's StepLog |
| `journeyProvider` | `StreamProvider<Journey>` | Watches journey progress |
| `statsProvider` | `FutureProvider.family<StatsSummary, StatsRange>` | 7 / 30 / 365 day aggregates |
| `streakProvider` | `Provider<int>` | Derived display streak |
| `nextMilestoneProvider` | `Provider<MilestoneProgress>` | Derived distance to next landmark |
| `celebrationQueueProvider` | `NotifierProvider` | Pending level-up / milestone / goal celebrations |
| `settingsControllerProvider` | `NotifierProvider` | Goal, units, name, notifications writes |
| `permissionStatusProvider` | `FutureProvider<PermissionState>` | Activity recognition + notification status |
| `themeModeProvider` | `Provider<ThemeMode>` | Follows system |
| `reduceMotionProvider` | `Provider<bool>` | Reads `MediaQuery.disableAnimations` |
| `routerProvider` | `Provider<GoRouter>` | Routes; redirects to onboarding until complete |
| `stepIngestorProvider` | `Provider<StepIngestor>` | Delta algorithm + batching; used by UI reconcile and the service |