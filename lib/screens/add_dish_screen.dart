import 'dart:io';

import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/category.dart';
import '../models/dish.dart';
import '../services/image_service.dart';
import '../theme/app_theme.dart';
import '../utils/feedback.dart';
import '../widgets/image_source_sheet.dart';

class AddDishScreen extends StatefulWidget {
  final Dish? dish;

  const AddDishScreen({super.key, this.dish});

  @override
  State<AddDishScreen> createState() => _AddDishScreenState();
}

class _AddDishScreenState extends State<AddDishScreen> {
  final _nameController = TextEditingController();
  int? _selectedCategoryId;
  String? _imagePath;
  List<DishCategory> _categories = [];
  bool _isLoading = true;
  bool _isSaving = false;

  /// 本次是否选过新图片；用于在未保存就退出时回收图片文件。
  bool _imageChanged = false;

  bool get _isEditing => widget.dish != null;

  @override
  void initState() {
    super.initState();
    final dish = widget.dish;
    if (dish != null) {
      _nameController.text = dish.name;
      _selectedCategoryId = dish.categoryId;
      _imagePath = dish.imagePath;
    }
    _loadData();
  }

  @override
  void dispose() {
    if (_imageChanged && _imagePath != widget.dish?.imagePath) {
      ImageService.delete(_imagePath);
    }
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final categories = await DatabaseHelper.instance.getAllCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _selectedCategoryId ??= categories.firstOrNull?.id;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mounted) showErrorSnackBar(context, '分类加载失败');
    }
  }

  Future<void> _pickImage() async {
    final newPath = await pickAndPersistImage(context);
    if (newPath == null || !mounted) return;
    // 本次会话里反复换图时，及时清理上一张未保存的图片。
    if (_imageChanged) await ImageService.delete(_imagePath);
    setState(() {
      _imagePath = newPath;
      _imageChanged = true;
    });
  }

  Future<void> _saveDish() async {
    if (_isSaving) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入菜品名称')));
      return;
    }
    final categoryId = _selectedCategoryId;
    if (categoryId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请选择分类')));
      return;
    }

    setState(() => _isSaving = true);
    final original = widget.dish;
    try {
      if (original != null) {
        await DatabaseHelper.instance.updateDish(
          original.copyWith(
            name: name,
            categoryId: categoryId,
            imagePath: _imagePath,
          ),
        );
        if (_imageChanged) await ImageService.delete(original.imagePath);
      } else {
        await DatabaseHelper.instance.insertDish(
          Dish(name: name, categoryId: categoryId, imagePath: _imagePath),
        );
      }
      _imageChanged = false;
    } catch (_) {
      if (mounted) showErrorSnackBar(context, '保存失败，请重试');
      return;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }

    if (mounted) Navigator.pop(context);
  }

  void _confirmDelete() {
    final dish = widget.dish!;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除菜品'),
        content: Text('确定要删除「${dish.name}」吗？'),
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
              await _deleteDish(dish);
            },
            child: const Text('删除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteDish(Dish dish) async {
    try {
      await DatabaseHelper.instance.deleteDish(dish.id!);
      await ImageService.delete(dish.imagePath);
      _imageChanged = false;
    } catch (_) {
      if (mounted) showErrorSnackBar(context, '删除失败，请重试');
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑菜品' : '添加菜品'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: AppTheme.deleteColor,
              ),
              tooltip: '删除菜品',
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildImagePicker(),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: '菜品名称',
                      prefixIcon: Icon(Icons.restaurant_menu),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '选择分类',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_categories.isEmpty)
                    const Text(
                      '还没有分类，请先到「菜谱库」页添加分类',
                      style: TextStyle(color: AppTheme.textHint, fontSize: 13),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.map((cat) {
                        final isSelected = cat.id == _selectedCategoryId;
                        return ChoiceChip(
                          avatar: Text(cat.emoji),
                          label: Text(cat.name),
                          selected: isSelected,
                          onSelected: (_) =>
                              setState(() => _selectedCategoryId = cat.id),
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
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: _isSaving || _categories.isEmpty
                        ? null
                        : _saveDish,
                    child: Text(
                      _isSaving
                          ? '保存中...'
                          : (widget.dish != null ? '保存修改' : '添加菜品'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildImagePicker() {
    final file = _imagePath == null ? null : File(_imagePath!);
    final hasImage = file != null && file.existsSync();
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          color: AppTheme.accentColor,
          borderRadius: BorderRadius.circular(20),
          image: hasImage
              ? DecorationImage(image: FileImage(file), fit: BoxFit.cover)
              : null,
        ),
        child: hasImage
            ? Align(
                alignment: Alignment.topRight,
                child: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              )
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo, size: 48, color: AppTheme.textHint),
                  SizedBox(height: 8),
                  Text('添加菜品照片', style: TextStyle(color: AppTheme.textHint)),
                ],
              ),
      ),
    );
  }
}
