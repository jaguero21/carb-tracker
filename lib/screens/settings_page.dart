import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:keyboard_actions/keyboard_actions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../config/app_colors.dart';
import '../config/storage_keys.dart';
import '../models/food_item.dart';
import '../services/health_kit_service.dart';
import '../services/premium_service.dart';
import '../services/purchase_service.dart';
import '../services/cloud_sync_service.dart';
import '../utils/date_format.dart';
import '../widgets/food_item_card.dart';

class SettingsResult {
  final double? dailyCarbGoal;
  final int resetHour;
  final double? proteinGoal;
  final double? fatGoal;
  final double? fiberGoal;
  final double? caloriesGoal;

  const SettingsResult({
    this.dailyCarbGoal,
    required this.resetHour,
    this.proteinGoal,
    this.fatGoal,
    this.fiberGoal,
    this.caloriesGoal,
  });
}

class SettingsPage extends StatefulWidget {
  final double? dailyCarbGoal;
  final int resetHour;
  final void Function(FoodItem)? onAddFood;
  final HealthKitService? healthKitService;
  final void Function(SettingsResult)? onSettingsChanged;
  final VoidCallback? onFavoritesChanged;
  final PremiumService? premiumService;
  final CloudSyncService? cloudSyncService;
  final Future<void> Function()? onCloudSyncEnabled;

  const SettingsPage({
    super.key,
    this.dailyCarbGoal,
    this.resetHour = 0,
    this.onAddFood,
    this.healthKitService,
    this.onSettingsChanged,
    this.onFavoritesChanged,
    this.premiumService,
    this.cloudSyncService,
    this.onCloudSyncEnabled,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _selectedTab = 0;
  int _savedFoodsLoadToken = 0;
  int _historyLoadToken = 0;
  int _macroGoalsLoadToken = 0;
  final PurchaseService _purchaseService = PurchaseService();
  Map<String, dynamic> _premiumProducts = {};

  // Goal state
  late TextEditingController _goalController;
  late int _resetHour;
  String? _goalError;

  // Macro goal state
  final TextEditingController _proteinGoalController = TextEditingController();
  final TextEditingController _fatGoalController = TextEditingController();
  final TextEditingController _fiberGoalController = TextEditingController();
  final TextEditingController _caloriesGoalController = TextEditingController();
  final FocusNode _goalFocusNode = FocusNode();
  final FocusNode _proteinGoalFocusNode = FocusNode();
  final FocusNode _fatGoalFocusNode = FocusNode();
  final FocusNode _fiberGoalFocusNode = FocusNode();
  final FocusNode _caloriesGoalFocusNode = FocusNode();

  // Favorites state
  List<FoodItem> _savedFoods = [];
  bool _isFavoritesLoading = true;

  // History state
  Map<DateTime, List<Map<String, dynamic>>> _dailyHistory = {};
  bool _isHistoryLoading = true;
  bool _hasPermission = true;
  bool _historyTimedOut = false;

  static const _tabIcons = [
    Icons.bookmark_border,
    Icons.history,
    Icons.adjust,
    Icons.workspace_premium
  ];
  static const _tabLabels = ['Favorites', 'History', 'Goals', 'Premium'];

  @override
  void initState() {
    super.initState();
    _goalController = TextEditingController(
      text: widget.dailyCarbGoal != null
          ? widget.dailyCarbGoal!.toStringAsFixed(0)
          : '',
    );
    _resetHour = widget.resetHour;
    _loadSavedFoods();
    _loadMacroGoals();
    _loadPremiumProducts();
    if (Platform.isIOS && widget.healthKitService != null) {
      _loadHistory();
    } else {
      _isHistoryLoading = false;
    }
  }

  @override
  void didUpdateWidget(SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dailyCarbGoal != widget.dailyCarbGoal) {
      _goalController.text = widget.dailyCarbGoal != null
          ? widget.dailyCarbGoal!.toStringAsFixed(0)
          : '';
    }
    if (oldWidget.resetHour != widget.resetHour) {
      _resetHour = widget.resetHour;
    }
  }

  @override
  void dispose() {
    _savedFoodsLoadToken++;
    _historyLoadToken++;
    _macroGoalsLoadToken++;
    _goalController.dispose();
    _proteinGoalController.dispose();
    _fatGoalController.dispose();
    _fiberGoalController.dispose();
    _caloriesGoalController.dispose();
    _goalFocusNode.dispose();
    _proteinGoalFocusNode.dispose();
    _fatGoalFocusNode.dispose();
    _fiberGoalFocusNode.dispose();
    _caloriesGoalFocusNode.dispose();
    super.dispose();
  }

  // ── Favorites ──

  Future<void> _loadSavedFoods() async {
    final token = ++_savedFoodsLoadToken;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || token != _savedFoodsLoadToken) return;
    final savedJson = prefs.getString(StorageKeys.savedFoods);
    if (savedJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(savedJson);
        setState(() {
          _savedFoods = decoded.map((item) => FoodItem.fromJson(item)).toList();
          _isFavoritesLoading = false;
        });
      } catch (_) {
        setState(() => _isFavoritesLoading = false);
      }
    } else {
      setState(() => _isFavoritesLoading = false);
    }
  }

  Future<void> _resetSavedFoods() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (context) => AlertDialog(
        backgroundColor:
            Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
        title: const Text('Reset Saved Foods'),
        content: const Text('Are you sure you want to clear all saved foods?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.terracotta),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(StorageKeys.savedFoods);
      setState(() => _savedFoods.clear());
      widget.onFavoritesChanged?.call();
    }
  }

  Future<void> _removeSavedFood(int index) async {
    final removed = _savedFoods[index];
    setState(() => _savedFoods.removeAt(index));
    HapticFeedback.mediumImpact();

    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_savedFoods.map((f) => f.toJson()).toList());
    await prefs.setString(StorageKeys.savedFoods, encoded);
    widget.onFavoritesChanged?.call();

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${removed.name} removed'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.white,
          onPressed: () async {
            setState(() {
              _savedFoods.insert(
                  index.clamp(0, _savedFoods.length), removed);
            });
            final p = await SharedPreferences.getInstance();
            await p.setString(
                StorageKeys.savedFoods,
                jsonEncode(
                    _savedFoods.map((f) => f.toJson()).toList()));
            widget.onFavoritesChanged?.call();
          },
        ),
      ),
    );
  }

  // ── History ──

  Future<void> _loadHistory() async {
    final token = ++_historyLoadToken;
    final hs = widget.healthKitService!;
    setState(() {
      _isHistoryLoading = true;
      _historyTimedOut = false;
    });
    final hasPerms = await hs.hasPermissions();
    if (!mounted || token != _historyLoadToken) return;
    if (!hasPerms) {
      final granted = await hs.requestAuthorization();
      if (!mounted || token != _historyLoadToken) return;
      if (!granted) {
        setState(() {
          _isHistoryLoading = false;
          _hasPermission = false;
        });
        return;
      }
    }
    try {
      final history = await hs
          .fetchDailyHistory(days: 30)
          .timeout(const Duration(seconds: 10));
      if (!mounted || token != _historyLoadToken) return;
      setState(() {
        _dailyHistory = history;
        _isHistoryLoading = false;
      });
    } on TimeoutException {
      if (!mounted || token != _historyLoadToken) return;
      setState(() {
        _isHistoryLoading = false;
        _historyTimedOut = true;
      });
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (date == today) return 'Today';
    if (date == yesterday) return 'Yesterday';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  // ── Goals ──

  Future<void> _loadMacroGoals() async {
    final token = ++_macroGoalsLoadToken;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || token != _macroGoalsLoadToken) return;
    final p = prefs.getDouble(StorageKeys.proteinGoal);
    final f = prefs.getDouble(StorageKeys.fatGoal);
    final fi = prefs.getDouble(StorageKeys.fiberGoal);
    final c = prefs.getDouble(StorageKeys.caloriesGoal);
    _proteinGoalController.text = p != null ? p.toStringAsFixed(0) : '';
    _fatGoalController.text = f != null ? f.toStringAsFixed(0) : '';
    _fiberGoalController.text = fi != null ? fi.toStringAsFixed(0) : '';
    _caloriesGoalController.text = c != null ? c.toStringAsFixed(0) : '';
  }

  Future<void> _savePrefGoal(
      SharedPreferences prefs, String key, double? value) {
    return value != null ? prefs.setDouble(key, value) : prefs.remove(key);
  }

  double? _parseMacroGoal(TextEditingController c) {
    final text = c.text.trim();
    if (text.isEmpty) return null;
    final v = double.tryParse(text);
    return (v != null && v > 0) ? v : null;
  }

  double? _parseGoal() {
    final text = _goalController.text.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  bool _validateAndSave() {
    final text = _goalController.text.trim();
    if (text.isNotEmpty) {
      final value = double.tryParse(text);
      if (value == null) {
        setState(() => _goalError = 'Enter a valid number');
        return false;
      }
      if (value <= 0) {
        setState(() => _goalError = 'Goal must be greater than 0');
        return false;
      }
    }
    setState(() => _goalError = null);
    return true;
  }

  Future<void> _saveGoals() async {
    if (!_validateAndSave()) return;
    final protein = _parseMacroGoal(_proteinGoalController);
    final fat = _parseMacroGoal(_fatGoalController);
    final fiber = _parseMacroGoal(_fiberGoalController);
    final calories = _parseMacroGoal(_caloriesGoalController);

    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      _savePrefGoal(prefs, StorageKeys.proteinGoal, protein),
      _savePrefGoal(prefs, StorageKeys.fatGoal, fat),
      _savePrefGoal(prefs, StorageKeys.fiberGoal, fiber),
      _savePrefGoal(prefs, StorageKeys.caloriesGoal, calories),
    ]);

    final result = SettingsResult(
      dailyCarbGoal: _parseGoal(),
      resetHour: _resetHour,
      proteinGoal: protein,
      fatGoal: fat,
      fiberGoal: fiber,
      caloriesGoal: calories,
    );
    widget.onSettingsChanged?.call(result);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _loadPremiumProducts() async {
    if (!Platform.isIOS) return;
    try {
      final available = await _purchaseService.isStoreAvailable();
      if (!available) return;
      final products = await _purchaseService.queryPremiumProducts();
      if (!mounted) return;
      setState(() {
        _premiumProducts = products;
      });
    } catch (_) {
      // Keep static pricing fallback when products cannot be loaded.
    }
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12:00 AM';
    if (hour == 12) return '12:00 PM';
    if (hour < 12) return '$hour:00 AM';
    return '${hour - 12}:00 PM';
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _focusPreviousGoalField(FocusNode current) {
    if (current == _caloriesGoalFocusNode) {
      _fiberGoalFocusNode.requestFocus();
      return;
    }
    if (current == _fiberGoalFocusNode) {
      _fatGoalFocusNode.requestFocus();
      return;
    }
    if (current == _fatGoalFocusNode) {
      _proteinGoalFocusNode.requestFocus();
      return;
    }
    if (current == _proteinGoalFocusNode) {
      _goalFocusNode.requestFocus();
    }
  }

  void _focusNextGoalField(FocusNode current) {
    if (current == _goalFocusNode) {
      _proteinGoalFocusNode.requestFocus();
      return;
    }
    if (current == _proteinGoalFocusNode) {
      _fatGoalFocusNode.requestFocus();
      return;
    }
    if (current == _fatGoalFocusNode) {
      _fiberGoalFocusNode.requestFocus();
      return;
    }
    if (current == _fiberGoalFocusNode) {
      _caloriesGoalFocusNode.requestFocus();
      return;
    }
    _dismissKeyboard();
    _saveGoals();
  }

  Widget _keyboardToolbarButton({
    required String label,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextButton(
      onPressed: () {
        HapticFeedback.lightImpact();
        onPressed();
      },
      style: TextButton.styleFrom(
        foregroundColor: isPrimary ? AppColors.sage : colorScheme.onSurface,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    );
  }

  KeyboardActionsConfig _buildGoalKeyboardActionsConfig() {
    KeyboardActionsItem itemFor(
      FocusNode node, {
      bool showPrevious = true,
      bool showNext = true,
      bool doneSaves = false,
      String doneLabel = 'Done',
    }) {
      final buttons = <Widget Function(FocusNode)>[];

      if (showPrevious) {
        buttons.add(
          (_) => _keyboardToolbarButton(
            label: 'Previous',
            onPressed: () => _focusPreviousGoalField(node),
          ),
        );
      }

      if (showNext) {
        buttons.add(
          (_) => _keyboardToolbarButton(
            label: 'Next',
            onPressed: () => _focusNextGoalField(node),
          ),
        );
      }

      buttons.add(
        (_) => _keyboardToolbarButton(
          label: doneLabel,
          isPrimary: true,
          onPressed: () {
            _dismissKeyboard();
            if (doneSaves) {
              _saveGoals();
            }
          },
        ),
      );

      return KeyboardActionsItem(
        focusNode: node,
        toolbarButtons: buttons,
      );
    }

    return KeyboardActionsConfig(
      keyboardActionsPlatform: KeyboardActionsPlatform.IOS,
      keyboardBarColor: Theme.of(context).colorScheme.surface,
      actions: [
        itemFor(_goalFocusNode, showPrevious: false),
        itemFor(_proteinGoalFocusNode),
        itemFor(_fatGoalFocusNode),
        itemFor(_fiberGoalFocusNode),
        itemFor(
          _caloriesGoalFocusNode,
          showNext: false,
          doneSaves: true,
          doneLabel: 'Save',
        ),
      ],
    );
  }

  // ── Helpers ──

  Widget _buildIconBadge(IconData icon) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.sage.withValues(alpha: 0.2),
            AppColors.sageLight.withValues(alpha: 0.2),
          ],
        ),
      ),
      child: Center(
        child: Icon(icon, size: 22, color: AppColors.sage),
      ),
    );
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tab bar with icons
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: List.generate(_tabLabels.length, (index) {
              final selected = _selectedTab == index;
              return Padding(
                padding: EdgeInsets.only(
                    right: index < _tabLabels.length - 1 ? 12 : 0),
                child: GestureDetector(
                  onTap: () {
                    _dismissKeyboard();
                    HapticFeedback.lightImpact();
                    setState(() => _selectedTab = index);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(
                      horizontal: selected ? 20 : 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.sage : Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _tabIcons[index],
                          size: 18,
                          color: selected
                              ? Colors.white
                              : colorScheme.onSurfaceVariant,
                        ),
                        if (selected) ...[
                          const SizedBox(width: 6),
                          Text(
                            _tabLabels[index],
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: 16),

        // Tab content
        Expanded(
          child: IndexedStack(
            index: _selectedTab,
            children: [
              _buildFavoritesTab(colorScheme, isDark),
              _buildHistoryTab(colorScheme, isDark),
              _buildGoalsTab(colorScheme, isDark),
              _buildPremiumTab(colorScheme, isDark),
            ],
          ),
        ),
      ],
    );
  }

  // ── Favorites Tab ──

  Widget _buildFavoritesTab(ColorScheme colorScheme, bool isDark) {
    if (_isFavoritesLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.sage));
    }
    if (_savedFoods.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bookmark_border,
                  size: 64, color: colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                'No saved foods yet',
                style: TextStyle(
                    fontSize: 18, color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Text(
                'Swipe right on food items to save them here',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        // Reset button for favorites
        if (_savedFoods.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: _resetSavedFoods,
                  child: Text(
                    'Clear All',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.terracotta,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            itemCount: _savedFoods.length,
            itemBuilder: (context, index) {
              final item = _savedFoods[index];
              return Dismissible(
                key: Key('saved_${item.id}'),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => _removeSavedFood(index),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: AppColors.terracotta,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.delete, size: 28, color: Colors.white),
                ),
                child: GestureDetector(
                  onTap: widget.onAddFood != null
                      ? () {
                          HapticFeedback.lightImpact();
                          widget.onAddFood!(item);
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  '${item.name} added (${item.carbs.toStringAsFixed(1)}g)'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      : null,
                  child: FoodItemCard(
                    name: item.name,
                    subtitle: '${item.carbs.toStringAsFixed(1)}g per serving',
                    carbs: item.carbs,
                    category: item.category,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── History Tab ──

  Widget _buildHistoryTab(ColorScheme colorScheme, bool isDark) {
    if (!Platform.isIOS) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history,
                  size: 64, color: colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                'History requires HealthKit',
                style: TextStyle(
                    fontSize: 18, color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Text(
                'Carb history is available on iOS with HealthKit.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    if (_isHistoryLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.sage));
    }

    if (_historyTimedOut) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off,
                  size: 64, color: colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                'History load timed out',
                style: TextStyle(
                    fontSize: 18, color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                'HealthKit took too long to respond.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loadHistory,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.sage),
              ),
            ],
          ),
        ),
      );
    }

    if (!_hasPermission) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.health_and_safety_outlined,
                  size: 64, color: colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                'HealthKit Access Required',
                style: TextStyle(
                  fontSize: 18,
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enable HealthKit access in Settings to view your carb history.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    final sortedDays = _dailyHistory.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    if (sortedDays.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history,
                  size: 64, color: colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                'No history yet',
                style: TextStyle(
                  fontSize: 18,
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your carb history will appear here as you log food.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      itemCount: sortedDays.length,
      itemBuilder: (context, index) {
        final date = sortedDays[index];
        final entries = _dailyHistory[date]!;
        final dayTotal = entries.fold<double>(
          0.0,
          (sum, e) => sum + ((e['carbs'] as num?)?.toDouble() ?? 0.0),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day header
            Padding(
              padding: EdgeInsets.only(top: index == 0 ? 8 : 24, bottom: 12),
              child: Row(
                children: [
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
                    _formatDate(date).toUpperCase(),
                    style: TextStyle(
                      fontSize: 14,
                      letterSpacing: 1.5,
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${dayTotal.toStringAsFixed(1)}g',
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.sage,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            ...entries.map((entry) {
              final time = entry['time'] as DateTime;
              final name = entry['name'] as String? ?? 'Unknown';
              final carbs = (entry['carbs'] as num?)?.toDouble() ?? 0.0;
              return FoodItemCard(
                name: name,
                subtitle: formatTime(time),
                carbs: carbs,
                category: FoodCategory.fromTime(time),
                onTap: widget.onAddFood == null
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        widget.onAddFood!(FoodItem(name: name, carbs: carbs));
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                '$name added (${carbs.toStringAsFixed(1)}g)'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
              );
            }),
          ],
        );
      },
    );
  }

  // ── Goals Tab ──

  Widget _buildGoalsTab(ColorScheme colorScheme, bool isDark) {
    return KeyboardActions(
      config: _buildGoalKeyboardActionsConfig(),
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        children: [
          // Daily Carb Goal card
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildIconBadge(Icons.adjust),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daily Carb Goal',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Set a daily target for carb intake',
                            style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _goalController,
                  focusNode: _goalFocusNode,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    _dismissKeyboard();
                    _saveGoals();
                  },
                  onTapOutside: (_) => _dismissKeyboard(),
                  decoration: InputDecoration(
                    hintText: 'e.g. 50',
                    suffixText: 'g',
                    errorText: _goalError,
                  ),
                  onChanged: (_) {
                    if (_goalError != null) {
                      setState(() => _goalError = null);
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Daily Reset Time card
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildIconBadge(Icons.schedule),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daily Reset Time',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'When your daily carb count resets to zero',
                            style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color:
                        isDark ? AppColors.darkBackground : AppColors.inputFill,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _resetHour,
                      isExpanded: true,
                      dropdownColor: colorScheme.surface,
                      items: List.generate(24, (i) => i).map((hour) {
                        return DropdownMenuItem<int>(
                          value: hour,
                          child: Text(
                            _formatHour(hour),
                            style: TextStyle(
                                fontSize: 15, color: colorScheme.onSurface),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _resetHour = value);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Macro Goals card — only shown when macros feature is enabled
          if (widget.premiumService?.isMacrosEnabled == true) ...[
            const SizedBox(height: 16),
            _buildMacroGoalsCard(colorScheme, isDark),
          ],

          const SizedBox(height: 32),

          // Save button with gradient
          Container(
            width: double.infinity,
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
              onPressed: _saveGoals,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                'Save Changes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroGoalsCard(ColorScheme colorScheme, bool isDark) {
    Widget field(
      String label,
      String hint,
      TextEditingController controller,
      FocusNode focusNode,
      TextInputAction textInputAction,
      VoidCallback onSubmitted, {
      bool isCalories = false,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: textInputAction,
                onSubmitted: (_) => onSubmitted(),
                onTapOutside: (_) => _dismissKeyboard(),
                decoration: InputDecoration(
                  hintText: hint,
                  suffixText: isCalories ? 'kcal' : 'g',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildIconBadge(Icons.bar_chart),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Macro Goals',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Set daily targets for each macro',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          field(
            'Protein',
            'e.g. 120',
            _proteinGoalController,
            _proteinGoalFocusNode,
            TextInputAction.next,
            () => _fatGoalFocusNode.requestFocus(),
          ),
          field(
            'Fat',
            'e.g. 65',
            _fatGoalController,
            _fatGoalFocusNode,
            TextInputAction.next,
            () => _fiberGoalFocusNode.requestFocus(),
          ),
          field(
            'Fiber',
            'e.g. 25',
            _fiberGoalController,
            _fiberGoalFocusNode,
            TextInputAction.next,
            () => _caloriesGoalFocusNode.requestFocus(),
          ),
          field(
            'Calories',
            'e.g. 2000',
            _caloriesGoalController,
            _caloriesGoalFocusNode,
            TextInputAction.done,
            () {
              _dismissKeyboard();
              _saveGoals();
            },
            isCalories: true,
          ),
        ],
      ),
    );
  }

  // ── Premium Tab ──

  Widget _buildPremiumFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required bool value,
    required bool enabled,
    String? badge,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Row(
        children: [
          _buildIconBadge(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: enabled
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.honey.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.honey,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeTrackColor: AppColors.sage,
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumIncludedItem({
    required IconData icon,
    required String title,
    required String description,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
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
          _buildIconBadge(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle, color: AppColors.sage, size: 20),
        ],
      ),
    );
  }

  String _planLabel(String? plan) {
    if (plan == PremiumService.monthlyPlan) {
      final dynamic p = _premiumProducts[PurchaseService.monthlyProductId];
      final dynamic price = p?.price;
      return (price is String && price.isNotEmpty)
          ? '$price/month'
          : r'$2.99/month';
    }
    if (plan == PremiumService.yearlyPlan) {
      final dynamic p = _premiumProducts[PurchaseService.yearlyProductId];
      final dynamic price = p?.price;
      return (price is String && price.isNotEmpty)
          ? '$price/year'
          : r'$29.99/year';
    }
    return 'Not selected';
  }

  Future<String?> _showPremiumPaywall(bool isDark) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget planButton({
      required String title,
      required String price,
      required String value,
      required bool highlighted,
    }) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: highlighted
                  ? AppColors.sage
                  : colorScheme.outline.withValues(alpha: 0.4),
              width: highlighted ? 1.6 : 1.0,
            ),
            backgroundColor: highlighted
                ? AppColors.sage.withValues(alpha: 0.08)
                : (isDark ? AppColors.darkSurface : Colors.white),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
          onPressed: () => Navigator.of(context).pop(value),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                price,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.sage,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: isDark ? AppColors.darkBackground : colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unlock CarpeCarb Premium',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Track smarter with advanced logging, syncing, and macro insights.',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '- Manual Entry\n- Apple Health Sync\n- Cloud Sync across devices\n- Macro Nutrients tracking',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurface,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 16),
                planButton(
                  title: 'Monthly',
                  price: _planLabel(PremiumService.monthlyPlan),
                  value: PremiumService.monthlyPlan,
                  highlighted: false,
                ),
                planButton(
                  title: 'Yearly',
                  price: _planLabel(PremiumService.yearlyPlan),
                  value: PremiumService.yearlyPlan,
                  highlighted: true,
                ),
                const SizedBox(height: 6),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Not now'),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => launchUrl(
                        Uri.parse('https://jaguero21.github.io/CarpeCarb/privacy-policy.html'),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: Text(
                        'Privacy Policy',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Text(
                      '·',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => launchUrl(
                        Uri.parse('https://jaguero21.github.io/CarpeCarb/eula.html'),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: Text(
                        'Terms of Use',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPremiumTab(ColorScheme colorScheme, bool isDark) {
    final ps = widget.premiumService;
    final selectedPlan = ps?.premiumPlan;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      children: [
        _buildPremiumFeatureCard(
          icon: Icons.workspace_premium,
          title: 'Premium Access',
          description: ps?.isPremium == true
              ? 'Active plan: ${_planLabel(selectedPlan)}'
              : 'Enable all premium features after purchase',
          value: ps?.isPremium ?? false,
          enabled: true,
          badge: ps?.isPremium == true ? 'ACTIVE' : null,
          isDark: isDark,
          onChanged: (v) async {
            if (v) {
              if (!Platform.isIOS) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Purchases are currently available on iOS.'),
                    duration: Duration(seconds: 3),
                  ),
                );
                setState(() {});
                return;
              }

              final isIosSimulator =
                  Platform.environment.containsKey('SIMULATOR_DEVICE_NAME');
              if (isIosSimulator) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'App Store sandbox purchases must be tested on a real iPhone. Simulator only supports local StoreKit testing.',
                    ),
                    duration: Duration(seconds: 5),
                  ),
                );
                setState(() {});
                return;
              }

              final plan = await _showPremiumPaywall(isDark);
              if (plan == null) {
                if (!mounted) return;
                setState(() {});
                return;
              }

              bool purchased = false;
              try {
                purchased = await _purchaseService.purchasePlan(plan);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Purchase failed: $e'),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                  setState(() {});
                }
                return;
              }
              if (!purchased) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Purchase not completed.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
                setState(() {});
                return;
              }

              final available =
                  await widget.cloudSyncService?.isAvailable() ?? false;
              if (!available && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Sign into iCloud in Settings to enable sync'),
                    duration: Duration(seconds: 3),
                  ),
                );
              }

              await ps?.setPremiumEnabled(true, plan: plan);
              await widget.onCloudSyncEnabled?.call();
            } else {
              await ps?.setPremiumEnabled(false);
              await widget.cloudSyncService?.stopListening();
            }

            if (!mounted) return;
            setState(() {});
          },
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () async {
              if (!Platform.isIOS) return;
              String? restoredPlan;
              try {
                restoredPlan = await _purchaseService.restorePremiumPlan();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Restore failed: $e'),
                    duration: const Duration(seconds: 3),
                  ),
                );
                return;
              }
              if (restoredPlan == null) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('No active premium purchase found to restore.'),
                    duration: Duration(seconds: 3),
                  ),
                );
                return;
              }

              await ps?.setPremiumEnabled(true, plan: restoredPlan);
              await widget.onCloudSyncEnabled?.call();
              if (!mounted) return;
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Restored ${_planLabel(restoredPlan)} plan.'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Restore Purchases'),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Included with Premium',
          style: TextStyle(
            fontSize: 13,
            letterSpacing: 1.0,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        _buildPremiumIncludedItem(
          icon: Icons.edit_note,
          title: 'Manual Entry',
          description: 'Enter food name and carb count directly',
          isDark: isDark,
        ),
        _buildPremiumIncludedItem(
          icon: Icons.favorite_border,
          title: 'Apple Health Sync',
          description: 'Sync carb data with Apple Health',
          isDark: isDark,
        ),
        _buildPremiumIncludedItem(
          icon: Icons.cloud_outlined,
          title: 'Cloud Sync',
          description: 'Sync data across your devices via iCloud',
          isDark: isDark,
        ),
        _buildPremiumIncludedItem(
          icon: Icons.bar_chart,
          title: 'Macro Nutrients',
          description: 'Track protein, fat, fiber and more',
          isDark: isDark,
        ),
      ],
    );
  }
}
