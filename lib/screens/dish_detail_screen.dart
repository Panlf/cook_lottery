import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../database/database_helper.dart';
import '../models/dish.dart';
import '../models/category.dart';
import '../theme/app_theme.dart';
import 'add_dish_screen.dart';

class DishDetailScreen extends StatefulWidget {
  final Dish dish;

  const DishDetailScreen({super.key, required this.dish});

  @override
  State<DishDetailScreen> createState() => _DishDetailScreenState();
}

class _DishDetailScreenState extends State<DishDetailScreen> {
  late Dish _dish;

  @override
  void initState() {
    super.initState();
    _dish = widget.dish;
  }

  Future<void> _replaceImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('更换图片', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.primaryColor),
              title: const Text('拍照'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.primaryColor),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, maxWidth: 1024, imageQuality: 85);
      if (picked != null) {
        final updated = _dish.copyWith(imagePath: picked.path);
        await DatabaseHelper.instance.updateDish(updated);
        setState(() => _dish = updated);
      }
    }
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
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AddDishScreen(dish: _dish)),
                  );
                  final updated = await DatabaseHelper.instance.getDish(_dish.id!);
                  if (updated != null) setState(() => _dish = updated);
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  _dish.imagePath != null && File(_dish.imagePath!).existsSync()
                      ? Image.file(File(_dish.imagePath!), fit: BoxFit.cover)
                      : Container(
                          color: AppTheme.accentColor,
                          child: const Center(
                            child: Icon(Icons.restaurant, size: 80, color: AppTheme.textHint),
                          ),
                        ),
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
                          colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: Text(
                      _dish.name,
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.camera_alt, size: 16, color: AppTheme.primaryColor),
                            SizedBox(width: 4),
                            Text('换图', style: TextStyle(color: AppTheme.primaryColor, fontSize: 13)),
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
              child: Column(
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
    return FutureBuilder<DishCategory?>(
      future: DatabaseHelper.instance.getCategory(_dish.categoryId),
      builder: (context, snapshot) {
        final category = snapshot.data;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('基本信息', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                _buildInfoRow('分类', category != null ? '${category.emoji} ${category.name}' : '-'),
                const SizedBox(height: 8),
                _buildInfoRow('添加时间', _formatDate(_dish.createdAt)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
        Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
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
            const Text('搭配历史', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _getDishMealHistory(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('暂无搭配记录', style: TextStyle(color: AppTheme.textHint)),
                    ),
                  );
                }
                return Column(
                  children: snapshot.data!.take(5).map((record) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.accentColor,
                        child: Text(
                          record['meal_type'] == 'lunch' ? '午' : '晚',
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                        ),
                      ),
                      title: Text(_formatDate(DateTime.fromMillisecondsSinceEpoch(record['date'])),
                          style: const TextStyle(fontSize: 14)),
                      trailing: record['rating'] != null
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(5, (i) => Icon(
                                i < record['rating'] ? Icons.star : Icons.star_border,
                                size: 16,
                                color: AppTheme.starColor,
                              )),
                            )
                          : const Text('未评价', style: TextStyle(color: AppTheme.textHint, fontSize: 12)),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getDishMealHistory() async {
    final db = await DatabaseHelper.instance.database;
    final results = await db.rawQuery(
      "SELECT * FROM meal_records WHERE ',' || dish_ids || ',' LIKE '%,?,%' ORDER BY date DESC LIMIT 10",
      [_dish.id],
    );
    return results;
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
}
