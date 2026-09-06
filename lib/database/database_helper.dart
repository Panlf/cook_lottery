import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/category.dart';
import '../models/dish.dart';
import '../models/meal_record.dart';
import '../models/practice_record.dart';

/// SQLite 本地数据库管理（单例）。
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static String? _debugPathOverride;

  DatabaseHelper._init();

  /// 仅供测试：覆盖数据库文件路径，避免依赖平台目录。
  @visibleForTesting
  static void debugSetDatabasePath(String path) => _debugPathOverride = path;

  /// 仅供测试：关闭并丢弃当前连接，下次访问时按当前路径重新打开。
  @visibleForTesting
  static Future<void> debugReset() async {
    final db = _database;
    _database = null;
    await db?.close();
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('cook_lottery.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final path = _debugPathOverride ?? join(await getDatabasesPath(), filePath);
    return openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        emoji TEXT DEFAULT '🍽️',
        sort_order INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE dishes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category_id INTEGER NOT NULL,
        image_path TEXT,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE meal_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date INTEGER NOT NULL,
        meal_type TEXT NOT NULL,
        dish_ids TEXT NOT NULL,
        rating INTEGER,
        notes TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE practice_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dish_name TEXT NOT NULL,
        category_id INTEGER NOT NULL,
        image_path TEXT,
        rating INTEGER,
        notes TEXT,
        is_promoted INTEGER DEFAULT 0,
        promoted_dish_id INTEGER,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories (id)
      )
    ''');

    final defaultCategories = [
      {'name': '海鲜', 'emoji': '🦐', 'sort_order': 0},
      {'name': '肉菜', 'emoji': '🥩', 'sort_order': 1},
      {'name': '蔬菜', 'emoji': '🥬', 'sort_order': 2},
      {'name': '汤品', 'emoji': '🍲', 'sort_order': 3},
      {'name': '主食', 'emoji': '🍚', 'sort_order': 4},
      {'name': '甜品', 'emoji': '🍰', 'sort_order': 5},
    ];

    for (final cat in defaultCategories) {
      await db.insert('categories', cat);
    }
  }

  // Category CRUD

  Future<List<DishCategory>> getAllCategories() async {
    final db = await database;
    final result = await db.query('categories', orderBy: 'sort_order ASC');
    return result.map(DishCategory.fromMap).toList();
  }

  Future<DishCategory?> getCategory(int id) async {
    final db = await database;
    final result = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isEmpty ? null : DishCategory.fromMap(result.first);
  }

  Future<int> insertCategory(DishCategory category) async {
    final db = await database;
    return db.insert('categories', category.toMap()..remove('id'));
  }

  Future<int> updateCategory(DishCategory category) async {
    final db = await database;
    return db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  /// 删除分类及其下所有菜品（事务保证原子性）。
  /// 返回被删菜品的图片路径列表，由调用方负责清理文件。
  Future<List<String?>> deleteCategory(int id) async {
    final db = await database;
    final dishes = await db.query(
      'dishes',
      columns: ['image_path'],
      where: 'category_id = ?',
      whereArgs: [id],
    );
    await db.transaction((txn) async {
      await txn.delete('dishes', where: 'category_id = ?', whereArgs: [id]);
      await txn.delete('categories', where: 'id = ?', whereArgs: [id]);
    });
    return dishes.map((row) => row['image_path'] as String?).toList();
  }

  /// 下一个可用的分类排序号（当前最大值 + 1，避免删除分类后产生重复排序号）。
  Future<int> getNextCategorySortOrder() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT MAX(sort_order) AS max_order FROM categories',
    );
    return ((result.first['max_order'] as int?) ?? -1) + 1;
  }

  // Dish CRUD

  Future<List<Dish>> getAllDishes() async {
    final db = await database;
    final result = await db.query('dishes', orderBy: 'created_at DESC');
    return result.map(Dish.fromMap).toList();
  }

  Future<Dish?> getDish(int id) async {
    final db = await database;
    final result = await db.query('dishes', where: 'id = ?', whereArgs: [id]);
    return result.isEmpty ? null : Dish.fromMap(result.first);
  }

  Future<Dish?> getDishByName(String name) async {
    final db = await database;
    final result = await db.query(
      'dishes',
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    return result.isEmpty ? null : Dish.fromMap(result.first);
  }

  Future<List<Dish>> getDishesByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    final result = await db.query(
      'dishes',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
    return result.map(Dish.fromMap).toList();
  }

  Future<int> insertDish(Dish dish) async {
    final db = await database;
    return db.insert('dishes', dish.toMap()..remove('id'));
  }

  Future<int> updateDish(Dish dish) async {
    final db = await database;
    return db.update(
      'dishes',
      dish.toMap(),
      where: 'id = ?',
      whereArgs: [dish.id],
    );
  }

  Future<int> deleteDish(int id) async {
    final db = await database;
    return db.delete('dishes', where: 'id = ?', whereArgs: [id]);
  }

  // Meal Record CRUD

  Future<List<MealRecord>> getAllMealRecords() async {
    final db = await database;
    // 同一天内按 午餐 →晚餐 的实际时间顺序展示
    final result = await db.query(
      'meal_records',
      orderBy: "date DESC, CASE WHEN meal_type = 'lunch' THEN 0 ELSE 1 END",
    );
    return result.map(MealRecord.fromMap).toList();
  }

  /// 查询包含指定菜品的饮食记录（菜品详情页的最近搭配列表）。
  Future<List<MealRecord>> getMealRecordsContainingDish(
    int dishId, {
    int limit = 10,
  }) async {
    final db = await database;
    // dish_ids 为逗号分隔文本，两侧补逗号后按「,id,」整段匹配，避免 5 误匹配 15。
    final result = await db.query(
      'meal_records',
      where: "',' || dish_ids || ',' LIKE ?",
      whereArgs: ['%,$dishId,%'],
      orderBy: 'date DESC',
      limit: limit,
    );
    return result.map(MealRecord.fromMap).toList();
  }

  /// 包含指定菜品的饮食记录总数（不受最近条数限制，用于「上桌次数」展示）。
  Future<int> countMealRecordsContainingDish(int dishId) async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) AS count FROM meal_records WHERE ',' || dish_ids || ',' LIKE ?",
      ['%,$dishId,%'],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// [since] 之后吃过的菜品 ID 集合（用于抽签时避开近期吃过的菜）。
  Future<Set<int>> getEatenDishIdsSince(DateTime since) async {
    final db = await database;
    final result = await db.query(
      'meal_records',
      columns: ['dish_ids'],
      where: 'date >= ?',
      whereArgs: [since.millisecondsSinceEpoch],
    );
    return {
      for (final row in result)
        ...MealRecord.parseDishIds(row['dish_ids'] as String? ?? ''),
    };
  }

  Future<int> insertMealRecord(MealRecord record) async {
    final db = await database;
    return db.insert('meal_records', record.toMap()..remove('id'));
  }

  Future<int> updateMealRecord(MealRecord record) async {
    final db = await database;
    return db.update(
      'meal_records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<int> deleteMealRecord(int id) async {
    final db = await database;
    return db.delete('meal_records', where: 'id = ?', whereArgs: [id]);
  }

  // Practice Record CRUD

  Future<List<PracticeRecord>> getAllPracticeRecords() async {
    final db = await database;
    final result = await db.query(
      'practice_records',
      orderBy: 'created_at DESC',
    );
    return result.map(PracticeRecord.fromMap).toList();
  }

  Future<int> insertPracticeRecord(PracticeRecord record) async {
    final db = await database;
    return db.insert('practice_records', record.toMap()..remove('id'));
  }

  Future<int> updatePracticeRecord(PracticeRecord record) async {
    final db = await database;
    return db.update(
      'practice_records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<int> deletePracticeRecord(int id) async {
    final db = await database;
    return db.delete('practice_records', where: 'id = ?', whereArgs: [id]);
  }
}
