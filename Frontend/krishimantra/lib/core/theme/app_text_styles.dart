import 'package:flutter/material.dart';
import '../constants/colors.dart';

/// Centralized text styles for consistent typography across the app.
/// Use these styles throughout the app to maintain consistency.
class AppTextStyles {
  // Prevent instantiation
  AppTextStyles._();

  // ============ HEADINGS ============

  /// Large heading - Used for screen titles
  /// Size: 28, Weight: Bold, Color: textDark
  static const TextStyle heading1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textDark,
  );

  /// Medium heading - Used for section titles
  /// Size: 24, Weight: Bold, Color: textDark
  static const TextStyle heading2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textDark,
  );

  /// Small heading - Used for card titles, list headers
  /// Size: 20, Weight: SemiBold, Color: textDark
  static const TextStyle heading3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
  );

  /// Smaller heading - Used for subsections
  /// Size: 18, Weight: SemiBold, Color: textDark
  static const TextStyle heading4 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
  );

  // ============ BODY TEXT ============

  /// Large body text
  /// Size: 16, Weight: Normal, Color: textDark
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textDark,
  );

  /// Medium body text (default)
  /// Size: 14, Weight: Normal, Color: textDark
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textDark,
  );

  /// Small body text
  /// Size: 12, Weight: Normal, Color: textGrey
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textGrey,
  );

  // ============ LABELS & CAPTIONS ============

  /// Label text - Used for form labels, chips
  /// Size: 14, Weight: Medium, Color: textDark
  static const TextStyle label = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textDark,
  );

  /// Caption text - Used for timestamps, hints
  /// Size: 12, Weight: Normal, Color: textLight
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textLight,
  );

  /// Overline text - Very small text
  /// Size: 10, Weight: Normal, Color: textLight
  static const TextStyle overline = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.normal,
    color: AppColors.textLight,
  );

  // ============ BUTTON TEXT ============

  /// Primary button text
  /// Size: 16, Weight: Bold, Color: white
  static const TextStyle buttonPrimary = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: AppColors.white,
  );

  /// Secondary button text
  /// Size: 14, Weight: SemiBold, Color: green
  static const TextStyle buttonSecondary = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.green,
  );

  /// Text button / link style
  /// Size: 14, Weight: Medium, Color: green
  static const TextStyle textButton = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.green,
  );

  // ============ SPECIAL STYLES ============

  /// App bar title style
  /// Size: 20, Weight: SemiBold, Color: white
  static const TextStyle appBarTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
  );

  /// App bar title dark style (for white backgrounds)
  /// Size: 20, Weight: SemiBold, Color: textDark
  static const TextStyle appBarTitleDark = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
  );

  /// Price text style
  /// Size: 18, Weight: Bold, Color: green
  static const TextStyle price = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.green,
  );

  /// Error text style
  /// Size: 12, Weight: Normal, Color: error
  static const TextStyle error = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.error,
  );

  /// Success text style
  /// Size: 14, Weight: Medium, Color: success
  static const TextStyle success = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.success,
  );

  // ============ DIALOG & MODAL STYLES ============

  /// Dialog title style
  /// Size: 18, Weight: Bold, Color: textDark
  static const TextStyle dialogTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.textDark,
  );

  /// Dialog body style
  /// Size: 14, Weight: Normal, Color: textGrey
  static const TextStyle dialogBody = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textGrey,
  );

  /// Bottom sheet title style
  /// Size: 20, Weight: Bold, Color: textDark
  static const TextStyle bottomSheetTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.textDark,
  );

  // ============ CARD STYLES ============

  /// Card title style
  /// Size: 16, Weight: SemiBold, Color: textDark
  static const TextStyle cardTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
  );

  /// Card subtitle style
  /// Size: 14, Weight: Normal, Color: textGrey
  static const TextStyle cardSubtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textGrey,
  );

  /// Card body style
  /// Size: 13, Weight: Normal, Color: textGrey
  static const TextStyle cardBody = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.normal,
    color: AppColors.textGrey,
  );

  // ============ INPUT STYLES ============

  /// Input text style
  /// Size: 16, Weight: Normal, Color: textDark
  static const TextStyle inputText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textDark,
  );

  /// Input hint style
  /// Size: 16, Weight: Normal, Color: textLight
  static const TextStyle inputHint = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textLight,
  );

  /// Input label style
  /// Size: 14, Weight: Medium, Color: textGrey
  static const TextStyle inputLabel = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textGrey,
  );

  // ============ CHIP STYLES ============

  /// Chip text style
  /// Size: 12, Weight: Medium, Color: textDark
  static const TextStyle chip = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textDark,
  );

  /// Selected chip text style
  /// Size: 12, Weight: Medium, Color: white
  static const TextStyle chipSelected = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.white,
  );

  // ============ WHITE TEXT STYLES (for dark backgrounds) ============

  /// White heading style
  /// Size: 24, Weight: Bold, Color: white
  static const TextStyle headingWhite = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.white,
  );

  /// White body style
  /// Size: 14, Weight: Normal, Color: white
  static const TextStyle bodyWhite = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.white,
  );

  /// White caption style
  /// Size: 12, Weight: Normal, Color: white with opacity
  static TextStyle captionWhite = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.white.withOpacity(0.8),
  );

  // ============ HELPER METHODS ============

  /// Create a custom text style with the given parameters
  static TextStyle custom({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.normal,
    Color color = AppColors.textDark,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
    );
  }

  /// Copy a style with a different color
  static TextStyle withColor(TextStyle style, Color color) {
    return style.copyWith(color: color);
  }

  /// Copy a style with a different size
  static TextStyle withSize(TextStyle style, double fontSize) {
    return style.copyWith(fontSize: fontSize);
  }
}
