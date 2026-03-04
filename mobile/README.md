# FITFLOW Mobile (Flutter)

Step 19 of the FITFLOW dev strategy. Clean architecture, Riverpod, Dio, go_router. Supports **mobile** and **web**.

## Prerequisites

- Flutter SDK 3.24+ (Dart 3.4+)
- Running FITFLOW API (e.g. `make run` or Docker). For web, ensure API CORS allows your app origin.

## Setup

```bash
cd mobile
flutter pub get
```

Set API base URL: edit `lib/core/config/app_config.dart` or use `--dart-define=API_BASE_URL=...` (e.g. `http://10.0.2.2:8080` for Android emulator, `http://localhost:8080` for web dev).

## Run

```bash
# Device / emulator
flutter run

# Web (Chrome)
flutter run -d chrome

# Web (release build, then serve build/web)
flutter build web
```

## Structure

- `lib/core/` — config, API client, errors, router, URL strategy (path-based on web)
- `lib/features/auth/` — login, register, token storage
- `lib/features/` — profile, gym, workout, progress, feed, trainer (placeholders)
- `lib/app.dart` — MaterialApp with Riverpod + go_router
- `web/` — `index.html`, `manifest.json` for web
