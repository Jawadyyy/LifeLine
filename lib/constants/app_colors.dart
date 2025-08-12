import 'package:flutter/material.dart';

// Your original colors, unchanged
class AppColors {
  static const Color primary = Color(0xFFFF6F61);
  static const Color accent = Color(0xFFFF8A80);
  static const Color secondary = Color(0xFF4CAF50);
  static const Color tertiary = Color(0xFFE0E0E0);
  static const Color transparent = Colors.transparent;

  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Colors.white;
  static const Color textPrimary = Colors.black87;
  static const Color textSecondary = Colors.black54;
  static const Color textTertiary = Colors.white;
  static const Color textGrey = Color(0xFF757575);
  static const Color textMedium = Color(0xFF616161);
  static const Color textLight = Color(0xFF9E9E9E);

  static const Color error = Colors.redAccent;
  static const Color success = Colors.green;

  static const Color navBarBackground = Colors.white;
  static const Color navBarUnselected = Color(0xFF757575);
  static const Color navBarShadow = Colors.black26;
}

// Now create a **dynamic accessor** that depends on current theme mode
class DynamicColors {
  final bool isDarkMode;

  DynamicColors(this.isDarkMode);

  // Primary colors stay the same
  Color get primary => AppColors.primary;
  Color get accent => AppColors.accent;
  Color get secondary => AppColors.secondary;
  Color get transparent => AppColors.transparent;
  Color get error => AppColors.error;

  // Dynamic colors: flip or use dark variants
  Color get tertiary => isDarkMode ? Color(0xFF303030) : AppColors.tertiary;
  Color get background => isDarkMode ? Color(0xFF121212) : AppColors.background;
  Color get surface => isDarkMode ? Color(0xFF1E1E1E) : AppColors.surface;
  Color get textPrimary => isDarkMode ? Colors.white70 : AppColors.textPrimary;
  Color get textSecondary =>
      isDarkMode ? Colors.white54 : AppColors.textSecondary;
  Color get textTertiary =>
      isDarkMode ? Colors.black87 : AppColors.textTertiary;
  Color get textGrey => isDarkMode ? Color(0xFFB0B0B0) : AppColors.textGrey;
  Color get textMedium => isDarkMode ? Color(0xFFCCCCCC) : AppColors.textMedium;
  Color get textLight => isDarkMode ? Color(0xFFE0E0E0) : AppColors.textLight;
  Color get success => isDarkMode ? Colors.greenAccent : AppColors.success;

  Color get navBarBackground =>
      isDarkMode ? Color(0xFF1E1E1E) : AppColors.navBarBackground;
  Color get navBarUnselected =>
      isDarkMode ? Color(0xFFB0B0B0) : AppColors.navBarUnselected;
  Color get navBarShadow =>
      isDarkMode ? Colors.black87 : AppColors.navBarShadow;
}
