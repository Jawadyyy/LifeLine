import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lifeline/constants/app_colors.dart';
import 'package:lifeline/services/chat_service.dart';
import 'package:lifeline/services/firestore_service.dart';
import 'package:lifeline/services/live_location_service.dart';
import 'package:lifeline/services/location_handler.dart';
import 'package:lifeline/views/main/donation/donation_map_screen.dart';
import 'package:lifeline/views/main/home/widgets/sos_countdown_dialog.dart';

import 'package:url_launcher/url_launcher.dart';

class HomeController {
  /// Default emergency services number (PK: Rescue 1122).
  static const String emergencyDialNumber = '1122';

  final State state;
  final void Function(void Function()) setStateFn;

  HomeController(this.state, this.setStateFn);

  BuildContext get context => state.context;
  bool get mounted => state.mounted;

  /// Fires an SOS: shows a cancellable countdown (I2), then posts the
  /// location alert into each emergency contact's in-app chat (B2).
  Future<void> sendEmergencyMessage(String emergencyType) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final proceed = await SosCountdownDialog.show(context, emergencyType);
    if (!proceed || !mounted) return;

    await _dispatchEmergency(user, emergencyType);
  }

  /// Builds the alert text and writes it into each contact's Firestore chat.
  Future<void> _dispatchEmergency(User user, String emergencyType) async {
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
      final contacts =
          await FirestoreService().getEmergencyContactsDetailed(user.uid);
      if (!mounted) return;
      if (contacts.isEmpty) {
        Navigator.pop(context);
        _promptAddContacts();
        return;
      }

      final position = await LocationHandler.getCurrentPosition();
      if (!mounted) return;
      if (position == null) {
        Navigator.pop(context);
        _showError(
            'Location unavailable. Enable location services and permission, then try again.');
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!mounted) return;

      final customMessage =
          userDoc.data()?['emergency_text']?.toString().trim();
      final username = userDoc.data()?['username'] ?? 'User';

      // Start a live location share so contacts can follow movement in-app.
      String? liveSessionId;
      try {
        liveSessionId =
            await LiveLocationService.instance.startBroadcast(ownerUid: user.uid);
      } catch (e) {
        debugPrint('live share start failed: $e');
      }
      if (!mounted) return;

      final mapUrl =
          'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';
      final timestamp = DateTime.now().toString().substring(0, 16);
      final liveLine =
          liveSessionId != null ? '\n📍 Live location sharing (open in app)' : '';

      final message = (customMessage == null || customMessage.isEmpty)
          ? '🚨 EMERGENCY: $emergencyType\n'
              '👤 Name: $username\n'
              '🗺️ Location: $mapUrl\n'
              '🕒 $timestamp$liveLine'
          : '$customMessage\n🗺️ Location: $mapUrl\n🕒 $timestamp$liveLine';

      final chat = ChatService(user.uid);
      final skipped = <String>[];
      var sent = 0;

      for (final contact in contacts) {
        if (!contact.hasUid) {
          skipped.add(contact.name);
          continue;
        }
        final chatId = ChatService.chatIdFor(user.uid, contact.uid);
        try {
          await chat.send(chatId, contact.uid, message,
              type: 'emergency', liveSessionId: liveSessionId);
          sent++;
        } catch (e) {
          debugPrint('Error sending SOS to ${contact.name}: $e');
          skipped.add(contact.name);
        }
      }

      if (!mounted) return;
      Navigator.pop(context);

      if (sent > 0) {
        final note = skipped.isEmpty
            ? ''
            : ' (${skipped.length} skipped — not registered LifeLine users)';
        _showResult(
          'Emergency alert sent to $sent contact${sent == 1 ? '' : 's'}$note',
          AppColors.success,
        );
      } else {
        _showError(
            'No reachable contacts. Emergency contacts must be registered LifeLine users.');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showError('Failed to send emergency alerts');
    }
  }

  /// One-tap direct dial to emergency services (I1).
  Future<void> callEmergencyServices(
      [String number = emergencyDialNumber]) async {
    final uri = Uri(scheme: 'tel', path: number);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) _showError('Could not open the dialer');
      }
    } catch (e) {
      debugPrint('Dial error: $e');
      if (mounted) _showError('Could not open the dialer');
    }
  }

  void _promptAddContacts() {
    _showResult(
      'Add at least one emergency contact first',
      AppColors.error,
    );
  }

  void _showError(String message) => _showResult(message, AppColors.error);

  void _showResult(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
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
          // Direct dial to emergency services (I1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _buildDirectCallTile(),
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

  /// Prominent "call emergency services" tile inside the bottom sheet.
  Widget _buildDirectCallTile() {
    return Material(
      color: AppColors.error,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.pop(context);
          callEmergencyServices();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.call, color: AppColors.textTertiary, size: 26),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Call Ambulance / $emergencyDialNumber',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Dial emergency services directly',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  /// Direct-dial card shown on the home screen (I1).
  Widget buildDirectCallButton(BuildContext context) {
    return GestureDetector(
      onTap: callEmergencyServices,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 30),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.error.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.call, color: AppColors.textTertiary, size: 22),
            SizedBox(width: 12),
            Text(
              'Call Ambulance / $emergencyDialNumber',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
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
