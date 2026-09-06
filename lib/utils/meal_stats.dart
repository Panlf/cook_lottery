import '../models/dish.dart';
import '../models/meal_record.dart';

/// 统计结果中最常吃菜品的一项；[dish] 为空表示该菜品已从菜库删除。
class TopDish {
  final Dish? dish;
  final int count;

  const TopDish({this.dish, required this.count});

  String get displayName => dish?.name ?? '已删除的菜';
}

/// 饮食记录统计：总餐数、近一周餐数、平均评分与最常吃的菜。
class MealStats {
  final int totalMeals;
  final int weekMeals;
  final int ratedMeals;
  final double averageRating;
  final List<TopDish> topDishes;

  const MealStats({
    required this.totalMeals,
    required this.weekMeals,
    required this.ratedMeals,
    required this.averageRating,
    required this.topDishes,
  });

  /// 纯函数计算，便于单元测试。
  static MealStats compute(
    List<MealRecord> records, {
    Map<int, Dish> dishById = const {},
    DateTime? now,
    int topN = 3,
  }) {
    final current = now ?? DateTime.now();
    final weekStart = current.subtract(const Duration(days: 7));

    var ratedCount = 0;
    var ratingSum = 0;
    var weekCount = 0;
    final dishCount = <int, int>{};
    for (final record in records) {
      if (record.rating != null) {
        ratedCount++;
        ratingSum += record.rating!;
      }
      if (record.date.isAfter(weekStart)) weekCount++;
      for (final id in record.dishIdList) {
        dishCount[id] = (dishCount[id] ?? 0) + 1;
      }
    }

    final topDishes = dishCount.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return a.key.compareTo(b.key);
      });

    return MealStats(
      totalMeals: records.length,
      weekMeals: weekCount,
      ratedMeals: ratedCount,
      averageRating: ratedCount == 0 ? 0.0 : ratingSum / ratedCount,
      topDishes: topDishes
          .take(topN)
          .map(
            (entry) => TopDish(dish: dishById[entry.key], count: entry.value),
          )
          .toList(),
    );
  }
}
