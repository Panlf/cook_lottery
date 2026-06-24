import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/dish.dart';
import '../models/category.dart';
import '../models/meal_record.dart';
import '../theme/app_theme.dart';

class BlindBoxScreen extends StatefulWidget {
  const BlindBoxScreen({super.key});

  @override
  State<BlindBoxScreen> createState() => _BlindBoxScreenState();
}

class _BlindBoxScreenState extends State<BlindBoxScreen> {
  List<DishCategory> _categories = [];
  Map<int, List<Dish>> _dishesByCategory = {};
  Set<int> _selectedCategoryIds = {};
  Map<int, int> _dishCountPerCategory = {};
  String _mealType = 'lunch';
  List<Dish> _resultDishes = [];
  bool _isSpinning = false;
  bool _showResult = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final categories = await DatabaseHelper.instance.getAllCategories();
    final dishesByCategory = <int, List<Dish>>{};
    for (final cat in categories) {
      dishesByCategory[cat.id!] = await DatabaseHelper.instance.getDishesByCategory(cat.id!);
    }
    setState(() {
      _categories = categories;
      _dishesByCategory = dishesByCategory;
    });
  }

  void _toggleCategory(int catId) {
    setState(() {
      if (_selectedCategoryIds.contains(catId)) {
        _selectedCategoryIds.remove(catId);
        _dishCountPerCategory.remove(catId);
      } else {
        _selectedCategoryIds.add(catId);
        final dishes = _dishesByCategory[catId] ?? [];
        _dishCountPerCategory[catId] = min(1, dishes.length);
      }
    });
  }

  void _updateDishCount(int catId, int count) {
    final maxCount = (_dishesByCategory[catId]?.length ?? 0);
    setState(() {
      _dishCountPerCategory[catId] = count.clamp(1, maxCount);
    });
  }

  void _randomize() {
    if (_selectedCategoryIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择至少一个分类')),
      );
      return;
    }

    setState(() {
      _isSpinning = true;
      _showResult = false;
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      final result = <Dish>[];
      for (final catId in _selectedCategoryIds) {
        final dishes = _dishesByCategory[catId] ?? [];
        if (dishes.isEmpty) continue;
        final count = _dishCountPerCategory[catId] ?? 1;
        final shuffled = List<Dish>.from(dishes)..shuffle();
        result.addAll(shuffled.take(count));
      }
      result.shuffle();
      setState(() {
        _resultDishes = result;
        _isSpinning = false;
        _showResult = true;
      });
    });
  }

  Future<void> _confirmMeal() async {
    if (_resultDishes.isEmpty) return;

    final record = MealRecord(
      date: DateTime.now(),
      mealType: _mealType,
      dishIds: _resultDishes.map((d) => d.id).join(','),
    );
    await DatabaseHelper.instance.insertMealRecord(record);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已记录今日${_mealType == "lunch" ? "午餐" : "晚餐"} 🎉'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      setState(() {
        _showResult = false;
        _resultDishes = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('今日盲盒'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildMealTypeSelector(),
            const SizedBox(height: 20),
            _buildCategorySelection(),
            const SizedBox(height: 24),
            _buildSpinButton(),
            if (_showResult) ...[
              const SizedBox(height: 24),
              _buildResultCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMealTypeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('选择餐次', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _mealType = 'lunch'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _mealType == 'lunch' ? AppTheme.primaryColor : AppTheme.accentColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '☀️ 午餐',
                          style: TextStyle(
                            color: _mealType == 'lunch' ? Colors.white : AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _mealType = 'dinner'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _mealType == 'dinner' ? AppTheme.primaryColor : AppTheme.accentColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '🌙 晚餐',
                          style: TextStyle(
                            color: _mealType == 'dinner' ? Colors.white : AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('选择分组', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                TextButton(
                  onPressed: () {
                    if (_selectedCategoryIds.length == _categories.length) {
                      setState(() {
                        _selectedCategoryIds.clear();
                        _dishCountPerCategory.clear();
                      });
                    } else {
                      setState(() {
                        for (final cat in _categories) {
                          _selectedCategoryIds.add(cat.id!);
                          final dishes = _dishesByCategory[cat.id!] ?? [];
                          _dishCountPerCategory[cat.id!] = min(1, dishes.length);
                        }
                      });
                    }
                  },
                  child: Text(
                    _selectedCategoryIds.length == _categories.length ? '取消全选' : '全选',
                    style: const TextStyle(color: AppTheme.primaryColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_categories.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('暂无分类，请先去菜谱添加', style: TextStyle(color: AppTheme.textHint)),
                ),
              )
            else
              ..._categories.map((cat) {
                final isSelected = _selectedCategoryIds.contains(cat.id!);
                final dishCount = _dishesByCategory[cat.id!]?.length ?? 0;
                final selectedCount = _dishCountPerCategory[cat.id!] ?? 1;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.accentColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppTheme.primaryColor : AppTheme.dividerColor,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => _toggleCategory(cat.id!),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                              color: isSelected ? AppTheme.primaryColor : AppTheme.textHint,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Text(cat.emoji, style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                                Text('$dishCount 道菜', style: const TextStyle(fontSize: 12, color: AppTheme.textHint)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (isSelected && dishCount > 0)
                        Row(
                          children: [
                            GestureDetector(
                              onTap: selectedCount > 1
                                  ? () => _updateDishCount(cat.id!, selectedCount - 1)
                                  : null,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: selectedCount > 1 ? AppTheme.primaryColor : AppTheme.dividerColor,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  Icons.remove,
                                  size: 16,
                                  color: selectedCount > 1 ? Colors.white : AppTheme.textHint,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '$selectedCount',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: selectedCount < dishCount
                                  ? () => _updateDishCount(cat.id!, selectedCount + 1)
                                  : null,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: selectedCount < dishCount ? AppTheme.primaryColor : AppTheme.dividerColor,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  Icons.add,
                                  size: 16,
                                  color: selectedCount < dishCount ? Colors.white : AppTheme.textHint,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildSpinButton() {
    return ElevatedButton(
      onPressed: _isSpinning ? null : _randomize,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 18),
      ),
      child: _isSpinning
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
          : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.casino, size: 22),
                SizedBox(width: 8),
                Text('🎲 开始抽签', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
    );
  }

  Widget _buildResultCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '✨ 今日${_mealType == "lunch" ? "午餐" : "晚餐"}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _randomize,
                  tooltip: '重新抽签',
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            ..._resultDishes.map((dish) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: dish.imagePath != null && File(dish.imagePath!).existsSync()
                        ? Image.file(File(dish.imagePath!), width: 56, height: 56, fit: BoxFit.cover)
                        : Container(
                            width: 56,
                            height: 56,
                            color: AppTheme.accentColor,
                            child: const Icon(Icons.restaurant, color: AppTheme.textHint),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(dish.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        FutureBuilder<DishCategory?>(
                          future: DatabaseHelper.instance.getCategory(dish.categoryId),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data != null) {
                              return Text(
                                '${snapshot.data!.emoji} ${snapshot.data!.name}',
                                style: const TextStyle(fontSize: 12, color: AppTheme.textHint),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _confirmMeal,
                icon: const Icon(Icons.check, size: 20),
                label: const Text('确定，就吃这些！'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
