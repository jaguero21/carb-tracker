# Carb Tracker App

A minimalist Flutter app that tracks carbohydrate intake using the Perplexity API.

## Setup Instructions

### 1. Install Flutter
If you haven't already:
- Download Flutter SDK from https://flutter.dev
- Follow the installation guide for your operating system
- Run `flutter doctor` to verify installation

### 2. Configure Your API Key
1. Open `lib/services/perplexity_service.dart`
2. Replace `'YOUR_PERPLEXITY_API_KEY_HERE'` with your actual Perplexity API key

### 3. Install Dependencies
```bash
cd carb_tracker
flutter pub get
```

### 4. Run the App
```bash
# For iOS simulator (requires Xcode)
flutter run

# To list available devices
flutter devices
```

## Features

- **Minimalist Interface**: Clean, distraction-free design
- **Quick Food Entry**: Simple text input for adding foods
- **Automatic Carb Calculation**: Uses Perplexity API to determine carb content
- **Running Total**: See your total carbs at a glance
- **Persistent Storage**: Your daily total is saved automatically
- **Swipe to Delete**: Remove items by swiping left
- **Reset Function**: Clear all entries and start fresh

## Project Structure

```
lib/
  ├── main.dart                    # Main app and home screen
  ├── models/
  │   └── food_item.dart          # Food item data model
  └── services/
      └── perplexity_service.dart # Perplexity API integration
```

## How It Works

1. User enters a food item (e.g., "banana", "1 slice of bread")
2. App sends the query to Perplexity API
3. API returns the carbohydrate content
4. App adds the food to the list and updates the total
5. Data is saved locally using SharedPreferences

## Customization Ideas

- Add calorie tracking
- Include protein and fat tracking
- Add date-based history
- Create daily goals
- Add search history/favorites
- Include meal categorization (breakfast, lunch, dinner)

## Testing

Before publishing, test with various food inputs:
- Simple items: "apple", "banana"
- With quantities: "2 slices of bread", "100g rice"
- Complex items: "chicken caesar salad"
- Ambiguous items: "sandwich" (to see how API handles it)

## Next Steps

1. Add your Perplexity API key
2. Run the app and test basic functionality
3. Customize the UI colors/styling to your preference
4. Consider adding more features based on your needs
5. Set up iOS signing for deployment

## Notes

- API calls may take 1-3 seconds depending on connection
- The app assumes standard serving sizes unless specified
- Local storage persists until app is uninstalled or manually reset
