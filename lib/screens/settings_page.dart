import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import '../config/app_colors.dart';
import '../config/app_icons.dart';
import '../config/storage_keys.dart';
import '../models/food_item.dart';
import '../services/health_kit_service.dart';
import '../widgets/glass_container.dart';

class SettingsResult {
  final double? dailyCarbGoal;
  final int resetHour;

  const SettingsResult({this.dailyCarbGoal, required this.resetHour});
}

class SettingsPage extends StatefulWidget {
  final double? dailyCarbGoal;
  final int resetHour;
  final void Function(FoodItem)? onAddFood;
  final HealthKitService? healthKitService;

  const SettingsPage({
    super.key,
    this.dailyCarbGoal,
    this.resetHour = 0,
    this.onAddFood,
    this.healthKitService,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _selectedTab = 0;

  // Goal state
  late TextEditingController _goalController;
  late int _resetHour;
  String? _goalError;

  // Favorites state
  List<FoodItem> _savedFoods = [];
  bool _isFavoritesLoading = true;

  // History state
  Map<DateTime, List<Map<String, dynamic>>> _dailyHistory = {};
  bool _isHistoryLoading = true;
  bool _hasPermission = true;

  static const _tabs = ['Favorites', 'History', 'Goals'];

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
    if (Platform.isIOS && widget.healthKitService != null) {
      _loadHistory();
    } else {
      _isHistoryLoading = false;
    }
  }

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  // ── Favorites ──

  Future<void> _loadSavedFoods() async {
    final prefs = await SharedPreferences.getInstance();
    final savedJson = prefs.getString(StorageKeys.savedFoods);
    if (savedJson != null) {
      final List<dynamic> decoded = jsonDecode(savedJson);
      setState(() {
        _savedFoods = decoded.map((item) => FoodItem.fromJson(item)).toList();
        _isFavoritesLoading = false;
      });
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
    }
  }

  Future<void> _removeSavedFood(int index) async {
    setState(() => _savedFoods.removeAt(index));
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_savedFoods.map((f) => f.toJson()).toList());
    await prefs.setString(StorageKeys.savedFoods, encoded);
  }

  // ── History ──

  Future<void> _loadHistory() async {
    final hs = widget.healthKitService!;
    final hasPerms = await hs.hasPermissions();
    if (!hasPerms) {
      final granted = await hs.requestAuthorization();
      if (!granted) {
        setState(() {
          _isHistoryLoading = false;
          _hasPermission = false;
        });
        return;
      }
    }
    final history = await hs.fetchDailyHistory(days: 30);
    setState(() {
      _dailyHistory = history;
      _isHistoryLoading = false;
    });
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (date == today) return 'Today';
    if (date == yesterday) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  // ── Goals ──

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

  void _saveGoals() {
    if (!_validateAndSave()) return;
    Navigator.pop(
      context,
      SettingsResult(dailyCarbGoal: _parseGoal(), resetHour: _resetHour),
    );
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12:00 AM';
    if (hour == 12) return '12:00 PM';
    if (hour < 12) return '$hour:00 AM';
    return '${hour - 12}:00 PM';
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with X button
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.close, color: colorScheme.onSurface),
                    onPressed: () => Navigator.pop(context),
                  ),
                  if (_selectedTab == 0 && _savedFoods.isNotEmpty)
                    TextButton(
                      onPressed: _resetSavedFoods,
                      child: const Text(
                        'Reset',
                        style: TextStyle(color: AppColors.terracotta),
                      ),
                    ),
                ],
              ),
            ),

            // Large title
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
              child: Text(
                'Settings',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ),

            // Tab chips
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _tabs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final selected = _selectedTab == index;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _selectedTab = index);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.sage
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _tabs[index],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: selected
                              ? Colors.white
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Tab content
            Expanded(
              child: IndexedStack(
                index: _selectedTab,
                children: [
                  _buildFavoritesTab(colorScheme),
                  _buildHistoryTab(colorScheme),
                  _buildGoalsTab(colorScheme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Favorites Tab ──

  Widget _buildFavoritesTab(ColorScheme colorScheme) {
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
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      itemCount: _savedFoods.length,
      itemBuilder: (context, index) {
        final item = _savedFoods[index];
        return Dismissible(
          key: Key('saved_${item.name}_$index'),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => _removeSavedFood(index),
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            color: AppColors.terracotta,
            child: AppIcons.deleteIcon(size: 28, color: Colors.white),
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
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                      color: colorScheme.outlineVariant, width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      style: TextStyle(
                          fontSize: 16, color: colorScheme.onSurface),
                    ),
                  ),
                  Text(
                    '${item.carbs.toStringAsFixed(1)}g',
                    style: TextStyle(
                      fontSize: 16,
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── History Tab ──

  Widget _buildHistoryTab(ColorScheme colorScheme) {
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
            Padding(
              padding: EdgeInsets.only(
                  top: index == 0 ? 8 : 24, bottom: 8),
              child: GlassContainer(
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                blur: 8,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDate(date).toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.5,
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${dayTotal.toStringAsFixed(1)}g',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.sage,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ...entries.map((entry) => Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                          color: colorScheme.outlineVariant, width: 1),
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
                              entry['name'] as String? ?? 'Unknown',
                              style: TextStyle(
                                  fontSize: 16,
                                  color: colorScheme.onSurface),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatTime(entry['time'] as DateTime),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${((entry['carbs'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(1)}g',
                        style: TextStyle(
                          fontSize: 16,
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        );
      },
    );
  }

  // ── Goals Tab ──

  Widget _buildGoalsTab(ColorScheme colorScheme) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      children: [
        // Daily Carb Goal card
        GlassContainer(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Daily Carb Goal',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Set a daily target for carb intake',
                style: TextStyle(
                    fontSize: 13, color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _goalController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
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
                  ),
                  if (_goalController.text.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () {
                        _goalController.clear();
                        setState(() => _goalError = null);
                      },
                      icon: const Icon(Icons.clear,
                          color: AppColors.terracotta, size: 20),
                      tooltip: 'Clear goal',
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Daily Reset Time card
        GlassContainer(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Daily Reset Time',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'When your daily carb count resets to zero',
                style: TextStyle(
                    fontSize: 13, color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.outlineVariant),
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

        const SizedBox(height: 32),

        // Save button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saveGoals,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.sage,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'Save',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ],
    );
  }
}
