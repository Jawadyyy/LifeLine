// lib/constants/app_text_styles.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  static final headingLarge = GoogleFonts.nunito(
    fontSize: 36,
    fontWeight: FontWeight.bold,
    color: AppColors.textTertiary,
  );

  static final headingMedium = GoogleFonts.nunito(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static final bodyText = GoogleFonts.nunito(
    fontSize: 16,
    color: AppColors.textGrey,
    height: 1.5,
  );

  static final buttonText = GoogleFonts.nunito(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textTertiary,
  );
}
