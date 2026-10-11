# AGENTS.md — StrideQuest

## Current repo state (important)
- This repo is **docs-only right now**: `PRD.md`, `architecture.md`, `build-prompt.md`, `game-config.md`, `testing-plan.md`, `UI-UX-DESIGN.md`, `roadmap.md`, `README.md`, and `trials/coastal_path.json`.
- There is **no Flutter project yet** — no `pubspec.yaml`, no `lib/`, no `android/`. Do not look for entrypoints that don't exist; `build-prompt.md` is the spec to implement from.
- `trials/coastal_path.json` is the seed trail definition. When the Flutter app is scaffolded, this file is moved/copied to `assets/trails/coastal_path.json` — **do not edit its values**.

## When code exists, the source of truth is `build-prompt.md`
- Tech stack is **locked** (§2): Flutter, Riverpod, Isar, pedometer, flutter_background_service, fl_chart, go_router (`StatefulShellRoute`), google_fonts (bundled, no runtime fetch), flutter_animate. Do not swap packages.
- Folder layout must match §3 exactly (`lib/core|data|domain|presentation`, `assets/` at root).
- **No network calls, accounts, ads, analytics, GPS, or `INTERNET` permission ever** — in release manifest too. Fonts must be bundled; disable runtime font fetching.

## Commands (once scaffold exists)
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # Isar codegen; rerun after model changes
flutter analyze && flutter test                            # must both pass before PR
flutter build apk --release                               # output: build/app/outputs/flutter-apk/app-release.apk
```
- Isar models use `part '*.g.dart'`; missing codegen errors mean you forgot `build_runner`.
- Test a real physical device for step tracking — emulators produce no realistic sensor data.

## Hard-won quirks to not miss
- Two isolates (UI + foreground service) share one named Isar instance; the service isolate is the only writer of step state. Verify this with the §6.9 / build-order step-3 spike before building on it.
- `StepIngestor` delta algorithm (build-prompt.md §6.3) handles sensor counter resets after reboot; boot restart via `RECEIVE_BOOT_COMPLETED`.
- Batching: flush at 25 steps or 30 s — never write to Isar per step.
- Every gameplay number lives in `lib/core/config/game_config.dart` only; never hardcode XP curves, stride, coins, goals elsewhere.
- Dates/datetimes for streaks and `StepLog.date` are **date-only, local**.
- Distances stored in meters; convert to miles at display time only.
- Domain layer (`domain/`) must not import Isar or pedometer; UI goes through Riverpod providers, widgets have no business logic.
- Isar 3.x upstream is unmaintained-ish; a community fork may be needed — model definitions are unchanged either way.
- Recovery path: if docs conflict with config, trust executable config/scripts; `build-prompt.md` + `architecture.md` agree where both defined.

## Workflow conventions
- Branches: `feature/<name>`, `fix/<name>`; `main` always buildable. Conventional Commits.
- One concern per PR; unit tests for any domain change; screenshots for UI changes.
- Scope discipline: not in current-phase PRD → open an issue, don't build it.
- App copy is warm, never guilt-based (missed goals say "New streak starts today", never red).
- Accessibility: 48dp touch targets, TalkBack labels, `MediaQuery.disableAnimations` must replace celebrations with fades.
