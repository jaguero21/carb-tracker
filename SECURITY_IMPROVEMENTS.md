# Security Improvements

## Summary

CarpeCarb uses a layered security approach. The Perplexity API key is stored server-side in Google Cloud Secret Manager and accessed only by a Firebase Cloud Function. The Flutter app never handles the key.

## Implemented Measures

### 1. Firebase Cloud Function Proxy
**File:** [`functions/index.js`](functions/index.js)

- All Perplexity API calls are routed through a Firebase Cloud Function
- API key stored in Google Cloud Secret Manager, not in the app
- Server-side input sanitization, retry logic, and error handling
- No app update needed to rotate the API key

### 2. Client-Side Rate Limiting
**File:** [`lib/services/perplexity_firebase_service.dart`](lib/services/perplexity_firebase_service.dart)

- 1500ms minimum interval between requests
- Prevents accidental rapid-fire API calls

### 3. Input Validation
**File:** [`lib/utils/input_validation.dart`](lib/utils/input_validation.dart)

- Length enforcement (2-100 characters)
- Character whitelist (alphanumeric + common punctuation)
- Prompt injection detection
- Control character stripping
- Validated on both client and server

### 4. Code Obfuscation
**File:** [`BUILD.md`](BUILD.md)

- Release builds use `--obfuscate` flag
- Debug symbols stored separately for crash analysis

### 5. Error Handling

- Firebase callable function errors mapped to user-friendly messages
- No raw error details or stack traces exposed to the client
- Server-side retry with backoff for transient Perplexity API failures

## Security Status

| Measure | Status |
|---------|--------|
| Server-side API key (Secret Manager) | Implemented |
| Firebase Cloud Function proxy | Implemented |
| Client-side rate limiting | Implemented |
| Input validation (client + server) | Implemented |
| Prompt injection detection | Implemented |
| Code obfuscation | Configured |
| Git security (.env, plist gitignored) | Verified |

## API Key Rotation

```bash
# Set new key
echo -n "NEW_KEY" | firebase functions:secrets:set PERPLEXITY_API_KEY --data-file -

# Redeploy
firebase deploy --only functions
```

No app update required.

## Documentation

- [`SECURITY.md`](SECURITY.md) — Full security architecture and data flow
- [`BUILD.md`](BUILD.md) — Build instructions with obfuscation
