import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens for the redesigned LifeLine surfaces — Home, Medical ID and the
/// AI Assistant — matching the Claude Design "LifeLine Redesign" spec.
///
/// Kept separate from [AppColors] so the warm orange system used by these three
/// screens can evolve without disturbing the rest of the app.
class LL {
  LL._();

  // ── Palette ─────────────────────────────────────────────────────────────
  static const Color ink = Color(0xFF1B1E26); // primary text
  static const Color ink2 = Color(0xFF2A2E38); // body text on cards
  static const Color muted = Color(0xFF8B8F99); // secondary text
  static const Color faint = Color(0xFF9CA0AB); // labels / placeholders
  static const Color canvas = Color(0xFFF4F5F7); // screen background
  static const Color card = Colors.white;
  static const Color border = Color(0xFFEAEBEF);

  static const Color orange = Color(0xFFEF5A2A); // brand primary
  static const Color orangeLight = Color(0xFFFF7A45);
  static const Color orangeDark = Color(0xFFDA3F18);
  static const Color soft = Color(0xFFFDE9DF); // pale orange chip / icon bg
  static const Color softTint = Color(0xFFFBF4F1); // card field bg
  static const Color orangeText = Color(0xFFEF8A65); // muted orange label

  static const Color green = Color(0xFF1FB36B); // call / online accent

  // ── Gradients ───────────────────────────────────────────────────────────
  static const LinearGradient grad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [orangeLight, orange],
  );

  /// Three-stop gradient used on the big SOS dial.
  static const LinearGradient sosGrad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [orangeLight, orange, orangeDark],
  );

  // ── Type ────────────────────────────────────────────────────────────────
  /// Bricolage Grotesque — display / headings.
  static TextStyle display(
    double size, {
    FontWeight weight = FontWeight.w700,
    Color color = ink,
    double letterSpacing = -0.3,
    double height = 1.05,
  }) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );

  /// Manrope — body / labels.
  static TextStyle body(
    double size, {
    FontWeight weight = FontWeight.w500,
    Color color = ink,
    double letterSpacing = 0,
    double height = 1.4,
  }) =>
      GoogleFonts.manrope(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );
}
