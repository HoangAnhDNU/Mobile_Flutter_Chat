import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class NetworkUtils {
  static Future<T?> handleAsync<T>(
    BuildContext context,
    Future<T> Function() action, {
    String? loadingMessage,
    String? successMessage,
  }) async {
    try {
      final result = await action().timeout(const Duration(seconds: 15));
      if (successMessage != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage), backgroundColor: AppColors.success),
        );
      }
      return result;
    } on TimeoutException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kết nối quá chậm. Vui lòng thử lại.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return null;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString().length > 80 ? '${e.toString().substring(0, 80)}...' : e}'),
            backgroundColor: AppColors.error,
            action: SnackBarAction(
              label: 'Thử lại',
              textColor: Colors.white,
              onPressed: () => handleAsync(context, action, loadingMessage: loadingMessage, successMessage: successMessage),
            ),
          ),
        );
      }
      return null;
    }
  }
}
