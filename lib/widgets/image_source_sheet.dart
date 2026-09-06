import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/image_service.dart';
import '../theme/app_theme.dart';
import '../utils/feedback.dart';

/// 弹出「拍照 / 相册」选择面板，返回用户选择的来源；取消时返回 null。
Future<ImageSource?> showImageSourceSheet(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '选择图片来源',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt, color: AppTheme.primaryColor),
            title: const Text('拍照'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(
              Icons.photo_library,
              color: AppTheme.primaryColor,
            ),
            title: const Text('从相册选择'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// 选择一张图片并持久化到应用目录，返回新路径；取消或失败时返回 null。
/// 相机/相册权限被拒、相机被占用、磁盘复制失败等异常在这里统一捕获并提示。
Future<String?> pickAndPersistImage(BuildContext context) async {
  final source = await showImageSourceSheet(context);
  if (source == null || !context.mounted) return null;
  try {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null) return null;
    return await ImageService.persist(picked.path);
  } catch (_) {
    if (context.mounted) {
      showErrorSnackBar(context, '获取图片失败，请检查相机/相册权限');
    }
    return null;
  }
}
