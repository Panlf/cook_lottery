import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/database_helper.dart';
import '../models/category.dart';
import '../models/dish.dart';
import '../models/meal_record.dart';
import '../services/image_service.dart';
import '../theme/app_theme.dart';
import '../utils/feedback.dart';
import '../utils/meal_type.dart';
import '../widgets/dish_image.dart';
import '../widgets/error_state.dart';
import '../widgets/image_source_sheet.dart';
import '../widgets/star_rating.dart';
import 'add_dish_screen.dart';

class DishDetailScreen extends StatefulWidget {
  final Dish dish;

  const DishDetailScreen({super.key, required this.dish});

  @override
  State<DishDetailScreen> createState() => _DishDetailScreenState();
}

class _DishDetailScreenState extends State<DishDetailScreen> {
  static final _dateFormat = DateFormat('yyyy/MM/dd');

  late Dish _dish;
  DishCategory? _category;
  List<MealRecord> _history = [];
  int _mealCount = 0;
  bool _isLoading = true;
  bool _loadError = false;

  @override
  void initState() {
    super.initState();
    _dish = widget.dish;
    _loadData();
  }

  void _retry() {
    setState(() {
      _isLoading = true;
      _loadError = false;
    });
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final category = await DatabaseHelper.instance.getCategory(
        _dish.categoryId,
      );
      final history = await DatabaseHelper.instance
          .getMealRecordsContainingDish(_dish.id!);
      // 上桌次数用完整计数查询，不随最近列表的条数上限截断
      final count = await DatabaseHelper.instance
          .countMealRecordsContainingDish(_dish.id!);
      if (!mounted) return;
      setState(() {
        _category = category;
        _history = history;
        _mealCount = count;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = true;
      });
    }
  }

  Future<void> _replaceImage() async {
    final newPath = await pickAndPersistImage(context);
    if (newPath == null || !mounted) return;
    final oldPath = _dish.imagePath;
    final updated = _dish.copyWith(imagePath: newPath);
    try {
      await DatabaseHelper.instance.updateDish(updated);
    } catch (_) {
      await ImageService.delete(newPath); // 保存失败回收新图，避免孤儿文件
      if (mounted) showErrorSnackBar(context, '更换图片失败');
      return;
    }
    await ImageService.delete(oldPath);
    if (!mounted) return;
    setState(() => _dish = updated);
  }

  Future<void> _editDish() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddDishScreen(dish: _dish)),
    );
    final updated = await DatabaseHelper.instance.getDish(_dish.id!);
    if (!mounted) return;
    if (updated == null) {
      // 菜品已在编辑页被删除
      Navigator.pop(context);
      return;
    }
    setState(() => _dish = updated);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: '编辑菜品',
                onPressed: _editDish,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  DishImage(imagePath: _dish.imagePath, iconSize: 80),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.6),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 100,
                    child: Text(
                      _dish.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: GestureDetector(
                      onTap: _replaceImage,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: AppTheme.primaryColor,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '换图',
                              style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _loadError
                  ? ErrorState(message: '菜品信息加载失败', onRetry: _retry)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoSection(),
                        const SizedBox(height: 24),
                        _buildHistorySection(),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    final category = _category;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '基本信息',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              '分类',
              category == null ? '-' : '${category.emoji} ${category.name}',
            ),
            const SizedBox(height: 8),
            _buildInfoRow('添加时间', _dateFormat.format(_dish.createdAt)),
            const SizedBox(height: 8),
            _buildInfoRow('上桌次数', _isLoading ? '-' : '$_mealCount 次'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildHistorySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _mealCount > _history.length ? '最近搭配（共 $_mealCount 次）' : '最近搭配',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryColor,
                  ),
                ),
              )
            else if (_history.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    '暂无搭配记录',
                    style: TextStyle(color: AppTheme.textHint),
                  ),
                ),
              )
            else
              ..._history.map(
                (record) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.accentColor,
                    child: Text(
                      record.mealType.mealShortLabel,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  title: Text(
                    _dateFormat.format(record.date),
                    style: const TextStyle(fontSize: 14),
                  ),
                  trailing: record.rating != null
                      ? StarRating(rating: record.rating!)
                      : const Text(
                          '未评价',
                          style: TextStyle(
                            color: AppTheme.textHint,
                            fontSize: 12,
                          ),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
