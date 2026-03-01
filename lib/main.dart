import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:home_widget/home_widget.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'services/perplexity_service.dart';
import 'services/health_kit_service.dart';
import 'models/food_item.dart';
import 'screens/settings_page.dart';
import 'config/app_colors.dart';
import 'config/app_icons.dart';
import 'config/storage_keys.dart';
import 'utils/input_validation.dart';
import 'widgets/glass_container.dart';

Future<void> main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize HomeWidget for iOS widget data sharing
  HomeWidget.setAppGroupId(StorageKeys.appGroupId);

  runApp(const CarbTrackerApp());
}

ThemeData _lightTheme() {
  return ThemeData(
    primarySwatch: sageSwatch,
    primaryColor: AppColors.sage,
    scaffoldBackgroundColor: AppColors.cream,
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: AppColors.sage,
      secondary: AppColors.honey,
      tertiary: AppColors.terracotta,
      surface: AppColors.warmWhite,
      error: AppColors.terracotta,
      onPrimary: Colors.white,
      onSecondary: AppColors.ink,
      onSurface: AppColors.ink,
      onError: Colors.white,
      onSurfaceVariant: AppColors.muted,
      outlineVariant: AppColors.border,
      outline: AppColors.borderMedium,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.cream,
      foregroundColor: AppColors.ink,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.sage,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.ink),
      bodyMedium: TextStyle(color: AppColors.charcoal),
      bodySmall: TextStyle(color: AppColors.muted),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.border, width: 1.5),
        borderRadius: BorderRadius.circular(999),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.borderMedium, width: 1.5),
        borderRadius: BorderRadius.circular(999),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.sage, width: 2),
        borderRadius: BorderRadius.circular(999),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

ThemeData _darkTheme() {
  return ThemeData(
    primarySwatch: sageSwatch,
    primaryColor: AppColors.sage,
    scaffoldBackgroundColor: AppColors.darkBackground,
    useMaterial3: true,
    colorScheme: ColorScheme.dark(
      primary: AppColors.sage,
      secondary: AppColors.honey,
      tertiary: AppColors.terracotta,
      surface: AppColors.darkSurface,
      error: AppColors.terracotta,
      onPrimary: Colors.white,
      onSecondary: AppColors.lightInk,
      onSurface: AppColors.lightInk,
      onError: Colors.white,
      onSurfaceVariant: AppColors.darkMuted,
      outlineVariant: AppColors.darkBorder,
      outline: AppColors.darkBorderMedium,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkBackground,
      foregroundColor: AppColors.lightInk,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.sage,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.lightInk),
      bodyMedium: TextStyle(color: AppColors.lightCharcoal),
      bodySmall: TextStyle(color: AppColors.darkMuted),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.darkBorder, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.darkBorderMedium, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.sage, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

class CarbTrackerApp extends StatelessWidget {
  const CarbTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CarpeCarb',
      theme: _lightTheme(),
      darkTheme: _darkTheme(),
      themeMode: ThemeMode.system,
      home: const CarbTrackerHome(),
    );
  }
}

class CarbTrackerHome extends StatefulWidget {
  const CarbTrackerHome({super.key});

  @override
  State<CarbTrackerHome> createState() => CarbTrackerHomeState();
}

// Made public for testing
class CarbTrackerHomeState extends State<CarbTrackerHome>
    with WidgetsBindingObserver {
  final TextEditingController _foodController = TextEditingController();
  final FocusNode _foodFocusNode = FocusNode();
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final PerplexityService _perplexityService = PerplexityService();
  final HealthKitService _healthKitService = HealthKitService();

  List<FoodItem> foodItems = [];
  double totalCarbs = 0.0;
  bool isLoading = false;
  bool showingDailyTotal = false;
  double? dailyCarbGoal;
  int resetHour = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSavedData();
    _checkWidgetLaunch();
    if (Platform.isIOS) _healthKitService.requestAuthorization();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _importSiriLoggedItems();
    }
  }

  Future<void> _checkWidgetLaunch() async {
    final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    if (uri != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _foodFocusNode.requestFocus();
      });
    }
  }

  Future<void> _updateWidget() async {
    await HomeWidget.saveWidgetData<double>(StorageKeys.widgetTotalCarbs, totalCarbs);
    await HomeWidget.saveWidgetData<String>(
      StorageKeys.widgetLastFoodName,
      foodItems.isNotEmpty ? foodItems.first.name : '',
    );
    await HomeWidget.saveWidgetData<double>(
      StorageKeys.widgetLastFoodCarbs,
      foodItems.isNotEmpty ? foodItems.first.carbs : 0.0,
    );
    await HomeWidget.saveWidgetData<double>(StorageKeys.widgetDailyCarbGoal, dailyCarbGoal ?? 0.0);
    await HomeWidget.updateWidget(iOSName: StorageKeys.widgetName);
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedGoal = prefs.getDouble(StorageKeys.dailyCarbGoal);
    final savedResetHour = prefs.getInt(StorageKeys.dailyResetHour) ?? 0;
    resetHour = savedResetHour;
    final lastSaveDate = prefs.getString(StorageKeys.lastSaveDate);
    final isNewDay = lastSaveDate != null && lastSaveDate != _todayString();

    if (isNewDay) {
      // New day — reset everything
      await prefs.remove(StorageKeys.foodItems);
      await prefs.remove(StorageKeys.lastSaveDate);
      await prefs.setDouble(StorageKeys.totalCarbs, 0.0);
      await HomeWidget.saveWidgetData<double>(StorageKeys.widgetTotalCarbs, 0.0);
      await HomeWidget.saveWidgetData<String>(StorageKeys.widgetLastFoodName, '');
      await HomeWidget.saveWidgetData<double>(StorageKeys.widgetLastFoodCarbs, 0.0);
      await HomeWidget.updateWidget(iOSName: StorageKeys.widgetName);
      setState(() {
        totalCarbs = 0.0;
        foodItems = [];
        dailyCarbGoal = savedGoal;
      });
      return;
    }

    // Same day — restore food list and total
    final savedTotal = prefs.getDouble(StorageKeys.totalCarbs) ?? 0.0;
    final widgetTotal = await HomeWidget.getWidgetData<double>(StorageKeys.widgetTotalCarbs) ?? 0.0;
    final effectiveTotal = widgetTotal > savedTotal ? widgetTotal : savedTotal;

    final itemsJson = prefs.getString(StorageKeys.foodItems);
    List<FoodItem> loadedItems = [];
    if (itemsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(itemsJson);
        loadedItems = decoded.map((item) => FoodItem.fromJson(item as Map<String, dynamic>)).toList();
      } catch (e) {
        debugPrint('Failed to decode saved food_items: $e');
      }
    }

    setState(() {
      totalCarbs = effectiveTotal;
      foodItems = loadedItems;
      dailyCarbGoal = savedGoal;
    });

    // Pick up any food items logged via Siri while the app was closed
    await _importSiriLoggedItems();
  }

  Future<void> _importSiriLoggedItems() async {
    final siriItemsJson = await HomeWidget.getWidgetData<String>(StorageKeys.widgetSiriLoggedItems);
    if (siriItemsJson == null) return;

    try {
      final List<dynamic> siriItems = jsonDecode(siriItemsJson);
      if (siriItems.isEmpty) return;

      // Build all items first, then insert one at a time to keep
      // AnimatedList's internal count in sync with the data list.
      final newItems = <FoodItem>[];
      for (final item in siriItems) {
        final citations = item['citations'] != null
            ? List<String>.from(item['citations'])
            : <String>[];
        DateTime? loggedAt;
        if (item['loggedAt'] != null) {
          loggedAt = DateTime.tryParse(item['loggedAt'] as String);
        }
        newItems.add(FoodItem(
          name: item['name'] as String,
          carbs: (item['carbs'] as num).toDouble(),
          details: item['details'] as String?,
          citations: citations,
          loggedAt: loggedAt ?? DateTime.now(),
        ));
      }
      for (final foodItem in newItems) {
        setState(() {
          foodItems.insert(0, foodItem);
        });
        _listKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 400));
      }

      // Clear the Siri buffer so we don't re-import on next launch
      await HomeWidget.saveWidgetData<String?>(StorageKeys.widgetSiriLoggedItems, null);
      await _saveData();

      // Sync Siri-logged items to HealthKit
      for (final foodItem in newItems) {
        _healthKitService.writeFoodItem(foodItem);
      }
    } catch (e) {
      debugPrint('Failed to import Siri logged items: $e');
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(StorageKeys.totalCarbs, totalCarbs);
    if (dailyCarbGoal != null) {
      await prefs.setDouble(StorageKeys.dailyCarbGoal, dailyCarbGoal!);
    } else {
      await prefs.remove(StorageKeys.dailyCarbGoal);
    }
    final itemsJson = jsonEncode(foodItems.map((f) => f.toJson()).toList());
    await prefs.setString(StorageKeys.foodItems, itemsJson);
    await prefs.setString(StorageKeys.lastSaveDate, _todayString());
  }

  String _todayString() {
    var now = DateTime.now();
    // If before the reset hour, treat it as the previous day
    if (resetHour > 0 && now.hour < resetHour) {
      now = now.subtract(const Duration(days: 1));
    }
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String? _validateFoodInput(String input) {
    // Use hardened validation from InputValidation utility
    // Protects against: control chars, prompt injection, SQL syntax, etc.
    return InputValidation.validateFoodInput(input);
  }

  Future<void> _addFood() async {
    final foodText = _foodController.text.trim();

    // Validate input
    final validationError = _validateFoodInput(foodText);
    if (validationError != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(validationError),
            backgroundColor: AppColors.honey.withValues(alpha: 0.9),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // Dismiss keyboard so the user can see results
    _foodFocusNode.unfocus();

    setState(() {
      isLoading = true;
    });

    try {
      final items = await _perplexityService.getMultipleCarbCounts(foodText);

      setState(() {
        for (final item in items) {
          totalCarbs += item.carbs;
        }
        isLoading = false;
        showingDailyTotal = false;
        _foodController.clear();
      });

      // Insert one at a time so AnimatedList and foodItems stay in sync
      // and every item gets its own entrance animation
      for (final item in items.reversed) {
        foodItems.insert(0, item);
        _listKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 400));
      }

      HapticFeedback.lightImpact();

      await _saveData();
      await _updateWidget();

      // Write each item to HealthKit (fire-and-forget)
      for (final item in items) {
        _healthKitService.writeFoodItem(item);
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      if (mounted) {
        // Extract user-friendly error message
        String errorMessage = e.toString();
        if (errorMessage.contains('Exception:')) {
          errorMessage = errorMessage.replaceAll('Exception:', '').trim();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.terracotta.withValues(alpha: 0.9),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  void _resetTotal() {
    // Capture items before clearing so animation builders have valid references.
    final snapshot = List<FoodItem>.from(foodItems);
    setState(() {
      foodItems.clear();
      totalCarbs = 0.0;
    });
    for (int i = snapshot.length - 1; i >= 0; i--) {
      final item = snapshot[i];
      _listKey.currentState?.removeItem(
        i,
        (context, animation) => _buildAnimatedItem(item, animation),
        duration: const Duration(milliseconds: 300),
      );
    }
    // Delete all reset items from HealthKit
    for (final item in snapshot) {
      _healthKitService.deleteFoodItem(item);
    }
    _saveData();
    _updateWidget();
  }

  void removeItem(int index) {
    final removedItem = foodItems[index];
    setState(() {
      totalCarbs -= removedItem.carbs;
      foodItems.removeAt(index);
    });
    _listKey.currentState?.removeItem(
      index,
      (context, animation) => _buildAnimatedItem(removedItem, animation),
      duration: const Duration(milliseconds: 300),
    );
    _saveData();
    _updateWidget();
    _healthKitService.deleteFoodItem(removedItem);

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${removedItem.name} removed'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.white,
            onPressed: () {
              setState(() {
                foodItems.insert(index.clamp(0, foodItems.length), removedItem);
                totalCarbs += removedItem.carbs;
              });
              _listKey.currentState?.insertItem(
                index.clamp(0, foodItems.length - 1),
                duration: const Duration(milliseconds: 400),
              );
              _saveData();
              _updateWidget();
              _healthKitService.writeFoodItem(removedItem);
            },
          ),
        ),
      );
    }
  }

  Widget _buildAnimatedItem(FoodItem item, Animation<double> animation) {
    return SizeTransition(
      sizeFactor: animation,
      child: FadeTransition(
        opacity: animation,
        child: _buildFoodTile(item),
      ),
    );
  }

  void _showFoodDetails(FoodItem item) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
        title: Text(item.name),
        content: SingleChildScrollView(
          child: RichText(
            text: _buildDetailsTextSpan(
              item.details ?? 'No details available for this item.',
              item.citations,
              baseColor: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Builds a TextSpan that renders [N] citation references as tappable links.
  TextSpan _buildDetailsTextSpan(String text, List<String> citations, {required Color baseColor}) {
    final spans = <InlineSpan>[];
    final citationPattern = RegExp(r'\[(\d+)\]');
    var lastEnd = 0;

    for (final match in citationPattern.allMatches(text)) {
      // Add plain text before this citation
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
        ));
      }

      final refNumber = int.tryParse(match.group(1)!) ?? 0;
      final citationIndex = refNumber - 1;
      final hasUrl = citationIndex >= 0 && citationIndex < citations.length;

      spans.add(TextSpan(
        text: '[${match.group(1)}]',
        style: TextStyle(
          color: hasUrl ? AppColors.sage : AppColors.muted,
          fontWeight: hasUrl ? FontWeight.w600 : FontWeight.normal,
          decoration: hasUrl ? TextDecoration.underline : TextDecoration.none,
        ),
        recognizer: hasUrl
            ? (TapGestureRecognizer()
              ..onTap = () {
                launchUrl(Uri.parse(citations[citationIndex]),
                    mode: LaunchMode.externalApplication);
              })
            : null,
      ));

      lastEnd = match.end;
    }

    // Add remaining text after last citation
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return TextSpan(
      style: TextStyle(
        fontSize: 15,
        color: baseColor,
        height: 1.5,
      ),
      children: spans,
    );
  }

  Future<void> _openSettings() async {
    final result = await Navigator.push<SettingsResult>(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsPage(
          dailyCarbGoal: dailyCarbGoal,
          resetHour: resetHour,
          onAddFood: _addSavedFood,
          healthKitService: _healthKitService,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        dailyCarbGoal = result.dailyCarbGoal;
        resetHour = result.resetHour;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(StorageKeys.dailyResetHour, resetHour);
      _saveData();
      _updateWidget();
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Widget _buildFoodTile(FoodItem item) {
    return GestureDetector(
      onLongPress: () => _showFoodDetails(item),
      child: Container(
      padding: const EdgeInsets.symmetric(
        vertical: 16,
        horizontal: 0,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatTime(item.loggedAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${item.carbs.toStringAsFixed(1)}g',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    ),
    );
  }

  void _addSavedFood(FoodItem item) {
    setState(() {
      foodItems.insert(0, item);
      totalCarbs += item.carbs;
      showingDailyTotal = false;
    });
    _listKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 400));
    _saveData();
    _updateWidget();
    _healthKitService.writeFoodItem(item);
  }

  Future<void> _saveToSavedFoods(FoodItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final savedJson = prefs.getString(StorageKeys.savedFoods);

    List<FoodItem> savedFoods = [];
    if (savedJson != null) {
      final List<dynamic> decoded = jsonDecode(savedJson);
      savedFoods = decoded.map((item) => FoodItem.fromJson(item)).toList();
    }

    // Check if item already exists
    final exists = savedFoods.any((food) =>
      food.name.toLowerCase() == item.name.toLowerCase());

    if (!exists) {
      savedFoods.add(item);
      final encoded = jsonEncode(savedFoods.map((f) => f.toJson()).toList());
      await prefs.setString(StorageKeys.savedFoods, encoded);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.name} saved to Food list'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.name} is already saved'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.7),
            ),
          ),
        ),
        title: const Text(
          'CarpeCarb',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: AppIcons.settingsIcon(size: 24),
            tooltip: 'Settings',
            onPressed: _openSettings,
          ),
        ],
      ),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            left: 24.0,
            right: 24.0,
            top: 24.0,
            bottom: 24.0 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              // Carb Display — tap to toggle, long press to set goal
              GestureDetector(
                onTap: foodItems.isNotEmpty
                    ? () {
                        setState(() {
                          showingDailyTotal = !showingDailyTotal;
                        });
                        HapticFeedback.lightImpact();
                      }
                    : null,
                onLongPress: () {
                  HapticFeedback.mediumImpact();
                  _openSettings();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 32.0),
                  child: Column(
                    children: [
                      Text(
                        showingDailyTotal || foodItems.isEmpty
                            ? 'Total Carbs'
                            : foodItems.first.name,
                        style: TextStyle(
                          fontSize: 20,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (dailyCarbGoal != null)
                        SizedBox(
                          width: 160,
                          height: 160,
                          child: CustomPaint(
                            painter: _GoalRingPainter(
                              progress: totalCarbs / dailyCarbGoal!,
                              trackColor: Theme.of(context).colorScheme.outlineVariant,
                              fillColor: totalCarbs > dailyCarbGoal!
                                  ? AppColors.terracotta
                                  : AppColors.sage,
                            ),
                            child: Center(
                              child: Text(
                                showingDailyTotal || foodItems.isEmpty
                                    ? '${totalCarbs.toStringAsFixed(1)}g'
                                    : '${foodItems.first.carbs.toStringAsFixed(1)}g',
                                style: TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.w300,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        Text(
                          showingDailyTotal || foodItems.isEmpty
                              ? '${totalCarbs.toStringAsFixed(1)}g'
                              : '${foodItems.first.carbs.toStringAsFixed(1)}g',
                          style: TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.w300,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      const SizedBox(height: 8),
                      if (dailyCarbGoal != null)
                        Text(
                          totalCarbs >= dailyCarbGoal!
                              ? 'over by ${(totalCarbs - dailyCarbGoal!).toStringAsFixed(1)}g'
                              : '${(dailyCarbGoal! - totalCarbs).toStringAsFixed(1)}g remaining',
                          style: TextStyle(
                            fontSize: 20,
                            color: totalCarbs > dailyCarbGoal!
                                ? AppColors.terracotta
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Input Section — glass container
              GlassContainer(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _foodController,
                      focusNode: _foodFocusNode,
                      decoration: InputDecoration(
                        hintText: 'Enter food item...',
                        hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                      onSubmitted: (_) => _addFood(),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _addFood,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: const StadiumBorder(),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Add Food',
                                style: TextStyle(
                                  fontSize: 16,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Food List Header
              if (foodItems.isNotEmpty)
                GlassContainer(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  blur: 8,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TODAY',
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 1.5,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton(
                        onPressed: _resetTotal,
                        child: const Text(
                          'Reset',
                          style: TextStyle(color: AppColors.terracotta),
                        ),
                      ),
                    ],
                  ),
                ),

              // Food List
              foodItems.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32.0),
                        child: Text(
                          'No foods added yet',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  : AnimatedList(
                      key: _listKey,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      initialItemCount: foodItems.length,
                      itemBuilder: (context, index, animation) {
                          final item = foodItems[index];
                          return SizeTransition(
                            sizeFactor: animation,
                            child: FadeTransition(
                              opacity: animation,
                              child: Dismissible(
                                key: Key('${item.name}_$index'),
                                direction: DismissDirection.horizontal,
                                confirmDismiss: (direction) async {
                                  if (direction == DismissDirection.startToEnd) {
                                    HapticFeedback.lightImpact();
                                    await _saveToSavedFoods(item);
                                    return false;
                                  } else {
                                    HapticFeedback.mediumImpact();
                                    return true;
                                  }
                                },
                                onDismissed: (_) => removeItem(index),
                                background: Container(
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.only(left: 16),
                                  color: AppColors.sage,
                                  child: AppIcons.bookmarkIcon(
                                    size: 28,
                                    color: Colors.white,
                                  ),
                                ),
                                secondaryBackground: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 16),
                                  color: AppColors.terracotta,
                                  child: AppIcons.deleteIcon(
                                    size: 28,
                                    color: Colors.white,
                                  ),
                                ),
                                child: _buildFoodTile(item),
                              ),
                            ),
                          );
                        },
                      ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _foodController.dispose();
    _foodFocusNode.dispose();
    super.dispose();
  }
}

class _GoalRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color fillColor;

  _GoalRingPainter({
    required this.progress,
    required this.trackColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - 8) / 2;
    const strokeWidth = 6.0;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Fill arc
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(_GoalRingPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      fillColor != oldDelegate.fillColor;
}
