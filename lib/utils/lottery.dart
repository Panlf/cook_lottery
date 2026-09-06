import 'dart:math';

import '../models/dish.dart';

/// 盲盒抽签算法：从选中的分类中各抽取指定数量的菜品。
///
/// 支持优先排除指定菜品（如近期吃过的菜）；当某分类被排除后无菜可抽时，
/// 自动回退为该分类的全部菜品，保证抽签总有结果。
class LotteryPicker {
  LotteryPicker._();

  static final Random _random = Random();

  static List<Dish> pick({
    required Iterable<int> selectedCategoryIds,
    required Map<int, List<Dish>> dishesByCategory,
    required Map<int, int> countPerCategory,
    Set<int> excludeDishIds = const {},
  }) {
    final result = <Dish>[];
    for (final categoryId in selectedCategoryIds) {
      final all = dishesByCategory[categoryId] ?? const <Dish>[];
      if (all.isEmpty) continue;

      var pool = all
          .where((dish) => !excludeDishIds.contains(dish.id))
          .toList();
      if (pool.isEmpty) pool = List.of(all);

      pool.shuffle(_random);
      final count = (countPerCategory[categoryId] ?? 1).clamp(1, pool.length);
      result.addAll(pool.take(count));
    }
    result.shuffle(_random);
    return result;
  }
}
