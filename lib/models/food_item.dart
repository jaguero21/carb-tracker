import 'package:flutter/foundation.dart';

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

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      name: json['name'] as String,
      carbs: (json['carbs'] as num).toDouble(),
      details: json['details'] as String?,
      citations: json['citations'] != null
          ? List<String>.from(json['citations'])
          : const [],
      loggedAt: _parseLoggedAt(json['loggedAt'], json['name'] as String),
    );
  }
}
