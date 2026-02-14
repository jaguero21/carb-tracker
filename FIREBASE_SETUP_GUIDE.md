# 🔥 Firebase Backend Setup - Step by Step

Follow these steps to set up Firebase Functions as your secure API proxy.

---

## Prerequisites

- [x] Firebase CLI installed (already done! ✅)
- [ ] Google account
- [ ] 10-15 minutes of time

---

## Step 1: Login to Firebase

Open your terminal and run:

```bash
firebase login
```

This will:
1. Open your browser
2. Ask you to sign in with Google
3. Grant Firebase CLI access

**Expected output:** "✔ Success! Logged in as your-email@gmail.com"

---

## Step 2: Create Firebase Project

### Option A: Create via Web Console (Recommended)

1. Go to: https://console.firebase.google.com
2. Click **"Add project"** or **"Create a project"**
3. Project name: `carbwise` (or any name you prefer)
4. Click **Continue**
5. Disable Google Analytics (not needed for this) → **Continue**
6. Click **Create project**
7. Wait for project creation (~30 seconds)
8. Click **Continue** when ready

### Option B: Create via CLI

```bash
# This will guide you through creating a project
firebase projects:create carbwise
```

**Copy your project ID** - you'll need it! (usually something like `carbwise-12345`)

---

## Step 3: Initialize Firebase in Your Project

In your project directory:

```bash
cd /Users/jamesaguero/Projects/carb_tracker
firebase init functions
```

You'll be asked several questions:

### Question 1: "Please select an option"
**Select:** `Use an existing project` (using arrow keys)
Press `Enter`

### Question 2: "Select a default Firebase project"
**Select:** The `carbwise` project you just created
Press `Enter`

### Question 3: "What language would you like to use?"
**Select:** `JavaScript` (easier for this use case)
Press `Enter`

### Question 4: "Do you want to use ESLint?"
**Type:** `n` (no)
Press `Enter`

### Question 5: "Do you want to install dependencies with npm now?"
**Type:** `Y` (yes)
Press `Enter`

**Wait for npm to install packages (~1-2 minutes)**

**Expected output:** Firebase initialization complete!

You should now have a `functions/` folder in your project.

---

## Step 4: Copy Function Code

Copy the example function code to the real functions folder:

```bash
# Copy the function code
cp firebase_backend_example/index.js functions/index.js

# Copy package.json
cp firebase_backend_example/package.json functions/package.json

# Install dependencies
cd functions
npm install
cd ..
```

---

## Step 5: Deploy Functions

```bash
firebase deploy --only functions
```

This will:
1. Build your functions
2. Upload to Firebase
3. Make them available via HTTPS

**Wait 1-2 minutes for deployment**

**Expected output:**
```
✔  Deploy complete!

Functions:
  getCarbCount(us-central1): https://us-central1-carbwise-xxxxx.cloudfunctions.net/getCarbCount
  getCarbCountHttp(us-central1): https://us-central1-carbwise-xxxxx.cloudfunctions.net/getCarbCountHttp
```

**Copy these URLs** - you'll need them for testing!

---

## Step 6: Set API Key in Firebase

Your Perplexity API key needs to be stored securely in Firebase:

```bash
firebase functions:config:set perplexity.key="YOUR_NEW_PERPLEXITY_API_KEY"
```

**Important:** Use your NEW rotated API key (not the old one from our conversation)!

After setting the key, redeploy:

```bash
firebase deploy --only functions
```

---

## Step 7: Test the Function

Test using curl (replace URL with your actual function URL):

```bash
curl -X POST https://us-central1-YOUR-PROJECT.cloudfunctions.net/getCarbCountHttp \
  -H "Content-Type: application/json" \
  -d '{"foodItem": "apple"}'
```

**Expected response:**
```json
{
  "foodItem": "apple",
  "carbs": 25,
  "rawResponse": "25"
}
```

If you get this, your backend is working! 🎉

---

## Step 8: Add Firebase to Flutter App

### 8.1: Add Firebase Packages

```bash
flutter pub add firebase_core cloud_functions
```

### 8.2: Configure Firebase for iOS

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase for your app
flutterfire configure
```

Select:
- Your `carbwise` project
- Platforms: iOS and Android
- Use default options for everything else

This creates `firebase_options.dart` file automatically.

### 8.3: Update main.dart

Replace the environment variable initialization with Firebase initialization:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'dart:convert';
import 'services/perplexity_service.dart';
import 'models/food_item.dart';
import 'screens/saved_food_list_page.dart';
import 'config/app_colors.dart';
import 'config/app_icons.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase instead of dotenv
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const CarbTrackerApp());
}
```

### 8.4: Create New Service File

Create a new file: `lib/services/perplexity_service_firebase.dart`

Copy from: `firebase_backend_example/flutter_integration.dart`

Or use this code:

```dart
import 'package:cloud_functions/cloud_functions.dart';

class PerplexityService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<double> getCarbCount(String foodItem) async {
    try {
      final callable = _functions.httpsCallable('getCarbCount');
      final result = await callable.call({'foodItem': foodItem});

      final data = result.data as Map<String, dynamic>;
      final carbs = (data['carbs'] as num).toDouble();

      return carbs;
    } on FirebaseFunctionsException catch (e) {
      switch (e.code) {
        case 'unauthenticated':
          throw Exception('Please sign in to use this feature');
        case 'invalid-argument':
          throw Exception('Invalid food item');
        case 'resource-exhausted':
          throw Exception('API rate limit exceeded. Please try again later.');
        default:
          throw Exception('Failed to get carb count: ${e.message}');
      }
    } catch (e) {
      throw Exception('Network error. Please check your connection.');
    }
  }
}
```

### 8.5: Replace Old Service

**Option 1:** Replace the file
```bash
cp lib/services/perplexity_service_firebase.dart lib/services/perplexity_service.dart
```

**Option 2:** Update imports in main.dart to use the new service

---

## Step 9: Test the App

```bash
flutter run
```

Add a food item and verify it works!

---

## ✅ Success Checklist

- [ ] Firebase CLI installed
- [ ] Logged into Firebase
- [ ] Firebase project created
- [ ] Functions initialized
- [ ] Functions deployed successfully
- [ ] API key configured in Firebase
- [ ] Function tested with curl (works!)
- [ ] Firebase packages added to Flutter
- [ ] Firebase configured for iOS/Android
- [ ] Service updated to use Firebase Functions
- [ ] App tested and working

---

## 🎯 What You Achieved

Before:
```
Flutter App → Perplexity API
(Has API key)   (Exposed)
```

After:
```
Flutter App → Firebase Functions → Perplexity API
(No API key)   (Has API key)      (Protected!)
```

**Your API key is now 100% secure!** ✨

---

## 💰 Costs

Firebase Free Tier:
- **125,000 invocations/month** - FREE
- **400,000 GB-seconds compute/month** - FREE
- **200,000 CPU-seconds/month** - FREE

For a personal carb tracking app, you'll never exceed this.

Paid tier (if you somehow exceed free tier):
- $0.40 per million invocations
- Very cheap for most use cases

---

## 🛠 Troubleshooting

### "Firebase command not found"
```bash
npm install -g firebase-tools
firebase --version  # Should show version
```

### "Permission denied" during deployment
```bash
firebase login --reauth
firebase deploy --only functions
```

### "PERMISSION_DENIED" error
Make sure you're logged in and selected the right project:
```bash
firebase projects:list
firebase use carbwise  # or your project ID
```

### Function returns error
Check logs:
```bash
firebase functions:log
```

### Flutter app can't connect
Make sure you ran `flutterfire configure` and selected both iOS and Android.

---

## 📚 Resources

- Firebase Console: https://console.firebase.google.com
- Firebase Functions Docs: https://firebase.google.com/docs/functions
- FlutterFire Docs: https://firebase.flutter.dev
- Pricing: https://firebase.google.com/pricing

---

## 🎉 Next Steps

Once everything is working:

1. ✅ Your API key is now secure on the server
2. ✅ No more code obfuscation needed (but still recommended)
3. ✅ Easy to rotate keys (just update Firebase config)
4. ✅ Built-in rate limiting and monitoring
5. ✅ Can add authentication later if needed

**Congratulations! You now have enterprise-grade API security!** 🚀
