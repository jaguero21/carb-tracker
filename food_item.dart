class FoodItem {
  final String name;
  final double carbs;

  FoodItem({
    required this.name,
    required this.carbs,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'carbs': carbs,
    };
  }

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      name: json['name'] as String,
      carbs: (json['carbs'] as num).toDouble(),
    );
  }
}
