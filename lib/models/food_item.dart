class FoodItem {
  final String name;
  final double carbs;
  final String? details;
  final List<String> citations;
  final DateTime timestamp;

  FoodItem({
    required this.name,
    required this.carbs,
    this.details,
    this.citations = const [],
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'carbs': carbs,
      'timestamp': timestamp.toIso8601String(),
      if (details != null) 'details': details,
      if (citations.isNotEmpty) 'citations': citations,
    };
  }

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      name: json['name'] as String,
      carbs: (json['carbs'] as num).toDouble(),
      details: json['details'] as String?,
      citations: json['citations'] != null
          ? List<String>.from(json['citations'])
          : const [],
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String get timeLabel {
    final hour = timestamp.hour;
    final minute = timestamp.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  String get dayPeriod {
    final hour = timestamp.hour;
    if (hour < 12) return 'MORNING';
    if (hour < 17) return 'AFTERNOON';
    return 'EVENING';
  }
}
