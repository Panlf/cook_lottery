import 'dart:async';

import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/category.dart';
import '../models/dish.dart';
import '../models/meal_record.dart';
import '../theme/app_theme.dart';
import '../utils/feedback.dart';
import '../utils/lottery.dart';
import '../utils/meal_type.dart';
import '../widgets/dish_image.dart';

class BlindBoxScreen extends StatefulWidget {
  const BlindBoxScreen({super.key});

  @override
  State<BlindBoxScreen> createState() => BlindBoxScreenState();
}

class BlindBoxScreenState extends State<BlindBoxScreen> {
  List<DishCategory> _categories = [];
  Map<int, List<Dish>> _dishesByCategory = {};
  final Set<int> _selectedCategoryIds = {};
  final Map<int, int> _dishCountPerCategory = {};
  String _mealType = 'lunch';

  /// 抽签时是否优先排除近几天吃过的菜。
  bool _excludeRecent = true;
  int _excludeDays = 3;

  List<Dish> _rollingDishes = [];
  List<Dish> _resultDishes = [];
  bool _isSpinning = false;
  bool _isConfirming = false;
  Timer? _spinTimer;

  Map<int, DishCategory> get _categoryById => {
    for (final cat in _categories) cat.id!: cat,
  };

  bool get _allSelected =>
      _categories.isNotEmpty &&
      _categories.every((cat) => _selectedCategoryIds.contains(cat.id));

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    _spinTimer?.cancel();
    super.dispose();
  }

  /// 重新加载数据；页签切换时由 HomeScreen 调用。
  void reload() => _loadData();

  Future<void> _loadData() async {
    try {
      final categories = await DatabaseHelper.instance.getAllCategories();
      final dishes = await DatabaseHelper.instance.getAllDishes();
      final dishesByCategory = {
        for (final cat in categories)
          cat.id!: dishes.where((dish) => dish.categoryId == cat.id).toList(),
      };
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _dishesByCategory = dishesByCategory;
        _pruneSelection();
      });
    } catch (_) {
      // 刷新失败保留旧数据并提示，避免页面异常
      if (mounted) showErrorSnackBar(context, '数据刷新失败');
    }
  }

  /// 分类或菜品变化后，清理已失效的勾选并把每类数量收敛到合法范围。
  void _pruneSelection() {
    _selectedCategoryIds.removeWhere(
      (id) => (_dishesByCategory[id] ?? const <Dish>[]).isEmpty,
    );
    _dishCountPerCategory.removeWhere(
      (id, _) => !_selectedCategoryIds.contains(id),
    );
    for (final id in _selectedCategoryIds) {
      final max = _dishesByCategory[id]!.length;
      _dishCountPerCategory[id] = (_dishCountPerCategory[id] ?? 1).clamp(
        1,
        max,
      );
    }
  }

  void _toggleCategory(int categoryId) {
    if ((_dishesByCategory[categoryId] ?? const <Dish>[]).isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('该分类还没有菜品，先去菜谱库添加吧')));
      return;
    }
    setState(() {
      if (!_selectedCategoryIds.add(categoryId)) {
        _selectedCategoryIds.remove(categoryId);
        _dishCountPerCategory.remove(categoryId);
      } else {
        _dishCountPerCategory[categoryId] = 1;
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_allSelected) {
        _selectedCategoryIds.clear();
        _dishCountPerCategory.clear();
      } else {
        for (final cat in _categories) {
          if ((_dishesByCategory[cat.id] ?? const <Dish>[]).isEmpty) continue;
          _selectedCategoryIds.add(cat.id!);
          _dishCountPerCategory[cat.id!] ??= 1;
        }
      }
    });
  }

  void _updateDishCount(int categoryId, int count) {
    setState(() {
      final max = _dishesByCategory[categoryId]?.length ?? 1;
      _dishCountPerCategory[categoryId] = count.clamp(1, max);
    });
  }

  Future<void> _startSpin() async {
    if (_isSpinning) return;
    if (_selectedCategoryIds.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先选择至少一个分类')));
      return;
    }

    // 先置位再查询，避免排除查询期间被重复触发
    setState(() => _isSpinning = true);

    final excludeIds = _excludeRecent
        ? await DatabaseHelper.instance.getEatenDishIdsSince(
            DateTime.now().subtract(Duration(days: _excludeDays)),
          )
        : const <int>{};
    if (!mounted) return;

    setState(() {
      _resultDishes = [];
      _rollingDishes = _pick(excludeIds);
    });

    // 滚动若干拍后落定结果，营造抽签的仪式感。
    var ticks = 0;
    _spinTimer?.cancel();
    _spinTimer = Timer.periodic(const Duration(milliseconds: 90), (timer) {
      ticks++;
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (ticks >= 9) {
        timer.cancel();
        setState(() {
          _resultDishes = _pick(excludeIds);
          _isSpinning = false;
        });
      } else {
        setState(() => _rollingDishes = _pick(excludeIds));
      }
    });
  }

  List<Dish> _pick(Set<int> excludeIds) {
    return LotteryPicker.pick(
      selectedCategoryIds: _selectedCategoryIds,
      dishesByCategory: _dishesByCategory,
      countPerCategory: _dishCountPerCategory,
      excludeDishIds: excludeIds,
    );
  }

  Future<void> _confirmMeal() async {
    if (_resultDishes.isEmpty || _isConfirming) return;
    setState(() => _isConfirming = true);
    final record = MealRecord(
      date: DateTime.now(),
      mealType: _mealType,
      dishIds: _resultDishes.map((dish) => dish.id).join(','),
    );
    try {
      await DatabaseHelper.instance.insertMealRecord(record);
    } catch (_) {
      if (mounted) showErrorSnackBar(context, '记录失败，请重试');
      return;
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已记录今日${_mealType.mealLabel} 🎉'),
        backgroundColor: AppTheme.successColor,
      ),
    );
    setState(() => _resultDishes = []);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('今日盲盒')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildMealTypeSelector(),
            const SizedBox(height: 16),
            _buildExcludeCard(),
            const SizedBox(height: 16),
            _buildCategorySelection(),
            const SizedBox(height: 24),
            _buildSpinButton(),
            if (_isSpinning) ...[
              const SizedBox(height: 24),
              _buildRollingCard(),
            ] else if (_resultDishes.isNotEmpty) ...[
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
            const Text(
              '选择餐次',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'lunch', label: Text('☀️ 午餐')),
                ButtonSegment(value: 'dinner', label: Text('🌙 晚餐')),
              ],
              selected: {_mealType},
              onSelectionChanged: (selection) =>
                  setState(() => _mealType = selection.first),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExcludeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                '避开最近吃过的菜',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                '抽签时优先排除近几天出现过的菜品',
                style: TextStyle(fontSize: 12),
              ),
              value: _excludeRecent,
              onChanged: (value) => setState(() => _excludeRecent = value),
            ),
            if (_excludeRecent)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Text(
                      '时间范围',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 1, label: Text('1 天')),
                          ButtonSegment(value: 3, label: Text('3 天')),
                          ButtonSegment(value: 7, label: Text('7 天')),
                        ],
                        selected: {_excludeDays},
                        onSelectionChanged: (selection) =>
                            setState(() => _excludeDays = selection.first),
                      ),
                    ),
                  ],
                ),
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
                const Text(
                  '选择分组',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                TextButton(
                  onPressed: _categories.isEmpty ? null : _toggleSelectAll,
                  child: Text(_allSelected ? '取消全选' : '全选'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_categories.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    '暂无分类，请先去菜谱添加',
                    style: TextStyle(color: AppTheme.textHint),
                  ),
                ),
              )
            else
              ..._categories.map(_buildCategoryRow),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryRow(DishCategory cat) {
    final isSelected = _selectedCategoryIds.contains(cat.id);
    final dishCount = _dishesByCategory[cat.id]?.length ?? 0;
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
          Expanded(
            child: GestureDetector(
              onTap: () => _toggleCategory(cat.id!),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.textHint,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(cat.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cat.name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '$dishCount 道菜',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textHint,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isSelected && dishCount > 0)
            Row(
              children: [
                _buildCountButton(
                  icon: Icons.remove,
                  enabled: selectedCount > 1,
                  onTap: () => _updateDishCount(cat.id!, selectedCount - 1),
                ),
                const SizedBox(width: 12),
                Text(
                  '$selectedCount',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 12),
                _buildCountButton(
                  icon: Icons.add,
                  enabled: selectedCount < dishCount,
                  onTap: () => _updateDishCount(cat.id!, selectedCount + 1),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCountButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: enabled ? AppTheme.primaryColor : AppTheme.dividerColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? Colors.white : AppTheme.textHint,
        ),
      ),
    );
  }

  Widget _buildSpinButton() {
    return ElevatedButton(
      onPressed: _isSpinning ? null : _startSpin,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 18),
      ),
      child: _isSpinning
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.casino, size: 22),
                SizedBox(width: 8),
                Text(
                  '🎲 开始抽签',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
    );
  }

  Widget _buildRollingCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              '🎲 抽签中...',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ..._rollingDishes.map(
              (dish) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: DishImage(
                  imagePath: dish.imagePath,
                  width: 48,
                  height: 48,
                  iconSize: 24,
                ),
                title: Text(
                  dish.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final categoryById = _categoryById;
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
                  '✨ 今日${_mealType.mealLabel}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _startSpin,
                  tooltip: '重新抽签',
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            ..._resultDishes.map((dish) {
              final category = categoryById[dish.categoryId];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    DishImage(
                      imagePath: dish.imagePath,
                      width: 56,
                      height: 56,
                      iconSize: 24,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dish.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          if (category != null)
                            Text(
                              '${category.emoji} ${category.name}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textHint,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isConfirming ? null : _confirmMeal,
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
