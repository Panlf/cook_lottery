class DishCategory {
  final int? id;
  final String name;
  final String emoji;
  final int sortOrder;

  DishCategory({
    this.id,
    required this.name,
    this.emoji = '🍽️',
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'emoji': emoji, 'sort_order': sortOrder};
  }

  factory DishCategory.fromMap(Map<String, dynamic> map) {
    return DishCategory(
      id: map['id'] as int?,
      name: map['name'] as String,
      emoji: map['emoji'] as String? ?? '🍽️',
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }

  DishCategory copyWith({
    int? id,
    String? name,
    String? emoji,
    int? sortOrder,
  }) {
    return DishCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
