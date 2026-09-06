import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cook_lottery/services/image_service.dart';

void main() {
  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('dish_images_test_');
    ImageService.debugSetRoot(tempRoot);
  });

  tearDown(() async {
    ImageService.debugSetRoot(null);
    try {
      await tempRoot.delete(recursive: true);
    } catch (_) {}
  });

  test('persist 把图片复制进管理目录并返回新路径', () async {
    final source = File('${tempRoot.path}${Platform.pathSeparator}source.png')
      ..writeAsStringSync('image-bytes');
    final persisted = await ImageService.persist(source.path);

    expect(ImageService.isManaged(persisted), isTrue);
    expect(persisted, endsWith('.png'));
    expect(File(persisted).readAsStringSync(), 'image-bytes');
    expect(persisted == source.path, isFalse);
  });

  test('persist 对无扩展名的文件默认按 jpg 保存', () async {
    final source = File('${tempRoot.path}${Platform.pathSeparator}noext')
      ..writeAsStringSync('data');
    final persisted = await ImageService.persist(source.path);
    expect(persisted, endsWith('.jpg'));
  });

  test('delete 移除管理目录内的文件', () async {
    final source = File('${tempRoot.path}${Platform.pathSeparator}a.jpg')
      ..writeAsStringSync('x');
    final managed = await ImageService.persist(source.path);
    expect(File(managed).existsSync(), isTrue);

    await ImageService.delete(managed);
    expect(File(managed).existsSync(), isFalse);
  });

  test('delete 目标文件已丢失时不抛异常', () async {
    final source = File('${tempRoot.path}${Platform.pathSeparator}gone.jpg')
      ..writeAsStringSync('x');
    final managed = await ImageService.persist(source.path);
    File(managed).deleteSync(); // 模拟文件已被外部清理

    await ImageService.delete(managed);
  });

  test('delete 忽略管理目录之外的路径，防止误删', () async {
    final outside = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}outside_${DateTime.now().microsecondsSinceEpoch}.jpg',
    )..writeAsStringSync('keep');
    addTearDown(() => outside.deleteSync());

    await ImageService.delete(outside.path);
    expect(outside.existsSync(), isTrue);

    await ImageService.delete(null);
    await ImageService.delete('');
  });
}
