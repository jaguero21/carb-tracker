# Firebase Setup

Firebase is fully configured for CarpeCarb. This documents the current setup and common operations.

## Current Architecture

```text
Flutter App  →  Firebase Cloud Function  →  Perplexity API
(no API key)    (Secret Manager)            (protected)
```

- **Project:** `carpecarb`
- **Function:** `getMultipleCarbCounts` (us-central1, Node 22, 2nd Gen)
- **Secret:** `PERPLEXITY_API_KEY` in Google Cloud Secret Manager

## Key Files

| File | Purpose |
| ---- | ------- |
| `functions/index.js` | Cloud Function source |
| `functions/package.json` | Node.js dependencies |
| `firebase.json` | Firebase project config |
| `.firebaserc` | Project alias |
| `lib/firebase_options.dart` | Generated Flutter config |
| `lib/services/perplexity_firebase_service.dart` | Flutter service calling the function |
| `ios/Runner/GoogleService-Info.plist` | iOS Firebase config (gitignored) |

## Common Operations

### Deploy function changes

```bash
firebase deploy --only functions
```

### Rotate the API key

```bash
echo -n "NEW_KEY" | firebase functions:secrets:set PERPLEXITY_API_KEY --data-file -
firebase deploy --only functions
```

### View function logs

```bash
firebase functions:log
```

### Reconfigure Flutter (e.g. after adding a platform)

```bash
flutterfire configure --project=carpecarb
```

### Check deployed functions

```bash
firebase functions:list
```

## Costs

Firebase Blaze plan with free tier:

- 125,000 function invocations/month — free
- 400,000 GB-seconds compute/month — free
- Secret Manager: 6 active versions, 10K accesses/month — free

For a personal carb tracking app, usage will stay well within the free tier.
