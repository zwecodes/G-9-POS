import 'package:flutter/material.dart';

import 'app_colors.dart';

/// UI-GUIDELINES.md §3.2.
class AppTextStyles {
  AppTextStyles._();

  static const saleTotal = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w800,
    letterSpacing: -1,
    color: AppColors.amountLarge,
  );

  static const title = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const sectionHeader = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: AppColors.textMuted,
  );

  static const buttonPrimary = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: AppColors.onPrimary,
  );
}
