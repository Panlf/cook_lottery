import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/category.dart';
import '../models/dish.dart';
import '../services/image_service.dart';
import '../theme/app_theme.dart';
import '../utils/feedback.dart';
import '../widgets/category_edit_dialog.dart';
import '../widgets/dish_image.dart';
import '../widgets/error_state.dart';
import 'add_dish_screen.dart';
import 'dish_detail_screen.dart';

class RecipeLibraryScreen extends StatefulWidget {
  const RecipeLibraryScreen({super.key});

  @override
  State<RecipeLibraryScreen> createState() => RecipeLibraryScreenState();
}

class RecipeLibraryScreenState extends State<RecipeLibraryScreen> {
  List<DishCategory> _categories = [];
  List<Dish> _dishes = [];
  int? _selectedCategoryId;
  String _searchQuery = '';
  bool _searchVisible = false;
  bool _isLoading = true;
  String? _error;

  final _searchController = TextEditingController();

  Map<int, DishCategory> get _categoryById => {
    for (final cat in _categories) cat.id!: cat,
  };

  List<Dish> get _filteredDishes {
    Iterable<Dish> dishes = _dishes;
    if (_selectedCategoryId != null) {
      dishes = dishes.where((dish) => dish.categoryId == _selectedCategoryId);
    }
    if (_searchQuery.isNotEmpty) {
      dishes = dishes.where(
        (dish) => dish.name.toLowerCase().contains(_searchQuery),
      );
    }
    return dishes.toList();
  }

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 重新加载数据；页签切换时由 HomeScreen 调用。
  void reload() => _loadData();

  Future<void> _loadData() async {
    try {
      final categories = await DatabaseHelper.instance.getAllCategories();
      final dishes = await DatabaseHelper.instance.getAllDishes();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _dishes = dishes;
        if (_selectedCategoryId != null &&
            !categories.any((cat) => cat.id == _selectedCategoryId)) {
          _selectedCategoryId = null;
        }
        _isLoading = false;
        _error = null;
      });
    } catch (_) {
      // 数据库异常（文件损坏/磁盘故障等）时给出可重试的错误视图，
      // 避免页面停留在无限加载。
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = '菜谱加载失败';
      });
    }
  }

  Future<void> _addDish() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddDishScreen()),
    );
    _loadData();
  }

  Future<void> _addCategory() async {
    final result = await showCategoryEditDialog(context);
    if (result == null || !mounted) return;
    try {
      final sortOrder = await DatabaseHelper.instance
          .getNextCategorySortOrder();
      await DatabaseHelper.instance.insertCategory(
        result.copyWith(sortOrder: sortOrder),
      );
    } catch (_) {
      if (mounted) showErrorSnackBar(context, '添加分类失败');
      return;
    }
    _loadData();
  }

  Future<void> _editCategory(DishCategory category) async {
    final result = await showCategoryEditDialog(context, existing: category);
    if (result == null || !mounted) return;
    try {
      await DatabaseHelper.instance.updateCategory(result);
    } catch (_) {
      if (mounted) showErrorSnackBar(context, '保存分类失败');
      return;
    }
    _loadData();
  }

  void _confirmDeleteCategory(DishCategory category) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除分类'),
        content: Text('确定要删除分类「${category.name}」吗？该分类下的所有菜品也会被删除。'),
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
              await _deleteCategory(category);
            },
            child: const Text('删除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCategory(DishCategory category) async {
    List<String?> imagePaths;
    try {
      imagePaths = await DatabaseHelper.instance.deleteCategory(category.id!);
    } catch (_) {
      if (mounted) showErrorSnackBar(context, '删除分类失败');
      return;
    }
    for (final path in imagePaths) {
      await ImageService.delete(path);
    }
    if (!mounted) return;
    setState(() => _selectedCategoryId = null);
    _loadData();
  }

  void _showCategoryManageSheet() {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.add_circle_outline,
                color: AppTheme.primaryColor,
              ),
              title: const Text('新增分类'),
              onTap: () {
                Navigator.pop(sheetContext);
                _addCategory();
              },
            ),
            const Divider(height: 1),
            ..._categories.map(
              (cat) => ListTile(
                leading: Text(cat.emoji, style: const TextStyle(fontSize: 24)),
                title: Text(cat.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _editCategory(cat);
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete,
                        size: 20,
                        color: AppTheme.deleteColor,
                      ),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _confirmDeleteCategory(cat);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
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
            icon: Icon(_searchVisible ? Icons.search_off : Icons.search),
            tooltip: '搜索菜品',
            onPressed: () {
              setState(() {
                _searchVisible = !_searchVisible;
                if (!_searchVisible) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '添加菜品',
            onPressed: _addDish,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : _error != null
          ? ErrorState(message: _error!, onRetry: reload)
          : Column(
              children: [
                _buildCategoryChips(),
                if (_searchVisible) _buildSearchField(),
                Expanded(child: _buildDishGrid()),
              ],
            ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: '搜索菜品名称',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
        ),
        onChanged: (value) =>
            setState(() => _searchQuery = value.trim().toLowerCase()),
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
                    onSelected: (_) =>
                        setState(() => _selectedCategoryId = null),
                    selectedColor: AppTheme.primaryColor,
                    labelStyle: TextStyle(
                      color: _selectedCategoryId == null
                          ? Colors.white
                          : AppTheme.textPrimary,
                    ),
                    checkmarkColor: Colors.white,
                  ),
                ),
                ..._categories.map(
                  (cat) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: Text(cat.emoji),
                      label: Text(cat.name),
                      onPressed: () =>
                          setState(() => _selectedCategoryId = cat.id),
                      backgroundColor: _selectedCategoryId == cat.id
                          ? AppTheme.primaryColor
                          : AppTheme.cardColor,
                      labelStyle: TextStyle(
                        color: _selectedCategoryId == cat.id
                            ? Colors.white
                            : AppTheme.textPrimary,
                      ),
                      side: BorderSide(
                        color: _selectedCategoryId == cat.id
                            ? AppTheme.primaryColor
                            : AppTheme.dividerColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.tune, color: AppTheme.textHint, size: 20),
            tooltip: '管理分类',
            onPressed: _showCategoryManageSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildDishGrid() {
    final dishes = _filteredDishes;
    if (dishes.isEmpty) {
      return _buildEmptyState();
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

  Widget _buildEmptyState() {
    final searching = _searchQuery.isNotEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            searching ? Icons.search_off : Icons.restaurant,
            size: 80,
            color: AppTheme.textHint.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            searching ? '没有找到匹配的菜品' : '还没有菜品',
            style: const TextStyle(color: AppTheme.textHint, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            searching ? '换个关键词试试' : '点击右上角 + 添加你的第一道菜',
            style: const TextStyle(color: AppTheme.textHint, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildDishCard(Dish dish) {
    final category = _categoryById[dish.categoryId];
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
            Expanded(child: DishImage(imagePath: dish.imagePath)),
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
                  if (category != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${category.emoji} ${category.name}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textHint,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
