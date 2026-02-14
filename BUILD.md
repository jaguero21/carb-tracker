# CarbWise Build Instructions

## Building with Code Obfuscation

To protect your API keys and make reverse engineering more difficult, **always build with obfuscation enabled** for release builds.

### Android Release Build

```bash
# Build APK with obfuscation
flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols

# Build App Bundle (recommended for Play Store)
flutter build appbundle --release --obfuscate --split-debug-info=build/app/outputs/symbols
```

### iOS Release Build

```bash
# Build for iOS with obfuscation
flutter build ios --release --obfuscate --split-debug-info=build/ios/outputs/symbols
```

## What Obfuscation Does

- **Renames classes, methods, and variables** to meaningless names (e.g., `a`, `b`, `c`)
- **Makes decompilation harder** but not impossible
- **Stores debug symbols** separately so you can still debug crashes
- **Reduces APK/IPA size** slightly

## Important Notes

⚠️ **Obfuscation is NOT complete security** - it only makes extraction harder, not impossible. For production apps, use a backend API proxy instead of embedding keys in the app.

✅ **Save the debug symbols** (`build/app/outputs/symbols`) - you'll need them to read crash reports from users

## Development Builds

For development and testing, you can skip obfuscation:

```bash
# Development build
flutter run

# Or debug APK
flutter build apk --debug
```

## Verifying Obfuscation

To verify obfuscation worked:

1. Extract the APK: `unzip build/app/outputs/flutter-apk/app-release.apk -d extracted`
2. Decompile with jadx: `jadx extracted/classes.dex`
3. Look for obfuscated names in the output

## Environment Setup

Before building, ensure your `.env` file is configured:

```bash
# Check if .env exists
cat .env

# Should contain:
# PERPLEXITY_API_KEY=your-key-here
```

If missing, copy from template:
```bash
cp .env.example .env
# Edit .env and add your API key
```
