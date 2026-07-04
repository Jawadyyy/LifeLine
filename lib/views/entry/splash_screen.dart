import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeline/components/navigation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lifeline/constants/app_colors.dart';
import 'package:lifeline/views/entry/welcome_screen.dart';
import 'package:lifeline/views/main/profile/profile_setup_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

/// Warm gradient behind the splash, ported from the "Lifeline Splash" design
/// and deepened with a third stop for more richness.
const List<Color> _splashGrad = [
  Color(0xFFF6824A),
  Color(0xFFE04E2A),
  Color(0xFFC5341F),
];

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulse; // glass-disc halo breathing
  late final AnimationController _ripple; // expanding sonar rings
  late final AnimationController _intro; // one-shot fade-up on entry
  late final AnimationController _loadBar; // indeterminate progress sweep
  bool _showContent = true;

  @override
  void initState() {
    super.initState();

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _ripple = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();

    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _loadBar = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
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

  /// Soft radial blob used to add depth to the flat gradient.
  Widget _glow(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white.withOpacity(opacity),
            Colors.white.withOpacity(0),
          ],
        ),
      ),
    );
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
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Base gradient.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _splashGrad,
                ),
              ),
            ),

            // Decorative soft blobs for depth.
            Positioned(top: -90, right: -80, child: _glow(280, 0.14)),
            Positioned(bottom: -120, left: -90, child: _glow(320, 0.10)),
            Positioned(top: 160, left: -60, child: _glow(150, 0.10)),

            // Radial highlight behind the emblem.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.18),
                  radius: 0.75,
                  colors: [Color(0x24FFFFFF), Color(0x00FFFFFF)],
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  const Spacer(),
                  _introWrap(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _RippleDisc(pulse: _pulse, ripple: _ripple),
                        const SizedBox(height: 32),
                        Text(
                          'LIFELINE',
                          style: GoogleFonts.nunito(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 9.0,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Help, closer than you think',
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  _introWrap(child: _LoadBar(anim: _loadBar)),
                  const SizedBox(height: 64),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // After splash, show AuthWrapper
    return const AuthWrapper();
  }
}

/// Glass emblem: expanding sonar rings + a breathing halo + a heart disc.
class _RippleDisc extends StatelessWidget {
  const _RippleDisc({required this.pulse, required this.ripple});

  final AnimationController pulse;
  final AnimationController ripple;

  static const List<double> _phases = [0.0, 0.34, 0.67];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Sonar rings radiating outward.
          AnimatedBuilder(
            animation: ripple,
            builder: (_, __) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  for (final phase in _phases)
                    _ring((ripple.value + phase) % 1.0),
                ],
              );
            },
          ),

          // Breathing halo.
          AnimatedBuilder(
            animation: pulse,
            builder: (_, __) {
              final t = pulse.value;
              return Opacity(
                opacity: 0.5 + 0.4 * t,
                child: Transform.scale(
                  scale: 1.0 + 0.08 * t,
                  child: Container(
                    width: 116,
                    height: 116,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.18),
                    ),
                  ),
                ),
              );
            },
          ),

          // Glass disc + heart.
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.16),
              border:
                  Border.all(color: Colors.white.withOpacity(0.45), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(Icons.favorite, color: Colors.white, size: 44),
          ),
        ],
      ),
    );
  }

  /// A single expanding, fading ring at progress [t] (0 → 1).
  Widget _ring(double t) {
    final double size = 96 + (210 - 96) * t;
    final double opacity = (1 - t) * 0.45;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(opacity), width: 2),
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
    const double trackW = 64;
    const double segW = trackW * 0.4;
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        width: trackW,
        height: 4,
        child: Stack(
          children: [
            Container(color: Colors.white.withOpacity(0.25)),
            AnimatedBuilder(
              animation: anim,
              builder: (_, __) {
                // Sweep the segment from off-left to off-right, matching the
                // design's -100% → 220% translate.
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

// NEW: AuthWrapper - handles automatic navigation based on auth state
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: AppColors.primary,
            body: Center(
              child: CircularProgressIndicator(
                color: AppColors.textTertiary,
              ),
            ),
          );
        }

        // Debug prints
        debugPrint('🔍 Auth State: ${snapshot.data?.email ?? "No user"}');
        debugPrint('🔍 User ID: ${snapshot.data?.uid ?? "null"}');

        // Not logged in - show welcome screen
        if (snapshot.data == null) {
          debugPrint('➡️ Navigating to WelcomeScreen');
          return const WelcomeScreen();
        }

        // Logged in - use StreamBuilder to listen to profile changes
        final userId = snapshot.data!.uid;
        debugPrint('➡️ User logged in, listening to profile changes...');

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .snapshots(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                backgroundColor: AppColors.primary,
                body: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.textTertiary,
                  ),
                ),
              );
            }

            // Handle case where document doesn't exist yet
            if (!profileSnapshot.hasData || !profileSnapshot.data!.exists) {
              debugPrint(
                  '⚠️ User document does not exist, showing ProfileSetupScreen');
              return ProfileSetupScreen(
                key: ValueKey(userId),
              );
            }

            // Check profile completion status
            final data = profileSnapshot.data!.data() as Map<String, dynamic>?;
            final isProfileComplete = data?['isProfileComplete'] == true;

            debugPrint('📋 Profile complete: $isProfileComplete');
            debugPrint('📋 User data: $data');

            if (isProfileComplete) {
              debugPrint('➡️ Navigating to MainNavigationScreen');
              return MainNavigationScreen(
                key: ValueKey(userId),
              );
            } else {
              debugPrint('➡️ Navigating to ProfileSetupScreen');
              return ProfileSetupScreen(
                key: ValueKey(userId),
              );
            }
          },
        );
      },
    );
  }
}
