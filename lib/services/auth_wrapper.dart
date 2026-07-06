import 'package:lifeline/utils/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lifeline/components/navigation.dart';
import 'package:lifeline/constants/app_colors.dart';
import 'package:lifeline/services/call_service.dart';
import 'package:lifeline/views/entry/welcome_screen.dart';
import 'package:lifeline/views/main/profile/profile_setup_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        logDebug('═══════════════════════════════════════');
        logDebug('🔄 AuthWrapper rebuild');
        logDebug('Connection state: ${snapshot.connectionState}');
        logDebug('Has data: ${snapshot.hasData}');
        logDebug('Has user: ${snapshot.data != null}');
        logDebug('User ID: ${snapshot.data?.uid}');
        logDebug('═══════════════════════════════════════');

        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          logDebug('⏳ Waiting for auth state...');
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
          logDebug('➡️ No user - showing WelcomeScreen');
          return const WelcomeScreen();
        }

        // Logged in - use StreamBuilder to listen to profile changes
        final userId = snapshot.data!.uid;
        logDebug('✅ User logged in: $userId');

        // Idempotent — re-subscribing on every rebuild is a no-op once
        // already listening for this uid.
        CallService.instance.listenForIncomingCalls(userId);

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .snapshots(),
          builder: (context, profileSnapshot) {
            logDebug('───────────────────────────────────────');
            logDebug('📄 Profile StreamBuilder');
            logDebug('Connection state: ${profileSnapshot.connectionState}');
            logDebug('Has data: ${profileSnapshot.hasData}');
            logDebug('Doc exists: ${profileSnapshot.data?.exists}');
            logDebug('───────────────────────────────────────');

            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              logDebug('⏳ Waiting for profile data...');
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
              logDebug('⚠️ User document does not exist');
              logDebug('➡️ Showing ProfileSetupScreen');
              return ProfileSetupScreen(
                key: ValueKey(userId),
              );
            }

            // Check profile completion status
            final data = profileSnapshot.data!.data() as Map<String, dynamic>?;
            final isProfileComplete = data?['isProfileComplete'] == true;

            logDebug('📋 Profile data: ${data != null ? "loaded" : "null"}');
            logDebug('📋 isProfileComplete: $isProfileComplete');

            if (isProfileComplete) {
              logDebug('✅ Profile complete');
              logDebug('➡️ Showing MainNavigationScreen');
              return MainNavigationScreen(
                key: ValueKey(userId),
              );
            } else {
              logDebug('❌ Profile incomplete');
              logDebug('➡️ Showing ProfileSetupScreen');
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
