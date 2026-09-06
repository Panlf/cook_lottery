import 'dart:io';

import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/category.dart';
import '../models/dish.dart';
import '../models/practice_record.dart';
import '../services/image_service.dart';
import '../theme/app_theme.dart';
import '../utils/feedback.dart';
import '../widgets/dish_image.dart';
import '../widgets/error_state.dart';
import '../widgets/image_source_sheet.dart';
import '../widgets/star_rating.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => PracticeScreenState();
}

class PracticeScreenState extends State<PracticeScreen> {
  List<PracticeRecord> _allRecords = [];
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
      final records = await DatabaseHelper.instance.getAllPracticeRecords();
      if (!mounted) return;
      setState(() {
        _allRecords = records;
        _isLoading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = '修炼记录加载失败';
      });
    }
  }

  /// 正在修炼（存在未升级记录）的菜品名，按最近一次修炼时间倒序。
  List<String> get _activeDishNames {
    final latestByName = <String, DateTime>{};
    for (final record in _allRecords) {
      if (record.isPromoted) continue;
      final latest = latestByName[record.dishName];
      if (latest == null || record.createdAt.isAfter(latest)) {
        latestByName[record.dishName] = record.createdAt;
      }
    }
    final names = latestByName.keys.toList()
      ..sort((a, b) => latestByName[b]!.compareTo(latestByName[a]!));
    return names;
  }

  List<PracticeRecord> _recordsOf(String dishName) {
    final records =
        _allRecords.where((record) => record.dishName == dishName).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return records;
  }

  /// 记录一次修炼。[existingName] 不为空时表示为已有菜品追加记录。
  Future<void> _showRecordDialog({String? existingName}) async {
    final nameController = TextEditingController(text: existingName);
    final notesController = TextEditingController();
    List<DishCategory> categories;
    try {
      categories = await DatabaseHelper.instance.getAllCategories();
    } catch (_) {
      if (mounted) showErrorSnackBar(context, '分类加载失败');
      return;
    }

    int? selectedCategoryId;
    if (existingName != null) {
      final existing = _recordsOf(existingName);
      if (existing.isNotEmpty) selectedCategoryId = existing.first.categoryId;
    }
    selectedCategoryId ??= categories.firstOrNull?.id;

    String? imagePath;
    int rating = 3;
    bool isSaving = false;
    if (!mounted) return;

    try {
      await showDialog(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(existingName == null ? '开始修炼' : '记录修炼'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (existingName == null)
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        hintText: '菜品名称（如：红烧肉）',
                      ),
                      autofocus: true,
                    ),
                  if (existingName == null) const SizedBox(height: 12),
                  if (categories.isEmpty)
                    const Text(
                      '还没有分类，请先到「菜谱库」页添加分类',
                      style: TextStyle(color: AppTheme.textHint, fontSize: 13),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.map((cat) {
                        final isSelected = cat.id == selectedCategoryId;
                        return ChoiceChip(
                          avatar: Text(cat.emoji),
                          label: Text(cat.name),
                          selected: isSelected,
                          onSelected: (_) =>
                              setDialogState(() => selectedCategoryId = cat.id),
                          selectedColor: AppTheme.primaryColor,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppTheme.textPrimary,
                          ),
                          checkmarkColor: Colors.white,
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () async {
                      // 权限被拒/复制失败等异常已在内部统一捕获并提示
                      final persisted = await pickAndPersistImage(context);
                      if (persisted != null) {
                        setDialogState(() => imagePath = persisted);
                      }
                    },
                    child: Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor,
                        borderRadius: BorderRadius.circular(12),
                        image: imagePath != null
                            ? DecorationImage(
                                image: FileImage(File(imagePath!)),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: imagePath == null
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_a_photo,
                                  size: 32,
                                  color: AppTheme.textHint,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '添加本次照片',
                                  style: TextStyle(
                                    color: AppTheme.textHint,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '本次评分',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: StarRating(
                      rating: rating,
                      size: 32,
                      onChanged: (value) =>
                          setDialogState(() => rating = value),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(hintText: '写下心得...'),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () => _savePracticeRecord(
                        dialogContext: dialogContext,
                        setDialogState: (saving) =>
                            setDialogState(() => isSaving = saving),
                        nameController: nameController,
                        notesController: notesController,
                        existingName: existingName,
                        selectedCategoryIdGetter: () => selectedCategoryId,
                        imagePathGetter: () => imagePath,
                        ratingGetter: () => rating,
                      ),
                child: const Text('保存'),
              ),
            ],
          ),
        ),
      );
    } finally {
      nameController.dispose();
      notesController.dispose();
    }
  }

  /// 保存修炼记录；读值都在弹窗关闭之前完成。
  Future<void> _savePracticeRecord({
    required BuildContext dialogContext,
    required ValueChanged<bool> setDialogState,
    required TextEditingController nameController,
    required TextEditingController notesController,
    required String? existingName,
    required int? Function() selectedCategoryIdGetter,
    required String? Function() imagePathGetter,
    required int Function() ratingGetter,
  }) async {
    final name = existingName ?? nameController.text.trim();
    final selectedCategoryId = selectedCategoryIdGetter();
    if (name.isEmpty || selectedCategoryId == null) {
      ScaffoldMessenger.of(
        dialogContext,
      ).showSnackBar(const SnackBar(content: Text('请填写菜品名称并选择分类')));
      return;
    }

    setDialogState(true);
    try {
      final notes = notesController.text.trim();
      final record = PracticeRecord(
        dishName: name,
        categoryId: selectedCategoryId,
        imagePath: imagePathGetter(),
        rating: ratingGetter(),
        notes: notes.isEmpty ? null : notes,
      );
      await DatabaseHelper.instance.insertPracticeRecord(record);
    } catch (_) {
      if (dialogContext.mounted) showErrorSnackBar(dialogContext, '保存失败，请重试');
      return;
    } finally {
      setDialogState(false);
    }
    if (dialogContext.mounted) Navigator.pop(dialogContext);
    _loadData();
  }

  Future<void> _promoteToLibrary(PracticeRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('升级到菜库'),
        content: Text('确定将「${record.dishName}」升级为正式菜品吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      // 菜库里已有同名菜品时直接关联，避免出现重复菜品。
      final existing = await DatabaseHelper.instance.getDishByName(
        record.dishName,
      );
      final dishId =
          existing?.id ??
          await DatabaseHelper.instance.insertDish(
            Dish(
              name: record.dishName,
              categoryId: record.categoryId,
              imagePath: record.imagePath,
            ),
          );
      await DatabaseHelper.instance.updatePracticeRecord(
        record.copyWith(isPromoted: true, promotedDishId: dishId),
      );
    } catch (_) {
      if (mounted) showErrorSnackBar(context, '升级失败，请重试');
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已升级到菜库 🎉'),
        backgroundColor: AppTheme.successColor,
      ),
    );
    _loadData();
  }

  Future<void> _deletePracticeRecord(PracticeRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除记录'),
        content: const Text('确定要删除这条修炼记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.deleteColor,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await DatabaseHelper.instance.deletePracticeRecord(record.id!);
    } catch (_) {
      if (mounted) showErrorSnackBar(context, '删除失败，请重试');
      return;
    }
    await _cleanupRecordImage(record);
    _loadData();
  }

  /// 清理修炼记录的图片：
  /// 未升级的记录图片直接删除；已升级的记录，图片可能已归属菜库菜品
  /// （升级时新建菜品的场景），只有确认不被菜品引用时才删除，避免孤儿文件。
  Future<void> _cleanupRecordImage(PracticeRecord record) async {
    if (record.imagePath == null) return;
    if (!record.isPromoted) {
      await ImageService.delete(record.imagePath);
      return;
    }
    final dish = record.promotedDishId == null
        ? null
        : await DatabaseHelper.instance.getDish(record.promotedDishId!);
    if (dish?.imagePath != record.imagePath) {
      await ImageService.delete(record.imagePath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dishNames = _isLoading ? const <String>[] : _activeDishNames;
    return Scaffold(
      appBar: AppBar(title: const Text('修炼模式')),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : _error != null
          ? ErrorState(message: _error!, onRetry: reload)
          : dishNames.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 80,
                    color: AppTheme.textHint.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '开始修炼新菜品',
                    style: TextStyle(color: AppTheme.textHint, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '在做菜过程中迭代提升',
                    style: TextStyle(color: AppTheme.textHint, fontSize: 13),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: dishNames.length,
              itemBuilder: (context, index) => _buildDishTile(dishNames[index]),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showRecordDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildDishTile(String dishName) {
    final records = _recordsOf(dishName);
    final hasPromoted = records.any((record) => record.isPromoted);
    final latestRating = records.firstOrNull?.rating;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDishDetail(dishName),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: hasPromoted
                        ? [
                            AppTheme.successColor,
                            AppTheme.successColor.withValues(alpha: 0.7),
                          ]
                        : [AppTheme.primaryColor, AppTheme.secondaryColor],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: hasPromoted
                      ? const Icon(Icons.check, color: Colors.white, size: 24)
                      : const Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                          size: 22,
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dishName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '已修炼 ${records.length} 次',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textHint,
                      ),
                    ),
                  ],
                ),
              ),
              if (latestRating != null)
                StarRating(rating: latestRating, size: 14),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AppTheme.textHint),
            ],
          ),
        ),
      ),
    );
  }

  void _showDishDetail(String dishName) {
    final records = _recordsOf(dishName);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dishName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: '追加一次修炼记录',
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _showRecordDialog(existingName: dishName);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: records.length,
                itemBuilder: (context, index) =>
                    _buildRecordTile(records[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordTile(PracticeRecord record) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DishImage(
                  imagePath: record.imagePath,
                  width: 60,
                  height: 60,
                  iconSize: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${record.createdAt.month}/${record.createdAt.day}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textHint,
                        ),
                      ),
                      const SizedBox(height: 4),
                      StarRating(rating: record.rating ?? 0, size: 16),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    record.isPromoted ? Icons.check_circle : Icons.upgrade,
                    color: record.isPromoted
                        ? AppTheme.successColor
                        : AppTheme.primaryColor,
                    size: 22,
                  ),
                  tooltip: record.isPromoted ? '已升级' : '升级到菜库',
                  onPressed: record.isPromoted
                      ? null
                      : () => _promoteToLibrary(record),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: AppTheme.deleteColor,
                  ),
                  onPressed: () => _deletePracticeRecord(record),
                ),
              ],
            ),
            if (record.notes != null && record.notes!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E5F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  record.notes!,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
