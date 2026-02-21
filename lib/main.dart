import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:home_widget/home_widget.dart';
import 'dart:convert';
import 'dart:math' as math;
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
class CarbTrackerHomeState extends State<CarbTrackerHome> {
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
    _loadSavedData();
    _checkWidgetLaunch();
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
    await HomeWidget.saveWidgetData<double>('dailyCarbGoal', dailyCarbGoal ?? 0.0);
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
    if (siriItemsJson == null) return;

    try {
      final List<dynamic> siriItems = jsonDecode(siriItemsJson);
      if (siriItems.isEmpty) return;

      setState(() {
        for (final item in siriItems) {
          final foodItem = FoodItem(
            name: item['name'] as String,
            carbs: (item['carbs'] as num).toDouble(),
          );
          foodItems.insert(0, foodItem);
          _listKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 400));
        }
        // Sync totalCarbs from shared UserDefaults (Siri already updated it)
      });

      // Clear the Siri buffer so we don't re-import on next launch
      await HomeWidget.saveWidgetData<String?>('siriLoggedItems', null);
      await _saveData();
    } catch (_) {
      // Ignore malformed Siri data
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('total_carbs', totalCarbs);
    if (dailyCarbGoal != null) {
      await prefs.setDouble('daily_carb_goal', dailyCarbGoal!);
    } else {
      await prefs.remove('daily_carb_goal');
    }
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
                _saveData();
                _updateWidget();
                Navigator.pop(context);
              },
              child: const Text(
                'Clear',
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
                _saveData();
                _updateWidget();
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
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
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SavedFoodListPage(),
                ),
              );
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
                  _showGoalDialog();
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
                          fontSize: 16,
                          color: AppColors.muted,
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
                              trackColor: AppColors.border,
                              fillColor: totalCarbs > dailyCarbGoal!
                                  ? AppColors.terracotta
                                  : AppColors.sage,
                            ),
                            child: Center(
                              child: Text(
                                showingDailyTotal || foodItems.isEmpty
                                    ? '${totalCarbs.toStringAsFixed(1)}g'
                                    : '${foodItems.first.carbs.toStringAsFixed(1)}g',
                                style: const TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.w300,
                                  color: AppColors.ink,
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
                          style: const TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.w300,
                            color: AppColors.ink,
                          ),
                        ),
                      const SizedBox(height: 8),
                      if (dailyCarbGoal != null)
                        Text(
                          totalCarbs >= dailyCarbGoal!
                              ? 'over by ${(totalCarbs - dailyCarbGoal!).toStringAsFixed(1)}g'
                              : '${(dailyCarbGoal! - totalCarbs).toStringAsFixed(1)}g remaining',
                          style: TextStyle(
                            fontSize: 14,
                            color: totalCarbs > dailyCarbGoal!
                                ? AppColors.terracotta
                                : AppColors.muted,
                          ),
                        ),
                    ],
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
