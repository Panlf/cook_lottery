import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../database/database_helper.dart';
import '../models/dish.dart';
import '../models/category.dart';
import '../theme/app_theme.dart';

class AddDishScreen extends StatefulWidget {
  final Dish? dish;
  final String? initialName;
  final int? initialCategoryId;

  const AddDishScreen({super.key, this.dish, this.initialName, this.initialCategoryId});

  @override
  State<AddDishScreen> createState() => _AddDishScreenState();
}

class _AddDishScreenState extends State<AddDishScreen> {
  final _nameController = TextEditingController();
  int? _selectedCategoryId;
  String? _imagePath;
  List<DishCategory> _categories = [];
  bool _isLoading = true;

  bool get _isEditing => widget.dish != null;

  @override
  void initState() {
    super.initState();
    _loadData();
    if (widget.dish != null) {
      _nameController.text = widget.dish!.name;
      _selectedCategoryId = widget.dish!.categoryId;
      _imagePath = widget.dish!.imagePath;
    } else {
      if (widget.initialName != null) _nameController.text = widget.initialName!;
      if (widget.initialCategoryId != null) _selectedCategoryId = widget.initialCategoryId;
    }
  }

  Future<void> _loadData() async {
    final categories = await DatabaseHelper.instance.getAllCategories();
    setState(() {
      _categories = categories;
      if (_selectedCategoryId == null && categories.isNotEmpty) {
        _selectedCategoryId = categories.first.id;
      }
      _isLoading = false;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 1024, imageQuality: 85);
    if (picked != null) {
      setState(() => _imagePath = picked.path);
    }
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.primaryColor),
              title: const Text('拍照'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.primaryColor),
              title: const Text('从相册选择'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑菜品' : '添加菜品'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.deleteColor),
              onPressed: _deleteDish,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
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
                  const Text('选择分类', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((cat) {
                      final isSelected = cat.id == _selectedCategoryId;
                      return ChoiceChip(
                        avatar: Text(cat.emoji),
                        label: Text(cat.name),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _selectedCategoryId = cat.id),
                        selectedColor: AppTheme.primaryColor,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppTheme.textPrimary,
                        ),
                        checkmarkColor: Colors.white,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: _saveDish,
                    child: Text(_isEditing ? '保存修改' : '添加菜品'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _showImagePicker,
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          color: AppTheme.accentColor,
          borderRadius: BorderRadius.circular(20),
          image: _imagePath != null && File(_imagePath!).existsSync()
              ? DecorationImage(
                  image: FileImage(File(_imagePath!)),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: _imagePath == null || !File(_imagePath!).existsSync()
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo, size: 48, color: AppTheme.textHint),
                  SizedBox(height: 8),
                  Text('添加菜品照片', style: TextStyle(color: AppTheme.textHint)),
                ],
              )
            : Align(
                alignment: Alignment.topRight,
                child: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                ),
              ),
      ),
    );
  }

  Future<void> _saveDish() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入菜品名称')),
      );
      return;
    }
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择分类')),
      );
      return;
    }

    if (_isEditing) {
      final updated = widget.dish!.copyWith(
        name: _nameController.text.trim(),
        categoryId: _selectedCategoryId!,
        imagePath: _imagePath,
      );
      await DatabaseHelper.instance.updateDish(updated);
    } else {
      final dish = Dish(
        name: _nameController.text.trim(),
        categoryId: _selectedCategoryId!,
        imagePath: _imagePath,
      );
      await DatabaseHelper.instance.insertDish(dish);
    }

    if (mounted) Navigator.pop(context);
  }

  void _deleteDish() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除菜品'),
        content: Text('确定要删除「${widget.dish!.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.deleteColor),
            onPressed: () async {
              await DatabaseHelper.instance.deleteDish(widget.dish!.id!);
              if (mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
              }
            },
            child: const Text('删除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
