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

  List<int> get dishIdList {
    if (dishIds.isEmpty) return [];
    return dishIds.split(',').map((e) => int.tryParse(e.trim()) ?? 0).where((e) => e > 0).toList();
  }

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

  MealRecord copyWith({
    int? id,
    DateTime? date,
    String? mealType,
    String? dishIds,
    int? rating,
    String? notes,
  }) {
    return MealRecord(
      id: id ?? this.id,
      date: date ?? this.date,
      mealType: mealType ?? this.mealType,
      dishIds: dishIds ?? this.dishIds,
      rating: rating ?? this.rating,
      notes: notes ?? this.notes,
      createdAt: createdAt,
    );
  }
}
