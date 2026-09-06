import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 统一的错误提示；写操作失败等场景都走这里，保证失败对用户有感知。
void showErrorSnackBar(BuildContext context, [String message = '操作失败，请重试']) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: AppTheme.deleteColor),
  );
}
