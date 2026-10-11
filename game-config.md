# StrideQuest — Game Configuration

Every tunable constant, with the reasoning behind it. All values live in `lib/core/config/game_config.dart` (full file in §9). Change numbers there, never in feature code.

**Related docs:** architecture.md §6, build-prompt.md §4, roadmap.md

---

## 1. XP System

| Constant | Value | Rationale |
|---|---|---|
| `xpPerStep` | 1 | Simplest possible mental model: one step, one XP. Users can estimate progress in their head. |
| `xpCurveBase` | 100 | Scales the whole curve. |
| `xpCurveExponent` | 1.5 | Each level costs noticeably more than the last, but sub-quadratically, so late levels feel like a stretch, not a wall. |
| `levelCap` | 50 | See below. |

**Formula:** `xpToCompleteLevel(N) = round(100 * N^1.5)`

*Call made: interpretation.* This is the cost to advance from level N to N+1, with `Companion.xp` holding progress within the current level.

| Level | Cost to complete | Cumulative XP to reach next level | Days at 6,000 steps/day |
|---|---|---|---|
| 1 | 100 | 100 | 0.02 |
| 2 | 283 | 383 | 0.06 |
| 5 | 1,118 | 1,703 | 0.28 |
| 10 | 3,162 | 14,500 (approx.) | 2.4 |
| 20 | 8,944 | 66,000 (approx.) | 11 |
| 50 (cap) | n/a | about 690,000 | about 115 |

<!-- ASSUMPTION: Level cap of 50 was not specified. Cumulative XP for 49 completed levels is about 690,000, roughly 115 days at the default goal: long enough to give committed users a four-month arc, short enough to be reachable. At cap, XP stops converting to levels; the companion keeps its final-stage look. -->

Early levels arrive fast on purpose: the first level-up should happen within the first session or two, because early rewards drive D1 retention.

## 2. Evolution Stages

`stage = min(4, level ~/ 5)`

| Stage | Levels | Visual change (target art direction) |
|---|---|---|
| 0 | 1-4 | Baby form, small, simple shape |
| 1 | 5-9 | Slightly larger, first accessory (e.g. scarf, leaf crown, gill frills) |
| 2 | 10-14 | Distinct silhouette change, richer color |
| 3 | 15-19 | Confident adult form, extra detail and glow |
| 4 | 20+ | Final form, signature aura or sparkle |

MVP placeholder: stage is expressed as emoji scale (1.0 to 1.4) plus an accessory badge; see build-prompt.md §8.

**Pacing warning:** with the locked formula, stage 4 (level 20) arrives at about day 11 at the default goal, meaning the final evolution occurs long before the 115-day level cap. See §8 for tuning options.

## 3. Distance Math

| Constant | Value |
|---|---|
| `strideKm` | 0.0007 |
| `strideM` | 0.7 |
| `kmToMiles` | 0.621371 |

Why 0.0007 km (0.7 m)? It is a conservative average stride that works across most adults without asking for height, and avoids overstating distance. A typical adult walking stride is a little over 0.7 m, so the app slightly under-reports rather than flatters. Personalizing by height is a V1 candidate; it needs an extra setting, so it is out of MVP scope.

Distance is stored in meters and converted for display. Imperial shows miles (km x 0.621371).

Conversion examples: 6,000 steps = 4.2 km = 2.61 mi. 10,000 steps = 7.0 km = 4.35 mi.

## 4. Calorie Estimate

`kcal = steps x kcalPerStep`, with `kcalPerStep = 0.04`.

<!-- ASSUMPTION: 0.04 kcal/step is a common rough figure for adult walking; no user weight or height is collected, so no personalization is possible. The spec requested a formula but did not specify a factor. -->

Rules: this is **a rough, display-only estimate** shown in a small pill and the ring's detail view. The UI must carry the disclaimer "Estimate only" in the detail view. It is never a goal, never compared to food, and never framed around weight loss. If it ever feels risky for a user group, remove the pill; nothing else depends on it.

## 5. Streak Rules

| Rule | Value |
|---|---|
| Increment | When today's steps >= `dailyGoal`, once per day |
| Continue | If `lastGoalMetOn` was yesterday, `streakCurrent + 1`; otherwise it restarts at 1 |
| Break | A full calendar day with steps < goal and no freeze used |
| Display | Show streak if `lastGoalMetOn` is today or yesterday; otherwise show 0 with "New streak starts today" |
| Longest | `streakLongest = max(streakLongest, streakCurrent)` |

**Freeze mechanics (V1, not built in MVP):**
- A freeze absorbs one missed day without breaking the streak.
- Earnable by steps (recommended): e.g. every 7 consecutive goal days grants a freeze, capped at 2 held.
- Applied automatically at day rollover; the user sees "A freeze kept your streak safe."
<!-- ASSUMPTION: "7 days per freeze, max 2 held" are placeholder V1 values for planning, not part of the MVP config. -->

Goal changes mid-day: raising the goal after it was met does not revoke the reward (`goalAwarded` is sticky); lowering it can trigger the reward immediately.

## 6. Coin Economy

| Source | Amount |
|---|---|
| Daily goal met | 10 coins (once per day) |
| Milestone unlock | 5, 10, 15, 20, 25, 30, 40, 50, 60, 100 (Coastal Path) |
| Total for Coastal Path | 355 coins |

MVP: coins accumulate and display on Settings/Journey; there is nothing to spend them on yet. That is acceptable: it trains the habit of earning.

**Planned V1 sinks:** cosmetic companion skins, trail themes, streak-freeze top-ups (earnable path preferred), and name-tag and accessory slots. Principle: coins never buy progression speed; they buy self-expression.
<!-- ASSUMPTION: Price ranges are a V1 task; a first guess is that a basic skin costs about one week of daily goals (70 coins) and a premium skin about two to four weeks. -->

## 7. Daily Goal Presets

| Preset | Steps | Intent |
|---|---|---|
| Casual | 4,000 | Gentle start; reachable on a low-activity day |
| Active | 8,000 | Common general-health target |
| Ambitious | 12,000 | Dedicated walkers |
| Default | 6,000 | Between casual and active; aims for a roughly 40%+ completion rate |

Slider range: 1,000 to 30,000, step 500.

Presets use neutral labels. Avoid labels like "Lazy" or "Beast".

## 8. Difficulty Tuning Notes

Retention is the metric. If numbers are low, adjust in this order.

| Symptom | Likely cause | Lever |
|---|---|---|
| D1 low | First reward comes too late | First level and first milestone should land in the first one or two days. Defaults already do this (level 1 at 100 steps; milestone 0 at 4.2 km, about 1 day at default goal). Consider a smaller first level cost. |
| D7 low | Little to look forward to after the first week | Companion evolves by day 3 and trail milestones come about daily early, but the trail ends around day 10. Add a second trail early in V1. |
| Goal completion under 40% | Default goal too high | Lower `defaultDailyGoal` (try 5,000) or promote the Casual preset in onboarding. |
| Goal completion over 70% | Too easy; no sense of achievement | Raise default to 7,000 or add stretch quests (V1). |
| Streaks break constantly | Streaks feel brittle | Ship streak freezes sooner (V1). |
| Companion maxes too early | Curve too gentle for stage structure | Raise `levelsPerStage` (e.g. 10) or `xpCurveBase`. |

**Known pacing issue (flagged):** At 0.7 m per step, the 42,195 m Coastal Path is 60,278 steps, about 10 days at the default goal. The PRD calls it a long-term aspirational goal, but the maths makes it a 10-day trail. Options:
1. Keep it, and ship 3+ trails early in V1 (recommended; fast early completion is a good first-week reward).
2. Raise `totalDistanceM` in the trail JSON (e.g. x5).
3. Introduce a per-trail distance multiplier (new config constant; not in MVP).

Do not change `strideKm` to fix pacing: it also drives the displayed real-world distance, which should stay honest.

## 9. `game_config.dart`

```dart
// lib/core/config/game_config.dart
//
// ALL gameplay tunables live here. Do not hardcode these numbers elsewhere.
// Rationale for every value: see docs/game-config.md.

import 'dart:math';

class GameConfig {
  const GameConfig._();

  // ---- XP ----
  static const int xpPerStep = 1;
  static const double xpCurveBase = 100;
  static const double xpCurveExponent = 1.5;
  static const int levelCap = 50; // assumption

  /// XP needed to advance from [level] to level + 1.
  static int xpToCompleteLevel(int level) =>
      (xpCurveBase * pow(level, xpCurveExponent)).round();

  // ---- Evolution ----
  static const int levelsPerStage = 5;
  static const int maxStage = 4;

  static int stageForLevel(int level) => min(maxStage, level ~/ levelsPerStage);

  // ---- Distance and display ----
  static const double strideKm = 0.0007; // 0.7 m per step
  static const double strideM = strideKm * 1000;
  static const double kmToMiles = 0.621371;

  // ---- Calorie estimate (rough, display only) ----
  static const double kcalPerStep = 0.04; // assumption

  // ---- Goals ----
  static const int defaultDailyGoal = 6000;
  static const int goalCasual = 4000;
  static const int goalActive = 8000;
  static const int goalAmbitious = 12000;
  static const int goalMin = 1000;
  static const int goalMax = 30000;
  static const int goalStepSize = 500;

  // ---- Coins ----
  static const int coinsPerGoalMet = 10;
  // Milestone coins are defined per milestone in assets/trails/*.json

  // ---- Tracking and batching ----
  static const int batchStepThreshold = 25;       // flush after N steps...
  static const Duration batchFlushInterval =      // ...or after this long
      Duration(seconds: 30);
  static const int stepPulseInterval = 1000;      // ring pulse every N steps

  // ---- Streak (V1, inactive in MVP) ----
  // static const int daysPerStreakFreeze = 7;
  // static const int maxStreakFreezes = 2;
}
```