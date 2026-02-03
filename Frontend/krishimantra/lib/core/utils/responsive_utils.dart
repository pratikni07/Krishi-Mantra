import 'package:flutter/material.dart';

/// Responsive utilities for consistent sizing across all screen sizes
/// Supports mobile phones, tablets, and handles orientation changes
class ResponsiveUtils {
  static late MediaQueryData _mediaQueryData;
  static late double screenWidth;
  static late double screenHeight;
  static late double blockSizeHorizontal;
  static late double blockSizeVertical;
  static late double safeBlockHorizontal;
  static late double safeBlockVertical;
  static late double textScaleFactor;
  static late EdgeInsets safePadding;

  /// Screen size breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  /// Initialize responsive utilities - call this in build method
  static void init(BuildContext context) {
    _mediaQueryData = MediaQuery.of(context);
    screenWidth = _mediaQueryData.size.width;
    screenHeight = _mediaQueryData.size.height;
    safePadding = _mediaQueryData.padding;
    textScaleFactor = _mediaQueryData.textScaler.scale(1.0).clamp(0.8, 1.4);

    // Block sizes for percentage-based sizing
    blockSizeHorizontal = screenWidth / 100;
    blockSizeVertical = screenHeight / 100;

    // Safe area adjusted block sizes
    final safeAreaHorizontal = safePadding.left + safePadding.right;
    final safeAreaVertical = safePadding.top + safePadding.bottom;
    safeBlockHorizontal = (screenWidth - safeAreaHorizontal) / 100;
    safeBlockVertical = (screenHeight - safeAreaVertical) / 100;
  }

  /// Device type detection
  static bool get isMobile => screenWidth < mobileBreakpoint;
  static bool get isTablet => screenWidth >= mobileBreakpoint && screenWidth < tabletBreakpoint;
  static bool get isDesktop => screenWidth >= tabletBreakpoint;
  static bool get isSmallMobile => screenWidth < 360;
  static bool get isLandscape => screenWidth > screenHeight;

  /// Responsive width (percentage of screen width)
  static double wp(double percentage) => blockSizeHorizontal * percentage;

  /// Responsive height (percentage of screen height)
  static double hp(double percentage) => blockSizeVertical * percentage;

  /// Safe responsive width (excluding safe area)
  static double swp(double percentage) => safeBlockHorizontal * percentage;

  /// Safe responsive height (excluding safe area)
  static double shp(double percentage) => safeBlockVertical * percentage;

  /// Responsive font size based on screen width
  static double sp(double size) {
    final scaledSize = (size * screenWidth) / 375; // Base on iPhone 8 width
    return scaledSize * textScaleFactor;
  }

  /// Responsive spacing/padding
  static double spacing(double value) {
    if (isSmallMobile) return value * 0.8;
    if (isTablet) return value * 1.2;
    if (isDesktop) return value * 1.4;
    return value;
  }

  /// Responsive icon size
  static double iconSize(double baseSize) {
    if (isSmallMobile) return baseSize * 0.85;
    if (isTablet) return baseSize * 1.15;
    if (isDesktop) return baseSize * 1.3;
    return baseSize;
  }

  /// Get responsive value based on device type
  static T responsive<T>({
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop && desktop != null) return desktop;
    if (isTablet && tablet != null) return tablet;
    return mobile;
  }

  /// Grid cross axis count based on screen size
  static int get gridCrossAxisCount {
    if (screenWidth >= 1200) return 4;
    if (screenWidth >= 900) return 3;
    if (screenWidth >= 600) return 3;
    return 2;
  }

  /// Grid child aspect ratio based on screen size
  static double get gridAspectRatio {
    if (isTablet) return 0.85;
    if (isSmallMobile) return 0.7;
    return 0.75;
  }
}

/// Extension for easy responsive sizing on num types
extension ResponsiveExtension on num {
  /// Responsive width percentage
  double get w => ResponsiveUtils.wp(toDouble());

  /// Responsive height percentage
  double get h => ResponsiveUtils.hp(toDouble());

  /// Responsive font size
  double get sp => ResponsiveUtils.sp(toDouble());

  /// Responsive spacing
  double get rs => ResponsiveUtils.spacing(toDouble());
}

/// Responsive sizing constants
class AppSizes {
  // Padding & Margins
  static double get paddingXS => 4.0.rs;
  static double get paddingS => 8.0.rs;
  static double get paddingM => 12.0.rs;
  static double get paddingL => 16.0.rs;
  static double get paddingXL => 24.0.rs;
  static double get paddingXXL => 32.0.rs;

  // Border Radius
  static double get radiusXS => 2.0.rs;
  static double get radiusS => 4.0.rs;
  static double get radiusM => 8.0.rs;
  static double get radiusL => 12.0.rs;
  static double get radiusXL => 16.0.rs;
  static double get radiusXXL => 24.0.rs;
  static double get radiusRound => 100.0;

  // Icon Sizes
  static double get iconXS => ResponsiveUtils.iconSize(16);
  static double get iconS => ResponsiveUtils.iconSize(20);
  static double get iconM => ResponsiveUtils.iconSize(24);
  static double get iconL => ResponsiveUtils.iconSize(32);
  static double get iconXL => ResponsiveUtils.iconSize(48);

  // Font Sizes
  static double get fontXS => 10.0.sp;
  static double get fontS => 12.0.sp;
  static double get fontM => 14.0.sp;
  static double get fontL => 16.0.sp;
  static double get fontXL => 18.0.sp;
  static double get fontXXL => 20.0.sp;
  static double get fontHeading => 24.0.sp;
  static double get fontTitle => 28.0.sp;

  // Button Heights
  static double get buttonHeight => ResponsiveUtils.responsive(
        mobile: 48.0,
        tablet: 52.0,
        desktop: 56.0,
      );

  static double get buttonHeightSmall => ResponsiveUtils.responsive(
        mobile: 36.0,
        tablet: 40.0,
        desktop: 44.0,
      );

  // Avatar Sizes
  static double get avatarS => ResponsiveUtils.responsive(
        mobile: 32.0,
        tablet: 40.0,
      );

  static double get avatarM => ResponsiveUtils.responsive(
        mobile: 48.0,
        tablet: 56.0,
      );

  static double get avatarL => ResponsiveUtils.responsive(
        mobile: 64.0,
        tablet: 80.0,
      );

  static double get avatarXL => ResponsiveUtils.responsive(
        mobile: 80.0,
        tablet: 100.0,
      );

  // Card dimensions
  static double get cardElevation => 2.0;
  static double get cardBorderRadius => radiusL;

  // App Bar
  static double get appBarHeight => ResponsiveUtils.responsive(
        mobile: 56.0,
        tablet: 64.0,
      );

  // Bottom Navigation
  static double get bottomNavHeight => ResponsiveUtils.responsive(
        mobile: 60.0,
        tablet: 70.0,
      );
}

/// Responsive SizedBox widgets
class RSizedBox {
  static SizedBox get h4 => SizedBox(height: 4.0.rs);
  static SizedBox get h8 => SizedBox(height: 8.0.rs);
  static SizedBox get h12 => SizedBox(height: 12.0.rs);
  static SizedBox get h16 => SizedBox(height: 16.0.rs);
  static SizedBox get h20 => SizedBox(height: 20.0.rs);
  static SizedBox get h24 => SizedBox(height: 24.0.rs);
  static SizedBox get h32 => SizedBox(height: 32.0.rs);
  static SizedBox get h48 => SizedBox(height: 48.0.rs);

  static SizedBox get w4 => SizedBox(width: 4.0.rs);
  static SizedBox get w8 => SizedBox(width: 8.0.rs);
  static SizedBox get w12 => SizedBox(width: 12.0.rs);
  static SizedBox get w16 => SizedBox(width: 16.0.rs);
  static SizedBox get w20 => SizedBox(width: 20.0.rs);
  static SizedBox get w24 => SizedBox(width: 24.0.rs);
  static SizedBox get w32 => SizedBox(width: 32.0.rs);
}

/// Responsive EdgeInsets
class RPadding {
  static EdgeInsets get zero => EdgeInsets.zero;

  static EdgeInsets all(double value) => EdgeInsets.all(value.rs);

  static EdgeInsets symmetric({double horizontal = 0, double vertical = 0}) =>
      EdgeInsets.symmetric(horizontal: horizontal.rs, vertical: vertical.rs);

  static EdgeInsets only({
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
  }) =>
      EdgeInsets.only(
        left: left.rs,
        top: top.rs,
        right: right.rs,
        bottom: bottom.rs,
      );

  // Common padding presets
  static EdgeInsets get screenHorizontal =>
      EdgeInsets.symmetric(horizontal: AppSizes.paddingL);

  static EdgeInsets get screenAll => EdgeInsets.all(AppSizes.paddingL);

  static EdgeInsets get cardPadding => EdgeInsets.all(AppSizes.paddingM);

  static EdgeInsets get listItemPadding => EdgeInsets.symmetric(
        horizontal: AppSizes.paddingL,
        vertical: AppSizes.paddingM,
      );
}
