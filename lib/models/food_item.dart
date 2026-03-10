import 'package:flutter/material.dart';

enum FoodCategory {
  breakfast,
  lunch,
  dinner,
  snack,
  drink;

  String get label {
    return name[0].toUpperCase() + name.substring(1);
  }

  IconData get icon {
    switch (this) {
      case FoodCategory.breakfast:
        return Icons.egg_alt;
      case FoodCategory.lunch:
        return Icons.lunch_dining;
      case FoodCategory.dinner:
        return Icons.dinner_dining;
      case FoodCategory.snack:
        return Icons.cookie;
      case FoodCategory.drink:
        return Icons.local_cafe;
    }
  }

  Color get color {
    switch (this) {
      case FoodCategory.breakfast:
        return const Color(0xFFE8A93C); // warm yellow
      case FoodCategory.lunch:
        return const Color(0xFF7D9B76); // sage green
      case FoodCategory.dinner:
        return const Color(0xFFD4714E); // terracotta
      case FoodCategory.snack:
        return const Color(0xFFB07CC6); // purple
      case FoodCategory.drink:
        return const Color(0xFF5B9BD5); // blue
    }
  }

  /// Assign category based on time of day
  static FoodCategory fromTime(DateTime time) {
    final hour = time.hour;
    if (hour >= 5 && hour < 11) return FoodCategory.breakfast;
    if (hour >= 11 && hour < 15) return FoodCategory.lunch;
    if (hour >= 15 && hour < 17) return FoodCategory.snack;
    if (hour >= 17 && hour < 21) return FoodCategory.dinner;
    return FoodCategory.snack; // late night = snack
  }

  static FoodCategory fromString(String value) {
    return FoodCategory.values.firstWhere(
      (c) => c.name == value,
      orElse: () => FoodCategory.snack,
    );
  }
}

class FoodItem {
  final String name;
  final double carbs;
  final double? protein;
  final double? fat;
  final double? fiber;
  final double? calories;
  final String? details;
  final List<String> citations;
  final DateTime loggedAt;
  final FoodCategory category;
  final bool isManualEntry;

  FoodItem({
    required this.name,
    required this.carbs,
    this.protein,
    this.fat,
    this.fiber,
    this.calories,
    this.details,
    this.citations = const [],
    this.isManualEntry = false,
    DateTime? loggedAt,
    FoodCategory? category,
  })  : loggedAt = loggedAt ?? DateTime.now(),
        category = category ?? FoodCategory.fromTime(loggedAt ?? DateTime.now());

  bool get hasMacros => protein != null || fat != null || fiber != null || calories != null;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'carbs': carbs,
      'loggedAt': loggedAt.toIso8601String(),
      'category': category.name,
      if (protein != null) 'protein': protein,
      if (fat != null) 'fat': fat,
      if (fiber != null) 'fiber': fiber,
      if (calories != null) 'calories': calories,
      if (details != null) 'details': details,
      if (citations.isNotEmpty) 'citations': citations,
      if (isManualEntry) 'isManualEntry': true,
    };
  }

  static DateTime? _parseLoggedAt(dynamic value, String name) {
    if (value == null) {
      debugPrint('FoodItem: missing loggedAt for "$name", defaulting to now');
      return null;
    }
    final parsed = DateTime.tryParse(value as String);
    if (parsed == null) {
      debugPrint('FoodItem: malformed loggedAt "$value" for "$name", defaulting to now');
    }
    return parsed;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    final loggedAt = _parseLoggedAt(json['loggedAt'], json['name'] as String);
    return FoodItem(
      name: json['name'] as String,
      carbs: (json['carbs'] as num).toDouble(),
      protein: _parseDouble(json['protein']),
      fat: _parseDouble(json['fat']),
      fiber: _parseDouble(json['fiber']),
      calories: _parseDouble(json['calories']),
      details: json['details'] as String?,
      citations: json['citations'] != null
          ? List<String>.from(json['citations'])
          : const [],
      loggedAt: loggedAt,
      isManualEntry: json['isManualEntry'] as bool? ?? false,
      category: json['category'] != null
          ? FoodCategory.fromString(json['category'] as String)
          : null,
    );
  }
}
