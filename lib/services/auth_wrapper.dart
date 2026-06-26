import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lifeline/components/navigation.dart';
import 'package:lifeline/constants/app_colors.dart';
import 'package:lifeline/views/entry/welcome_screen.dart';
import 'package:lifeline/views/main/profile/profile_setup_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        debugPrint('═══════════════════════════════════════');
        debugPrint('🔄 AuthWrapper rebuild');
        debugPrint('Connection state: ${snapshot.connectionState}');
        debugPrint('Has data: ${snapshot.hasData}');
        debugPrint('User: ${snapshot.data?.email}');
        debugPrint('User ID: ${snapshot.data?.uid}');
        debugPrint('═══════════════════════════════════════');

        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          debugPrint('⏳ Waiting for auth state...');
          return Scaffold(
            backgroundColor: AppColors.primary,
            body: Center(
              child: CircularProgressIndicator(
                color: AppColors.textTertiary,
              ),
            ),
          );
        }

        // Not logged in - show welcome screen
        if (snapshot.data == null) {
          debugPrint('➡️ No user - showing WelcomeScreen');
          return const WelcomeScreen();
        }

        // Logged in - use StreamBuilder to listen to profile changes
        final userId = snapshot.data!.uid;
        debugPrint('✅ User logged in: $userId');

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .snapshots(),
          builder: (context, profileSnapshot) {
            debugPrint('───────────────────────────────────────');
            debugPrint('📄 Profile StreamBuilder');
            debugPrint('Connection state: ${profileSnapshot.connectionState}');
            debugPrint('Has data: ${profileSnapshot.hasData}');
            debugPrint('Doc exists: ${profileSnapshot.data?.exists}');
            debugPrint('───────────────────────────────────────');

            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              debugPrint('⏳ Waiting for profile data...');
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
              debugPrint('⚠️ User document does not exist');
              debugPrint('➡️ Showing ProfileSetupScreen');
              return ProfileSetupScreen(
                key: ValueKey(userId),
              );
            }

            // Check profile completion status
            final data = profileSnapshot.data!.data() as Map<String, dynamic>?;
            final isProfileComplete = data?['isProfileComplete'] == true;

            debugPrint('📋 Profile data: $data');
            debugPrint('📋 isProfileComplete: $isProfileComplete');

            if (isProfileComplete) {
              debugPrint('✅ Profile complete');
              debugPrint('➡️ Showing MainNavigationScreen');
              return MainNavigationScreen(
                key: ValueKey(userId),
              );
            } else {
              debugPrint('❌ Profile incomplete');
              debugPrint('➡️ Showing ProfileSetupScreen');
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
