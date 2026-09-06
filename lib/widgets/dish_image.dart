import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 菜品图片：文件存在时展示图片（按显示尺寸解码以节省内存），
/// 文件缺失或解码失败时展示占位图。
class DishImage extends StatelessWidget {
  final String? imagePath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double iconSize;

  const DishImage({
    super.key,
    this.imagePath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.iconSize = 40,
  });

  @override
  Widget build(BuildContext context) {
    final file = (imagePath == null || imagePath!.isEmpty)
        ? null
        : File(imagePath!);
    if (file != null && file.existsSync()) {
      // 缩略图按显示尺寸解码，避免整图占用内存
      final ratio = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;
      return Image.file(
        file,
        width: width,
        height: height,
        fit: fit,
        cacheWidth: width == null ? null : (width! * ratio).round(),
        errorBuilder: (_, _, _) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: AppTheme.accentColor,
      alignment: Alignment.center,
      child: Icon(Icons.restaurant, size: iconSize, color: AppTheme.textHint),
    );
  }
}
