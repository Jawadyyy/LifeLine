import 'package:flutter/material.dart';
import 'package:lifeline/constants/app_colors.dart';
import 'package:lifeline/views/chatbot/screens/chat_home_screen.dart';
import 'package:lifeline/views/main/home/controller/home_controller.dart';
import 'package:lifeline/services/global_data_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  String _currentAddress = 'Fetching location...';
  bool _showEmergencyOptions = false;
  bool _isLocationFetched = false;
  bool _isLoadingLocation = false;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late HomeController controller;
  final GlobalDataService _globalDataService = GlobalDataService();

  // Expose fields for controller via dynamic calls (used internally by controller)
  dynamic getField(String name) => {
        '_currentAddress': _currentAddress,
        '_showEmergencyOptions': _showEmergencyOptions,
        '_isLocationFetched': _isLocationFetched,
        '_isLoadingLocation': _isLoadingLocation,
        '_animationController': _animationController,
      }[name];

  void setField(String name, dynamic value) {
    switch (name) {
      case '_currentAddress':
        _currentAddress = value as String;
        break;
      case '_showEmergencyOptions':
        _showEmergencyOptions = value as bool;
        break;
      case '_isLocationFetched':
        _isLocationFetched = value as bool;
        break;
      case '_isLoadingLocation':
        _isLoadingLocation = value as bool;
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

    // Initialize location data from global service (only once)
    _initializeLocationData();
  }

  void _initializeLocationData() {
    // Get initial location data from global service
    _updateLocationFromGlobal();

    // Listen to global data service for location updates (only when location actually changes)
    _globalDataService.addListener(_onGlobalDataChanged);
  }

  void _onGlobalDataChanged() {
    if (mounted) {
      // Only update if the location has actually changed
      final newAddress = _globalDataService.currentAddress;
      final newIsLocationFetched = _globalDataService.isLocationFetched;
      final newIsLoadingLocation = _globalDataService.isLoadingLocation;

      // Only update state if values have actually changed
      if (_currentAddress != newAddress ||
          _isLocationFetched != newIsLocationFetched ||
          _isLoadingLocation != newIsLoadingLocation) {
        _updateLocationFromGlobal();
      }
    }
  }

  void _updateLocationFromGlobal() {
    if (mounted) {
      setState(() {
        _currentAddress = _globalDataService.currentAddress;
        _isLocationFetched = _globalDataService.isLocationFetched;
        _isLoadingLocation = _globalDataService.isLoadingLocation;
      });
    }
  }

  // Handle manual location refresh (only when user explicitly requests it)
  Future<void> _handleManualLocationRefresh() async {
    if (!_isLoadingLocation) {
      // Check if location data is already fresh
      if (_globalDataService.isLocationDataFresh) {
        // Show a message that location is already up to date
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location is already up to date'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        // Only update if location data is stale
        await _globalDataService.updateLocationData();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _globalDataService.removeListener(_onGlobalDataChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Image.asset('assets/images/logos/logo1.png',
              height: 40, width: 40),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current location',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: size.width * 0.6,
              child: _isLoadingLocation
                  ? LinearProgressIndicator(
                      minHeight: 4,
                      color: AppColors.primary,
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    )
                  : Text(
                      _currentAddress,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
          ],
        ),
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
