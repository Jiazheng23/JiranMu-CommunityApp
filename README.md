# assignment (JiranMu)

[![Flutter](https://img.shields.io/badge/Framework-Flutter-blue.svg)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Language-Dart-0175C2.svg)](https://dart.dev/)
<!-- Add CI / test badges here when available -->

Mobile app built with Flutter. Targets mobile (Android/iOS), web and desktop (Windows/macOS/Linux). The app uses Supabase for backend/auth and includes features such as chat, visitor pass requests, maps/location, QR scanning, calendar, and local notifications.

> Note: This repository currently contains a Supabase URL and anon key in `lib/main.dart`. Anon keys are intended for client usage but committing any service_role or other secrets is unsafe. See "Configuration & Security" below.

## Table of contents
- What this is
- Features
- Stack / Notable dependencies
- Getting started
- Configuration & Security
- How to run
- Tests
- Project layout
- Contributions (high level)
- Contributing
- License & contact
- Acknowledgements

## What this is
A multi-platform Flutter application (code name: assignment, UI title: "JiranMu") providing resident/admin features: chat (community & individual), visitor pass requests, admin dashboard, polls/events, geolocation & maps, QR scanning, and local notifications. The repo includes native platform runners for Android, iOS, web and desktop.

## Features
- User authentication via Supabase
- Resident and Admin roles with separate dashboards
- Community and individual chat with realtime listeners
- Visitor pass request flow (create/list/auto-expiry)
- Google Maps integration and location services
- QR scanning and QR generation
- Calendar UI (table_calendar) and time formatting
- Local notifications (flutter_local_notifications)
- Shared preferences for simple persistent storage

## Stack / Notable dependencies
- Language: Dart (Flutter)
- Framework: Flutter (stable)
- Notable packages (see `pubspec.yaml` for full versions):
  - supabase_flutter — backend & auth
  - google_maps_flutter — map display
  - geolocator — location access
  - table_calendar — calendar UI
  - qr_flutter, mobile_scanner — QR features
  - flutter_local_notifications — local notifications
  - shared_preferences — lightweight persistence
  - intl, timeago — date/time formatting

## Getting started — prerequisites
- Flutter SDK (project requires Dart SDK >= 3.10.7 as declared in pubspec.yaml)
  - Install from: https://flutter.dev/docs/get-started/install
- Platform toolchains:
  - Android: Android SDK, Android Studio or command-line tools
  - iOS: Xcode (for macOS)
  - Web: Chrome (or other supported browser)
  - Desktop: platform-specific build requirements (see Flutter docs)
- A Supabase project (optional for running features that require backend)
- A Google Maps API key (optional for maps features)

## Setup (local)
1. Clone the repo:
   git clone https://github.com/Jiazheng23/mobile_assignment.git
   cd mobile_assignment

2. Install dependencies:
   flutter pub get

3. Configure secrets (recommended)
   - Do NOT leave service_role or other confidential keys in source control.
   - The project currently contains a Supabase base URL and anon key in `lib/main.dart` for convenience. Replace with your project's values or provide via an env/config file.
   - Example local `.env` (not included in repo):
     SUPABASE_URL=https://your-project.supabase.co
     SUPABASE_ANON_KEY=your-anon-key
     GOOGLE_MAPS_API_KEY=YOUR_GOOGLE_MAPS_KEY

   - If you use a `.env` approach, add `.env` to `.gitignore` and adapt the app to read env values (or provide a `lib/config.dart` that is gitignored).

4. Android Google Maps key:
   - Replace the `com.google.android.geo.API_KEY` meta-data value in:
     `android/app/src/main/AndroidManifest.xml`
   - Or configure via environment variables/gradle properties if you prefer.

## How to run
- Run on default connected device or emulator:
  flutter run

- Run on a specific device:
  flutter run -d android
  flutter run -d chrome   # web

- Build artifacts:
  flutter build apk
  flutter build ios
  flutter build web
  flutter build windows
  flutter build macos
  flutter build linux

## Tests
- Run Flutter tests:
  flutter test

- Run static analysis:
  dart analyze

## Configuration & Security notes
- Hardcoded keys:
  - `lib/main.dart` currently contains:
    - a Supabase URL and anon key.
  - Anon keys are ok for client use but should still be rotated if accidentally published and should never be used server-side.
  - For production, store keys in environment variables, CI secrets, platform-specific secure storage, or a backend proxy.

- Google Maps:
  - `android/app/src/main/AndroidManifest.xml` contains a placeholder Google Maps API key. Replace with an API key configured for the Android app SHA/package.

- Permissions:
  - Android manifest requests location, camera, notification, and foreground service permissions. Ensure you handle runtime permission prompts in the app.

## Project layout (top-level)
```
lib/                    # Flutter app source (entry: lib/main.dart)
  admin/                # admin screens and widgets
  chat/                 # chat screens & helpers
  resident/             # resident screens
  shared/               # shared widgets/utilities
android/                # Android runner, manifests, resources
ios/                    # iOS runner and project files
web/                    # Web index and manifest
linux/, macos/, windows/# Desktop runner code and configs
assets/                 # static assets (images, icons)
test/                   # widget/unit tests
pubspec.yaml            # dependencies and assets configuration
README.md               # this file
```

## Contributions by melissa0619
The following summarizes the concrete work authored by user melissa0619 (extracted from commit history and messages):

- Chat / Messaging
  - Implemented community chat list, individual chat flows, and chat UI/UX.
  - Separated admin vs resident chat screens.
  - Fixed a crash for chat list loads (limited DB queries, deduplication).
  - Added user-friendly message previews (JSON parsing for polls/events).
  - Improved FAB/menu behaviour in admin chat UI (auto-collapse and removal where appropriate).

- Visitor Pass & Requests
  - Enhanced VisitorPassRequestScreen: stricter validation rules (name length, IC/passport patterns), realtime error feedback, input formatters, and summary of missing required fields.
  - Implemented auto-expiry logic in VisitorPassListScreen: mark approved passes as used when validity ends.
  - Streamlined data loading and cleaned up code/comments.

- Admin dashboard & UI
  - Updated admin bottom navigation styling and overall UI spacing.
  - Removed unused UI cards (e.g., facility access card) and cleaned imports.

- Polls & Notifications
  - Ensured poll results refresh before display and improved notification-related code paths.
  - Added/removed NotificationService references as part of iteration.

- Maintenance & merges
  - Merged several feature branches (facility, SOS, event, etc.), resolved conflicts across a number of files.
  - Downgraded some locked dependencies for compatibility in pubspec.lock.
  - Miscellaneous fixes: added uuid for default user id, removed unused imports, and small refactors.

If you would like, I can produce a file-by-file diff/summary of melissa0619's changes or add an explicit "Contributors" section to this README listing these items more compactly.

## Contributing
We welcome contributions — small fixes to docs up to feature branches.

Short guidelines:
- Create an issue for anything larger than a typo.
- Branch from `main`:
  - feature/<short-desc>, fix/<short-desc>
- Run `dart analyze` and `flutter test` before submitting PRs.
- Avoid committing secrets. Document required environment variables in PRs.

For a detailed guide, add a CONTRIBUTING.md (recommended). If you want, I can create that file plus GitHub issue/PR templates.

## License & contact
- License: (Not specified) — tell me which license you want (e.g., MIT, Apache-2.0) and I will add a LICENSE file.
- Maintainer / primary contact: melissa0619 (https://github.com/melissa0619)

## Acknowledgements
- Built with Flutter — https://flutter.dev/
- Uses Supabase — https://supabase.com/
- Icons & libraries as listed in `pubspec.yaml`.

---

If you'd like this README committed to the repository, I can:
1. Create a branch (e.g., `update/readme-full`) and commit this README.
2. Open a PR for you to review.
3. Optionally add CONTRIBUTING.md, PULL_REQUEST_TEMPLATE, and ISSUE_TEMPLATE in the same PR.

Tell me:
- Approve this README content as-is, or list edits you'd like.
- Which license to include (if any).
- Whether to add CONTRIBUTING and templates in the same change.
