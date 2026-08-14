import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTextStyles {
  static const TextStyle display = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 30,
    height: 1.15,
    fontWeight: FontWeight.w800,
  );

  static const TextStyle title = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 22,
    height: 1.25,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle subtitle = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle label = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 13,
    height: 1.2,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle body = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 14,
    height: 1.45,
  );

  static const TextStyle caption = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 12,
    height: 1.4,
  );
}
