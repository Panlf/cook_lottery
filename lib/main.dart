import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _initDatabaseFactory();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const CookLotteryApp());
}

/// sqflite 官方插件仅支持 Android/iOS；桌面端必须切换到 FFI 实现，
/// 否则首次访问数据库会抛 MissingPluginException。
///
/// 注意：Windows 发行版需要将 sqlite3.dll 放在可执行文件同级目录
/// （开发调试时会自动加载 sqflite_common_ffi 包内自带的 dll）。
void _initDatabaseFactory() {
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  }
}

class CookLotteryApp extends StatelessWidget {
  const CookLotteryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '菜盒日记',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const HomeScreen(),
    );
  }
}
