# CarpeCarb TestFlight Beta Details

Use this sheet to fill in App Store Connect TestFlight metadata for internal and external testing.

## App Name
CarpeCarb

## Build Version
1.0.0 (Build 1)

## Beta App Description (TestFlight)
CarpeCarb is a minimalist carb tracking app for iPhone that lets users describe what they ate in plain language and get AI-powered carb estimates. It supports daily goal tracking, saved foods, Apple Health sync, and iCloud-based cloud sync across devices.

## What to Test
1. Add food using AI lookup and verify carb totals update correctly.
2. Add food using Manual Entry mode and verify totals and list behavior.
3. Toggle premium features in Settings > Premium and confirm behavior changes:
	- Manual Entry
	- Apple Health Sync
	- Cloud Sync
4. Confirm saved foods flow works:
	- Swipe right to save
	- Add from saved foods in Settings
	- Reset saved foods
5. Verify daily goal and reset hour behavior in Settings > Goals.
6. Verify widget values update after adding/removing foods.
7. If testing on multiple iCloud-signed devices, verify cloud sync propagation.

## Test Information (for external testers)
Primary focus for this beta:
- Data accuracy and consistency of daily totals
- Stability when toggling sync features
- Health sync behavior and permission prompts
- Cloud sync reliability across app resumes

Please report:
- Exact steps to reproduce
- Expected vs actual behavior
- Device model + iOS version
- Screenshots or screen recording if possible

## Known Issues / Notes
1. AI carb estimates may vary based on source quality and food specificity.
2. First cloud sync may take a short moment after app launch/resume.
3. App Store validation may warn about launch image asset quality if default placeholders are still present.

## Contact for Feedback
- Name: James Aguero
- Email: <your-support-email@example.com>

## Demo Account / Login
No login required.

## Privacy Notes for Testers
- Food entries are stored locally on device.
- Optional cloud sync uses iCloud key-value storage.
- Optional Apple Health sync writes nutrition entries when enabled.

## Suggested TestFlight "What to Test" (short paste version)
Please test AI food lookup, manual entry, saved foods, daily goals/reset hour, Apple Health sync, widget updates, and iCloud cloud sync across devices. Report any incorrect carb totals, sync delays, crashes, or UI issues with steps, expected result, and device/iOS version.
