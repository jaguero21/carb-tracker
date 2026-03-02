# CarpeCarb Icon Pack Implementation Guide

## 📦 What's Included

The CarpeCarb icon pack has been successfully integrated into your Flutter app! Here's what's been added:

### 1. **Brand Colors** (`lib/config/app_colors.dart`)
- **Sage** (#7D9B76) - Primary brand color
- **Honey** (#E8A93C) - Secondary/accent color
- **Terracotta** (#D4714E) - Error/warning color
- **Cream** (#FAF7F2) - Background color
- **Sky** (#5B8DB8) - Info color
- Plus all color variations and gradients

### 2. **UI Icons** (`assets/icons/`)
All icons are SVG format for crisp rendering at any size:
- `dashboard.svg` - Home/Dashboard icon
- `add_meal.svg` - Add meal icon with plus sign
- `search.svg` - Search icon
- `history.svg` - History/clock icon
- `profile.svg` - User profile icon
- `settings.svg` - Settings gear icon
- `bookmark.svg` - Saved foods icon
- `trends.svg` - Analytics/trends chart icon
- `scan.svg` - Barcode scanner icon
- `nutrition.svg` - Nutrition facts icon
- `delete.svg` - Delete/trash icon

### 3. **App Icon** (`assets/app_icon/`)
- `app_icon.svg` - Main app icon (bowl with food and leaf design)
- Ready to be converted to PNG for iOS/Android

### 4. **Icon Helper Class** (`lib/config/app_icons.dart`)
Easy-to-use helper methods for displaying icons:
```dart
// Simple usage
AppIcons.dashboardIcon(size: 24)
AppIcons.bookmarkIcon(size: 28, color: Colors.white)

// Or use the generic method
AppIcons.icon(AppIcons.search, size: 20, color: AppColors.sage)
```

## 🎨 Theme Integration

The app theme has been fully updated with CarpeCarb colors:
- App name changed to "CarpeCarb"
- Sage color scheme throughout
- Warm cream background
- Custom bookmark and delete icons in swipe actions
- Consistent color palette for buttons, inputs, and text

## 📱 Generating the App Icon

To set up the app icon for iOS and Android:

### Step 1: Convert SVG to PNG
You need to convert `assets/app_icon/app_icon.svg` to PNG format at 1024×1024 pixels.

**Option A - Online Tool:**
1. Go to https://svgtopng.com or https://cloudconvert.com/svg-to-png
2. Upload `assets/app_icon/app_icon.svg`
3. Set dimensions to 1024×1024 pixels
4. Download as `app_icon.png`
5. Save to `assets/app_icon/app_icon.png`

**Option B - Command Line (if you have ImageMagick):**
```bash
magick convert -density 300 -background none assets/app_icon/app_icon.svg -resize 1024x1024 assets/app_icon/app_icon.png
```

**Option C - macOS Preview:**
1. Open `app_icon.svg` in Preview
2. File → Export
3. Format: PNG
4. Resolution: 1024×1024
5. Save as `app_icon.png` in the same folder

### Step 2: Generate Icon Assets
Once you have the PNG file:

```bash
flutter pub run flutter_launcher_icons
```

This will automatically generate all required icon sizes for:
- iOS (all required sizes)
- Android (adaptive icons with sage background)

### Step 3: Verify
Check these locations:
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
- `android/app/src/main/res/mipmap-*/`

## 🚀 Using Icons in Your Code

### In Widgets:
```dart
import 'package:carb_tracker/config/app_icons.dart';
import 'package:carb_tracker/config/app_colors.dart';

// Example 1: Simple icon
IconButton(
  icon: AppIcons.settingsIcon(),
  onPressed: () {},
)

// Example 2: Custom size and color
AppIcons.dashboardIcon(
  size: 32,
  color: AppColors.sage,
)

// Example 3: In a container
Container(
  child: AppIcons.trendsIcon(size: 48),
)
```

### Using Colors:
```dart
// Background colors
Container(color: AppColors.cream)
Container(color: AppColors.warmWhite)

// Text colors
Text('Hello', style: TextStyle(color: AppColors.ink))
Text('Subtitle', style: TextStyle(color: AppColors.muted))

// Accent colors
ElevatedButton(
  style: ElevatedButton.styleFrom(backgroundColor: AppColors.sage),
  child: Text('Button'),
)

// Using gradients
Container(
  decoration: BoxDecoration(
    gradient: AppColors.sageGradient,
  ),
)
```

## 🎯 Design Philosophy

The CarpeCarb icon pack follows these principles:
- **Warm & Natural**: Sage greens and honey yellows evoke wholesome, natural foods
- **Clarity**: Clean, simple shapes that are easy to understand at a glance
- **Consistency**: All icons use the same stroke weights and corner radii
- **iOS-Friendly**: Designed to match iOS Human Interface Guidelines

## 📝 Next Steps

1. ✅ Icons integrated into the app
2. ⏳ Convert SVG app icon to PNG (1024×1024)
3. ⏳ Run `flutter pub run flutter_launcher_icons`
4. ✅ Test the app to see the new design!

## 🛠 Customization

Want to add more icons? Follow this pattern:

1. Create SVG in `assets/icons/your_icon.svg`
2. Add path constant in `AppIcons` class:
   ```dart
   static const String yourIcon = '${_basePath}your_icon.svg';
   ```
3. Add convenience method:
   ```dart
   static Widget yourIconIcon({double size = 24.0, Color? color}) =>
       icon(yourIcon, size: size, color: color);
   ```

---

**Enjoy your new CarpeCarb design! 🌿🍽️**
