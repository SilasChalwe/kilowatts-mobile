import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTextStyles {
  static const TextStyle display = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 32,
    height: 1.14,
    letterSpacing: -0.6,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle pageTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 26,
    height: 1.2,
    letterSpacing: -0.35,
    fontWeight: FontWeight.w700,
  );

  /// Kept for existing call sites. New page headings should use [pageTitle].
  static const TextStyle title = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 20,
    height: 1.25,
    letterSpacing: -0.15,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle sectionTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 16,
    height: 1.3,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle subtitle = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 14,
    height: 1.5,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle label = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 13,
    height: 1.3,
    letterSpacing: 0.05,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle body = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 14,
    height: 1.5,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle bodyStrong = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 14,
    height: 1.5,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle caption = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 12,
    height: 1.45,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle overline = TextStyle(
    color: AppColors.textTertiary,
    fontSize: 11,
    height: 1.3,
    letterSpacing: 0.8,
    fontWeight: FontWeight.w700,
  );
}
