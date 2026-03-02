# CarpeCarb Build Instructions

## Building with Code Obfuscation

Always build with obfuscation enabled for release builds.

### iOS Release Build

```bash
flutter build ios --release --obfuscate --split-debug-info=build/ios/outputs/symbols
```

### Android Release Build

```bash
# Build APK with obfuscation
flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols

# Build App Bundle (recommended for Play Store)
flutter build appbundle --release --obfuscate --split-debug-info=build/app/outputs/symbols
```

## What Obfuscation Does

- Renames classes, methods, and variables to meaningless names
- Makes decompilation harder
- Stores debug symbols separately so you can still debug crashes
- Reduces APK/IPA size slightly

## Important Notes

- Save the debug symbols (`build/*/outputs/symbols`) — you need them to read crash reports
- The Perplexity API key is NOT in the app binary — it lives in Google Cloud Secret Manager and is accessed only by the Firebase Cloud Function

## Development Builds

```bash
flutter run
```

## Prerequisites

Before building, ensure Firebase is configured:

```bash
# Verify Firebase project is set up
firebase projects:list

# Verify Cloud Function is deployed
firebase functions:list
```

No `.env` file or local API key is needed — the key is managed server-side via Secret Manager.
