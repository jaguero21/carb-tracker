# CarpeCarb Beta Testing Guide

Thank you for helping test CarpeCarb! This guide covers everything you need to test in this build. Please work through each section and note anything that feels broken, confusing, or just off.

---

## What's New in This Build

- **Macro Nutrients** — AI-powered lookup now returns protein, fat, fiber, and calories alongside carbs. Enable Macros in Settings → Premium to see a daily totals strip and per-item breakdowns.
- **Macro Goals** — Set daily targets for each macro in Settings → Goals (appears when Macros is enabled).
- **Cloud Sync** — Food items, favorites, and goals now sync across your devices via iCloud.
- **Manual Entry mode** — Toggle to enter carb counts directly without AI lookup.
- **Premium feature toggles** — All premium features can be independently enabled/disabled in Settings → Premium.

---

## Setup (Do This First)

1. Open the app and tap the **Settings** icon (top right)
2. Go to the **Premium** tab
3. Enable whichever features you want to test — all are available in this beta:
   - Manual Entry
   - Apple Health Sync
   - Cloud Sync (requires iCloud sign-in)
   - Macro Nutrients

---

## Test Areas

### 1. AI Carb Lookup (Core Feature)

**What to do:**
- Type a food item and tap **Add** (or press Return)
- Try brand names: `HEB fajita tortilla`, `Chick-fil-A sandwich`, `Oreos`
- Try generic foods: `banana`, `white rice 1 cup`, `glass of orange juice`
- Try multiple foods at once: `burger and fries`, `eggs and toast`

**What to check:**
- [ ] Results come back within ~5 seconds
- [ ] Carb amount looks accurate for the food
- [ ] Food name is specific (not just "sandwich" for a Chick-fil-A sandwich)
- [ ] Long-pressing an item shows a details panel with source info
- [ ] Citations/links in the details panel open correctly in Safari

**Edge cases to try:**
- Very vague input: `food`, `stuff`
- Very specific: `McDonald's Big Mac no sauce`
- Non-food: `water`, `diet coke`
- Long text near the 100-character limit

---

### 2. Manual Entry (Premium)

**Setup:** Settings → Premium → enable Manual Entry

**What to do:**
- Tap the **Manual** chip to switch modes
- Enter a food name and carb amount, tap Add
- Switch back to **AI Lookup** chip

**What to check:**
- [ ] Manual chip only appears when Manual Entry is enabled
- [ ] Carb field accepts decimals (e.g. `12.5`)
- [ ] Submitting with empty name shows an error
- [ ] Submitting with a negative or invalid carb amount shows an error
- [ ] Manual items appear in the food list identically to AI-looked-up items
- [ ] Disabling Manual Entry in Premium settings hides the chip immediately

---

### 3. Macro Nutrients (Premium)

**Setup:** Settings → Premium → enable Macro Nutrients

**What to do:**
- Log 2–3 foods via AI Lookup
- Check the **macro strip** that appears below the carb card
- Long-press any item to see per-item macro breakdown in the details modal

**What to check:**
- [ ] Macro strip appears after logging your first item
- [ ] Strip shows Protein / Fat / Fiber / Calories totals
- [ ] Values look plausible for what you ate (not wildly off)
- [ ] Long-press modal shows Carbs, Protein, Fat, Fiber, Calories for that item
- [ ] Disabling Macros in Premium hides the strip immediately
- [ ] Items logged before macros was enabled show no macro data (that's expected)

**With macro goals set:**
- Go to Settings → Goals → fill in Protein, Fat, Fiber, Calories goals → Save
- [ ] Macro strip now shows `45 / 120g` format (actual / goal)
- [ ] Values update as you log more food

---

### 4. Goals

**What to do:**
- Settings → Goals tab
- Set a **Daily Carb Goal** (e.g. 150)
- Set a **Daily Reset Time**
- If Macros is enabled, set **Macro Goals** for each macro
- Tap **Save Changes**

**What to check:**
- [ ] Carb goal appears on the home screen as `of 150g daily goal`
- [ ] Progress bar fills as you log food
- [ ] Progress bar turns red if you exceed your goal
- [ ] Reset time saves and persists after closing/reopening the app
- [ ] Macro Goals card only appears in Goals when Macros is enabled
- [ ] Clearing a macro goal field and saving removes the goal (no `/ 0g` shown)
- [ ] Goals persist after force-quitting and reopening the app

---

### 5. Favorites

**What to do:**
- Long-press any logged item → tap **Save to Favorites** (if available)
- Go to Settings → Favorites tab
- Tap a favorite to add it to today's list
- Swipe to delete a favorite
- Try **Reset Favorites** at the bottom

**What to check:**
- [ ] Saved item appears in the Favorites list
- [ ] Tapping a favorite adds it instantly to the home screen
- [ ] Deleting a favorite works and updates the list
- [ ] Favorites persist after closing and reopening the app

---

### 6. History

**What to do:**
- Log several items across different meal times
- Go to Settings → History tab

**What to check:**
- [ ] History shows past days grouped by date
- [ ] Each entry shows food name and carb count
- [ ] History requires Apple Health permission — if prompted, tap Allow
- [ ] If Health permission is denied, a clear message is shown (not a crash)

---

### 7. Cloud Sync (Premium)

**Setup:** Sign into iCloud on your device. Settings → Premium → enable Cloud Sync.

**What to do:**
- Log food on one device
- Open the app on a second device (or after some time)
- Check that your food list, favorites, and goals appear on the second device

**What to check:**
- [ ] Data appears on second device within ~30 seconds (iCloud timing varies)
- [ ] Favorites sync across devices
- [ ] Carb goal and reset time sync across devices
- [ ] If iCloud is not signed in, enabling Cloud Sync shows a helpful message
- [ ] Disabling Cloud Sync stops future syncing (existing data stays)

---

### 8. Apple Health Sync (Premium)

**Setup:** Settings → Premium → enable Apple Health Sync

**What to do:**
- Log a food item
- Open the Health app → Browse → Nutrition → Carbohydrates
- Delete a food item from CarpeCarb

**What to check:**
- [ ] Carb entry appears in Apple Health after logging
- [ ] Deleting an item from CarpeCarb also removes it from Health
- [ ] Resetting the daily total removes all today's entries from Health

---

### 9. Home Screen Widget

**Setup:** Long-press your home screen → add the **CarbWise** widget

**What to do:**
- Log a food item in the app
- Check the widget on your home screen

**What to check:**
- [ ] Widget updates after logging (may take a few seconds)
- [ ] Carb total matches what's in the app
- [ ] Last food name and carb count are correct
- [ ] Widget shows goal if one is set
- [ ] Tapping the widget opens the app

---

### 10. General UX

**What to check:**
- [ ] Dark mode looks correct (Settings → Display & Brightness → Dark)
- [ ] Keyboard appears automatically when the app opens
- [ ] Tapping the carb total card toggles between today's total and the latest item
- [ ] Long-pressing the carb total card navigates to Settings
- [ ] Logging many items (10+) doesn't slow down the app
- [ ] Force-quitting and reopening restores all data correctly
- [ ] App handles no internet connection gracefully (AI Lookup shows a clear error)

---

## Known Limitations

- **Macros on existing items:** Items logged before enabling Macro Nutrients won't have macro data. Only newly looked-up items will show macros.
- **Cloud sync timing:** iCloud sync is not instant — allow up to 60 seconds for data to appear on a second device.
- **History on simulator:** Apple Health is not available on the iOS Simulator. Test history on a physical device.
- **Manual entry + macros:** Manually entered items don't get macro data (only AI-looked-up items do).

---

## How to Report Issues

Please note the following when reporting a bug:

1. **What you did** — step by step
2. **What you expected** — what should have happened
3. **What happened instead** — the actual behavior
4. **Device + iOS version** — e.g. iPhone 15 Pro, iOS 18.2

Send feedback to: **james.aguero@gmail.com**

Or use the TestFlight feedback button (shake your device while in the app).

---

*Build: userentercarb branch — Thank you for your time!*
