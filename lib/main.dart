import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:home_widget/home_widget.dart';
import 'dart:convert';
import 'services/perplexity_service.dart';
import 'models/food_item.dart';
import 'screens/saved_food_list_page.dart';
import 'config/app_colors.dart';
import 'config/app_icons.dart';
import 'utils/input_validation.dart';

Future<void> main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize HomeWidget for iOS widget data sharing
  HomeWidget.setAppGroupId('group.com.jamesaguero.mycarbtracker');

  runApp(const CarbTrackerApp());
}

class CarbTrackerApp extends StatelessWidget {
  const CarbTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CarpeCarb',
      theme: ThemeData(
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
            borderRadius: BorderRadius.circular(8),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: AppColors.borderMedium, width: 1.5),
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: AppColors.sage, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
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
class CarbTrackerHomeState extends State<CarbTrackerHome> with WidgetsBindingObserver {
  final TextEditingController _foodController = TextEditingController();
  final FocusNode _foodFocusNode = FocusNode();
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final PerplexityService _perplexityService = PerplexityService();

  List<FoodItem> foodItems = [];
  double totalCarbs = 0.0;
  bool isLoading = false;
  bool showingDailyTotal = false;
  double? dailyCarbGoal;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSavedData();
    _checkWidgetLaunch();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _foodFocusNode.requestFocus();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _importSiriLoggedItems();
      _syncTotalFromWidget();
    }
  }

  Future<void> _syncTotalFromWidget() async {
    final widgetTotal = await HomeWidget.getWidgetData<double>('totalCarbs') ?? 0.0;
    if (widgetTotal > totalCarbs) {
      setState(() {
        totalCarbs = widgetTotal;
      });
      await _saveData();
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
    await HomeWidget.saveWidgetData<double>('totalCarbs', totalCarbs);
    await HomeWidget.saveWidgetData<String>(
      'lastFoodName',
      foodItems.isNotEmpty ? foodItems.first.name : '',
    );
    await HomeWidget.saveWidgetData<double>(
      'lastFoodCarbs',
      foodItems.isNotEmpty ? foodItems.first.carbs : 0.0,
    );
    if (dailyCarbGoal != null) {
      await HomeWidget.saveWidgetData<double>('dailyCarbGoal', dailyCarbGoal!);
    }
    await HomeWidget.updateWidget(iOSName: 'CarbWiseWidget');
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTotal = prefs.getDouble('total_carbs') ?? 0.0;
    final savedGoal = prefs.getDouble('daily_carb_goal');

    // Also check the shared UserDefaults total (Siri may have updated it)
    final widgetTotal = await HomeWidget.getWidgetData<double>('totalCarbs') ?? 0.0;
    final effectiveTotal = widgetTotal > savedTotal ? widgetTotal : savedTotal;

    setState(() {
      totalCarbs = effectiveTotal;
      dailyCarbGoal = savedGoal;
    });
    // Pick up any food items logged via Siri while the app was closed
    await _importSiriLoggedItems();
  }

  Future<void> _importSiriLoggedItems() async {
    final siriItemsJson = await HomeWidget.getWidgetData<String>('siriLoggedItems');
    if (siriItemsJson == null || siriItemsJson.isEmpty) return;

    try {
      final List<dynamic> siriItems = jsonDecode(siriItemsJson);
      if (siriItems.isEmpty) return;

      // Clear the buffer first to prevent re-import if something fails below
      await HomeWidget.saveWidgetData<String?>('siriLoggedItems', null);

      final newItems = <FoodItem>[];
      for (final item in siriItems) {
        newItems.add(FoodItem(
          name: item['name'] as String,
          carbs: (item['carbs'] as num).toDouble(),
        ));
      }

      final wasEmpty = foodItems.isEmpty;
      setState(() {
        for (final item in newItems) {
          foodItems.insert(0, item);
        }
      });

      // If the list was empty, AnimatedList is freshly created with
      // initialItemCount already set — no need to call insertItem.
      // Only call insertItem when the list already existed.
      if (!wasEmpty) {
        for (var i = 0; i < newItems.length; i++) {
          _listKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 400));
        }
      }

      await _saveData();
    } catch (_) {
      // Ignore malformed Siri data
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('total_carbs', totalCarbs);
  }

  Future<void> _saveGoal(double? goal) async {
    final prefs = await SharedPreferences.getInstance();
    if (goal != null) {
      await prefs.setDouble('daily_carb_goal', goal);
      await HomeWidget.saveWidgetData<double>('dailyCarbGoal', goal);
    } else {
      await prefs.remove('daily_carb_goal');
      await HomeWidget.saveWidgetData<double?>('dailyCarbGoal', null);
    }
    await HomeWidget.updateWidget(iOSName: 'CarbWiseWidget');
  }

  void _showGoalDialog() {
    final controller = TextEditingController(
      text: dailyCarbGoal != null ? dailyCarbGoal!.toStringAsFixed(0) : '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Daily Carb Goal'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. 50',
            suffixText: 'g',
          ),
        ),
        actions: [
          if (dailyCarbGoal != null)
            TextButton(
              onPressed: () {
                setState(() {
                  dailyCarbGoal = null;
                });
                _saveGoal(null);
                Navigator.pop(context);
              },
              child: const Text(
                'Remove',
                style: TextStyle(color: AppColors.terracotta),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              if (value != null && value > 0) {
                setState(() {
                  dailyCarbGoal = value;
                });
                _saveGoal(value);
                Navigator.pop(context);
              }
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
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
            backgroundColor: AppColors.honey,
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
        for (final item in items.reversed) {
          foodItems.insert(0, item);
          totalCarbs += item.carbs;
        }
        isLoading = false;
        showingDailyTotal = false;
        _foodController.clear();
      });

      for (var i = 0; i < items.length; i++) {
        _listKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 400));
      }

      HapticFeedback.lightImpact();

      await _saveData();
      await _updateWidget();
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
            backgroundColor: AppColors.terracotta,
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

  void _quickAddFood(FoodItem item) {
    setState(() {
      foodItems.insert(0, item);
      totalCarbs += item.carbs;
      showingDailyTotal = true;
    });
    _listKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 400));
    HapticFeedback.lightImpact();
    _saveData();
    _updateWidget();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.name} added (${item.carbs.toStringAsFixed(1)}g)'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _resetTotal() {
    for (int i = foodItems.length - 1; i >= 0; i--) {
      _listKey.currentState?.removeItem(
        i,
        (context, animation) => _buildAnimatedItem(foodItems[i], animation),
        duration: const Duration(milliseconds: 300),
      );
    }
    setState(() {
      foodItems.clear();
      totalCarbs = 0.0;
    });
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

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${removedItem.name} removed'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Undo',
            textColor: AppColors.honey,
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
    if (item.details == null) {
      _fetchAndShowDetails(item);
      return;
    }

    _showDetailsDialog(item);
  }

  Future<void> _fetchAndShowDetails(FoodItem item) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.sage),
      ),
    );

    try {
      final results = await _perplexityService.getMultipleCarbCounts(item.name);
      if (!mounted) return;
      Navigator.pop(context); // dismiss loading

      if (results.isNotEmpty) {
        final enriched = results.first;
        // Update the item in the list with full details
        final index = foodItems.indexOf(item);
        if (index != -1) {
          setState(() {
            foodItems[index] = FoodItem(
              name: item.name,
              carbs: item.carbs,
              details: enriched.details,
              citations: enriched.citations,
            );
          });
          _showDetailsDialog(foodItems[index]);
        } else {
          _showDetailsDialog(enriched);
        }
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load details: ${e.toString().replaceAll('Exception:', '').trim()}'),
          backgroundColor: AppColors.terracotta,
        ),
      );
    }
  }

  void _showDetailsDialog(FoodItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.name),
        content: SingleChildScrollView(
          child: RichText(
            text: _buildDetailsTextSpan(
              item.details ?? 'No details available for this item.',
              item.citations,
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
  TextSpan _buildDetailsTextSpan(String text, List<String> citations) {
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
      style: const TextStyle(
        fontSize: 15,
        color: AppColors.ink,
        height: 1.5,
      ),
      children: spans,
    );
  }

  Widget _buildFoodTile(FoodItem item) {
    return GestureDetector(
      onLongPress: () => _showFoodDetails(item),
      child: Container(
      padding: const EdgeInsets.symmetric(
        vertical: 16,
        horizontal: 0,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.border,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              item.name,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.ink,
              ),
            ),
          ),
          Text(
            '${item.carbs.toStringAsFixed(1)}g',
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.muted,
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    ),
    );
  }

  Future<void> _saveToSavedFoods(FoodItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final savedJson = prefs.getString('saved_foods');

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
      await prefs.setString('saved_foods', encoded);

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
      appBar: AppBar(
        title: const Text(
          'CarpeCarb',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: AppIcons.bookmarkIcon(size: 24),
            tooltip: 'Saved Foods',
            onPressed: () async {
              final result = await Navigator.push<FoodItem>(
                context,
                MaterialPageRoute(
                  builder: (context) => const SavedFoodListPage(),
                ),
              );
              if (result != null) {
                _quickAddFood(result);
              }
            },
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
              // Carb Display — long press to toggle between last item and daily total
              GestureDetector(
                onLongPress: foodItems.isNotEmpty
                    ? () {
                        setState(() {
                          showingDailyTotal = !showingDailyTotal;
                        });
                        HapticFeedback.lightImpact();
                      }
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 32.0),
                  child: Column(
                    children: [
                      Text(
                        showingDailyTotal || foodItems.isEmpty
                            ? 'Total Carbs'
                            : foodItems.first.name,
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.muted,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        showingDailyTotal || foodItems.isEmpty
                            ? '${totalCarbs.toStringAsFixed(1)}g'
                            : '${foodItems.first.carbs.toStringAsFixed(1)}g',
                        style: const TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w300,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Goal progress indicator
              GestureDetector(
                onTap: _showGoalDialog,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: dailyCarbGoal != null
                      ? Column(
                          children: [
                            Text(
                              '${totalCarbs.toStringAsFixed(1)} / ${dailyCarbGoal!.toStringAsFixed(0)}g',
                              style: TextStyle(
                                fontSize: 14,
                                color: totalCarbs > dailyCarbGoal!
                                    ? AppColors.terracotta
                                    : AppColors.muted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (totalCarbs / dailyCarbGoal!).clamp(0.0, 1.0),
                                minHeight: 4,
                                backgroundColor: AppColors.border,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  totalCarbs > dailyCarbGoal!
                                      ? AppColors.terracotta
                                      : totalCarbs > dailyCarbGoal! * 0.8
                                          ? AppColors.honey
                                          : AppColors.sage,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Text(
                          'Set a daily goal',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.muted.withValues(alpha: 0.6),
                          ),
                        ),
                ),
              ),

              // Input Field
              TextField(
                controller: _foodController,
                focusNode: _foodFocusNode,
                decoration: InputDecoration(
                  hintText: 'Enter food item...',
                  hintStyle: TextStyle(color: AppColors.muted.withValues(alpha: 0.6)),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                onSubmitted: (_) => _addFood(),
              ),

              const SizedBox(height: 16),

              // Add Button
              ElevatedButton(
                onPressed: isLoading ? null : _addFood,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
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

              const SizedBox(height: 32),

              // Food List Header
              if (foodItems.isNotEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TODAY',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.5,
                        color: AppColors.muted,
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

              // Food List
              foodItems.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32.0),
                        child: Text(
                          'No foods added yet',
                          style: TextStyle(
                            color: AppColors.muted,
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
