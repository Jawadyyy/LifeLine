import 'package:flutter/material.dart';
import 'package:lifeline/components/clip_wave.dart';
import 'package:lifeline/constants/app_colors.dart';

class AuthHeader extends StatelessWidget {
  final double heightFactor;
  final bool showBack;
  final List<Color> gradientColors;

  const AuthHeader({
    super.key,
    this.heightFactor = 0.35,
    this.showBack = false,
    this.gradientColors = const [AppColors.primary, AppColors.primary],
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return SizedBox(
      height: size.height * heightFactor,
      child: Stack(
        children: [
          ClipPath(
            clipper: TopWaveClipper(),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                ),
              ),
            ),
          ),
          if (showBack)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 10, top: 10),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back,
                      color: AppColors.textTertiary),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
