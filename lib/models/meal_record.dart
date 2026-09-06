class MealRecord {
  final int? id;
  final DateTime date;
  final String mealType; // 'lunch' or 'dinner'
  final String dishIds; // comma-separated dish IDs
  final int? rating; // 1-5
  final String? notes;
  final DateTime createdAt;

  MealRecord({
    this.id,
    required this.date,
    required this.mealType,
    required this.dishIds,
    this.rating,
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 解析逗号分隔的菜品 ID 字符串，忽略空值、非法值和 0。
  static List<int> parseDishIds(String dishIds) {
    return dishIds
        .split(',')
        .map((part) => int.tryParse(part.trim()))
        .whereType<int>()
        .where((id) => id > 0)
        .toList();
  }

  List<int> get dishIdList => parseDishIds(dishIds);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.millisecondsSinceEpoch,
      'meal_type': mealType,
      'dish_ids': dishIds,
      'rating': rating,
      'notes': notes,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory MealRecord.fromMap(Map<String, dynamic> map) {
    return MealRecord(
      id: map['id'] as int?,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      mealType: map['meal_type'] as String,
      dishIds: map['dish_ids'] as String,
      rating: map['rating'] as int?,
      notes: map['notes'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  static const _unset = Object();

  /// [rating]/[notes] 缺省时保留原值；显式传 null 可清除对应字段（哨兵模式）。
  MealRecord copyWith({
    int? id,
    DateTime? date,
    String? mealType,
    String? dishIds,
    Object? rating = _unset,
    Object? notes = _unset,
  }) {
    return MealRecord(
      id: id ?? this.id,
      date: date ?? this.date,
      mealType: mealType ?? this.mealType,
      dishIds: dishIds ?? this.dishIds,
      rating: rating == _unset ? this.rating : rating as int?,
      notes: notes == _unset ? this.notes : notes as String?,
      createdAt: createdAt,
    );
  }
}
