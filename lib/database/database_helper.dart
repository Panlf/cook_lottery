import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/dish.dart';
import '../models/category.dart';
import '../models/meal_record.dart';
import '../models/practice_record.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('cook_lottery.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
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
    return result.map((map) => DishCategory.fromMap(map)).toList();
  }

  Future<DishCategory?> getCategory(int id) async {
    final db = await database;
    final result = await db.query('categories', where: 'id = ?', whereArgs: [id]);
    if (result.isEmpty) return null;
    return DishCategory.fromMap(result.first);
  }

  Future<int> insertCategory(DishCategory category) async {
    final db = await database;
    return await db.insert('categories', category.toMap()..remove('id'));
  }

  Future<int> updateCategory(DishCategory category) async {
    final db = await database;
    return await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    await db.delete('dishes', where: 'category_id = ?', whereArgs: [id]);
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // Dish CRUD
  Future<List<Dish>> getAllDishes() async {
    final db = await database;
    final result = await db.query('dishes', orderBy: 'created_at DESC');
    return result.map((map) => Dish.fromMap(map)).toList();
  }

  Future<List<Dish>> getDishesByCategory(int categoryId) async {
    final db = await database;
    final result = await db.query(
      'dishes',
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'created_at DESC',
    );
    return result.map((map) => Dish.fromMap(map)).toList();
  }

  Future<Dish?> getDish(int id) async {
    final db = await database;
    final result = await db.query('dishes', where: 'id = ?', whereArgs: [id]);
    if (result.isEmpty) return null;
    return Dish.fromMap(result.first);
  }

  Future<int> insertDish(Dish dish) async {
    final db = await database;
    return await db.insert('dishes', dish.toMap()..remove('id'));
  }

  Future<int> updateDish(Dish dish) async {
    final db = await database;
    return await db.update(
      'dishes',
      dish.toMap(),
      where: 'id = ?',
      whereArgs: [dish.id],
    );
  }

  Future<int> deleteDish(int id) async {
    final db = await database;
    return await db.delete('dishes', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getDishCountByCategory(int categoryId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM dishes WHERE category_id = ?',
      [categoryId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Meal Record CRUD
  Future<List<MealRecord>> getAllMealRecords() async {
    final db = await database;
    final result = await db.query('meal_records', orderBy: 'date DESC, meal_type ASC');
    return result.map((map) => MealRecord.fromMap(map)).toList();
  }

  Future<List<MealRecord>> getMealRecordsByDate(DateTime date) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final result = await db.query(
      'meal_records',
      where: 'date >= ? AND date < ?',
      whereArgs: [startOfDay.millisecondsSinceEpoch, endOfDay.millisecondsSinceEpoch],
      orderBy: 'meal_type ASC',
    );
    return result.map((map) => MealRecord.fromMap(map)).toList();
  }

  Future<int> insertMealRecord(MealRecord record) async {
    final db = await database;
    return await db.insert('meal_records', record.toMap()..remove('id'));
  }

  Future<int> updateMealRecord(MealRecord record) async {
    final db = await database;
    return await db.update(
      'meal_records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<int> deleteMealRecord(int id) async {
    final db = await database;
    return await db.delete('meal_records', where: 'id = ?', whereArgs: [id]);
  }

  // Practice Record CRUD
  Future<List<PracticeRecord>> getAllPracticeRecords() async {
    final db = await database;
    final result = await db.query('practice_records', orderBy: 'created_at DESC');
    return result.map((map) => PracticeRecord.fromMap(map)).toList();
  }

  Future<List<PracticeRecord>> getPracticeRecordsByDish(String dishName) async {
    final db = await database;
    final result = await db.query(
      'practice_records',
      where: 'dish_name = ?',
      whereArgs: [dishName],
      orderBy: 'created_at DESC',
    );
    return result.map((map) => PracticeRecord.fromMap(map)).toList();
  }

  Future<List<String>> getAllPracticeDishNames() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT DISTINCT dish_name FROM practice_records WHERE is_promoted = 0 ORDER BY dish_name ASC'
    );
    return result.map((map) => map['dish_name'] as String).toList();
  }

  Future<int> insertPracticeRecord(PracticeRecord record) async {
    final db = await database;
    return await db.insert('practice_records', record.toMap()..remove('id'));
  }

  Future<int> updatePracticeRecord(PracticeRecord record) async {
    final db = await database;
    return await db.update(
      'practice_records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<int> deletePracticeRecord(int id) async {
    final db = await database;
    return await db.delete('practice_records', where: 'id = ?', whereArgs: [id]);
  }

  // Stats
  Future<int> getTotalDishes() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM dishes');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getTotalMeals() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM meal_records');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<double> getAverageRating() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT AVG(rating) as avg_rating FROM meal_records WHERE rating IS NOT NULL'
    );
    return (result.first['avg_rating'] as double?) ?? 0.0;
  }
}
