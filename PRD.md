# StrideQuest — Product Requirements Document

**Version:** 0.1 (MVP definition)
**Status:** Ready for build
**Related docs:** architecture.md, ui-ux-design.md, game-config.md, roadmap.md, testing-plan.md, build-prompt.md

---

## 1. One-liner

StrideQuest is a local-first, ad-free step tracker where every step feeds a companion creature and moves you along a story-driven trail, so walking becomes a daily habit you want to keep.

Tagline: **Turn your steps into a journey.**

## 2. Problem Statement

Step trackers fail users in two distinct ways.

**Trap 1: Boring utilities.** Google Fit, Pacer and Stepz show numbers and charts. Numbers do not create a reason to return tomorrow. Retention collapses around week 3 because nothing emotional or narrative pulls the user back.

**Trap 2: Predatory monetization.** Stepz moved to roughly $3/week subscriptions with aggressive ads. Long-time users describe it as an "annoying ad machine" and feel betrayed. The category now carries a trust deficit.

The people who *want* to walk more still fall off. Stories, pets, streaks and collection progress motivate; dashboards do not. No mainstream tracker combines a low-friction tracker with a warm game layer and an honest business model.

## 3. Vision

A walking app that feels like opening a small, friendly game, not a gym membership. It respects the user's privacy (no account, no cloud), their wallet (free core, forever) and their feelings (no guilt, no weight-loss framing). In the long run, StrideQuest is where friends and teams walk together toward shared destinations, without ever turning the user into the product.

## 4. Target Users

| Segment | Who | What they need | Design implication |
|---|---|---|---|
| **Primary** | Casual walkers, 18-40, who want to move more but find fitness apps boring | A reason to open the app daily; zero setup friction; no pressure | Gamification over dashboards; goal default of 6,000 steps; encouragement-only copy |
| **Secondary** | Pet and collection game fans | A low-effort daily habit with collection and progression | Companion levels and evolutions; trail landmarks; V1 cosmetics |
| **Tertiary (V2)** | Friend groups, workplace wellness teams | Light social competition without leaderboards that shame | Co-op trails, leagues, opt-in sync |

## 5. Core Loop

```
   Walk  →  Steps count  →  Companion gains XP + Journey progresses
     ↑                                    ↓
   Come back tomorrow  ←  Streak grows, rewards unlock, map reveals
```

Three intertwined systems:

1. **Companion ("Trailbuddy")**: a creature that levels and evolves as you walk. Emotional attachment drives retention.
2. **Journey Map**: steps convert to distance along a themed trail. Landmarks give a discovery reward.
3. **Streaks and Goals**: daily goal ring, consecutive-day streaks, and (V1) streak freezes. This is the habit engine.

Target session: 30-90 seconds. The app is checked, not "used".

## 6. Feature Scope

### 6.1 MVP (APK test, local only)

| Feature | Description | Priority |
|---|---|---|
| Onboarding | Pick companion, set daily goal, grant permission | P0 |
| Background step tracking | Counts steps even when app is closed | P0 |
| Home screen | Goal ring, steps, distance, companion, streak | P0 |
| Companion XP and levels | Steps = XP; visible level-up celebration | P0 |
| Journey map | 1 trail (Coastal Path), 10 milestones | P0 |
| Local persistence | State survives restarts and reboots | P0 |
| Stats screen | Daily/weekly bar chart (7/30/365 toggle) | P1 |
| Settings | Goal, units, companion rename, notifications, privacy page | P1 |
| No backend, no login, no ads | Hard constraint | P0 |

### 6.2 V1 (post-validation)

| Feature | Description |
|---|---|
| Health Connect / HealthKit sync | System-of-truth step source, survives reinstall |
| 3+ trails, more companions | Content expansion for retention beyond week 2 |
| Coin economy and cosmetic shop | Spend coins on skins; the only monetization surface |
| Streak freezes, daily quests | Habit forgiveness and variety |
| Home widget and notification nudges | Reduce friction to check in |
| iOS release | Same codebase |

### 6.3 V2 (social and scale)

| Feature | Description |
|---|---|
| Friend leaderboards | Opt-in, friend-graph only |
| Weekly leagues (bronze to diamond) | Light competition |
| Co-op trails | Team walks toward a shared goal |
| Optional account sync | Cross-device, never required |
| Real-world reward partnerships | Plant trees, brand discounts (reviewed for fit with the no-ads promise) |

## 7. Explicit Non-Goals (MVP)

- Ads of any kind
- Subscriptions
- Login or accounts
- Network calls
- Social features
- Health Connect (V1)
- GPS
- Calorie or weight tracking (a rough on-screen estimate is display-only; no weight input, no targets)
- iOS-specific code (stay cross-platform friendly)

## 8. User Stories

### Onboarding
- As a new user, I want to pick a companion in my first minute so that the app feels personal immediately.
- As a new user, I want to set a daily goal with sensible presets so that I do not have to know how many steps I "should" take.
- As a new user, I want a plain-language explanation before the permission prompt so that I trust the app with motion data.
- As a new user, I want onboarding to finish in under 60 seconds so that I reach the home screen while motivated.

### Daily use
- As a user, I want to see my progress ring and companion in under 2 seconds of opening the app so that I get an instant good feeling.
- As a user, I want my steps counted while the app is closed so that I never think about tracking.
- As a user, I want my companion to react when I tap it so that it feels alive.
- As a user, I want a celebration when my companion levels up so that effort feels rewarded.
- As a user, I want to see how far to the next landmark so that I have a reason to take a few more steps.
- As a user, I want to browse the trail and read landmark lore so that walking feels like exploring.

### Habit
- As a user, I want a streak that grows when I hit my goal so that I have a reason to return tomorrow.
- As a user, I want a missed day to be met with encouragement ("New streak starts today") so that I come back instead of quitting.
- As a user, I want to see my last 7 days at a glance so that I notice my own consistency.
- As a user, I want a gentle reminder at a time I choose so that I remember without being nagged.

### Control
- As a user, I want to change my goal, units and companion name at any time so that the app adapts to me.
- As a user, I want a clear statement that my data never leaves my phone so that I can trust the app.
- As a user who denied the activity permission, I want a friendly explanation and a one-tap path to settings so that I can fix it without guilt.
- As a user, I want text scaling and reduced-motion respected so that the app is usable for me.

## 9. Success Metrics (MVP)

Retention is the only metric that matters for MVP. Everything else is noise.

| Metric | Target |
|---|---|
| D1 retention | > 45% |
| D7 retention | > 25% |
| D30 retention | > 12% |
| Daily goal completion | > 40% of active users |
| Session length | 30-90s |
| Crash-free sessions | > 99% |
| Step accuracy vs system pedometer | ±2% |
| Battery drain | < 3% per hour of active tracking |

<!-- ASSUMPTION: With no network calls, retention cannot be measured by telemetry in MVP. Measure D1/D7/D30 through a small tester cohort and manual check-ins (see roadmap.md, Decision Gates). Do not add analytics SDKs to MVP; it would break the "Data not collected" privacy label. -->

## 10. Monetization Philosophy

**Free forever core. No ads, ever. Premium is cosmetics only (V1+).**

This is a differentiator, not a limitation:

1. The category's incumbents burned trust with ads and weekly subscriptions. "No ads, ever" is a message the competition structurally cannot copy.
2. Cosmetic-only premium means the core habit loop is never paywalled, so retention is never throttled by monetization.
3. Local-first plus no ads means no tracking SDKs, so the store privacy label reads "Data not collected". That is a marketing asset.
4. Users who trust the app become advocates. For a no-ad-budget product, word of mouth is the growth channel.

Rules that follow: no feature required for the core loop may ever be gated; no interstitials or banners in any build; coins are earned by walking, and V1 cosmetics never affect progression speed.

<!-- ASSUMPTION: Cosmetic purchases in V1 would be a one-time purchase or coin spend, not a subscription. Exact pricing deferred to V1 planning. -->

## 11. Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Android background step counting is unreliable across OEMs | Test Samsung, Xiaomi, Pixel early; Health Connect as source of truth in V1 |
| Gamification feels gimmicky | Playtest the companion loop with 5 real users before V1 |
| Battery drain complaints | Sensor batching; no GPS; document battery usage |
| Users do not trust another tracker | Local-first, no account, clear privacy copy |
| Trail pace is too fast: at default stride, the 42,195 m trail takes roughly 10 days at 6,000 steps/day | Tuning lever documented in game-config.md; add longer trails early in V1 |
| Local-only data is lost on reinstall (MVP) | Accept for MVP; Health Connect in V1 restores history; consider export-to-file as a V1 option |

## 12. Open Questions

1. **Companion art style:** pixel, flat vector, or 3D-lite? This heavily affects cost. MVP uses placeholder emoji/SVG.
2. **First trail theme:** Coastal is the working recommendation and is what this doc set assumes.
3. **Streak freeze:** earnable by steps or purchasable? Recommendation: earnable.
4. **Trail pacing:** keep 1:1 step-to-distance and lengthen trails, or scale distance per step? (see game-config.md §8)
5. **Reinstall data loss:** is an MVP export/import worth the effort, or is Health Connect in V1 sufficient?