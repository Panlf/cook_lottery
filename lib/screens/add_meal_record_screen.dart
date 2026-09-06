import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/database_helper.dart';
import '../models/dish.dart';
import '../models/meal_record.dart';
import '../theme/app_theme.dart';
import '../utils/feedback.dart';
import '../widgets/dish_image.dart';
import '../widgets/error_state.dart';

/// 手动记录一餐：选择日期、餐次和菜品，无需经过盲盒抽签。
/// 适合记录外出就餐或临时起意做的菜。
class AddMealRecordScreen extends StatefulWidget {
  const AddMealRecordScreen({super.key});

  @override
  State<AddMealRecordScreen> createState() => _AddMealRecordScreenState();
}

class _AddMealRecordScreenState extends State<AddMealRecordScreen> {
  final _notesController = TextEditingController();
  final _searchController = TextEditingController();
  final Set<int> _selectedDishIds = {};

  List<Dish> _dishes = [];
  String _mealType = 'lunch';
  DateTime _date = DateTime.now();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final dishes = await DatabaseHelper.instance.getAllDishes();
      if (!mounted) return;
      setState(() {
        _dishes = dishes;
        _isLoading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = '菜品加载失败';
      });
    }
  }

  List<Dish> get _filteredDishes {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _dishes;
    return _dishes
        .where((dish) => dish.name.toLowerCase().contains(query))
        .toList();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    final now = DateTime.now();
    setState(() {
      _date = DateTime(
        picked.year,
        picked.month,
        picked.day,
        now.hour,
        now.minute,
      );
    });
  }

  void _toggleDish(int dishId) {
    setState(() {
      if (!_selectedDishIds.add(dishId)) _selectedDishIds.remove(dishId);
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (_selectedDishIds.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请至少选择一道菜品')));
      return;
    }
    setState(() => _isSaving = true);

    try {
      final notes = _notesController.text.trim();
      final record = MealRecord(
        date: _date,
        mealType: _mealType,
        dishIds: _selectedDishIds.join(','),
        notes: notes.isEmpty ? null : notes,
      );
      await DatabaseHelper.instance.insertMealRecord(record);
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(context, '保存失败，请重试');
      return;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('记一餐')),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : _error != null
          ? ErrorState(message: _error!, onRetry: _loadData)
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildMealTypeSelector(),
                const SizedBox(height: 16),
                _buildDateSelector(),
                const SizedBox(height: 16),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    hintText: '写下这一餐的心得（可选）...',
                    prefixIcon: Icon(Icons.edit_note),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                _buildDishSelection(),
              ],
            ),
      bottomNavigationBar: _buildSaveButton(),
    );
  }

  Widget _buildMealTypeSelector() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'lunch', label: Text('☀️ 午餐')),
        ButtonSegment(value: 'dinner', label: Text('🌙 晚餐')),
      ],
      selected: {_mealType},
      onSelectionChanged: (selection) =>
          setState(() => _mealType = selection.first),
    );
  }

  Widget _buildDateSelector() {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.calendar_today, color: AppTheme.primaryColor),
        title: const Text('日期'),
        subtitle: Text(DateFormat('yyyy年MM月dd日').format(_date)),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.textHint),
        onTap: _pickDate,
      ),
    );
  }

  Widget _buildDishSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              _selectedDishIds.isEmpty
                  ? '选择吃过的菜品'
                  : '已选 ${_selectedDishIds.length} 道',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: '搜索菜品名称',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        if (_dishes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                '菜谱还是空的，先去添加菜品吧',
                style: TextStyle(color: AppTheme.textHint),
              ),
            ),
          )
        else if (_filteredDishes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                '没有找到匹配的菜品',
                style: TextStyle(color: AppTheme.textHint),
              ),
            ),
          )
        else
          ..._filteredDishes.map(_buildDishTile),
      ],
    );
  }

  Widget _buildDishTile(Dish dish) {
    final selected = _selectedDishIds.contains(dish.id);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: DishImage(
        imagePath: dish.imagePath,
        width: 48,
        height: 48,
        iconSize: 24,
      ),
      title: Text(dish.name),
      trailing: Icon(
        selected ? Icons.check_circle : Icons.add_circle_outline,
        color: selected ? AppTheme.primaryColor : AppTheme.textHint,
      ),
      onTap: () => _toggleDish(dish.id!),
    );
  }

  Widget _buildSaveButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: ElevatedButton.icon(
          onPressed: (_isSaving || _error != null) ? null : _save,
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.check, size: 20),
          label: Text(
            _selectedDishIds.isEmpty
                ? '保存'
                : '保存这一餐（已选 ${_selectedDishIds.length} 道）',
          ),
        ),
      ),
    );
  }
}
