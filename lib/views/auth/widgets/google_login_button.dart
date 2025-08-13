import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeline/constants/app_colors.dart';

class GoogleLoginButton extends StatelessWidget {
  final VoidCallback onPressed;
  const GoogleLoginButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Image.asset('assets/images/icons/google.png',
            width: 24, height: 24),
        label: Text(
          "Login with Google",
          style: GoogleFonts.nunito(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.tertiary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
    );
  }
}
