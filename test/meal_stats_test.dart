import 'package:flutter_test/flutter_test.dart';

import 'package:cook_lottery/models/dish.dart';
import 'package:cook_lottery/models/meal_record.dart';
import 'package:cook_lottery/utils/meal_stats.dart';

MealRecord _record({required DateTime date, int? rating, String dishIds = ''}) {
  return MealRecord(
    date: date,
    mealType: 'lunch',
    dishIds: dishIds,
    rating: rating,
  );
}

Dish _dish(int id, String name) => Dish(
  id: id,
  name: name,
  categoryId: 1,
  createdAt: DateTime.fromMillisecondsSinceEpoch(id * 1000),
);

void main() {
  final now = DateTime(2026, 9, 6, 12);

  test('空记录得到全零统计', () {
    final stats = MealStats.compute(const [], now: now);
    expect(stats.totalMeals, 0);
    expect(stats.weekMeals, 0);
    expect(stats.ratedMeals, 0);
    expect(stats.averageRating, 0.0);
    expect(stats.topDishes, isEmpty);
  });

  test('统计总餐数与本周餐数', () {
    final stats = MealStats.compute([
      _record(date: now, dishIds: '1'),
      _record(date: now.subtract(const Duration(days: 1)), dishIds: '2'),
      _record(
        date: now.subtract(const Duration(days: 6, hours: -1)),
        dishIds: '1',
      ),
      _record(date: now.subtract(const Duration(days: 30)), dishIds: '3'),
    ], now: now);
    expect(stats.totalMeals, 4);
    expect(stats.weekMeals, 3);
  });

  test('平均评分只统计已评价的记录', () {
    final stats = MealStats.compute([
      _record(date: now, rating: 5, dishIds: '1'),
      _record(date: now, rating: 3, dishIds: '2'),
      _record(date: now, dishIds: '3'),
    ], now: now);
    expect(stats.ratedMeals, 2);
    expect(stats.averageRating, closeTo(4.0, 0.001));
  });

  test('最常吃的菜品按次数倒序排列', () {
    final dishById = {
      1: _dish(1, '红烧肉'),
      2: _dish(2, '番茄炒蛋'),
      3: _dish(3, '已删除'),
    };
    final stats = MealStats.compute(
      [
        _record(date: now, dishIds: '1,2'),
        _record(date: now, dishIds: '1,2'),
        _record(date: now, dishIds: '1'),
        _record(date: now, dishIds: '3,4'),
      ],
      dishById: dishById,
      now: now,
      topN: 3,
    );
    expect(stats.topDishes.map((t) => t.displayName).toList(), [
      '红烧肉',
      '番茄炒蛋',
      '已删除',
    ]);
    expect(stats.topDishes[0].count, 3);
    expect(stats.topDishes[1].count, 2);
  });

  test('被删除的菜品显示为「已删除的菜」', () {
    final stats = MealStats.compute(
      [_record(date: now, dishIds: '9')],
      dishById: const {},
      now: now,
    );
    expect(stats.topDishes.single.displayName, '已删除的菜');
  });
}
