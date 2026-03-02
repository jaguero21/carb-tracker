# Security Documentation

## Overview

CarpeCarb is a carb tracking iOS app that uses AI-powered nutrition lookup via the Perplexity API. All API communication is routed through a Firebase Cloud Function so that no API keys are stored in or shipped with the app.

---

## Architecture

```
Flutter App  →  Firebase Cloud Function  →  Perplexity API
(no API key)    (has API key via Secret     (protected)
                 Manager)
```

The app never contacts the Perplexity API directly. The Cloud Function acts as a secure proxy, holding the API key server-side via Google Cloud Secret Manager.

---

## Security Measures

### 1. Server-Side API Key
**Status:** Implemented

The Perplexity API key is stored in Google Cloud Secret Manager and accessed only by the Cloud Function at runtime. It is never embedded in the app binary, transmitted to the client, or committed to source control.

**Files:**
- [`functions/index.js`](functions/index.js) — Cloud Function that accesses the secret
- [`.gitignore`](.gitignore) — Excludes `.env`, `GoogleService-Info.plist`, and API key files

### 2. Input Validation & Sanitization
**Status:** Implemented

User input is validated and sanitized on both the client and server before reaching the Perplexity API.

**Client-side** ([`lib/utils/input_validation.dart`](lib/utils/input_validation.dart)):
- Length enforcement (2-100 characters)
- Character whitelist (alphanumeric + common punctuation)
- Prompt injection detection (blocks keywords like "ignore", "system", "override")
- Control character stripping and whitespace normalization

**Server-side** ([`functions/index.js`](functions/index.js)):
- Duplicate length and type validation
- Sanitization of control characters, null bytes, and whitespace
- Input is never interpolated into the system prompt

### 3. Rate Limiting
**Status:** Implemented

- Client-side: 1500ms minimum interval between requests prevents accidental rapid-fire submissions
- Server-side: Firebase Cloud Functions enforce per-instance concurrency limits

**Location:** [`lib/services/perplexity_firebase_service.dart`](lib/services/perplexity_firebase_service.dart)

### 4. Error Handling
**Status:** Implemented

- Firebase callable function errors are mapped to user-friendly messages
- API authentication failures, rate limits, and server errors are handled distinctly
- No raw error details or stack traces are exposed to the client
- Server-side retry logic (up to 3 attempts) handles transient Perplexity API failures

### 5. Code Obfuscation
**Status:** Configured

- Release builds use `--obfuscate` and `--split-debug-info` flags
- Symbol files are stored separately for crash debugging

**See:** [`BUILD.md`](BUILD.md)

### 6. Local Data Storage
**Status:** Implemented

- Food items and preferences are stored locally via `SharedPreferences`
- Carb data syncs to Apple Health (with user permission) via the HealthKit API
- No user data is sent to any server other than the food lookup query text to the Cloud Function

---

## Data Flow

1. User types a food item (e.g., "Big Mac and fries")
2. Client validates and sanitizes the input
3. Client calls the `getMultipleCarbCounts` Firebase Cloud Function
4. Cloud Function retrieves the Perplexity API key from Secret Manager
5. Cloud Function calls the Perplexity API with the sanitized input
6. Cloud Function parses the response into structured food items and returns them
7. Client stores results locally and optionally syncs to Apple Health

No user accounts, authentication tokens, or personal identifiers are collected or transmitted.

---

## API Key Rotation

If the Perplexity API key is compromised:

1. Revoke the key at https://www.perplexity.ai/settings/api
2. Generate a new key
3. Update the secret:
   ```bash
   echo -n "NEW_KEY_HERE" | firebase functions:secrets:set PERPLEXITY_API_KEY --data-file -
   ```
4. Redeploy the function:
   ```bash
   firebase deploy --only functions
   ```

No app update is required — the key lives entirely server-side.

---

## Security Checklist

- [x] API key stored in Cloud Secret Manager (not in app)
- [x] `.env` and `GoogleService-Info.plist` in `.gitignore`
- [x] Input validation on client and server
- [x] Prompt injection detection
- [x] Rate limiting on client
- [x] Code obfuscation enabled for release builds
- [x] Error messages sanitized (no internal details exposed)
- [x] Retry logic with backoff for transient failures
- [x] No user PII collected or transmitted

---

**Last Updated:** 2026-03-01
