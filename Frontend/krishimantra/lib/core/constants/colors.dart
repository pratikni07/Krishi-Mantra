import 'package:flutter/material.dart';

class AppColors {
  // Prevent instantiation
  AppColors._();

  // Primary Colors
  static const Color white = Colors.white;
  static const Color black = Colors.black;
  static const Color faintGreen = Color(0xFFEFEFF0);
  static const Color green = Color(0xFF31A05F);
  static const Color lightGreen = Color(0xFF74CE58);
  static const Color orange = Color(0xFFEF9920);
  static const Color warmOrange = Color(0xFFE09F3E);

  // Background Colors
  static const Color background = Color(0xFFF5F3EF);
  static const Color cardBackground = Colors.white;
  static const Color scaffoldBackground = Color(0xFFF5F5F5);
  static const Color surfaceLight = Color(0xFFFAFAFA);

  // Text Colors
  static const Color textDark = Color(0xFF2C3639);
  static const Color textLight = Color(0xFF6B7280);
  static const Color textGrey = Color(0xFF4B4B4B);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color iconBgColor = Color(0xFF4B4B4B);

  // Border Colors
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color borderGrey = Color(0xFFD1D5DB);
  static const Color divider = Color(0xFFE0E0E0);

  // Status Colors
  static const Color error = Color(0xFFE53935);
  static const Color success = Color(0xFF43A047);
  static const Color warning = Color(0xFFFFA726);
  static const Color info = Color(0xFF29B6F6);

  // Overlay & Shadow Colors
  static const Color shadowLight = Color(0x1A000000);
  static const Color shadowMedium = Color(0x26000000);
  static const Color overlayDark = Color(0x80000000);

  // Disabled State Colors
  static const Color disabled = Color(0xFFBDBDBD);
  static const Color disabledBackground = Color(0xFFF5F5F5);

  // Input Field Colors
  static const Color inputFill = Color(0xFFF5F5F5);
  static const Color inputBorder = Color(0xFFE0E0E0);
  static const Color inputFocusBorder = green;

  // Shimmer Colors (for loading states)
  static const Color shimmerBase = Color(0xFFE0E0E0);
  static const Color shimmerHighlight = Color(0xFFF5F5F5);
}
