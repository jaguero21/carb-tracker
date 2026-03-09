import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:home_widget/home_widget.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'dart:convert';
import 'dart:io';
import 'services/perplexity_firebase_service.dart';
import 'services/health_kit_service.dart';
import 'models/food_item.dart';
import 'screens/settings_page.dart';
import 'config/app_colors.dart';
import 'config/app_theme.dart';
import 'config/storage_keys.dart';
import 'utils/date_format.dart';
import 'utils/input_validation.dart';
import 'widgets/food_item_card.dart';

Future<void> main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize HomeWidget for iOS widget data sharing
  HomeWidget.setAppGroupId(StorageKeys.appGroupId);

  runApp(const CarbTrackerApp());
}

class CarbTrackerApp extends StatelessWidget {
  const CarbTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CarpeCarb',
      theme: lightTheme(),
      darkTheme: darkTheme(),
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
  final PerplexityFirebaseService _perplexityService = PerplexityFirebaseService();
  final HealthKitService _healthKitService = HealthKitService();

  List<FoodItem> foodItems = [];
  double get totalCarbs => foodItems.fold(0.0, (sum, item) => sum + item.carbs);
  bool isLoading = false;
  bool showingDailyTotal = false;
  double? dailyCarbGoal;
  int resetHour = 0;
  int _currentPage = 0; // 0 = home, 1 = settings

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSavedData();
    _checkWidgetLaunch();
    if (Platform.isIOS) _healthKitService.requestAuthorization();
    // Auto-open keyboard so users can start typing immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _foodFocusNode.requestFocus();
    });
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
        foodItems = [];
        dailyCarbGoal = savedGoal;
      });
      return;
    }

    // Same day — restore food list
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

  void _switchToPage(int page) {
    setState(() => _currentPage = page);
  }

  void _applySettingsResult(SettingsResult result) async {
    setState(() {
      dailyCarbGoal = result.dailyCarbGoal;
      resetHour = result.resetHour;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(StorageKeys.dailyResetHour, resetHour);
    _saveData();
    _updateWidget();
  }

  Widget _buildFoodTile(FoodItem item) {
    return FoodItemCard(
      name: item.name,
      subtitle: formatTime(item.loggedAt),
      carbs: item.carbs,
      category: item.category,
      onLongPress: () => _showFoodDetails(item),
    );
  }

  void _addSavedFood(FoodItem item) {
    setState(() {
      foodItems.insert(0, item);
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

  Widget _buildNavIcon({
    required int page,
    required Widget icon,
    required String tooltip,
  }) {
    final isActive = _currentPage == page;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => _switchToPage(page),
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? (isDark ? AppColors.lightInk : AppColors.charcoal)
                : Colors.transparent,
          ),
          child: Center(child: icon),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            // Shared AppBar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 16, 0),
              child: Row(
                children: [
                  Text(
                    'CarpeCarb',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  _buildNavIcon(
                    page: 0,
                    icon: Icon(
                      Icons.restaurant,
                      size: 20,
                      color: _currentPage == 0
                          ? (isDark ? AppColors.darkBackground : Colors.white)
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    tooltip: 'Home',
                  ),
                  const SizedBox(width: 8),
                  _buildNavIcon(
                    page: 1,
                    icon: Icon(
                      Icons.settings,
                      size: 20,
                      color: _currentPage == 1
                          ? (isDark ? AppColors.darkBackground : Colors.white)
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    tooltip: 'Settings',
                  ),
                ],
              ),
            ),

            // Page content
            Expanded(
              child: IndexedStack(
                index: _currentPage,
                children: [
                  _buildHomePage(isDark),
                  SettingsPage(
                    dailyCarbGoal: dailyCarbGoal,
                    resetHour: resetHour,
                    onAddFood: _addSavedFood,
                    healthKitService: _healthKitService,
                    onSettingsChanged: _applySettingsResult,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomePage(bool isDark) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        left: 24.0,
        right: 24.0,
        top: 16.0,
        bottom: 24.0 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Total Carbs Card
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
                _switchToPage(1);
              },
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // "Today's Total" badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.sage.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        showingDailyTotal || foodItems.isEmpty
                            ? "Today's Total"
                            : foodItems.first.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.sage,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Large carb number
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: showingDailyTotal || foodItems.isEmpty
                                ? totalCarbs.toStringAsFixed(1)
                                : foodItems.first.carbs.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 64,
                              fontWeight: FontWeight.w300,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          TextSpan(
                            text: 'g',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w300,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (dailyCarbGoal != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'of ${dailyCarbGoal!.toStringAsFixed(0)}g daily goal',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Linear progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (totalCarbs / dailyCarbGoal!).clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: isDark
                              ? AppColors.darkBorderMedium
                              : const Color(0xFFE5E7EB),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            totalCarbs > dailyCarbGoal!
                                ? AppColors.terracotta
                                : AppColors.sage,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Input Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _foodController,
                    focusNode: _foodFocusNode,
                    decoration: InputDecoration(
                      hintText: 'Enter food item...',
                      hintStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                    onSubmitted: (_) => _addFood(),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.sage.withValues(alpha: 0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _addFood,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
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
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add, size: 20, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text(
                                    'Add Food',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Food List Header
            if (foodItems.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    // Green vertical bar
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppColors.sage,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'TODAY',
                      style: TextStyle(
                        fontSize: 14,
                        letterSpacing: 1.5,
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _resetTotal,
                      child: Row(
                        children: [
                          Icon(
                            Icons.refresh,
                            size: 16,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Reset',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
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
                              decoration: BoxDecoration(
                                color: AppColors.sage,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.bookmark,
                                size: 28,
                                color: Colors.white,
                              ),
                            ),
                            secondaryBackground: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 16),
                              decoration: BoxDecoration(
                                color: AppColors.terracotta,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.delete,
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

