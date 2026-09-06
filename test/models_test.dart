import 'package:flutter_test/flutter_test.dart';

import 'package:cook_lottery/models/category.dart';
import 'package:cook_lottery/models/dish.dart';
import 'package:cook_lottery/models/meal_record.dart';
import 'package:cook_lottery/models/practice_record.dart';

void main() {
  group('MealRecord.parseDishIds', () {
    test('解析逗号分隔的 ID 并忽略非法值', () {
      expect(MealRecord.parseDishIds('1,2,3'), [1, 2, 3]);
      expect(MealRecord.parseDishIds(' 5 , 12 '), [5, 12]);
      expect(MealRecord.parseDishIds('1,,abc,0,3'), [1, 3]);
      expect(MealRecord.parseDishIds(''), isEmpty);
      expect(MealRecord.parseDishIds('abc'), isEmpty);
    });

    test('dishIdList 复用解析逻辑', () {
      final record = MealRecord(
        date: DateTime(2026, 9, 1),
        mealType: 'lunch',
        dishIds: '4,8,15',
      );
      expect(record.dishIdList, [4, 8, 15]);
    });
  });

  group('MealRecord', () {
    test('toMap/fromMap 往返一致', () {
      final record = MealRecord(
        id: 7,
        date: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        mealType: 'dinner',
        dishIds: '1,2',
        rating: 4,
        notes: '不错',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000001000),
      );
      final restored = MealRecord.fromMap(record.toMap());
      expect(restored.id, record.id);
      expect(restored.date, record.date);
      expect(restored.mealType, record.mealType);
      expect(restored.dishIds, record.dishIds);
      expect(restored.rating, record.rating);
      expect(restored.notes, record.notes);
      expect(restored.createdAt, record.createdAt);
    });

    test('copyWith 保留原有 createdAt', () {
      final createdAt = DateTime(2026, 9, 1, 12);
      final record = MealRecord(
        date: createdAt,
        mealType: 'lunch',
        dishIds: '1',
        createdAt: createdAt,
      );
      final updated = record.copyWith(rating: 5, notes: '好吃');
      expect(updated.rating, 5);
      expect(updated.notes, '好吃');
      expect(updated.createdAt, createdAt);
      expect(updated.date, createdAt);
    });

    test('copyWith 哨兵模式：缺省保留、显式 null 清除', () {
      final record = MealRecord(
        date: DateTime(2026, 9, 1),
        mealType: 'lunch',
        dishIds: '1',
        rating: 4,
        notes: '好吃',
      );
      // 未提及的字段保留原值
      final unchanged = record.copyWith(date: DateTime(2026, 9, 2));
      expect(unchanged.rating, 4);
      expect(unchanged.notes, '好吃');
      // 显式传 null 清除字段
      final cleared = record.copyWith(rating: null);
      expect(cleared.rating, isNull);
      expect(cleared.notes, '好吃');
    });
  });

  group('Dish', () {
    test('toMap/fromMap 往返一致', () {
      final dish = Dish(
        id: 3,
        name: '红烧肉',
        categoryId: 2,
        imagePath: '/tmp/a.jpg',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
      final restored = Dish.fromMap(dish.toMap());
      expect(restored.id, 3);
      expect(restored.name, '红烧肉');
      expect(restored.categoryId, 2);
      expect(restored.imagePath, '/tmp/a.jpg');
      expect(restored.createdAt, dish.createdAt);
    });

    test('imagePath 允许为空', () {
      final dish = Dish(name: '白粥', categoryId: 5);
      expect(dish.imagePath, isNull);
      expect(
        Dish.fromMap({
          'id': 1,
          'name': '白粥',
          'category_id': 5,
          'created_at': 0,
        }).imagePath,
        isNull,
      );
    });
  });

  group('DishCategory', () {
    test('fromMap 对缺失字段应用默认值', () {
      final category = DishCategory.fromMap({'id': 1, 'name': '水果'});
      expect(category.emoji, '🍽️');
      expect(category.sortOrder, 0);
    });

    test('copyWith 更新名称与图标', () {
      final category = DishCategory(
        id: 1,
        name: '海鲜',
        emoji: '🦐',
        sortOrder: 0,
      );
      final updated = category.copyWith(name: '河鲜', emoji: '🐟');
      expect(updated.name, '河鲜');
      expect(updated.emoji, '🐟');
      expect(updated.id, 1);
      expect(updated.sortOrder, 0);
    });
  });

  group('PracticeRecord', () {
    test('isPromoted 与数据库 0/1 值互转', () {
      final record = PracticeRecord(
        dishName: '蛋炒饭',
        categoryId: 4,
        isPromoted: true,
      );
      expect(record.toMap()['is_promoted'], 1);
      expect(
        PracticeRecord.fromMap({
          ...record.toMap(),
          'id': 1,
          'created_at': 0,
        }).isPromoted,
        isTrue,
      );

      final notPromoted = PracticeRecord.fromMap({
        'id': 1,
        'dish_name': '蛋炒饭',
        'category_id': 4,
        'created_at': 0,
      });
      expect(notPromoted.isPromoted, isFalse);
      expect(notPromoted.promotedDishId, isNull);
    });
  });
}
