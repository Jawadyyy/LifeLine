import 'package:flutter/material.dart';
import 'package:lifeline/components/clip_wave.dart';
import 'package:lifeline/constants/app_colors.dart';

class LoginHeader extends StatelessWidget {
  const LoginHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return SizedBox(
      height: size.height * 0.35,
      child: Stack(
        children: [
          ClipPath(
            clipper: TopWaveClipper(),
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    AppColors.primary,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
