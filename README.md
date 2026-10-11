# StrideQuest

**Turn your steps into a journey.**

StrideQuest is a gamified step tracker built with Flutter. Walk, and a companion creature levels up and evolves while you travel a story-driven trail from landmark to landmark. There are no ads, no subscriptions, no accounts and no network calls. Your data stays on your phone.

---

## Why it exists

Most step trackers are either boring dashboards that nobody opens by week three, or ad-and-subscription machines that treat the user as inventory. StrideQuest takes a different path:

- **Play, not pressure.** A companion, a map and a streak give you a reason to come back tomorrow. Missed goals get encouragement, never guilt.
- **Honest business model.** Free core, no ads ever. Premium (V1+) is cosmetics only.
- **Private by construction.** Local-first. No account, no cloud, no personal data collected.

## Screenshots

<!-- Replace with real captures once the MVP builds. -->

| Home | Journey | Stats | Level-up |
|---|---|---|---|
| _screenshot pending_ | _screenshot pending_ | _screenshot pending_ | _screenshot pending_ |

Place images in `docs/screenshots/` and link them above.

## Features (MVP)

- Onboarding: pick a companion (Fox, Sprout or Axolotl) and set a daily goal
- Background step tracking via the Android step sensor and a foreground service
- Home screen with animated goal ring, distance and calorie estimate, companion and streak
- Companion XP, levels and evolution stages, with a level-up celebration
- Journey map: the 42 km Coastal Path with 10 landmarks and lore
- Daily goal, streak and coins
- Stats: 7 / 30 / 365-day bar charts with goal line
- Settings: goal, units (metric/imperial), companion name, reminders
- Light and dark themes, TalkBack support, reduced-motion support

## Quick Start

### Requirements

- Flutter (latest stable channel)
- Android SDK with an Android 9+ (API 28) device or emulator
- A **physical device** is recommended: emulators do not produce realistic step-sensor data

<!-- ASSUMPTION: Exact Flutter and Dart version pins are set in pubspec.yaml at project creation; update this section with them then. -->

### Clone and install

```bash
git clone <your-repo-url> stridequest
cd stridequest
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generates Isar code
```

### Run

```bash
flutter run
```

Grant the Activity Recognition permission when prompted, then walk.

### Build the APK

```bash
flutter build apk --release
```

The APK lands at:

```
build/app/outputs/flutter-apk/app-release.apk
```

Copy it to your phone and install it (enable "install unknown apps" for your file manager). For a quicker debug build, use `flutter build apk --debug`.

## Folder Map

```
lib/
├── main.dart, app.dart
├── core/          # config (game_config.dart), theme, router, utils
├── data/          # Isar models, repositories, step sources
├── domain/        # entities and use cases (pure Dart)
└── presentation/  # onboarding, home, journey, stats, settings, widgets
assets/            # trails/*.json, fonts, images
docs/              # PRD, architecture, design, roadmap, testing plan
```

Deeper detail lives in `docs/architecture.md`. Every gameplay number is tunable in `lib/core/config/game_config.dart` (see `docs/game-config.md`).

## Contributing

- **Branching:** `main` is always buildable. Work on `feature/<short-name>` or `fix/<short-name>` branches.
- **Commits:** Conventional Commits (`feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `chore:`). Keep commits small and focused.
- **Pull requests:** One concern per PR; describe the change and how you tested it; include a screenshot for UI changes; unit tests for any domain change; `flutter analyze` and `flutter test` must pass.
- **Scope discipline:** If it is not in the PRD for the current phase, open an issue first. No ads, trackers, network calls or accounts, ever.
- **Tone:** App copy is warm and never guilt-based. See `docs/ui-ux-design.md` section 7.

## Privacy

**Your data never leaves your phone.** StrideQuest has no account system, no servers and no analytics. The release build requests no internet permission. The store privacy label is "Data not collected."

## License

MIT (suggested). Add a `LICENSE` file with the MIT text and your name and year before publishing.
<!-- ASSUMPTION: MIT is a placeholder; confirm the license before the first public release. -->

## Contact and Credits

- Maintainer: _your name / handle here_
- Issues and ideas: open a GitHub issue
- Tonal inspiration: Walkr, Finch and Duolingo (inspiration only, no assets used)
- Built with Flutter, Riverpod, Isar, fl_chart, go_router and flutter_animate