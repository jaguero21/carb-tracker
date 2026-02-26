import 'package:flutter/material.dart';
import '../services/health_kit_service.dart';
import '../config/app_colors.dart';
import '../widgets/glass_container.dart';

class CarbHistoryPage extends StatefulWidget {
  final HealthKitService healthKitService;

  const CarbHistoryPage({super.key, required this.healthKitService});

  @override
  State<CarbHistoryPage> createState() => _CarbHistoryPageState();
}

class _CarbHistoryPageState extends State<CarbHistoryPage> {
  Map<DateTime, List<Map<String, dynamic>>> _dailyHistory = {};
  bool _isLoading = true;
  bool _hasPermission = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final hasPerms = await widget.healthKitService.hasPermissions();
    if (!hasPerms) {
      final granted = await widget.healthKitService.requestAuthorization();
      if (!granted) {
        setState(() {
          _isLoading = false;
          _hasPermission = false;
        });
        return;
      }
    }

    final history = await widget.healthKitService.fetchDailyHistory(days: 30);
    setState(() {
      _dailyHistory = history;
      _isLoading = false;
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

  @override
  Widget build(BuildContext context) {
    final sortedDays = _dailyHistory.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'History',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.sage),
            )
          : !_hasPermission
              ? _buildNoPermission()
              : sortedDays.isEmpty
                  ? _buildEmpty()
                  : _buildHistoryList(sortedDays),
    );
  }

  Widget _buildNoPermission() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.health_and_safety_outlined,
              size: 64,
              color: AppColors.muted,
            ),
            const SizedBox(height: 16),
            const Text(
              'HealthKit Access Required',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.ink,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enable HealthKit access in Settings to view your carb history.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: AppColors.muted,
            ),
            const SizedBox(height: 16),
            const Text(
              'No history yet',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.ink,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your carb history will appear here as you log food.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList(List<DateTime> sortedDays) {
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
                top: index == 0 ? 16 : 24,
                bottom: 8,
              ),
              child: GlassContainer(
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                blur: 8,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDate(date).toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.5,
                        color: AppColors.muted,
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
                              entry['name'] as String? ?? 'Unknown',
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatTime(entry['time'] as DateTime),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${((entry['carbs'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(1)}g',
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.muted,
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
}
