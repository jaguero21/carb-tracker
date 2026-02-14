# Security Documentation

## Overview

This document outlines the security measures implemented in CarbWise and recommendations for production deployment.

---

## ✅ Current Security Measures

### 1. Environment Variables
**Status:** ✅ Implemented

- API keys are stored in `.env` file (not committed to git)
- Loaded at runtime using `flutter_dotenv`
- `.env` and `lib/config/api_keys.dart` are in `.gitignore`

**Files:**
- [`.env`](.env) - Contains actual API key (gitignored)
- [`.env.example`](.env.example) - Template file (committed to git)

### 2. Rate Limiting
**Status:** ✅ Implemented

- Client-side rate limiting prevents API abuse
- Minimum 1.5 seconds between requests
- Prevents accidental rapid-fire requests

**Location:** [`lib/services/perplexity_service.dart`](lib/services/perplexity_service.dart)

### 3. Code Obfuscation
**Status:** ✅ Configured

- Build scripts use `--obfuscate` flag
- Symbol files stored separately for crash debugging
- Makes reverse engineering more difficult

**See:** [`BUILD.md`](BUILD.md) for build instructions

### 4. Input Validation
**Status:** ✅ Implemented

- Food input validated before API calls
- Length checks (2-100 characters)
- Character whitelist (alphanumeric + common punctuation)
- Prevents injection attacks

**Location:** [`lib/main.dart`](lib/main.dart) - `_validateFoodInput()`

### 5. Error Handling
**Status:** ✅ Implemented

- Proper HTTP status code handling
- Timeout protection (30 seconds)
- Network error detection
- User-friendly error messages

---

## ⚠️ Known Vulnerabilities

### 1. Client-Side API Key Exposure
**Severity:** CRITICAL (for production)
**Status:** 🟡 Mitigated but not solved

**Issue:**
Even with environment variables and obfuscation, the API key is still embedded in the compiled app binary. A determined attacker can extract it.

**Current Mitigation:**
- Environment variables (not hardcoded)
- Code obfuscation enabled
- Rate limiting to prevent abuse

**Recommended Solution for Production:**
Implement a backend API proxy (see [Backend Solutions](#backend-solutions) below)

---

## 🛡️ Production Recommendations

### Option A: Firebase Functions (Recommended)

**Why:** Free tier, automatic scaling, no server management

**Setup:**
1. Create Firebase project
2. Deploy cloud function as API proxy
3. Store API key in Firebase environment config
4. Update Flutter app to call Firebase function instead of Perplexity directly

**Example Function:**
```javascript
exports.getCarbCount = functions.https.onCall(async (data, context) => {
  const { foodItem } = data;

  // Optional: Add authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  // Call Perplexity API with server-side key
  const response = await fetch('https://api.perplexity.ai/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${functions.config().perplexity.key}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({/* ... */})
  });

  return await response.json();
});
```

**Flutter Integration:**
```dart
import 'package:cloud_functions/cloud_functions.dart';

Future<double> getCarbCount(String foodItem) async {
  final result = await FirebaseFunctions.instance
    .httpsCallable('getCarbCount')
    .call({'foodItem': foodItem});

  return result.data['carbs'];
}
```

**Costs:** Free for up to 125K requests/month

---

### Option B: Custom Backend API

**Why:** Full control, can add features like user accounts, analytics, etc.

**Recommended Platforms:**
- **Vercel** (free tier, easy deployment)
- **Railway** (generous free tier)
- **Fly.io** (free tier available)
- **Render** (free tier with limitations)

**Example Backend (Node.js/Express):**
```javascript
const express = require('express');
const app = express();

app.use(express.json());

app.post('/api/carbs', async (req, res) => {
  const { foodItem } = req.body;

  // Add rate limiting (e.g., using express-rate-limit)
  // Add authentication if needed

  try {
    const response = await fetch('https://api.perplexity.ai/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${process.env.PERPLEXITY_API_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({/* ... */})
    });

    const data = await response.json();
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.listen(3000);
```

---

## 🔒 API Key Management

### Rotating API Keys

If you suspect your API key has been compromised:

1. **Generate new key** at https://www.perplexity.ai/settings/api
2. **Update `.env` file:**
   ```bash
   PERPLEXITY_API_KEY=new-key-here
   ```
3. **Rebuild and redeploy app:**
   ```bash
   flutter clean
   flutter pub get
   flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols
   ```
4. **Revoke old key** in Perplexity dashboard

### Best Practices

✅ **DO:**
- Store API keys in environment variables
- Use `.gitignore` for sensitive files
- Build with obfuscation for releases
- Monitor API usage for anomalies
- Set usage limits in Perplexity dashboard

❌ **DON'T:**
- Commit API keys to git
- Share API keys in chat/email
- Hardcode keys in source code
- Use same key for dev and production
- Skip obfuscation in release builds

---

## 📊 Monitoring & Alerting

### Perplexity Dashboard

Monitor usage at: https://www.perplexity.ai/settings/api

**Set up alerts for:**
- Unusual spike in requests
- Reaching usage limits
- Failed authentication attempts

### App Analytics (Optional)

Consider adding analytics to track:
- API call frequency
- Error rates
- User patterns

**Recommended tools:**
- Firebase Analytics (free)
- Sentry (error tracking)
- PostHog (open source analytics)

---

## 🚨 Incident Response

If your API key is compromised:

1. **Immediately revoke** the key in Perplexity dashboard
2. **Generate new key** and update `.env`
3. **Review usage logs** for unauthorized requests
4. **Deploy updated app** with new key
5. **Investigate** how the key was compromised
6. **Implement additional security** if needed

---

## 📝 Security Checklist

Before deploying to production:

- [ ] API keys in environment variables (not hardcoded)
- [ ] `.env` file in `.gitignore`
- [ ] Code obfuscation enabled in build
- [ ] Rate limiting implemented
- [ ] Input validation active
- [ ] Error handling robust
- [ ] Usage monitoring set up
- [ ] Backend proxy deployed (recommended)
- [ ] Git history checked for exposed keys
- [ ] `.env.example` updated (without real keys)

---

## 📚 Additional Resources

- [OWASP Mobile Security](https://owasp.org/www-project-mobile-security/)
- [Flutter Security Best Practices](https://docs.flutter.dev/deployment/obfuscate)
- [API Key Security Guide](https://cloud.google.com/docs/authentication/api-keys)

---

**Last Updated:** 2026-02-12
**Next Review:** Before production release
