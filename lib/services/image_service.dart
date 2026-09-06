import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// 菜品图片文件管理。
///
/// image_picker 返回的是系统临时目录中的文件，随时可能被系统清理，
/// 因此选图后必须通过 [persist] 复制到应用文档目录下统一管理；
/// 删除时通过 [delete] 清理，且只会删除管理目录内的文件，防止误删。
class ImageService {
  static const _dirName = 'dish_images';
  static const _uuid = Uuid();

  static Directory? _rootOverride;
  static Directory? _resolvedDir;

  /// 仅供测试：覆盖图片管理根目录。
  @visibleForTesting
  static void debugSetRoot(Directory? root) {
    _rootOverride = root;
    _resolvedDir = null;
  }

  static Future<Directory> _imagesDir() async {
    final existing = _resolvedDir;
    if (existing != null) return existing;
    final root = _rootOverride ?? await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, _dirName));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return _resolvedDir = dir;
  }

  /// 把临时图片复制进管理目录，返回持久化后的路径。
  static Future<String> persist(String sourcePath) async {
    final dir = await _imagesDir();
    final ext = p.extension(sourcePath);
    final destPath = p.join(
      dir.path,
      '${_uuid.v4()}${ext.isEmpty ? '.jpg' : ext}',
    );
    await File(sourcePath).copy(destPath);
    return destPath;
  }

  /// 删除由 [persist] 管理的图片文件；路径不在管理目录内时直接忽略。
  /// 清理失败（如文件被占用）只吞掉异常，不阻断业务流程。
  static Future<void> delete(String? path) async {
    if (path == null || path.isEmpty) return;
    if (_resolvedDir == null) await _imagesDir();
    if (!isManaged(path)) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // 清理失败可留待下次操作重试
    }
  }

  /// 判断路径是否位于当前图片管理目录内（按已解析的目录全路径比对，
  /// 而非仅比对末级目录名，避免其它位置的 dish_images 目录被误判）。
  static bool isManaged(String path) =>
      _resolvedDir != null &&
      p.normalize(p.dirname(path)) == p.normalize(_resolvedDir!.path);
}
