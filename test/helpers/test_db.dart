import 'dart:io';

import 'package:cook_lottery/database/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 在测试进程中启用 FFI 版 sqflite（无需平台通道与 isolate）。
///
/// [databaseFactoryFfiNoIsolate] 在当前 isolate 内同步执行 SQLite 调用，
/// 兼容 flutter_test 的 FakeAsync 环境。
///
/// 必须在 setUpAll 中 await：sqlite3 动态库加载等一次性初始化涉及真实
/// 异步 I/O，若推迟到 testWidgets 的 FakeAsync 区内触发会永远无法完成。
Future<void> initTestDatabaseFactory() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;
  final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
  await db.close();
}

/// 每个测试用例独立的临时数据库，互不干扰。
class TestDatabase {
  static Directory? _dir;

  static Future<void> setUp() async {
    _dir = await Directory.systemTemp.createTemp('cook_lottery_test_');
    DatabaseHelper.debugSetDatabasePath(
      '${_dir!.path}${Platform.pathSeparator}test.db',
    );
    await DatabaseHelper.debugReset();
  }

  static Future<void> tearDown() async {
    await DatabaseHelper.debugReset();
    final dir = _dir;
    _dir = null;
    if (dir != null) {
      try {
        await dir.delete(recursive: true);
      } catch (_) {
        // 个别平台上文件句柄释放有延迟，清理失败不影响测试结果。
      }
    }
  }
}
