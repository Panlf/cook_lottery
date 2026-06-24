import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../database/database_helper.dart';
import '../models/dish.dart';
import '../models/category.dart';
import '../models/practice_record.dart';
import '../theme/app_theme.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  List<String> _dishNames = [];
  Map<String, List<PracticeRecord>> _recordsByDish = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final names = await DatabaseHelper.instance.getAllPracticeDishNames();
    final recordsByDish = <String, List<PracticeRecord>>{};
    for (final name in names) {
      recordsByDish[name] = await DatabaseHelper.instance.getPracticeRecordsByDish(name);
    }
    setState(() {
      _dishNames = names;
      _recordsByDish = recordsByDish;
      _isLoading = false;
    });
  }

  void _showAddPracticeDialog() {
    final nameController = TextEditingController();
    int? selectedCategoryId;
    List<DishCategory> categories = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => FutureBuilder<List<DishCategory>>(
          future: DatabaseHelper.instance.getAllCategories(),
          builder: (context, snapshot) {
            if (snapshot.hasData) categories = snapshot.data!;
            return AlertDialog(
              title: const Text('开始修炼'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(hintText: '菜品名称（如：红烧肉）'),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('选择分类', style: TextStyle(color: AppTheme.textSecondary)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories.map((cat) {
                      final isSelected = cat.id == selectedCategoryId;
                      return ChoiceChip(
                        avatar: Text(cat.emoji),
                        label: Text(cat.name),
                        selected: isSelected,
                        onSelected: (_) => setDialogState(() => selectedCategoryId = cat.id),
                        selectedColor: AppTheme.primaryColor,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppTheme.textPrimary,
                        ),
                        checkmarkColor: Colors.white,
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nameController.text.trim().isNotEmpty && selectedCategoryId != null) {
                      Navigator.pop(context);
                      _showAddRecordDialog(
                        dishName: nameController.text.trim(),
                        categoryId: selectedCategoryId!,
                      );
                    }
                  },
                  child: const Text('下一步'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showAddRecordDialog({String? dishName, int? categoryId}) async {
    final dishNameController = TextEditingController(text: dishName ?? '');
    int? selectedCategoryId = categoryId;
    List<DishCategory> categories = await DatabaseHelper.instance.getAllCategories();
    String? imagePath;
    int rating = 3;
    final notesController = TextEditingController();

    if (dishName != null) {
      final existingRecords = await DatabaseHelper.instance.getPracticeRecordsByDish(dishName);
      if (existingRecords.isNotEmpty) {
        selectedCategoryId = existingRecords.first.categoryId;
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(dishName != null ? '记录修炼' : '记录修炼'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dishName == null)
                  TextField(
                    controller: dishNameController,
                    decoration: const InputDecoration(hintText: '菜品名称'),
                  ),
                if (dishName == null) const SizedBox(height: 12),
                if (dishName == null)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories.map((cat) {
                      final isSelected = cat.id == selectedCategoryId;
                      return ChoiceChip(
                        avatar: Text(cat.emoji),
                        label: Text(cat.name),
                        selected: isSelected,
                        onSelected: (_) => setDialogState(() => selectedCategoryId = cat.id),
                        selectedColor: AppTheme.primaryColor,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppTheme.textPrimary,
                        ),
                        checkmarkColor: Colors.white,
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () async {
                    final source = await showModalBottomSheet<ImageSource>(
                      context: context,
                      builder: (context) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.camera_alt),
                              title: const Text('拍照'),
                              onTap: () => Navigator.pop(context, ImageSource.camera),
                            ),
                            ListTile(
                              leading: const Icon(Icons.photo_library),
                              title: const Text('相册'),
                              onTap: () => Navigator.pop(context, ImageSource.gallery),
                            ),
                          ],
                        ),
                      ),
                    );
                    if (source != null) {
                      final picker = ImagePicker();
                      final picked = await picker.pickImage(source: source, maxWidth: 1024, imageQuality: 85);
                      if (picked != null) setDialogState(() => imagePath = picked.path);
                    }
                  },
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor,
                      borderRadius: BorderRadius.circular(12),
                      image: imagePath != null && File(imagePath!).existsSync()
                          ? DecorationImage(image: FileImage(File(imagePath!)), fit: BoxFit.cover)
                          : null,
                    ),
                    child: imagePath == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo, size: 32, color: AppTheme.textHint),
                              SizedBox(height: 4),
                              Text('添加本次照片', style: TextStyle(color: AppTheme.textHint, fontSize: 13)),
                            ],
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('评分', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) => GestureDetector(
                    onTap: () => setDialogState(() => rating = i + 1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        i < rating ? Icons.star : Icons.star_border,
                        size: 32,
                        color: AppTheme.starColor,
                      ),
                    ),
                  )),
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
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = dishName ?? dishNameController.text.trim();
                if (name.isEmpty || selectedCategoryId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请填写完整信息')),
                  );
                  return;
                }
                final record = PracticeRecord(
                  dishName: name,
                  categoryId: selectedCategoryId!,
                  imagePath: imagePath,
                  rating: rating,
                  notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                );
                await DatabaseHelper.instance.insertPracticeRecord(record);
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

  void _showDishDetail(String dishName) {
    final records = _recordsByDish[dishName] ?? [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
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
                  Text(dishName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      Navigator.pop(context);
                      _showAddRecordDialog(dishName: dishName);
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
                itemBuilder: (context, index) {
                  final record = records[index];
                  return _buildRecordTile(record);
                },
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
                if (record.imagePath != null && File(record.imagePath!).existsSync())
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(File(record.imagePath!), width: 60, height: 60, fit: BoxFit.cover),
                  )
                else
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.restaurant, color: AppTheme.textHint),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${record.createdAt.month}/${record.createdAt.day}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textHint),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: List.generate(5, (i) => Icon(
                          i < (record.rating ?? 0) ? Icons.star : Icons.star_border,
                          size: 16,
                          color: AppTheme.starColor,
                        )),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    record.isPromoted ? Icons.check_circle : Icons.upgrade,
                    color: record.isPromoted ? AppTheme.successColor : AppTheme.primaryColor,
                    size: 22,
                  ),
                  onPressed: record.isPromoted ? null : () => _promoteToLibrary(record),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.deleteColor),
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
                child: Text(record.notes!, style: const TextStyle(fontSize: 13)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _promoteToLibrary(PracticeRecord record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('升级到菜库'),
        content: Text('确定将「${record.dishName}」升级为正式菜品吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final dish = Dish(
                name: record.dishName,
                categoryId: record.categoryId,
                imagePath: record.imagePath,
              );
              final dishId = await DatabaseHelper.instance.insertDish(dish);
              final updated = record.copyWith(isPromoted: true, promotedDishId: dishId);
              await DatabaseHelper.instance.updatePracticeRecord(updated);
              Navigator.pop(context);
              _loadData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('已升级到菜库 🎉'),
                    backgroundColor: AppTheme.successColor,
                  ),
                );
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _deletePracticeRecord(PracticeRecord record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除记录'),
        content: const Text('确定要删除这条修炼记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.deleteColor),
            onPressed: () async {
              await DatabaseHelper.instance.deletePracticeRecord(record.id!);
              Navigator.pop(context);
              _loadData();
            },
            child: const Text('删除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('修炼模式')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : _dishNames.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_awesome, size: 80, color: AppTheme.textHint.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      const Text('开始修炼新菜品', style: TextStyle(color: AppTheme.textHint, fontSize: 16)),
                      const SizedBox(height: 8),
                      const Text('在做菜过程中迭代提升', style: TextStyle(color: AppTheme.textHint, fontSize: 13)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _dishNames.length,
                  itemBuilder: (context, index) => _buildDishTile(_dishNames[index]),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPracticeDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildDishTile(String dishName) {
    final records = _recordsByDish[dishName] ?? [];
    final hasPromoted = records.any((r) => r.isPromoted);
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
                        ? [AppTheme.successColor, AppTheme.successColor.withOpacity(0.7)]
                        : [AppTheme.primaryColor, AppTheme.secondaryColor],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: hasPromoted
                      ? const Icon(Icons.check, color: Colors.white, size: 24)
                      : const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dishName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '已修炼 ${records.length} 次',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textHint),
                    ),
                  ],
                ),
              ),
              if (latestRating != null)
                Row(
                  children: List.generate(5, (i) => Icon(
                    i < latestRating ? Icons.star : Icons.star_border,
                    size: 14,
                    color: AppTheme.starColor,
                  )),
                ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AppTheme.textHint),
            ],
          ),
        ),
      ),
    );
  }
}
