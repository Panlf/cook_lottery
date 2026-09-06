import 'package:flutter_test/flutter_test.dart';

import 'package:cook_lottery/database/database_helper.dart';
import 'package:cook_lottery/models/category.dart';
import 'package:cook_lottery/models/dish.dart';
import 'package:cook_lottery/models/meal_record.dart';
import 'package:cook_lottery/models/practice_record.dart';

import 'helpers/test_db.dart';

DatabaseHelper get db => DatabaseHelper.instance;

void main() {
  setUpAll(() async {
    await initTestDatabaseFactory();
  });

  setUp(() => TestDatabase.setUp());
  tearDown(() => TestDatabase.tearDown());

  Future<int> createDish(String name, int categoryId) =>
      db.insertDish(Dish(name: name, categoryId: categoryId));

  group('初始化', () {
    test('首次创建写入 6 个默认分类', () async {
      final categories = await db.getAllCategories();
      expect(categories.map((c) => c.name), [
        '海鲜',
        '肉菜',
        '蔬菜',
        '汤品',
        '主食',
        '甜品',
      ]);
    });
  });

  group('菜品 CRUD', () {
    test('插入、查询、更新、删除', () async {
      final categories = await db.getAllCategories();
      final categoryId = categories.first.id!;

      final dishId = await createDish('红烧肉', categoryId);
      expect(dishId, greaterThan(0));

      final dish = await db.getDish(dishId);
      expect(dish, isNotNull);
      expect(dish!.name, '红烧肉');

      await db.updateDish(
        dish.copyWith(name: '秘制红烧肉', imagePath: '/img/a.jpg'),
      );
      final updated = await db.getDish(dishId);
      expect(updated!.name, '秘制红烧肉');
      expect(updated.imagePath, '/img/a.jpg');

      await db.deleteDish(dishId);
      expect(await db.getDish(dishId), isNull);
    });

    test('getDishesByIds 只返回存在的菜品', () async {
      final categories = await db.getAllCategories();
      final categoryId = categories.first.id!;
      final id1 = await createDish('菜一', categoryId);
      await createDish('菜二', categoryId);

      final dishes = await db.getDishesByIds([id1, 99999]);
      expect(dishes.length, 1);
      expect(dishes.first.id, id1);
      expect(await db.getDishesByIds([]), isEmpty);
    });

    test('getDishByName 按名称精确查找', () async {
      final categories = await db.getAllCategories();
      final categoryId = categories.first.id!;
      await createDish('可乐鸡翅', categoryId);

      expect((await db.getDishByName('可乐鸡翅'))!.categoryId, categoryId);
      expect(await db.getDishByName('不存在的菜'), isNull);
    });

    test('删除分类时其下菜品一并删除', () async {
      final categoryId = await db.insertCategory(
        DishCategory(name: '水果', emoji: '🍎', sortOrder: 99),
      );
      await createDish('苹果派', categoryId);
      expect((await db.getAllDishes()).length, 1);

      // 返回被删菜品的图片路径，供调用方清理文件
      final imagePaths = await db.deleteCategory(categoryId);
      expect(imagePaths, hasLength(1));
      expect(await db.getCategory(categoryId), isNull);
      expect(await db.getAllDishes(), isEmpty);
    });

    test('删除分类后下一个排序号不与现存分类重复', () async {
      // 初始预置 6 个分类（sort_order 0..5）
      expect(await db.getNextCategorySortOrder(), 6);
      await db.insertCategory(
        DishCategory(name: '水果', emoji: '🍎', sortOrder: 6),
      );
      expect(await db.getNextCategorySortOrder(), 7);

      for (final category in await db.getAllCategories()) {
        await db.deleteCategory(category.id!);
      }
      expect(await db.getNextCategorySortOrder(), 0);
    });
  });

  group('饮食记录', () {
    test('getMealRecordsContainingDish 按 ID 整段匹配', () async {
      final categories = await db.getAllCategories();
      final categoryId = categories.first.id!;
      // 1 和 11 是专门设计的边界：简单的子串匹配会把 1 误匹配进 11。
      final id1 = await createDish('菜一', categoryId);
      final id11 = await createDish('菜十一', categoryId);
      final id2 = await createDish('菜二', categoryId);

      final now = DateTime.now();
      await db.insertMealRecord(
        MealRecord(date: now, mealType: 'lunch', dishIds: '$id11'),
      );
      await db.insertMealRecord(
        MealRecord(date: now, mealType: 'dinner', dishIds: '$id1,$id2'),
      );

      final forDish1 = await db.getMealRecordsContainingDish(id1);
      expect(forDish1.length, 1);
      expect(forDish1.first.mealType, 'dinner');

      final forDish11 = await db.getMealRecordsContainingDish(id11);
      expect(forDish11.length, 1);
      expect(forDish11.first.mealType, 'lunch');

      expect(await db.getMealRecordsContainingDish(id2), hasLength(1));
    });

    test('countMealRecordsContainingDish 返回完整计数', () async {
      final categories = await db.getAllCategories();
      final categoryId = categories.first.id!;
      final id1 = await createDish('菜一', categoryId);
      final id11 = await createDish('菜十一', categoryId);

      final now = DateTime.now();
      await db.insertMealRecord(
        MealRecord(date: now, mealType: 'lunch', dishIds: '$id1'),
      );
      await db.insertMealRecord(
        MealRecord(date: now, mealType: 'dinner', dishIds: '$id1,$id11'),
      );

      expect(await db.countMealRecordsContainingDish(id1), 2);
      expect(await db.countMealRecordsContainingDish(id11), 1);
      expect(await db.countMealRecordsContainingDish(999999), 0);
    });

    test('同一天内午餐排在晚餐之前', () async {
      final now = DateTime.now();
      await db.insertMealRecord(
        MealRecord(date: now, mealType: 'dinner', dishIds: '1'),
      );
      await db.insertMealRecord(
        MealRecord(date: now, mealType: 'lunch', dishIds: '2'),
      );

      final records = await db.getAllMealRecords();
      expect(records.first.mealType, 'lunch');
      expect(records.last.mealType, 'dinner');
    });

    test('getEatenDishIdsSince 返回指定时间后吃过的菜品 ID', () async {
      final now = DateTime.now();
      await db.insertMealRecord(
        MealRecord(date: now, mealType: 'lunch', dishIds: '1,2'),
      );
      await db.insertMealRecord(
        MealRecord(
          date: now.subtract(const Duration(days: 30)),
          mealType: 'dinner',
          dishIds: '3',
        ),
      );

      final eaten = await db.getEatenDishIdsSince(
        now.subtract(const Duration(days: 7)),
      );
      expect(eaten, {1, 2});
    });
  });

  group('修炼记录', () {
    test('升级流程：插入修炼记录并标记升级', () async {
      final categories = await db.getAllCategories();
      final categoryId = categories.first.id!;

      final recordId = await db.insertPracticeRecord(
        PracticeRecord(dishName: '蛋炒饭', categoryId: categoryId, rating: 3),
      );
      expect(recordId, greaterThan(0));

      final dishId = await createDish('蛋炒饭', categoryId);
      final record = (await db.getAllPracticeRecords()).first;
      await db.updatePracticeRecord(
        record.copyWith(isPromoted: true, promotedDishId: dishId),
      );

      final promoted = (await db.getAllPracticeRecords()).first;
      expect(promoted.isPromoted, isTrue);
      expect(promoted.promotedDishId, dishId);
    });

    test('删除修炼记录', () async {
      final categories = await db.getAllCategories();
      final recordId = await db.insertPracticeRecord(
        PracticeRecord(dishName: '番茄炒蛋', categoryId: categories.first.id!),
      );
      await db.deletePracticeRecord(recordId);
      expect(await db.getAllPracticeRecords(), isEmpty);
    });
  });
}
