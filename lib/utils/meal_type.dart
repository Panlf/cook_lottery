/// 餐次（'lunch' / 'dinner'）相关的展示文案。
extension MealTypeText on String {
  bool get isLunch => this == 'lunch';

  String get mealLabel => isLunch ? '午餐' : '晚餐';

  String get mealEmoji => isLunch ? '☀️' : '🌙';

  String get mealShortLabel => isLunch ? '午' : '晚';
}
