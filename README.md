# CarpeCarb

**Website:** https://jaguero21.github.io/CarpeCarb/

A minimalist iOS app for tracking daily carb intake. Type what you ate in plain language and get instant, AI-powered carb counts with cited sources — no manual database searching required.

## How It Works

1. **Enter any food** — describe what you ate naturally (e.g. "two tacos and a horchata")
2. **Get instant results** — AI looks up the carb count and returns it with source citations
3. **Track your day** — watch your progress toward a daily carb goal with a visual progress bar
4. **Stay in sync** — data syncs to Apple Health and is accessible from your Home Screen widget or Siri

## Features

- **AI-Powered Lookup** — natural language food entry powered by Perplexity's sonar-pro model
- **Daily Progress Tracking** — visual progress bar toward a customizable daily carb goal
- **Apple HealthKit Sync** — carb data automatically written to and read from Apple Health
- **Siri Integration** — log foods hands-free with App Intents
- **Home Screen Widget** — see your daily carb total at a glance without opening the app
- **Favorites** — swipe right to save frequently eaten foods for one-tap re-entry
- **30-Day History** — review past intake trends pulled from HealthKit
- **Smart Categories** — foods auto-categorized by meal time (breakfast, lunch, dinner, snack)
- **Configurable Reset** — set a custom daily reset time to match your schedule
- **Dark Mode** — full light and dark theme support

## Tech Stack

| Layer | Technology |
|-------|-----------|
| **Frontend** | Flutter (Dart) — single codebase, iOS-focused |
| **AI / Nutrition** | Perplexity API (sonar-pro) via Firebase Cloud Function |
| **Backend** | Firebase Cloud Functions (Node.js) |
| **Secret Management** | Google Cloud Secret Manager — API key never touches the client |
| **Local Storage** | SharedPreferences for food log, goals, and favorites |
| **Health Data** | Apple HealthKit (read/write dietary carbohydrates) |
| **Native iOS** | Swift — Siri App Intents, Home Screen Widget, shared App Group data |
| **Design** | Custom warm color palette (sage, honey, terracotta, cream) with card-based layout |

## Architecture

```
┌─────────────┐     HTTPS      ┌──────────────────────┐     API Call    ┌─────────────────┐
│  Flutter App │  ──────────►   │  Firebase Cloud Fn   │  ──────────►   │  Perplexity API │
│  (no keys)   │  ◄──────────   │  (Secret Manager)    │  ◄──────────   │  (sonar-pro)    │
└─────────────┘                 └──────────────────────┘                 └─────────────────┘
       │
       ├── SharedPreferences (food log, favorites, goals)
       ├── Apple HealthKit (carb sync + 30-day history)
       ├── Home Screen Widget (App Group shared data)
       └── Siri App Intents (hands-free logging)
```

## Project Structure

```
lib/
  ├── main.dart                 # App entry, home screen, food list
  ├── models/food_item.dart     # FoodItem model with auto-categorization
  ├── services/
  │   ├── perplexity_firebase_service.dart   # Cloud Function client
  │   └── health_kit_service.dart            # HealthKit integration
  ├── screens/settings_page.dart             # Favorites, History, Goals tabs
  ├── config/                   # Colors, icons, storage keys, theme
  ├── utils/                    # Input validation, date formatting
  └── widgets/                  # Reusable UI components
functions/
  └── index.js                  # Cloud Function — Perplexity API proxy
ios/
  ├── Runner/CarbIntents.swift  # Siri App Intents
  ├── CarbWiseWidget/           # Home Screen widget
  └── CarbShared/               # Shared Swift package for widget/Siri
```

## Getting Started

```bash
# Install dependencies
flutter pub get

# Run on iOS simulator
flutter run

# Build for device
flutter build ios
```

Firebase setup requires configuring a Cloud Function with a Perplexity API key stored in Google Cloud Secret Manager. No API keys are bundled in the client.

## License

See [LICENSE](LICENSE) for details.
