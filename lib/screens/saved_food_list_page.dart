import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/food_item.dart';
import '../config/app_colors.dart';
import '../config/app_icons.dart';

class SavedFoodListPage extends StatefulWidget {
  final void Function(FoodItem)? onAddFood;

  const SavedFoodListPage({super.key, this.onAddFood});

  @override
  State<SavedFoodListPage> createState() => _SavedFoodListPageState();
}

class _SavedFoodListPageState extends State<SavedFoodListPage> {
  List<FoodItem> _savedFoods = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedFoods();
  }

  Future<void> _loadSavedFoods() async {
    final prefs = await SharedPreferences.getInstance();
    final savedJson = prefs.getString('saved_foods');

    if (savedJson != null) {
      final List<dynamic> decoded = jsonDecode(savedJson);
      setState(() {
        _savedFoods = decoded.map((item) => FoodItem.fromJson(item)).toList();
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _resetSavedFoods() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Saved Foods'),
        content: const Text('Are you sure you want to clear all saved foods?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_foods');
      setState(() {
        _savedFoods.clear();
      });
    }
  }

  Future<void> _removeSavedFood(int index) async {
    setState(() {
      _savedFoods.removeAt(index);
    });
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_savedFoods.map((f) => f.toJson()).toList());
    await prefs.setString('saved_foods', encoded);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Food',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          if (_savedFoods.isNotEmpty)
            TextButton(
              onPressed: _resetSavedFoods,
              child: const Text(
                'Reset',
                style: TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _savedFoods.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bookmark_border,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No saved foods yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Swipe right on food items to save them here',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(24.0),
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
                        child: AppIcons.deleteIcon(
                          size: 28,
                          color: Colors.white,
                        ),
                      ),
                      child: GestureDetector(
                        onTap: widget.onAddFood != null
                            ? () {
                                HapticFeedback.lightImpact();
                                widget.onAddFood!(item);
                                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${item.name} added (${item.carbs.toStringAsFixed(1)}g)'),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 0,
                          ),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey,
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              Text(
                                '${item.carbs.toStringAsFixed(1)}g',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
