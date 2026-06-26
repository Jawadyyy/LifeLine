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

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _heartbeatAnimation;
  bool _showContent = true;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _heartbeatAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show splash animation for 3 seconds, then switch to AuthWrapper
    if (_showContent) {
      return Scaffold(
        backgroundColor: AppColors.primary,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _heartbeatAnimation,
                child: Image.asset(
                  'assets/images/logos/logo1.png',
                  width: 200,
                  height: 200,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'L I F E L I N E',
                style: GoogleFonts.nunito(
                  fontSize: 42,
                  color: AppColors.textTertiary,
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
