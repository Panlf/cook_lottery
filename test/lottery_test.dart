import 'package:flutter_test/flutter_test.dart';

import 'package:cook_lottery/models/dish.dart';
import 'package:cook_lottery/utils/lottery.dart';

Dish _dish(int id, int categoryId) => Dish(
  id: id,
  name: '菜品$id',
  categoryId: categoryId,
  createdAt: DateTime.fromMillisecondsSinceEpoch(id * 1000),
);

void main() {
  group('LotteryPicker.pick', () {
    test('每个分类按指定数量抽取', () {
      final dishesByCategory = {
        1: [1, 2, 3, 4].map((id) => _dish(id, 1)).toList(),
        2: [5, 6].map((id) => _dish(id, 2)).toList(),
      };
      final result = LotteryPicker.pick(
        selectedCategoryIds: [1, 2],
        dishesByCategory: dishesByCategory,
        countPerCategory: {1: 2, 2: 1},
      );
      expect(result.length, 3);
      expect(result.where((d) => d.categoryId == 1).length, 2);
      expect(result.where((d) => d.categoryId == 2).length, 1);
    });

    test('同一分类内不出现重复菜品', () {
      final dishes = [1, 2, 3, 4, 5].map((id) => _dish(id, 1)).toList();
      for (var i = 0; i < 20; i++) {
        final result = LotteryPicker.pick(
          selectedCategoryIds: [1],
          dishesByCategory: {1: dishes},
          countPerCategory: {1: 3},
        );
        expect(result.map((d) => d.id).toSet().length, 3);
      }
    });

    test('抽取数量不超过该分类的菜品总数', () {
      final dishes = [1, 2].map((id) => _dish(id, 1)).toList();
      final result = LotteryPicker.pick(
        selectedCategoryIds: [1],
        dishesByCategory: {1: dishes},
        countPerCategory: {1: 10},
      );
      expect(result.length, 2);
    });

    test('排除近期吃过的菜品后不再被抽中', () {
      final dishes = [1, 2, 3, 4].map((id) => _dish(id, 1)).toList();
      for (var i = 0; i < 20; i++) {
        final result = LotteryPicker.pick(
          selectedCategoryIds: [1],
          dishesByCategory: {1: dishes},
          countPerCategory: {1: 2},
          excludeDishIds: {1, 2},
        );
        final ids = result.map((d) => d.id);
        expect(ids.contains(1), isFalse);
        expect(ids.contains(2), isFalse);
      }
    });

    test('整分类被排除时回退为全部菜品，保证有结果', () {
      final dishes = [1, 2].map((id) => _dish(id, 1)).toList();
      final result = LotteryPicker.pick(
        selectedCategoryIds: [1],
        dishesByCategory: {1: dishes},
        countPerCategory: {1: 1},
        excludeDishIds: {1, 2},
      );
      expect(result, isNotEmpty);
    });

    test('空分类被跳过，不影响其它分类', () {
      final result = LotteryPicker.pick(
        selectedCategoryIds: [1, 2],
        dishesByCategory: {
          1: <Dish>[],
          2: [5].map((id) => _dish(id, 2)).toList(),
        },
        countPerCategory: {1: 1, 2: 1},
      );
      expect(result.length, 1);
      expect(result.first.categoryId, 2);
    });

    test('未指定数量时默认每类抽 1 道', () {
      final result = LotteryPicker.pick(
        selectedCategoryIds: [1],
        dishesByCategory: {
          1: [1, 2].map((id) => _dish(id, 1)).toList(),
        },
        countPerCategory: {},
      );
      expect(result.length, 1);
    });
  });
}
