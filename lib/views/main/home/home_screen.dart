import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lifeline/constants/app_colors.dart';
import 'package:lifeline/services/chat_service.dart';
import 'package:lifeline/services/live_location_service.dart';
import 'package:lifeline/services/push_service.dart';
import 'package:lifeline/services/sos_followup.dart';
import 'package:lifeline/views/chatbot/screens/chat_home_screen.dart';
import 'package:lifeline/views/main/home/controller/home_controller.dart';
import 'package:lifeline/views/main/medical_id/medical_id_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late HomeController controller;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    controller = HomeController(this, setState);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Image.asset(
            'assets/images/logos/logo1.png',
            height: 40,
            width: 40,
          ),
        ),
        title: Text(
          'L I F E L I N E',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: l.medicalId,
            icon: const Icon(Icons.medical_information_outlined,
                color: AppColors.primary),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MedicalIdScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const _LiveShareBanner(),
          const _SafeFollowupBanner(),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
          Text(
            l.emergencyAssistance,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              l.emergencyPrompt,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
          const SizedBox(height: 40),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: controller.buildMainEmergencyButton(
                  context,
                  onTap: controller.toggleEmergencyOptions,
                ),
              ),
              const SizedBox(height: 30),
              controller.buildBloodDonationCard(context),
              const SizedBox(height: 16),
              controller.buildDirectCallButton(context),
            ],
          ),
        ],
      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ChatHomeScreen()),
          );
        },
        backgroundColor: AppColors.surface,
        elevation: 4,
        child: Image.asset('assets/images/icons/brain.png', height: 28),
      ),
    );
  }
}

/// Persistent banner shown while a live location share is active, with a one-tap
/// stop. Listens to the process-global [LiveLocationService.activeSession].
class _LiveShareBanner extends StatelessWidget {
  const _LiveShareBanner();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: LiveLocationService.activeSession,
      builder: (context, sessionId, _) {
        if (sessionId == null) return const SizedBox.shrink();
        return Material(
          color: AppColors.primary,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: Row(
              children: [
                const Icon(Icons.share_location_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Sharing your live location with contacts',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: () => LiveLocationService.instance.stopBroadcast(),
                  child: const Text('STOP',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Contextual "I'm safe now" banner shown after an SOS, sending a `type:'safe'`
/// follow-up to the same contacts. Driven by [SosFollowup.alertedContacts].
class _SafeFollowupBanner extends StatelessWidget {
  const _SafeFollowupBanner();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<String>>(
      valueListenable: SosFollowup.alertedContacts,
      builder: (context, contacts, _) {
        if (contacts.isEmpty) return const SizedBox.shrink();
        return Material(
          color: AppColors.success,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: Row(
              children: [
                const Icon(Icons.verified_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Emergency active — let your contacts know you are safe',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final user = FirebaseAuth.instance.currentUser;
                    final uid = user?.uid;
                    if (uid == null) return;
                    // Snapshot recipients before sendSafe clears them, so we can
                    // fire best-effort pushes to the same contacts.
                    final recipients =
                        List<String>.from(SosFollowup.alertedContacts.value);
                    final count = await SosFollowup.sendSafe(currentUid: uid);
                    final push = PushService();
                    for (final r in recipients) {
                      push.notify(
                        recipientUid: r,
                        kind: 'safe',
                        chatId: ChatService.chatIdFor(uid, r),
                        payload: {
                          'senderUid': uid,
                          'senderName': user?.displayName ?? 'Your contact',
                        },
                      );
                    }
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(count > 0
                            ? "Sent 'I'm safe' to $count contact${count == 1 ? '' : 's'}"
                            : "Nothing to send"),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text("I'M SAFE",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
