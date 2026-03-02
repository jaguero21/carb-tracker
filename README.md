# CarpeCarb

A minimalist iOS app for tracking daily carbohydrate intake, powered by AI-driven nutrition lookup.

## Architecture

```
Flutter App  →  Firebase Cloud Function  →  Perplexity API
(no API key)    (Secret Manager)            (protected)
```

## Features

- Natural language food entry — type what you ate and get carb breakdowns with cited sources
- Daily carb goal tracking with a visual progress ring
- Apple Health integration for syncing carb data
- Siri support for hands-free logging
- Home Screen widget for daily totals at a glance
- Favorites and history for quick re-entry
- Configurable daily reset time
- Frosted glass UI design

## Setup

### 1. Install Flutter

- Download Flutter SDK from https://flutter.dev
- Run `flutter doctor` to verify installation

### 2. Firebase Configuration

The app uses Firebase Cloud Functions to securely proxy Perplexity API calls. See [`SECURITY.md`](SECURITY.md) for the full architecture.

1. Install Firebase CLI: `npm install -g firebase-tools`
2. Login: `firebase login`
3. Configure FlutterFire: `flutterfire configure --project=carpecarb`
4. Set the API secret: `echo -n "YOUR_KEY" | firebase functions:secrets:set PERPLEXITY_API_KEY --data-file -`
5. Deploy: `firebase deploy --only functions`

### 3. Run

```bash
flutter pub get
flutter run
```

## Project Structure

```
lib/
  ├── main.dart                              # App entry point and home screen
  ├── firebase_options.dart                  # Generated Firebase config
  ├── models/
  │   └── food_item.dart                     # Food item data model
  ├── services/
  │   ├── perplexity_firebase_service.dart   # Firebase-backed nutrition lookup
  │   └── health_kit_service.dart            # Apple HealthKit integration
  ├── screens/
  │   └── settings_page.dart                 # Settings with favorites, history, goals
  ├── config/
  │   ├── app_colors.dart                    # Color palette
  │   ├── app_icons.dart                     # SVG icon helpers
  │   └── storage_keys.dart                  # SharedPreferences keys
  ├── utils/
  │   └── input_validation.dart              # Input sanitization and validation
  └── widgets/
      └── glass_container.dart               # Frosted glass UI component
functions/
  ├── index.js                               # Cloud Function (Perplexity API proxy)
  └── package.json                           # Node.js dependencies
```

## How It Works

1. User enters a food item (e.g., "Big Mac and fries")
2. Client validates and sanitizes the input
3. Request is sent to a Firebase Cloud Function
4. Cloud Function calls Perplexity API with the API key from Secret Manager
5. Response is parsed into structured food items with carb counts and citations
6. Results are stored locally and optionally synced to Apple Health

## Build

```bash
# iOS release with obfuscation
flutter build ios --release --obfuscate --split-debug-info=build/ios/outputs/symbols
```

See [`BUILD.md`](BUILD.md) for full build instructions.
