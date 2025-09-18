import 'package:flutter/material.dart';
import 'package:lifeline/constants/app_colors.dart';
import 'package:lifeline/views/chatbot/screens/chat_home_screen.dart';
import 'package:lifeline/views/main/home/controller/home_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  bool _showEmergencyOptions = false;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late HomeController controller;

  // Expose fields for controller via dynamic calls
  dynamic getField(String name) => {
        '_showEmergencyOptions': _showEmergencyOptions,
        '_animationController': _animationController,
      }[name];

  void setField(String name, dynamic value) {
    switch (name) {
      case '_showEmergencyOptions':
        _showEmergencyOptions = value as bool;
        break;
    }
  }

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
      ),
      body: Stack(
        children: [
          Column(
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
                ],
              ),
            ],
          ),
          if (_showEmergencyOptions) ...controller.buildEmergencyOptions(),
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
