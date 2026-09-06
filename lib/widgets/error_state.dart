import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 数据加载失败时的兜底视图，提供重试入口，避免页面停留在无限加载。
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorState({super.key, this.message = '数据加载失败', required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppTheme.textHint),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: AppTheme.textHint, fontSize: 16),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
