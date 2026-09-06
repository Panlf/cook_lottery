import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/database_helper.dart';
import '../models/dish.dart';
import '../models/meal_record.dart';
import '../theme/app_theme.dart';
import '../utils/feedback.dart';
import '../utils/meal_stats.dart';
import '../utils/meal_type.dart';
import '../widgets/error_state.dart';
import '../widgets/star_rating.dart';
import 'add_meal_record_screen.dart';

/// 评价弹窗的操作结果。
enum _RatingAction { save, cancel, clear }

class MealHistoryScreen extends StatefulWidget {
  const MealHistoryScreen({super.key});

  @override
  State<MealHistoryScreen> createState() => MealHistoryScreenState();
}

class MealHistoryScreenState extends State<MealHistoryScreen> {
  List<MealRecord> _records = [];
  Map<int, Dish> _dishById = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    reload();
  }

  /// 重新加载数据；页签切换时由 HomeScreen 调用。
  void reload() => _loadData();

  Future<void> _loadData() async {
    try {
      final records = await DatabaseHelper.instance.getAllMealRecords();
      final dishIds = {for (final record in records) ...record.dishIdList};
      final dishes = await DatabaseHelper.instance.getDishesByIds(
        dishIds.toList(),
      );
      if (!mounted) return;
      setState(() {
        _records = records;
        _dishById = {for (final dish in dishes) dish.id!: dish};
        _isLoading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = '饮食记录加载失败';
      });
    }
  }

  Map<String, List<MealRecord>> get _groupedRecords {
    final map = <String, List<MealRecord>>{};
    for (final record in _records) {
      map
          .putIfAbsent(DateFormat('yyyy年MM月dd日').format(record.date), () => [])
          .add(record);
    }
    return map;
  }

  void _deleteRecord(MealRecord record) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除记录'),
        content: const Text('确定要删除这条饮食记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.deleteColor,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await DatabaseHelper.instance.deleteMealRecord(record.id!);
              } catch (_) {
                if (mounted) showErrorSnackBar(context, '删除失败，请重试');
                return;
              }
              _loadData();
            },
            child: const Text('删除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// 评价/清除评价/取消；控制器在弹窗关闭后统一释放。
  Future<void> _showRatingDialog(MealRecord record) async {
    int rating = record.rating ?? 3;
    final notesController = TextEditingController(text: record.notes);
    try {
      final action = await showDialog<_RatingAction>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('评价这一餐'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: StarRating(
                    rating: rating,
                    size: 36,
                    onChanged: (value) => setDialogState(() => rating = value),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    hintText: '写下你的心得...',
                    prefixIcon: Icon(Icons.edit_note),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              if (record.rating != null)
                TextButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext, _RatingAction.clear),
                  child: const Text('清除评价'),
                ),
              TextButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, _RatingAction.cancel),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, _RatingAction.save),
                child: const Text('保存'),
              ),
            ],
          ),
        ),
      );

      // 读值要在控制器释放之前完成
      final notes = notesController.text.trim();
      if (action == _RatingAction.save) {
        try {
          await DatabaseHelper.instance.updateMealRecord(
            record.copyWith(
              rating: rating,
              notes: notes.isEmpty ? null : notes,
            ),
          );
        } catch (_) {
          if (mounted) showErrorSnackBar(context, '保存评价失败');
        }
        _loadData();
      } else if (action == _RatingAction.clear) {
        try {
          await DatabaseHelper.instance.updateMealRecord(
            record.copyWith(rating: null),
          );
        } catch (_) {
          if (mounted) showErrorSnackBar(context, '清除评价失败');
        }
        _loadData();
      }
    } finally {
      notesController.dispose();
    }
  }

  Future<void> _addManualRecord() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddMealRecordScreen()),
    );
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('饮食记录')),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : _error != null
          ? ErrorState(message: _error!, onRetry: reload)
          : _records.isEmpty
          ? _buildEmptyState()
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: _buildStatsCard(),
                ),
                Expanded(child: _buildHistoryList()),
              ],
            ),
      floatingActionButton: (_isLoading || _error != null)
          ? null
          : _buildManualRecordFab(),
    );
  }

  Widget _buildManualRecordFab() {
    return FloatingActionButton.extended(
      onPressed: _addManualRecord,
      icon: const Icon(Icons.edit_calendar),
      label: const Text('记一餐'),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today,
            size: 80,
            color: AppTheme.textHint.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            '还没有饮食记录',
            style: TextStyle(color: AppTheme.textHint, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            '去盲盒抽一餐，或点右下角「记一餐」手动记录',
            style: TextStyle(color: AppTheme.textHint, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    final stats = MealStats.compute(_records, dishById: _dishById);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStatItem('共 ${stats.totalMeals} 餐'),
                const SizedBox(width: 16),
                _buildStatItem('近 7 天 ${stats.weekMeals} 餐'),
                const Spacer(),
                StarRating(rating: stats.averageRating.round(), size: 14),
                const SizedBox(width: 6),
                Text(
                  stats.averageRating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (stats.topDishes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '🔥 最常吃：${stats.topDishes.map((t) => '${t.displayName} ×${t.count}').join('、')}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildHistoryList() {
    final grouped = _groupedRecords;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final dateKey = grouped.keys.elementAt(index);
        final records = grouped[dateKey]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                dateKey,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            ...records.map(_buildRecordCard),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildRecordCard(MealRecord record) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showRatingDialog(record),
        onLongPress: () => _deleteRecord(record),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: record.mealType.isLunch
                          ? const Color(0xFFFFF3E0)
                          : const Color(0xFFE8EAF6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${record.mealType.mealEmoji} ${record.mealType.mealLabel}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: record.mealType.isLunch
                            ? const Color(0xFFE65100)
                            : const Color(0xFF283593),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (record.rating != null)
                    StarRating(rating: record.rating!)
                  else
                    const Text(
                      '点击评价',
                      style: TextStyle(fontSize: 12, color: AppTheme.textHint),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: record.dishIdList
                    .map(
                      (id) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.dividerColor),
                        ),
                        child: Text(
                          _dishById[id]?.name ?? '已删除的菜',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    )
                    .toList(),
              ),
              if (record.notes != null && record.notes!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    record.notes!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
