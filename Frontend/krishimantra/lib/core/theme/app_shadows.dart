import 'package:flutter/material.dart';

/// Centralised shadow tokens.
///
/// Why: every card, dialog, and floating button used to inline its own
/// `BoxShadow(...)` with subtly different blur and offset values.
/// Result: visually inconsistent depth and a one-line change rippling
/// through dozens of files. Anywhere you'd type a `BoxShadow` literal,
/// reach for one of these instead.
class AppShadows {
  AppShadows._();

  /// Soft drop shadow for resting cards / list tiles.
  static const List<BoxShadow> low = [
    BoxShadow(
      color: Color(0x14000000), // ~8% black
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];

  /// Standard depth — buttons, sheets, primary surfaces.
  static const List<BoxShadow> medium = [
    BoxShadow(
      color: Color(0x1F000000), // ~12% black
      blurRadius: 10,
      offset: Offset(0, 4),
    ),
  ];

  /// Floating elements — FAB, bottom sheets, modal cards.
  static const List<BoxShadow> high = [
    BoxShadow(
      color: Color(0x29000000), // ~16% black
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
  ];

  /// Inset-feel for chips and pills that need just a hint of depth.
  static const List<BoxShadow> hairline = [
    BoxShadow(
      color: Color(0x0F000000), // ~6% black
      blurRadius: 3,
      offset: Offset(0, 1),
    ),
  ];
}
