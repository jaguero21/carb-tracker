class FoodItem {
  final String name;
  final double carbs;
  final String? details;
  final List<String> citations;
  final DateTime loggedAt;

  FoodItem({
    required this.name,
    required this.carbs,
    this.details,
    this.citations = const [],
    DateTime? loggedAt,
  }) : loggedAt = loggedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'carbs': carbs,
      'loggedAt': loggedAt.toIso8601String(),
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
      loggedAt: json['loggedAt'] != null
          ? DateTime.parse(json['loggedAt'] as String)
          : null,
    );
  }
}
