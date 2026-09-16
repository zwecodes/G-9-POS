import 'package:flutter/material.dart';

/// Design tokens — UI-GUIDELINES.md §3.1. Never hardcode hex in widgets.
class AppColors {
  AppColors._();

  static const primary = Color(0xFF1B4FFF);
  static const primaryLight = Color(0xFFEEF2FF);

  static const background = Color(0xFFF5F5F5);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF0F0F0);

  static const textPrimary = Color(0xFF111111);
  static const textSecondary = Color(0xFF666666);
  static const textMuted = Color(0xFF999999);

  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const stale = Color(0xFFEA580C);
  static const error = Color(0xFFDC2626);
  static const info = Color(0xFF0EA5E9);

  static const amount = Color(0xFF111111);
  static const amountLarge = Color(0xFF1B4FFF);

  static const onPrimary = Color(0xFFFFFFFF);
  static const offlineBanner = Color(0xFFF59E0B);
}
