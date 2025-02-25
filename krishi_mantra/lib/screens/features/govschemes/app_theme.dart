// app_theme.dart

import 'package:flutter/material.dart';

class AppTheme {
  // Primary Colors
  static const primaryGreen = Color(0xFF2E7D32); // Dark Green
  static const secondaryGreen = Color(0xFF4CAF50); // Medium Green
  static final lightGreen = Colors.green[50]; // Very Light Green

  // Background Colors
  static const backgroundColor = Colors.white;
  static final surfaceColor = Colors.grey[50]; // Off-white

  // Text Colors
  static const primaryText = Color(0xFF212121);
  static const secondaryText = Color(0xFF757575);

  // Custom Colors
  static final chipBackground = Colors.green[50];
  static final chipSelectedBackground = Colors.green[100];

  static ThemeData get theme => ThemeData(
        primaryColor: primaryGreen,
        scaffoldBackgroundColor: backgroundColor,
        appBarTheme: AppBarTheme(
          backgroundColor: primaryGreen,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryGreen,
            foregroundColor: Colors.white,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryGreen,
            side: BorderSide(color: primaryGreen),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primaryGreen,
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: chipBackground,
          selectedColor: chipSelectedBackground,
          labelStyle: TextStyle(color: primaryText),
          secondaryLabelStyle: TextStyle(color: primaryGreen),
        ),
        cardTheme: CardTheme(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
}
