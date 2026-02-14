# Firebase Backend API Proxy (Optional)

This is an **optional** backend solution that provides better security by keeping your API key on the server instead of in the app.

## Why Use This?

Without a backend, your Perplexity API key is embedded in the Flutter app, making it vulnerable to extraction. With Firebase Functions, the key stays on the server.

**Architecture:**
```
Flutter App → Firebase Functions → Perplexity API
(No API key)   (Has API key)      (Protected)
```

## Setup Instructions

### 1. Install Firebase CLI

```bash
npm install -g firebase-tools
firebase login
```

### 2. Initialize Firebase Project

```bash
cd firebase_backend_example
firebase init functions
```

Select:
- **JavaScript** (or TypeScript if you prefer)
- **Install dependencies** (yes)

### 3. Deploy the Function

```bash
firebase deploy --only functions
```

### 4. Set API Key

```bash
firebase functions:config:set perplexity.key="YOUR_PERPLEXITY_API_KEY"
firebase deploy --only functions  # Redeploy to use new config
```

### 5. Update Flutter App

See [`flutter_integration.dart`](flutter_integration.dart) for how to call the Firebase function from your Flutter app.

## Costs

Firebase Functions pricing:
- **Free tier:** 125K invocations/month, 40K GB-seconds/month
- **After free tier:** $0.40 per million invocations

For a personal carb tracking app, you'll likely stay within the free tier.

## Files

- `index.js` - Cloud function code
- `package.json` - Dependencies
- `flutter_integration.dart` - Example Flutter code to call the function
