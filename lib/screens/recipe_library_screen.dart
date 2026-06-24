import 'dart:io';
import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/dish.dart';
import '../models/category.dart';
import '../theme/app_theme.dart';
import 'add_dish_screen.dart';
import 'dish_detail_screen.dart';

class RecipeLibraryScreen extends StatefulWidget {
  const RecipeLibraryScreen({super.key});

  @override
  State<RecipeLibraryScreen> createState() => _RecipeLibraryScreenState();
}

class _RecipeLibraryScreenState extends State<RecipeLibraryScreen> {
  List<DishCategory> _categories = [];
  List<Dish> _dishes = [];
  int? _selectedCategoryId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final categories = await DatabaseHelper.instance.getAllCategories();
    final dishes = await DatabaseHelper.instance.getAllDishes();
    setState(() {
      _categories = categories;
      _dishes = dishes;
      _isLoading = false;
    });
  }

  List<Dish> get _filteredDishes {
    if (_selectedCategoryId == null) return _dishes;
    return _dishes.where((d) => d.categoryId == _selectedCategoryId).toList();
  }

  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    String selectedEmoji = '🍽️';
    final emojis = ['🦐', '🥩', '🥬', '🍲', '🍚', '🍰', '🥚', '🍜', '🥗', '🍕', '🌮', '🍣', '🍱', '🥘', '🧁', '☕'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('添加分类'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(hintText: '分类名称'),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('选择图标', style: TextStyle(color: AppTheme.textSecondary)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: emojis.map((emoji) {
                  final isSelected = emoji == selectedEmoji;
                  return GestureDetector(
                    onTap: () => setDialogState(() => selectedEmoji = emoji),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.accentColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? Border.all(color: AppTheme.primaryColor, width: 2)
                            : null,
                      ),
                      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
                    ),
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
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty) {
                  final category = DishCategory(
                    name: nameController.text.trim(),
                    emoji: selectedEmoji,
                    sortOrder: _categories.length,
                  );
                  await DatabaseHelper.instance.insertCategory(category);
                  Navigator.pop(context);
                  _loadData();
                }
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCategoryDialog(DishCategory category) {
    final nameController = TextEditingController(text: category.name);
    String selectedEmoji = category.emoji;
    final emojis = ['🦐', '🥩', '🥬', '🍲', '🍚', '🍰', '🥚', '🍜', '🥗', '🍕', '🌮', '🍣', '🍱', '🥘', '🧁', '☕'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('编辑分类'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(hintText: '分类名称'),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('选择图标', style: TextStyle(color: AppTheme.textSecondary)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: emojis.map((emoji) {
                  final isSelected = emoji == selectedEmoji;
                  return GestureDetector(
                    onTap: () => setDialogState(() => selectedEmoji = emoji),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.accentColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? Border.all(color: AppTheme.primaryColor, width: 2)
                            : null,
                      ),
                      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
                    ),
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
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty) {
                  final updated = category.copyWith(
                    name: nameController.text.trim(),
                    emoji: selectedEmoji,
                  );
                  await DatabaseHelper.instance.updateCategory(updated);
                  Navigator.pop(context);
                  _loadData();
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteCategory(DishCategory category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除分类'),
        content: Text('确定要删除分类「${category.name}」吗？该分类下的所有菜品也会被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.deleteColor),
            onPressed: () async {
              await DatabaseHelper.instance.deleteCategory(category.id!);
              if (_selectedCategoryId == category.id) {
                _selectedCategoryId = null;
              }
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
      appBar: AppBar(
        title: const Text('我的菜谱'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddDishScreen()),
              );
              _loadData();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : Column(
              children: [
                _buildCategoryChips(),
                Expanded(child: _buildDishGrid()),
              ],
            ),
    );
  }

  Widget _buildCategoryChips() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('全部'),
                    selected: _selectedCategoryId == null,
                    onSelected: (_) => setState(() => _selectedCategoryId = null),
                    selectedColor: AppTheme.primaryColor,
                    labelStyle: TextStyle(
                      color: _selectedCategoryId == null ? Colors.white : AppTheme.textPrimary,
                    ),
                    checkmarkColor: Colors.white,
                  ),
                ),
                ..._categories.map((cat) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: Text(cat.emoji),
                    label: Text(cat.name),
                    onPressed: () {
                      setState(() => _selectedCategoryId = cat.id);
                    },
                    backgroundColor: _selectedCategoryId == cat.id
                        ? AppTheme.primaryColor
                        : AppTheme.cardColor,
                    labelStyle: TextStyle(
                      color: _selectedCategoryId == cat.id ? Colors.white : AppTheme.textPrimary,
                    ),
                    side: BorderSide(
                      color: _selectedCategoryId == cat.id
                          ? AppTheme.primaryColor
                          : AppTheme.dividerColor,
                    ),
                  ),
                )),
              ],
            ),
          ),
          GestureDetector(
            onTap: _showAddCategoryDialog,
            onLongPress: _categories.isEmpty ? null : () {
              showModalBottomSheet(
                context: context,
                builder: (context) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('管理分类', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                      ..._categories.map((cat) => ListTile(
                        leading: Text(cat.emoji, style: const TextStyle(fontSize: 24)),
                        title: Text(cat.name),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () {
                                Navigator.pop(context);
                                _showEditCategoryDialog(cat);
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, size: 20, color: AppTheme.deleteColor),
                              onPressed: () {
                                Navigator.pop(context);
                                _deleteCategory(cat);
                              },
                            ),
                          ],
                        ),
                      )),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              );
            },
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.settings, color: AppTheme.textHint, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDishGrid() {
    final dishes = _filteredDishes;
    if (dishes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant, size: 80, color: AppTheme.textHint.withOpacity(0.3)),
            const SizedBox(height: 16),
            const Text('还没有菜品', style: TextStyle(color: AppTheme.textHint, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('点击右上角 + 添加你的第一道菜', style: TextStyle(color: AppTheme.textHint, fontSize: 13)),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: dishes.length,
      itemBuilder: (context, index) => _buildDishCard(dishes[index]),
    );
  }

  Widget _buildDishCard(Dish dish) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => DishDetailScreen(dish: dish)),
        );
        _loadData();
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: dish.imagePath != null && File(dish.imagePath!).existsSync()
                  ? Image.file(File(dish.imagePath!), fit: BoxFit.cover)
                  : Container(
                      color: AppTheme.accentColor,
                      child: const Center(
                        child: Icon(Icons.restaurant, size: 40, color: AppTheme.textHint),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dish.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
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
      ),
    );
  }
}
