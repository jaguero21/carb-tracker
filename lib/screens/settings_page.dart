import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import '../config/app_colors.dart';
import '../config/storage_keys.dart';
import '../models/food_item.dart';
import '../services/health_kit_service.dart';
import '../services/premium_service.dart';
import '../services/cloud_sync_service.dart';
import '../utils/date_format.dart';
import '../widgets/food_item_card.dart';

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
  final void Function(SettingsResult)? onSettingsChanged;
  final PremiumService? premiumService;
  final CloudSyncService? cloudSyncService;

  const SettingsPage({
    super.key,
    this.dailyCarbGoal,
    this.resetHour = 0,
    this.onAddFood,
    this.healthKitService,
    this.onSettingsChanged,
    this.premiumService,
    this.cloudSyncService,
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

  static const _tabIcons = [Icons.bookmark_border, Icons.history, Icons.adjust, Icons.workspace_premium];
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
    final result = SettingsResult(dailyCarbGoal: _parseGoal(), resetHour: _resetHour);
    widget.onSettingsChanged?.call(result);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings saved'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12:00 AM';
    if (hour == 12) return '12:00 PM';
    if (hour < 12) return '$hour:00 AM';
    return '${hour - 12}:00 PM';
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
                padding: EdgeInsets.only(right: index < _tabLabels.length - 1 ? 12 : 0),
                child: GestureDetector(
                  onTap: () {
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
                key: Key('saved_${item.name}_$index'),
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
              padding: EdgeInsets.only(
                  top: index == 0 ? 8 : 24, bottom: 12),
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
              return FoodItemCard(
                name: entry['name'] as String? ?? 'Unknown',
                subtitle: formatTime(time),
                carbs: (entry['carbs'] as num?)?.toDouble() ?? 0.0,
                category: FoodCategory.fromTime(time),
              );
            }),
          ],
        );
      },
    );
  }

  // ── Goals Tab ──

  Widget _buildGoalsTab(ColorScheme colorScheme, bool isDark) {
    return ListView(
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
                              fontSize: 13, color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _goalController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _saveGoals(),
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
                              fontSize: 13, color: colorScheme.onSurfaceVariant),
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
                  color: isDark ? AppColors.darkBackground : AppColors.inputFill,
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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

  Widget _buildPremiumTab(ColorScheme colorScheme, bool isDark) {
    final ps = widget.premiumService;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      children: [
        _buildPremiumFeatureCard(
          icon: Icons.edit_note,
          title: 'Manual Entry',
          description: 'Enter food name and carb count directly',
          value: ps?.isManualEntryEnabled ?? false,
          enabled: ps?.isPremium ?? false,
          isDark: isDark,
          onChanged: (v) async {
            await ps?.setFeatureEnabled(StorageKeys.premiumManualEntry, v);
            setState(() {});
          },
        ),
        _buildPremiumFeatureCard(
          icon: Icons.favorite_border,
          title: 'Apple Health Sync',
          description: 'Sync carb data with Apple Health',
          value: ps?.isHealthSyncEnabled ?? false,
          enabled: ps?.isPremium ?? false,
          isDark: isDark,
          onChanged: (v) async {
            await ps?.setFeatureEnabled(StorageKeys.premiumHealthSync, v);
            setState(() {});
          },
        ),
        _buildPremiumFeatureCard(
          icon: Icons.cloud_outlined,
          title: 'Cloud Sync',
          description: 'Sync data across your devices via iCloud',
          value: ps?.isCloudSyncEnabled ?? false,
          enabled: ps?.isPremium ?? false,
          isDark: isDark,
          onChanged: (v) async {
            if (v) {
              final available = await widget.cloudSyncService?.isAvailable() ?? false;
              if (!available && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sign into iCloud in Settings to enable sync'),
                    duration: Duration(seconds: 3),
                  ),
                );
                return;
              }
            }
            await ps?.setFeatureEnabled(StorageKeys.premiumCloudSync, v);
            if (v) {
              await widget.cloudSyncService?.pushToCloud();
            } else {
              await widget.cloudSyncService?.stopListening();
            }
            setState(() {});
          },
        ),
        _buildPremiumFeatureCard(
          icon: Icons.bar_chart,
          title: 'Macro Nutrients',
          description: 'Track protein, fat, fiber and more',
          value: false,
          enabled: false,
          badge: 'Coming soon',
          isDark: isDark,
          onChanged: (_) {},
        ),
      ],
    );
  }
}
