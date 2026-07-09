import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeline/services/auth_wrapper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

/// Warm top-down radial gradient behind the splash, ported from the
/// "LifeLine Splash v2" design.
const List<Color> _splashGrad = [
  Color(0xFFFF7A47),
  Color(0xFFEF5A2A),
  Color(0xFFCE4519),
];

const Color _brandOrange = Color(0xFFEF5A2A);

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulse; // ring / glow breathing + blips
  late final AnimationController _ripple; // expanding ping rings
  late final AnimationController _intro; // one-shot fade-up on entry
  late final AnimationController _loadBar; // indeterminate progress sweep
  bool _showContent = true;

  @override
  void initState() {
    super.initState();

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    _ripple = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();

    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _loadBar = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    // Hide splash after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showContent = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _ripple.dispose();
    _intro.dispose();
    _loadBar.dispose();
    super.dispose();
  }

  /// Fades + lifts its child in on first frame using the intro controller.
  Widget _introWrap({required Widget child}) {
    final curve = CurvedAnimation(parent: _intro, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: curve,
      builder: (_, c) => Opacity(
        opacity: curve.value,
        child: Transform.translate(
          offset: Offset(0, (1 - curve.value) * 16),
          child: c,
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show splash animation for 3 seconds, then switch to AuthWrapper
    if (_showContent) {
      return Scaffold(
        body: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Base radial gradient (warm, brightest at the top-centre).
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -1),
                    radius: 1.3,
                    colors: _splashGrad,
                    stops: [0.0, 0.52, 1.0],
                  ),
                ),
              ),

              // Radar field of concentric rings + responder blips near the top.
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 90),
                  child: _RadarField(pulse: _pulse),
                ),
              ),

              SafeArea(
                child: Column(
                  children: [
                    // Centre the icon + wordmark block in the free vertical
                    // space so the icon sits dead-centre of the screen.
                    Expanded(
                      child: Center(
                        child: _introWrap(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _IconEmblem(pulse: _pulse, ripple: _ripple),
                              // Wordmark kept close to the logo.
                              const SizedBox(height: 14),
                              Text(
                                'LifeLine',
                                style: GoogleFonts.figtree(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Help, closer than you think.',
                                style: GoogleFonts.figtree(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.white.withOpacity(0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Bottom loader + reassurance line.
                    _introWrap(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _LoadBar(anim: _loadBar),
                          const SizedBox(height: 18),
                          Text(
                            "You're not alone — help is nearby",
                            style: GoogleFonts.figtree(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // After splash, show AuthWrapper
    return const AuthWrapper();
  }
}

/// The centred app emblem: a white rounded-square tile holding the orange
/// heartbeat mark, wrapped in a breathing glow and two expanding ping rings.
class _IconEmblem extends StatelessWidget {
  const _IconEmblem({required this.pulse, required this.ripple});

  final AnimationController pulse;
  final AnimationController ripple;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      height: 190,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Breathing radial glow.
          AnimatedBuilder(
            animation: pulse,
            builder: (_, __) {
              final t = (math.sin(pulse.value * 2 * math.pi) + 1) / 2;
              return Opacity(
                opacity: 0.55 + 0.35 * t,
                child: Transform.scale(
                  scale: 1.0 + 0.08 * t,
                  child: Container(
                    width: 190,
                    height: 190,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [Color(0x4DFFFFFF), Color(0x00FFFFFF)],
                        stops: [0.0, 0.7],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Two expanding ping rings.
          AnimatedBuilder(
            animation: ripple,
            builder: (_, __) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  _ping((ripple.value) % 1.0),
                  _ping((ripple.value + 0.5) % 1.0),
                ],
              );
            },
          ),

          // White tile + heartbeat mark.
          AnimatedBuilder(
            animation: pulse,
            builder: (_, child) {
              final t = (math.sin(pulse.value * 2 * math.pi) + 1) / 2;
              return Transform.scale(scale: 1.0 + 0.015 * t, child: child);
            },
            child: Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFFFFF), Color(0xFFFFF4EE)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF781E00).withOpacity(0.5),
                    blurRadius: 50,
                    offset: const Offset(0, 24),
                    spreadRadius: -12,
                  ),
                ],
              ),
              child: Center(
                child: CustomPaint(
                  size: const Size(62, 62),
                  painter: _HeartbeatPainter(_brandOrange),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A single expanding, fading ping ring at progress [t] (0 → 1).
  Widget _ping(double t) {
    final double scale = 1.0 + 1.4 * t; // 104 → ~250
    final double opacity = (1 - t) * 0.5;
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 104,
        height: 104,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(opacity), width: 1.5),
        ),
      ),
    );
  }
}

/// Paints the LifeLine heartbeat line + trailing dot (viewBox 0 0 200 200).
class _HeartbeatPainter extends CustomPainter {
  _HeartbeatPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 200.0;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(22 * s, 100 * s)
      ..lineTo(50 * s, 100 * s)
      ..lineTo(62 * s, 66 * s)
      ..lineTo(82 * s, 148 * s)
      ..lineTo(101 * s, 52 * s)
      ..lineTo(118 * s, 124 * s)
      ..lineTo(131 * s, 100 * s)
      ..lineTo(152 * s, 100 * s);
    canvas.drawPath(path, stroke);
    canvas.drawCircle(
        Offset(170 * s, 100 * s), 9 * s, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_HeartbeatPainter old) => old.color != color;
}

/// Concentric radar rings with pulsing responder blips, sitting near the top.
class _RadarField extends StatelessWidget {
  const _RadarField({required this.pulse});

  final AnimationController pulse;

  // ring outer size, border opacity, whether it breathes, breathe phase
  static const List<List<double>> _rings = [
    [520, 0.14, 1, 0.0],
    [380, 0.18, 1, 0.15],
    [240, 0.24, 1, 0.30],
    [120, 0.28, 0, 0.0],
  ];

  // blip: x%, y%, size, blink phase
  static const List<List<double>> _blips = [
    [0.22, 0.30, 8, 0.24],
    [0.72, 0.24, 6, 0.58],
    [0.66, 0.68, 7, 0.82],
    [0.30, 0.72, 5, 0.06],
  ];

  @override
  Widget build(BuildContext context) {
    const double box = 520;
    return SizedBox(
      width: box,
      height: box,
      child: AnimatedBuilder(
        animation: pulse,
        builder: (_, __) {
          final v = pulse.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              for (final r in _rings)
                _ring(r[0], r[1], r[2] == 1, r[3], v),
              for (final b in _blips)
                Positioned(
                  left: b[0] * box,
                  top: b[1] * box,
                  child: _blip(b[2], b[3], v),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _ring(
      double size, double baseOpacity, bool breathe, double phase, double v) {
    double opacity = baseOpacity;
    if (breathe) {
      final t = (math.sin((v + phase) * 2 * math.pi) + 1) / 2;
      opacity = baseOpacity * (0.6 + 0.4 * t);
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(opacity), width: 1),
      ),
    );
  }

  Widget _blip(double size, double phase, double v) {
    final t = (math.sin((v + phase) * 2 * math.pi) + 1) / 2;
    return Opacity(
      opacity: 0.15 + 0.85 * t,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.white.withOpacity(0.8),
                blurRadius: 10,
                spreadRadius: 0.5),
          ],
        ),
      ),
    );
  }
}

/// Indeterminate progress: a short white segment sweeping across a faint track.
class _LoadBar extends StatelessWidget {
  const _LoadBar({required this.anim});

  final AnimationController anim;

  @override
  Widget build(BuildContext context) {
    const double trackW = 72;
    const double segW = trackW * 0.4;
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        width: trackW,
        height: 3,
        child: Stack(
          children: [
            Container(color: Colors.white.withOpacity(0.14)),
            AnimatedBuilder(
              animation: anim,
              builder: (_, __) {
                final dx = -segW + (trackW + segW) * anim.value;
                return Transform.translate(
                  offset: Offset(dx, 0),
                  child: Container(
                    width: segW,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
