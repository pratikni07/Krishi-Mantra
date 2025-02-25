import 'package:flutter/material.dart';

class AppPalette {
  static const Color secondaryColor = Color(0xFF31A05F);
  static const Color backgroundColor = Color(0xFFF5F5F5);
}

class ThemeClass{
  static ThemeData themeData = ThemeData(
    scaffoldBackgroundColor: AppPalette.backgroundColor,

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.disabled)) {
            return Colors.grey; // Disabled button color
          }
          return AppPalette.secondaryColor; // Default button color
        }),
        foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.disabled)) {
            return Colors.white54; // Disabled text color
          }
          return Colors.white; // Default text color
        }),
        shape: WidgetStateProperty.all<RoundedRectangleBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        textStyle: WidgetStateProperty.all<TextStyle>(
          const TextStyle(
            color: Colors.white,
          ),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppPalette.secondaryColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppPalette.secondaryColor),
      ),
      errorBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.red),
      ),
      labelStyle: TextStyle(color: AppPalette.secondaryColor),

    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppPalette.secondaryColor,
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all<Color>(Colors.white),
        foregroundColor:
        WidgetStateProperty.all<Color>(AppPalette.secondaryColor),
        shape: WidgetStateProperty.all<RoundedRectangleBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppPalette.backgroundColor,
      selectedItemColor: AppPalette.secondaryColor,
      unselectedItemColor: Colors.grey,
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.all<Color>(AppPalette.secondaryColor),
    ),


  );
}

