# StrideQuest — Testing Plan

**Related docs:** architecture.md §9, build-prompt.md §14, game-config.md

---

## 1. Testing Philosophy

**Test the domain, smoke the UI, manual the sensors.**

- **Domain logic** (XP, levels, distance, streaks, journey, coins) is pure Dart and gets thorough automated unit tests. This is where regressions hide and where tests are cheap.
- **UI** gets a few widget tests that prove the key states render and update; we do not pixel-test.
- **Sensors, background execution and battery** cannot be trusted in emulators; they get structured manual tests on real devices.
- Every use case takes a clock and repositories as constructor arguments. No test depends on wall-clock time or real storage.

## 2. Unit Test Plan

Tools: `flutter_test`; fake in-memory repositories; fixed clock.

### 2.1 XP math

| Case | Expected |
|---|---|
| `xpToCompleteLevel(1)` | 100 |
| `xpToCompleteLevel(2)` | 283 |
| `xpToCompleteLevel(5)` | 1,118 |
| `xpToCompleteLevel(10)` | 3,162 |
| Award 99 XP at level 1, xp 0 | level 1, xp 99 |
| Award exactly 100 XP at level 1, xp 0 (exact threshold) | level 2, xp 0 |
| Award 101 XP at level 1, xp 0 | level 2, xp 1 |
| Award 1 XP at level 1, xp 99 | level 2, xp 0 |
| Award 500 XP at level 1, xp 0 (multi-level) | level 3, xp 117 (100 + 283 consumed) |
| Award 0 steps | no change, no event |
| At level cap (50) | level stays 50; no overflow into level 51; no error |
| Evolution stage at levels 1, 4, 5, 9, 10, 19, 20, 49 | 0, 0, 1, 1, 2, 3, 4, 4 |
| Level-up event fired when level increases | Fired once, carrying the highest level reached |
| Stage-change flag | True only when the stage changes |

### 2.2 Distance conversion

| Case | Expected |
|---|---|
| 0 steps | 0 m |
| 1,000 steps | 700 m (metric: 0.70 km) |
| 6,000 steps | 4,200 m; imperial 2.61 mi |
| 10,000 steps | 7,000 m; imperial 4.35 mi |
| Imperial rounding | One decimal place in UI, no loss in storage (stored meters) |
| Floating-point accumulation | 10,000 batches of 1 step equals one batch of 10,000 within 0.001 m |
| kcal estimate | steps x 0.04; 6,000 steps = 240 kcal |

### 2.3 Streak logic

| Case | Expected |
|---|---|
| First goal day ever | streak 1; longest 1 |
| Goal met on consecutive days | streak increments by 1 per day |
| Goal met twice in the same day (steps keep growing) | Increments once only (`goalAwarded` guard) |
| Steps exactly equal to goal | Counts as met |
| Steps one below goal | Not met |
| Day skipped (lastGoalMetOn two days ago) | streakCurrent reset to 0 on rollover/open; longest unchanged |
| After break, next goal day | streak 1 |
| Goal met today, app reopened tomorrow before steps | Displayed streak still shows yesterday's count; not reset until a full day is missed |
| Goal lowered mid-day so today's steps now meet it | Reward and increment trigger once |
| Goal raised after being met | Reward not revoked |
| Midnight rollover during a walk | Steps after midnight go to the new date's log |
| Month and year boundaries; DST change days | Date-only keys; "yesterday" computed by calendar date, not 24 hours |
| Freeze behavior | Not in MVP; test file includes a pending placeholder marked V1 |

### 2.4 Journey advancement

Using `coastal_path.json` (milestones at 4,200 / 8,400 / 12,600 / 16,800 / 21,098 / 25,300 / 29,500 / 33,700 / 37,900 / 42,195 m).

| Case | Expected |
|---|---|
| 0 steps | progress 0; unlockedMile -1 |
| 5,999 steps (4,199.3 m) | No unlock |
| 6,000 steps (4,200 m, exact) | Milestone 0 unlocked; +5 coins |
| One batch of 13,000 steps (9,100 m) | Milestones 0 and 1 unlocked in order; +15 coins total |
| Re-processing same progress | No duplicate unlocks or coins (idempotent via `unlockedMile`) |
| Large single batch (overshoot, e.g. 70,000 steps) | All 10 unlocked; coins total 355; progress clamped to 42,195 m; `completedAt` set |
| Steps after completion | No change; no errors |
| Trail JSON validation | Parses; milestones ascending; indexes 0-9; last `distanceM` equals `totalDistanceM`; coins match 5,10,15,20,25,30,40,50,60,100 |
| Missing or malformed trail asset | Fails loudly in tests (and app shows a safe error state, not a crash) |

### 2.5 Coin awards

| Case | Expected |
|---|---|
| Goal met | +10 once per day |
| Goal met three days in a row | +30 |
| Milestone unlock | + `rewardCoins` from JSON |
| Goal plus milestone in same batch | Both awarded; total is the sum |
| Coins never negative | Invariant; no spend paths exist in MVP |

### 2.6 Step ingestor

| Case | Expected |
|---|---|
| First run | Baseline set; delta 0 |
| Normal increase (1,000 to 1,050) | delta 50 |
| Counter reset (current less than last) | delta equals current value |
| Same value twice | delta 0; no writes |
| Batching: 24 steps then 29 s | No flush; at 25 steps or 30 s, flush |
| Flush on app pause | Pending buffer written |

## 3. Widget Test Plan

Use provider overrides with fake data; set a fixed test surface size and a text scale of 1.0, plus one run at 2.0.

### 3.1 Home screen states

| State | Assertions |
|---|---|
| **0 steps** | Ring empty; "0 / 6,000"; copy "Your day starts here. Take a few steps!"; streak badge hidden when streak is 0; companion visible |
| **Mid-progress (4,320 / 6,000)** | Ring at 72%; steps text "4,320"; distance pill "3.0 km"; XP bar matches fake companion; next milestone line visible |
| **Goal met (6,000+)** | Ring full; goal-met copy shown; no red anywhere; celebration triggered once (not on every rebuild) |
| **Permission denied** | Explainer card and "Open Settings" button; app otherwise navigable |
| **Imperial units** | Distance shows miles |

### 3.2 Progress ring

- Animates from 0 to the target fraction (pump frames; verify the value at start, mid and end).
- Fraction clamps to 1.0 above goal.
- With reduce-motion enabled, the ring jumps to its value without animation.
- Semantics label reads "4,320 of 6,000 steps, 72 percent".

### 3.3 Companion XP bar

- At level 1, xp 0: empty bar, "0/100 XP".
- At level 7, xp 680: bar at 680/1,852 and label "680/1,852 XP".
- At the exact threshold boundary: shows the next level, xp 0.
- Level change triggers the level label update.
- Tap on companion plays the reaction and does not change state.

### 3.4 Other smoke tests

- Onboarding: can complete all steps; goal presets set the expected values; routes to Home.
- Stats: chart renders with 7 bars; met bars use primary color, missed bars use gray; no red.
- Settings: changing the goal persists (fake repository receives the write).
- Journey: locked vs unlocked nodes render; detail sheet shows lore.

## 4. Integration Test Plan

Tools: `integration_test` with in-memory (or temp-directory) Isar and a `FakeStepSource` that emits scripted values.

| Scenario | Steps | Pass condition |
|---|---|---|
| **Step stream to DB to UI** | Fresh user; emit 0, then 500, then 1,200 cumulative | Today's StepLog is 1,200 steps (after baseline); Home ring and XP reflect it without manual refresh |
| **Goal and streak flow** | Emit enough steps to cross the goal | +10 coins, streak 1, goal celebration once |
| **Level-up while "closed"** | Write steps via ingestor with UI not mounted; then launch UI | Level-up modal shows on first Home resume; shows once |
| **Milestone unlock** | Emit steps to cross 4,200 m | Journey node unlocked; coins awarded; modal queued once |
| **App restart preserves state** | Record steps; dispose providers; recreate container and reopen DB | All values match; no re-celebration; checkpoint intact |
| **Device reboot simulation** | Cumulative 8,000, then emit 120 (counter reset) | Delta credited as 120; no negative or double count; day total is correct |
| **Midnight rollover** | Fake clock advances across midnight mid-stream | Steps split between two date rows; streak logic evaluates the new day |
| **Permission flow** | Fake source returns denied | Home shows explainer; no crashes; granting later starts tracking |

## 5. Manual Test Plan

### 5.1 Device matrix

| Device | Why | Must pass |
|---|---|---|
| **Pixel (current Android)** | Baseline; AOSP behavior | All tests |
| **Samsung (One UI)** | Battery optimization quirks, "sleeping apps" | Background kill, battery, accuracy |
| **Xiaomi (MIUI/HyperOS)** | Aggressive background killing | Background kill, restart after reboot, onboarding help text for battery settings |
| **At least one Android 9 device (API 28)** | Backward compatibility (minSdk 28) | Install, permissions, service, notifications |

<!-- ASSUMPTION: A device on Android 14+ is part of the Pixel baseline so FOREGROUND_SERVICE_HEALTH behavior is exercised. -->

### 5.2 Step accuracy test

1. Install the app and a reference pedometer (or read the system step counter via a trusted app).
2. Carry the phone normally (pocket, bag, hand) and walk 1,000 known steps (count manually or via a counted route).
3. Record the app value and the system value.
4. **Pass:** app within ±2% of the system pedometer (980-1,020 for 1,000). Repeat for pocket, hand and bag carry positions, and with screen off.
5. Record results per device in a table: device, carry position, app, system, deviation %.

### 5.3 Battery test

1. Charge to at least 90%; note the percentage; use Battery usage stats if available.
2. Take a 1-hour walk with the screen off and the app in the background.
3. Compare to a baseline hour without the app (same device, same conditions) if possible.
4. **Pass:** StrideQuest attributable drain under 3% per hour.

### 5.4 Background kill test

1. Start tracking; walk 100 steps; confirm the count.
2. Swipe the app away from recents; walk 200 steps with the screen off.
3. Reopen: count increased by about 200.
4. Repeat after: force-stop from settings (document the expected behavior: tracking resumes on next launch with the checkpoint intact), battery-saver mode, and a reboot (verify the service restarts and no steps are lost or double counted).
5. **Pass:** tracking continues after swipe-away on all devices; after reboot it resumes, and any gaps are documented, not silent.

### 5.5 Permission denial test

1. Fresh install; deny `ACTIVITY_RECOGNITION` in the prompt.
2. Expect: friendly explainer, "Open Settings" button, no crash, other tabs work.
3. Grant in system settings; return to the app: tracking starts without a restart.
4. Deny "Don't ask again" path; deny notification permission; revoke the permission while the service is running. App and service must degrade gracefully.

### 5.6 Other manual checks

- Accessibility: TalkBack walkthrough of all screens; text scale 200%; reduce-motion on; dark mode contrast spot-check.
- Celebrations: level-up, evolution, milestone and goal-met all fire once, with haptics.
- Offline: airplane mode full run; confirm no network requests (proxy or `adb` network stats).
- Long run: leave tracking for 3 days; verify no drift, memory growth or notification loss.

## 6. Regression Checklist (before each APK release)

- [ ] `flutter analyze` clean; `flutter test` and integration tests pass
- [ ] Fresh install: onboarding, permission grant, first steps counted
- [ ] Upgrade install over previous build: data preserved (Isar migration safe)
- [ ] Steps counted with app in background and after swipe-away
- [ ] Reboot resumes tracking; no double count
- [ ] Level-up, milestone and goal celebrations fire exactly once
- [ ] Streak behaves correctly across a simulated day boundary
- [ ] Stats, Journey and Settings load; settings persist
- [ ] Permission-denied path works
- [ ] Reduce-motion and 200% text scale OK
- [ ] No red used for failure states (visual scan)
- [ ] Release manifest has no `INTERNET` permission; no analytics SDKs present
- [ ] APK installs on the Android 9 device
- [ ] Version number and build number bumped; release notes written

## 7. Crash Monitoring Plan

- **MVP:** manual. Testers send logs on request (`adb logcat`, or a hidden "copy diagnostics" action that copies recent local logs to the clipboard, with no network). Review logs weekly; keep a crash and bug tracker.
- Wrap the service entry point and `runApp` in error zones that write to a local rolling log file (size-capped). <!-- ASSUMPTION: A small local rolling log is acceptable for MVP; it never leaves the device unless the user shares it. -->
- **V1:** Sentry for crash reporting. Evaluate its effect on the "Data not collected" label first; configure to avoid PII and consider making it opt-in.

## 8. Definition of "Release-Ready" (MVP)

All of the following must be true:

1. Every item in build-prompt.md §14 (Definition of Done) is checked.
2. All unit, widget and integration tests pass in CI or locally.
3. Manual device matrix complete (Pixel, Samsung, Xiaomi, Android 9) with no open P0/P1 bugs.
4. Step accuracy within ±2%; battery under 3% per hour; background kill test passed on every device.
5. Crash-free across a 3-day soak on at least two devices (target above 99% of sessions).
6. Regression checklist (§6) fully ticked.
7. Release manifest verified: no `INTERNET`, no analytics; privacy page reads "Your data never leaves your phone."
8. A signed release APK installs cleanly over the previous build and from scratch.