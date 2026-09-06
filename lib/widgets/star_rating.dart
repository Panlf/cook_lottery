import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 五星评分组件；[onChanged] 为空时只读。
class StarRating extends StatelessWidget {
  final int rating;
  final ValueChanged<int>? onChanged;
  final double size;

  const StarRating({
    super.key,
    required this.rating,
    this.onChanged,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final star = Icon(
          index < rating ? Icons.star : Icons.star_border,
          size: size,
          color: AppTheme.starColor,
        );
        if (onChanged == null) return star;
        return GestureDetector(
          onTap: () => onChanged(index + 1),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: size * 0.25),
            child: star,
          ),
        );
      }),
    );
  }
}
