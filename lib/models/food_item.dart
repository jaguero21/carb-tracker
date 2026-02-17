class FoodItem {
  final String name;
  final double carbs;
  final String? details;
  final List<String> citations;

  FoodItem({
    required this.name,
    required this.carbs,
    this.details,
    this.citations = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'carbs': carbs,
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
    );
  }
}
