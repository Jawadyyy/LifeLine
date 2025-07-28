import 'package:flutter/material.dart';
import 'dart:ui';

class TopWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();

    // Start from top-left down to base of wave
    path.lineTo(0, size.height * 0.93);

    // First wave segment (left side - goes slightly up)
    final firstControlPoint = Offset(size.width * 0.25, size.height * 0.86);
    final firstEndPoint = Offset(size.width * 0.5, size.height * 0.93);
    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );

    // Second wave segment (right side - dips lower)
    final secondControlPoint = Offset(size.width * 0.75, size.height * 1.02);
    final secondEndPoint = Offset(size.width, size.height * 0.97);
    path.quadraticBezierTo(
      secondControlPoint.dx,
      secondControlPoint.dy,
      secondEndPoint.dx,
      secondEndPoint.dy,
    );

    // Top-right corner
    path.lineTo(size.width, 0);

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
