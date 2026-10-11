# StrideQuest — Roadmap

**Related docs:** PRD.md §6, architecture.md, testing-plan.md

*Estimates are rough dev-days for one developer working with an AI coding agent, including testing. Treat them as ranges, not commitments.*
<!-- ASSUMPTION: Effort figures are not in the source spec; they assume one full-time developer using an agent for scaffolding, with art as placeholders. -->

---

## 1. Phase Overview

| Phase | Goal | Audience | Est. effort | Key risk |
|---|---|---|---|---|
| **MVP** | Prove the habit loop: do people come back for a companion and a trail? | 5-20 testers via APK | 22-30 dev-days | Android background tracking reliability |
| **V1** | Make it durable and shippable: reliable data, more content, first cosmetics, iOS | Public (Play Store, then App Store) | 35-50 dev-days | Content volume; Health Connect edge cases |
| **V2** | Add social and scale without breaking the privacy promise | Growing public base | 40-60 dev-days | Backend cost and trust; scope creep |

## 2. MVP

### Features and estimates

| Feature | Est. (dev-days) | Depends on |
|---|---|---|
| Scaffold, theme, router, config | 2 | n/a |
| Isar models and repositories | 2-3 | Scaffold |
| Foreground-service spike (pedometer plus cross-isolate Isar) | 2-3 | Models |
| Domain use cases plus unit tests | 3-4 | Models |
| Step ingestor (delta, reboot, batching) | 2-3 | Spike, use cases |
| Onboarding plus permissions | 2-3 | Router |
| Home screen plus companion card (placeholder art) | 3-4 | Use cases |
| Celebrations (level-up, milestone) | 2-3 | Home |
| Journey screen (one trail) | 2-3 | Trail JSON, use cases |
| Stats screen | 1-2 | Step logs |
| Settings and notifications | 2-3 | Models |
| Device testing, battery, polish, release APK | 3-4 | Everything |
| **Total** | **~26-37 (planning range 22-30 with parallel work)** | |

### Critical path

Scaffold, models, **service spike**, ingestor, Home, celebrations, device testing. The spike is the single biggest unknown; do it before any UI polish. If the cross-isolate Isar approach fails, the fallback is a service-owned write path plus a lightweight polling refresh in the UI.

### Exit criteria

- Definition of Done in build-prompt.md §14 passes in full.
- Step accuracy within ±2% of the system pedometer on the test devices.
- Battery drain under 3% per hour of active tracking.
- Tracking survives app swipe-away on Pixel, Samsung and Xiaomi test devices.
- 5 real users have used it for 7 days; feedback collected on the companion loop.

## 3. V1

| Feature | Rationale | Depends on (MVP) | Est. (dev-days) |
|---|---|---|---|
| Health Connect integration (`health` package), fallback to pedometer | Reliability, dedupe, survives reinstall; solves the OEM-kill problem | `StepSource` abstraction | 6-8 |
| Historical import and reconciliation | Restore history on reinstall | Health Connect | 3-4 |
| 3+ trails plus trail selection | Trail 1 completes in about 10 days; content is the retention bridge | Trail JSON format, Journey | 4-6 (art and writing extra) |
| More companions plus final art (and Rive decision) | Emotional hook; replace placeholders | Companion model | 6-10 (art cost dominates) |
| Coin shop plus cosmetic skins | The only monetization surface; makes coins meaningful | Coins, `equippedSkin` | 5-7 |
| Streak freezes (earnable) | Reduce brittle-streak churn | Streak logic | 2-3 |
| Daily quests | Variety and reasons to return | Domain layer | 4-5 |
| Home-screen widget plus smarter notification nudges | Lower friction to check in | Notifications | 4-6 |
| Sentry crash monitoring | Visibility at scale (re-check privacy label impact) | n/a | 1-2 |
| iOS release (CoreMotion/HealthKit source, signing, store) | Reach | `StepSource` abstraction | 8-12 |

**Critical path:** Health Connect, then the step-source swap, then trails and companions, then iOS.

**Exit criteria:** crash-free sessions above 99% on public traffic; D7 above 25% and D30 above 12% holding at a few hundred users; store listings approved with the "Data not collected" label intact (or a clearly explained change).

## 4. V2

| Feature | Rationale | Depends on (V1) | Est. (dev-days) |
|---|---|---|---|
| Supabase backend (auth, profile, aggregates) | Prerequisite for any social feature | V1 stable | 8-10 |
| Optional account plus cross-device sync | Convenience; strictly opt-in | Backend | 6-8 |
| Friend graph and leaderboards | Light social pull | Account | 6-8 |
| Weekly leagues (bronze to diamond) | Competition for the motivated subset | Leaderboards | 6-8 |
| Co-op trails | Shared goals without shame | Friend graph, trails | 8-10 |
| Real-world reward partnerships | Meaning beyond the app (e.g. tree planting) | Backend | 4-6 plus partner time |

**Critical path:** Backend, accounts, friend graph, then leagues or co-op.

**Principles that carry into V2:** step logs stay local; only aggregates sync; no account required for the core experience; no ads.

## 5. Someday / Maybe

| Idea | Why it is tempting | Why deferred |
|---|---|---|
| Height-based stride personalization | More accurate distance | Needs extra input; MVP accuracy is acceptable |
| GPS routes and real-world maps | Looks impressive | Battery cost, privacy cost, off-message |
| Wear OS / Apple Watch app | Convenient glance | Large scope; Health Connect already pulls watch data |
| Companion breeding or trading | Collection depth | Needs social infrastructure and economy design |
| Seasonal events and limited skins | Retention spikes | Needs live-ops cadence; V1+ at best |
| Calorie or weight goals | Common request | Conflicts with the no weight-loss framing |
| Ad-supported free tier | Easy revenue | Violates the core promise; never |
| Subscription | Predictable revenue | Violates the positioning; never for core |
| Export/import backup file | Solves MVP reinstall loss without a backend | Health Connect in V1 solves it more completely |
| AI-generated companion dialogue | Charming | Needs network/on-device model; conflicts with local-first for now |

## 6. Decision Gates

| Gate | Move forward when | If not |
|---|---|---|
| **MVP to V1** | D1 above 45%, D7 above 25% among testers (n of at least 20 if possible); tracking works on all three OEM test families; battery under 3% per hour | Fix tracking first. If retention is low but tracking is fine, iterate on the companion loop (game-config.md §8) before adding content |
| **V1 to public launch** | Crash-free above 99%; D30 above 12%; Health Connect stable across Pixel, Samsung, Xiaomi | Extend closed beta |
| **V1 to V2** | Retention targets hold at scale; qualitative demand for social (user requests, not guesses); capacity to run a backend responsibly | Deepen content (trails, companions) instead |

<!-- ASSUMPTION: With no telemetry in MVP, retention is measured by a tester cohort and manual check-ins. If this proves too weak, an opt-in local "export my stats" file that testers email is the privacy-preserving alternative. -->

## 7. Known Unknowns to Research

**Before MVP build:**
- Does Isar behave correctly across the service and UI isolates (shared instance, watchers)?
- Current requirements for `FOREGROUND_SERVICE_HEALTH` on Android 14+ with `flutter_background_service`.
- Isar's maintenance status and the right package to depend on.
- How each OEM (MIUI, One UI) treats `TYPE_STEP_COUNTER` listeners after the app is swiped away.
- Whether `google_fonts` runtime fetching can be fully disabled and the fonts bundled.

**Before V1:**
- Health Connect: availability on Android 9-13 (installable app vs built-in on 14+), permission flows, historical data limits.
- Dedupe rules when multiple apps write steps to Health Connect.
- Play Store policy for health-category and foreground-service apps.
- Art pipeline and cost: pixel vs vector vs 3D-lite; Rive licensing and workflow.
- iOS: CMPedometer history limits (about 7 days) and HealthKit entitlements.

**Before V2:**
- Supabase cost model at target scale; privacy review of aggregate sync.
- Anti-cheat for leaderboards (spoofed sensors, manual health entries).
- Moderation needs for any user-generated names or friend features.
- Legal review of partnership rewards against the "no ads" promise.