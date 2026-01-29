import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lifeline/constants/app_colors.dart';
import 'package:lifeline/services/firestore_service.dart';
import 'package:lifeline/services/location_handler.dart';
import 'package:lifeline/views/main/donation/donation_map_screen.dart';

import 'package:url_launcher/url_launcher.dart';

class HomeController {
  final State state;
  final void Function(void Function()) setStateFn;

  HomeController(this.state, this.setStateFn);

  BuildContext get context => state.context;
  bool get mounted => state.mounted;

  T _getField<T>(String name) => (state as dynamic).getField(name) as T;
  void _setField(String name, dynamic value) =>
      (state as dynamic).setField(name, value);

  Future<void> sendEmergencyMessage(String emergencyType) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setStateFn(() {
      _setField('_showEmergencyOptions', false);
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Sending emergency alerts...'),
          ],
        ),
      ),
    );

    try {
      final contacts = await FirestoreService().getEmergencyContacts(user.uid);
      if (contacts.isEmpty) {
        Navigator.pop(context);
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final customMessage =
          userDoc.data()?['emergency_text']?.toString().trim();
      final username = userDoc.data()?['username'] ?? 'User';

      final position = await LocationHandler.getCurrentPosition();
      if (position == null) {
        Navigator.pop(context);
        return;
      }

      final mapUrl =
          'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';

      final fallbackMessage = '🚨 EMERGENCY: $emergencyType\n'
          '👤 Name: $username\n'
          '🗺️ Location: $mapUrl\n'
          '🕒 ${DateTime.now().toString().substring(0, 16)}';

      final message = (customMessage == null || customMessage.isEmpty)
          ? fallbackMessage
          : '$customMessage\n🗺️ Location: $mapUrl\n🕒 ${DateTime.now().toString().substring(0, 16)}';

      for (String contact in contacts) {
        final whatsappUrl =
            'https://wa.me/$contact?text=${Uri.encodeComponent(message)}';
        try {
          await launch(whatsappUrl);
          await Future.delayed(const Duration(seconds: 2));
        } catch (e) {
          debugPrint('Error sending to $contact: $e');
        }
      }

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Emergency alerts sent for $emergencyType'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send emergency alerts'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void toggleEmergencyOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildEmergencyBottomSheet(),
    );
  }

  Widget _buildEmergencyBottomSheet() {
    final List<Map<String, dynamic>> emergencyTypes = [
      {
        "image": 'assets/images/icons/ambulance.png',
        "type": 'Medical Emergency',
        "description": 'Request immediate medical assistance',
        "color": Color(0xFFFF6B6B),
      },
      {
        "image": 'assets/images/icons/policeman.png',
        "type": 'Police Assistance',
        "description": 'Alert for security or law enforcement',
        "color": Color(0xFF4ECDC4),
      },
      {
        "image": 'assets/images/icons/fire.png',
        "type": 'Fire Alert',
        "description": 'Report fire or smoke emergency',
        "color": Color(0xFFFF8C42),
      },
      {
        "image": 'assets/images/icons/healthcare.png',
        "type": 'Health Issue',
        "description": 'Non-critical health concern',
        "color": Color(0xFF95E1D3),
      },
      {
        "image": 'assets/images/icons/warning.png',
        "type": 'SOS',
        "description": 'General distress signal',
        "color": Color(0xFFFFA07A),
      },
      {
        "image": 'assets/images/icons/bandage.png',
        "type": 'General Emergency',
        "description": 'Other emergency situations',
        "color": Color(0xFFAA96DA),
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textGrey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.warning_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Select Emergency Type',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          // Emergency type tiles
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: emergencyTypes.length,
            itemBuilder: (context, index) {
              return TweenAnimationBuilder<double>(
                duration: Duration(milliseconds: 300 + (index * 80)),
                curve: Curves.easeOutCubic,
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, 50 * (1 - value)),
                    child: Opacity(
                      opacity: value,
                      child: child,
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: emergencyTypes[index]["color"].withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: emergencyTypes[index]["color"].withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        sendEmergencyMessage(emergencyTypes[index]["type"]);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: emergencyTypes[index]["color"]
                                    .withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Image.asset(
                                  emergencyTypes[index]["image"],
                                  height: 32,
                                  width: 32,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    emergencyTypes[index]["type"],
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    emergencyTypes[index]["description"],
                                    style: TextStyle(
                                      fontSize: 13,
                                      color:
                                          AppColors.textGrey.withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 18,
                              color: emergencyTypes[index]["color"],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget buildMainEmergencyButton(BuildContext context,
      {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 180,
        width: 180,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              AppColors.primary.withOpacity(0.9),
              AppColors.primary.withOpacity(0.7),
              AppColors.primary.withOpacity(0.5),
            ],
            stops: const [0.3, 0.7, 1.0],
            radius: 0.85,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.5),
              blurRadius: 35,
              spreadRadius: 8,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(
            color: AppColors.textTertiary.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/icons/tap.png',
                height: 65,
                color: AppColors.textTertiary.withOpacity(0.95),
              ),
              const SizedBox(height: 10),
              const Text(
                'EMERGENCY',
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildBloodDonationCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(PageRouteBuilder(
          pageBuilder: (_, __, ___) => const DonationMapScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ));
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 30),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.error.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: AppColors.primary.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              height: 50,
              width: 50,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Image.asset('assets/images/icons/blood.png'),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Donate Blood, Save Lives',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tap to view donation opportunities near you',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 16, color: AppColors.textGrey),
          ],
        ),
      ),
    );
  }
}
