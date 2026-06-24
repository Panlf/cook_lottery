class PracticeRecord {
  final int? id;
  final String dishName;
  final int categoryId;
  final String? imagePath;
  final int? rating;
  final String? notes;
  final bool isPromoted;
  final int? promotedDishId;
  final DateTime createdAt;

  PracticeRecord({
    this.id,
    required this.dishName,
    required this.categoryId,
    this.imagePath,
    this.rating,
    this.notes,
    this.isPromoted = false,
    this.promotedDishId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dish_name': dishName,
      'category_id': categoryId,
      'image_path': imagePath,
      'rating': rating,
      'notes': notes,
      'is_promoted': isPromoted ? 1 : 0,
      'promoted_dish_id': promotedDishId,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory PracticeRecord.fromMap(Map<String, dynamic> map) {
    return PracticeRecord(
      id: map['id'] as int?,
      dishName: map['dish_name'] as String,
      categoryId: map['category_id'] as int,
      imagePath: map['image_path'] as String?,
      rating: map['rating'] as int?,
      notes: map['notes'] as String?,
      isPromoted: (map['is_promoted'] as int?) == 1,
      promotedDishId: map['promoted_dish_id'] as int?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  PracticeRecord copyWith({
    int? id,
    String? dishName,
    int? categoryId,
    String? imagePath,
    int? rating,
    String? notes,
    bool? isPromoted,
    int? promotedDishId,
  }) {
    return PracticeRecord(
      id: id ?? this.id,
      dishName: dishName ?? this.dishName,
      categoryId: categoryId ?? this.categoryId,
      imagePath: imagePath ?? this.imagePath,
      rating: rating ?? this.rating,
      notes: notes ?? this.notes,
      isPromoted: isPromoted ?? this.isPromoted,
      promotedDishId: promotedDishId ?? this.promotedDishId,
      createdAt: createdAt,
    );
  }
}
