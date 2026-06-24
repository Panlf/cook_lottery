import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/dish.dart';
import '../models/meal_record.dart';
import '../theme/app_theme.dart';

class MealHistoryScreen extends StatefulWidget {
  const MealHistoryScreen({super.key});

  @override
  State<MealHistoryScreen> createState() => _MealHistoryScreenState();
}

class _MealHistoryScreenState extends State<MealHistoryScreen> {
  List<MealRecord> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final records = await DatabaseHelper.instance.getAllMealRecords();
    setState(() {
      _records = records;
      _isLoading = false;
    });
  }

  Map<String, List<MealRecord>> get _groupedRecords {
    final map = <String, List<MealRecord>>{};
    for (final record in _records) {
      final key = DateFormat('yyyy年MM月dd日').format(record.date);
      map.putIfAbsent(key, () => []).add(record);
    }
    return map;
  }

  void _deleteRecord(MealRecord record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除记录'),
        content: const Text('确定要删除这条饮食记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.deleteColor),
            onPressed: () async {
              await DatabaseHelper.instance.deleteMealRecord(record.id!);
              Navigator.pop(context);
              _loadData();
            },
            child: const Text('删除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRatingDialog(MealRecord record) {
    int rating = record.rating ?? 3;
    final notesController = TextEditingController(text: record.notes ?? '');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('评价这一餐'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => GestureDetector(
                  onTap: () => setDialogState(() => rating = i + 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      i < rating ? Icons.star : Icons.star_border,
                      size: 36,
                      color: AppTheme.starColor,
                    ),
                  ),
                )),
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
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                final updated = record.copyWith(
                  rating: rating,
                  notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                );
                await DatabaseHelper.instance.updateMealRecord(updated);
                Navigator.pop(context);
                _loadData();
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<Dish>> _getDishesForRecord(MealRecord record) async {
    final dishes = <Dish>[];
    for (final id in record.dishIdList) {
      final dish = await DatabaseHelper.instance.getDish(id);
      if (dish != null) dishes.add(dish);
    }
    return dishes;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('饮食记录')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : _records.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today, size: 80, color: AppTheme.textHint.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      const Text('还没有饮食记录', style: TextStyle(color: AppTheme.textHint, fontSize: 16)),
                      const SizedBox(height: 8),
                      const Text('去盲盒页面抽签吧！', style: TextStyle(color: AppTheme.textHint, fontSize: 13)),
                    ],
                  ),
                )
              : _buildHistoryList(),
    );
  }

  Widget _buildHistoryList() {
    final grouped = _groupedRecords;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
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
            ...records.map((record) => _buildRecordCard(record)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: record.mealType == 'lunch'
                          ? const Color(0xFFFFF3E0)
                          : const Color(0xFFE8EAF6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      record.mealType == 'lunch' ? '☀️ 午餐' : '🌙 晚餐',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: record.mealType == 'lunch'
                            ? const Color(0xFFE65100)
                            : const Color(0xFF283593),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (record.rating != null)
                    Row(
                      children: List.generate(5, (i) => Icon(
                        i < record.rating! ? Icons.star : Icons.star_border,
                        size: 16,
                        color: AppTheme.starColor,
                      )),
                    )
                  else
                    const Text('点击评价', style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                ],
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<Dish>>(
                future: _getDishesForRecord(record),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox(height: 40);
                  final dishes = snapshot.data!;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: dishes.map((dish) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.dividerColor),
                      ),
                      child: Text(dish.name, style: const TextStyle(fontSize: 13)),
                    )).toList(),
                  );
                },
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
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
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
