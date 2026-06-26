import 'package:flutter/material.dart';
import 'package:lifeline/constants/app_colors.dart';
import 'package:lifeline/services/live_location_service.dart';
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
            tooltip: 'Medical ID',
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
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
          Text(
            'Emergency Assistance',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Press the emergency button below to get immediate help',
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
