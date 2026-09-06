import 'package:flutter/material.dart';

import '../models/category.dart';
import '../theme/app_theme.dart';

/// 分类可选的 emoji 图标。
const kCategoryEmojis = [
  '🦐',
  '🥩',
  '🥬',
  '🍲',
  '🍚',
  '🍰',
  '🥚',
  '🍜',
  '🥗',
  '🍕',
  '🌮',
  '🍣',
  '🍱',
  '🥘',
  '🧁',
  '☕',
];

/// 新增/编辑分类弹窗。
///
/// [existing] 为空表示新增；确认后返回携带新名称与图标的分类对象，取消返回 null。
Future<DishCategory?> showCategoryEditDialog(
  BuildContext context, {
  DishCategory? existing,
}) async {
  final nameController = TextEditingController(text: existing?.name);
  String selectedEmoji = existing?.emoji ?? kCategoryEmojis.first;

  try {
    return await showDialog<DishCategory>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? '添加分类' : '编辑分类'),
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
                child: Text(
                  '选择图标',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kCategoryEmojis.map((emoji) {
                  final isSelected = emoji == selectedEmoji;
                  return GestureDetector(
                    onTap: () => setDialogState(() => selectedEmoji = emoji),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.accentColor
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? Border.all(color: AppTheme.primaryColor, width: 2)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
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
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(
                  context,
                  existing?.copyWith(name: name, emoji: selectedEmoji) ??
                      DishCategory(name: name, emoji: selectedEmoji),
                );
              },
              child: Text(existing == null ? '添加' : '保存'),
            ),
          ],
        ),
      ),
    );
  } finally {
    nameController.dispose();
  }
}
