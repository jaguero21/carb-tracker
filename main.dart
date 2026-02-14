import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/perplexity_service.dart';
import 'models/food_item.dart';

void main() {
  runApp(const CarbTrackerApp());
}

class CarbTrackerApp extends StatelessWidget {
  const CarbTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Carb Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const CarbTrackerHome(),
    );
  }
}

class CarbTrackerHome extends StatefulWidget {
  const CarbTrackerHome({super.key});

  @override
  State<CarbTrackerHome> createState() => _CarbTrackerHomeState();
}

class _CarbTrackerHomeState extends State<CarbTrackerHome> {
  final TextEditingController _foodController = TextEditingController();
  final PerplexityService _perplexityService = PerplexityService();
  
  List<FoodItem> _foodItems = [];
  double _totalCarbs = 0.0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTotal = prefs.getDouble('total_carbs') ?? 0.0;
    setState(() {
      _totalCarbs = savedTotal;
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('total_carbs', _totalCarbs);
  }

  Future<void> _addFood() async {
    final foodText = _foodController.text.trim();
    if (foodText.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final carbCount = await _perplexityService.getCarbCount(foodText);
      
      final newItem = FoodItem(
        name: foodText,
        carbs: carbCount,
      );

      setState(() {
        _foodItems.insert(0, newItem);
        _totalCarbs += carbCount;
        _isLoading = false;
        _foodController.clear();
      });

      await _saveData();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  void _resetTotal() {
    setState(() {
      _foodItems.clear();
      _totalCarbs = 0.0;
    });
    _saveData();
  }

  void _removeItem(int index) {
    setState(() {
      _totalCarbs -= _foodItems[index].carbs;
      _foodItems.removeAt(index);
    });
    _saveData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Total Display
              Container(
                padding: const EdgeInsets.symmetric(vertical: 32.0),
                child: Column(
                  children: [
                    const Text(
                      'Total Carbs',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_totalCarbs.toStringAsFixed(1)}g',
                      style: const TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w300,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),

              // Input Field
              TextField(
                controller: _foodController,
                decoration: const InputDecoration(
                  hintText: 'Enter food item...',
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey, width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black, width: 1),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                onSubmitted: (_) => _addFood(),
              ),

              const SizedBox(height: 16),

              // Add Button
              ElevatedButton(
                onPressed: _isLoading ? null : _addFood,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Add Food',
                        style: TextStyle(
                          fontSize: 16,
                          letterSpacing: 1.2,
                        ),
                      ),
              ),

              const SizedBox(height: 32),

              // Food List Header
              if (_foodItems.isNotEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TODAY',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.5,
                        color: Colors.grey,
                      ),
                    ),
                    TextButton(
                      onPressed: _resetTotal,
                      child: const Text(
                        'Reset',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),

              // Food List
              Expanded(
                child: _foodItems.isEmpty
                    ? const Center(
                        child: Text(
                          'No foods added yet',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _foodItems.length,
                        itemBuilder: (context, index) {
                          final item = _foodItems[index];
                          return Dismissible(
                            key: Key('${item.name}_$index'),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) => _removeItem(index),
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 16),
                              color: Colors.red,
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
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
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _foodController.dispose();
    super.dispose();
  }
}
