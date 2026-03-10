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
import 'services/premium_service.dart';
import 'services/cloud_sync_service.dart';
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
  final TextEditingController _carbController = TextEditingController();
  final FocusNode _foodFocusNode = FocusNode();
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final PerplexityFirebaseService _perplexityService =
      PerplexityFirebaseService();
  final HealthKitService _healthKitService = HealthKitService();
  final PremiumService _premiumService = PremiumService();
  final CloudSyncService _cloudSyncService = CloudSyncService();
  bool _isManualEntryMode = false;

  List<FoodItem> foodItems = [];
  double get totalCarbs => foodItems.fold(0.0, (sum, item) => sum + item.carbs);
  bool isLoading = false;
  bool showingDailyTotal = false;
  double? dailyCarbGoal;
  double? proteinGoal;
  double? fatGoal;
  double? fiberGoal;
  double? caloriesGoal;
  int resetHour = 0;
  int _currentPage = 0; // 0 = home, 1 = settings

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _premiumService.init().then((_) {
      if (mounted) setState(() {});
      if (Platform.isIOS && _premiumService.isHealthSyncEnabled) {
        _healthKitService.requestAuthorization();
      }
      _initCloudSync();
    });
    _loadSavedData();
    _checkWidgetLaunch();
    // Auto-open keyboard so users can start typing immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _foodFocusNode.requestFocus();
    });
  }

  Future<void> _initCloudSync() async {
    if (!_premiumService.isCloudSyncEnabled) return;
    await _cloudSyncService.startListening(_onRemoteCloudChange);
    final pulled = await _cloudSyncService.pullFromCloud();
    if (pulled != null && mounted) {
      final prefs = await SharedPreferences.getInstance();
      final cloudTs = pulled[StorageKeys.cloudLastModified] as String? ?? '';
      final localTs = prefs.getString(StorageKeys.cloudLastModified) ?? '';
      if (cloudTs.isNotEmpty && cloudTs.compareTo(localTs) > 0) {
        await _applyCloudData(pulled);
      }
    }
  }

  void _onRemoteCloudChange(Map<String, dynamic>? data) {
    if (data != null && mounted) _applyCloudData(data);
  }

  /// Builds the payload of all syncable data for a cloud push.
  Map<String, dynamic> _buildSyncPayload(SharedPreferences prefs) {
    return {
      StorageKeys.foodItems:
          jsonEncode(foodItems.map((f) => f.toJson()).toList()),
      StorageKeys.savedFoods: prefs.getString(StorageKeys.savedFoods) ?? '',
      StorageKeys.dailyCarbGoal: dailyCarbGoal ?? 0.0,
      StorageKeys.dailyResetHour: resetHour,
      StorageKeys.lastSaveDate: _todayString(),
    };
  }

  /// Applies a cloud data payload to SharedPreferences then reloads state.
  /// Only applies food items when [last_save_date] matches today, so that
  /// stale food from another device doesn't overwrite the current day's list.
  Future<void> _applyCloudData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();

    final goal = data[StorageKeys.dailyCarbGoal];
    if (goal is num && goal.toDouble() > 0) {
      await prefs.setDouble(StorageKeys.dailyCarbGoal, goal.toDouble());
    } else if (goal is num) {
      await prefs.remove(StorageKeys.dailyCarbGoal);
    }

    final resetHourVal = data[StorageKeys.dailyResetHour];
    if (resetHourVal is num) {
      await prefs.setInt(StorageKeys.dailyResetHour, resetHourVal.toInt());
    }

    if (data[StorageKeys.savedFoods] is String) {
      await prefs.setString(
          StorageKeys.savedFoods, data[StorageKeys.savedFoods] as String);
    }

    // Only import food items if the cloud data is from today
    final cloudSaveDate = data[StorageKeys.lastSaveDate] as String?;
    if (cloudSaveDate == _todayString() &&
        data[StorageKeys.foodItems] is String) {
      await prefs.setString(
          StorageKeys.foodItems, data[StorageKeys.foodItems] as String);
      await prefs.setString(StorageKeys.lastSaveDate, cloudSaveDate!);
    }

    if (data[StorageKeys.cloudLastModified] is String) {
      await prefs.setString(StorageKeys.cloudLastModified,
          data[StorageKeys.cloudLastModified] as String);
    }

    if (mounted) _loadSavedData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _importSiriLoggedItems();
      if (_premiumService.isCloudSyncEnabled) {
        _cloudSyncService.pullFromCloud().then((pulled) {
          if (pulled != null && mounted) _applyCloudData(pulled);
        });
      } else {
        _cloudSyncService.stopListening();
      }
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
    await HomeWidget.saveWidgetData<double>(
        StorageKeys.widgetTotalCarbs, totalCarbs);
    await HomeWidget.saveWidgetData<String>(
      StorageKeys.widgetLastFoodName,
      foodItems.isNotEmpty ? foodItems.first.name : '',
    );
    await HomeWidget.saveWidgetData<double>(
      StorageKeys.widgetLastFoodCarbs,
      foodItems.isNotEmpty ? foodItems.first.carbs : 0.0,
    );
    await HomeWidget.saveWidgetData<double>(
        StorageKeys.widgetDailyCarbGoal, dailyCarbGoal ?? 0.0);
    await HomeWidget.updateWidget(iOSName: StorageKeys.widgetName);
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedGoal = prefs.getDouble(StorageKeys.dailyCarbGoal);
    final savedResetHour = prefs.getInt(StorageKeys.dailyResetHour) ?? 0;
    resetHour = savedResetHour;
    proteinGoal = prefs.getDouble(StorageKeys.proteinGoal);
    fatGoal = prefs.getDouble(StorageKeys.fatGoal);
    fiberGoal = prefs.getDouble(StorageKeys.fiberGoal);
    caloriesGoal = prefs.getDouble(StorageKeys.caloriesGoal);
    final lastSaveDate = prefs.getString(StorageKeys.lastSaveDate);
    final isNewDay = lastSaveDate != null && lastSaveDate != _todayString();

    if (isNewDay) {
      // New day — reset everything
      await prefs.remove(StorageKeys.foodItems);
      await prefs.remove(StorageKeys.lastSaveDate);
      await prefs.setDouble(StorageKeys.totalCarbs, 0.0);
      await HomeWidget.saveWidgetData<double>(
          StorageKeys.widgetTotalCarbs, 0.0);
      await HomeWidget.saveWidgetData<String>(
          StorageKeys.widgetLastFoodName, '');
      await HomeWidget.saveWidgetData<double>(
          StorageKeys.widgetLastFoodCarbs, 0.0);
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
        loadedItems = decoded
            .map((item) => FoodItem.fromJson(item as Map<String, dynamic>))
            .toList();
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
    final siriItemsJson = await HomeWidget.getWidgetData<String>(
        StorageKeys.widgetSiriLoggedItems);
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
        _listKey.currentState
            ?.insertItem(0, duration: const Duration(milliseconds: 400));
      }

      // Clear the Siri buffer so we don't re-import on next launch
      await HomeWidget.saveWidgetData<String?>(
          StorageKeys.widgetSiriLoggedItems, null);
      await _saveData();

      // Sync Siri-logged items to HealthKit
      if (_premiumService.isHealthSyncEnabled) {
        for (final foodItem in newItems) {
          _healthKitService.writeFoodItem(foodItem);
        }
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

    // Push to iCloud if cloud sync is enabled
    if (_premiumService.isCloudSyncEnabled) {
      _cloudSyncService.pushToCloud(_buildSyncPayload(prefs));
    }
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
        _listKey.currentState
            ?.insertItem(0, duration: const Duration(milliseconds: 400));
      }

      HapticFeedback.lightImpact();

      await _saveData();
      await _updateWidget();

      // Write each item to HealthKit (fire-and-forget)
      if (_premiumService.isHealthSyncEnabled) {
        for (final item in items) {
          _healthKitService.writeFoodItem(item);
        }
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

  void _addManualFood() {
    if (!_premiumService.isManualEntryEnabled) return;
    final name = _foodController.text.trim();
    final carbText = _carbController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a food name'),
          backgroundColor: AppColors.honey.withValues(alpha: 0.9),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final carbs = double.tryParse(carbText);
    if (carbs == null || carbs < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a valid carb amount'),
          backgroundColor: AppColors.honey.withValues(alpha: 0.9),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    _foodFocusNode.unfocus();

    final item = FoodItem(name: name, carbs: carbs, isManualEntry: true);
    setState(() {
      foodItems.insert(0, item);
      showingDailyTotal = false;
      _foodController.clear();
      _carbController.clear();
    });
    _listKey.currentState
        ?.insertItem(0, duration: const Duration(milliseconds: 400));
    HapticFeedback.lightImpact();
    _saveData();
    _updateWidget();
    if (_premiumService.isHealthSyncEnabled) {
      _healthKitService.writeFoodItem(item);
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
    if (_premiumService.isHealthSyncEnabled) {
      for (final item in snapshot) {
        _healthKitService.deleteFoodItem(item);
      }
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
    if (_premiumService.isHealthSyncEnabled) {
      _healthKitService.deleteFoodItem(removedItem);
    }

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
              if (_premiumService.isHealthSyncEnabled) {
                _healthKitService.writeFoodItem(removedItem);
              }
            },
          ),
        ),
      );
    }
  }

  Widget _buildModeChip(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.sage : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? AppColors.sage
                : Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isActive
                ? Colors.white
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
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
    final showMacros = _premiumService.isMacrosEnabled && item.hasMacros;
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (context) => AlertDialog(
        backgroundColor:
            Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
        title: Text(item.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showMacros) ...[
                _buildMacroGrid(item, context),
                const SizedBox(height: 16),
              ],
              RichText(
                text: _buildDetailsTextSpan(
                  item.details ?? 'No details available for this item.',
                  item.citations,
                  baseColor: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
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

  Widget _buildMacroGrid(FoodItem item, BuildContext context) {
    final tiles = <_MacroTile>[
      _MacroTile('Carbs', item.carbs, 'g'),
      if (item.protein != null) _MacroTile('Protein', item.protein!, 'g'),
      if (item.fat != null) _MacroTile('Fat', item.fat!, 'g'),
      if (item.fiber != null) _MacroTile('Fiber', item.fiber!, 'g'),
      if (item.calories != null) _MacroTile('Calories', item.calories!, 'kcal'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tiles.map((t) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.sage.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text(
                '${t.value.toStringAsFixed(t.unit == 'kcal' ? 0 : 1)}${t.unit}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                t.label,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Builds a TextSpan that renders [N] citation references as tappable links.
  TextSpan _buildDetailsTextSpan(String text, List<String> citations,
      {required Color baseColor}) {
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
      proteinGoal = result.proteinGoal;
      fatGoal = result.fatGoal;
      fiberGoal = result.fiberGoal;
      caloriesGoal = result.caloriesGoal;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(StorageKeys.dailyResetHour, resetHour);
    _saveData();
    _updateWidget();
  }

  /// Called by SettingsPage when favorites are added/removed, so we can push
  /// the full sync payload (which includes saved_foods) to iCloud.
  void _onFavoritesChanged() async {
    if (!_premiumService.isCloudSyncEnabled) return;
    final prefs = await SharedPreferences.getInstance();
    _cloudSyncService.pushToCloud(_buildSyncPayload(prefs));
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

  Widget _buildMacroStrip(bool isDark) {
    final protein = foodItems.fold(0.0, (s, i) => s + (i.protein ?? 0));
    final fat = foodItems.fold(0.0, (s, i) => s + (i.fat ?? 0));
    final fiber = foodItems.fold(0.0, (s, i) => s + (i.fiber ?? 0));
    final calories = foodItems.fold(0.0, (s, i) => s + (i.calories ?? 0));

    Widget col(String label, double value, double? goal, {bool isCalories = false}) {
      final unit = isCalories ? '' : 'g';
      final valueStr = isCalories
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(0);
      final goalStr = goal != null
          ? (isCalories ? ' / ${goal.toStringAsFixed(0)}' : ' / ${goal.toStringAsFixed(0)}g')
          : null;

      return Expanded(
        child: Column(
          children: [
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$valueStr$unit',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  if (goalStr != null)
                    TextSpan(
                      text: goalStr,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    Widget divider() => Container(
          width: 1,
          height: 32,
          color: Theme.of(context)
              .colorScheme
              .onSurfaceVariant
              .withValues(alpha: 0.15),
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          col('Protein', protein, proteinGoal),
          divider(),
          col('Fat', fat, fatGoal),
          divider(),
          col('Fiber', fiber, fiberGoal),
          divider(),
          col('Calories', calories, caloriesGoal, isCalories: true),
        ],
      ),
    );
  }

  void _addSavedFood(FoodItem item) {
    setState(() {
      foodItems.insert(0, item);
      showingDailyTotal = false;
    });
    _listKey.currentState
        ?.insertItem(0, duration: const Duration(milliseconds: 400));
    _saveData();
    _updateWidget();
    if (_premiumService.isHealthSyncEnabled) {
      _healthKitService.writeFoodItem(item);
    }
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
    final exists = savedFoods
        .any((food) => food.name.toLowerCase() == item.name.toLowerCase());

    if (!exists) {
      savedFoods.add(item);
      final encoded = jsonEncode(savedFoods.map((f) => f.toJson()).toList());
      await prefs.setString(StorageKeys.savedFoods, encoded);

      if (_premiumService.isCloudSyncEnabled) {
        _cloudSyncService.pushToCloud(_buildSyncPayload(prefs));
      }

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
                    onFavoritesChanged: _onFavoritesChanged,
                    premiumService: _premiumService,
                    cloudSyncService: _cloudSyncService,
                    onCloudSyncEnabled: () {
                      _initCloudSync();
                      _saveData();
                    },
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
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // "Today's Total" badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
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

            // Macro totals strip (premium, only when data exists)
            if (_premiumService.isMacrosEnabled &&
                foodItems.any((i) => i.hasMacros)) ...[
              _buildMacroStrip(isDark),
              const SizedBox(height: 16),
            ],

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
                  // Mode toggle (AI Lookup / Manual)
                  if (_premiumService.isManualEntryEnabled)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          _buildModeChip('AI Lookup', !_isManualEntryMode, () {
                            setState(() => _isManualEntryMode = false);
                          }),
                          const SizedBox(width: 8),
                          _buildModeChip('Manual', _isManualEntryMode, () {
                            setState(() => _isManualEntryMode = true);
                          }),
                        ],
                      ),
                    ),
                  TextField(
                    controller: _foodController,
                    focusNode: _foodFocusNode,
                    decoration: InputDecoration(
                      hintText: _isManualEntryMode
                          ? 'Food name...'
                          : 'Enter food item...',
                      hintStyle: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                    onSubmitted: (_) =>
                        (_isManualEntryMode && _premiumService.isManualEntryEnabled) ? _addManualFood() : _addFood(),
                  ),
                  if (_isManualEntryMode && _premiumService.isManualEntryEnabled) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _carbController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        hintText: 'Carbs (g)',
                        suffixText: 'g',
                        hintStyle: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withValues(alpha: 0.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                      onSubmitted: (_) => _addManualFood(),
                    ),
                  ],
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
                        onPressed: isLoading
                            ? null
                            : ((_isManualEntryMode && _premiumService.isManualEntryEnabled) ? _addManualFood : _addFood),
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
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.add,
                                      size: 20, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isManualEntryMode ? 'Add' : 'Add Food',
                                    style: const TextStyle(
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
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Reset',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
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
    _cloudSyncService.stopListening();
    _foodController.dispose();
    _carbController.dispose();
    _foodFocusNode.dispose();
    super.dispose();
  }
}

class _MacroTile {
  final String label;
  final double value;
  final String unit;
  const _MacroTile(this.label, this.value, this.unit);
}
