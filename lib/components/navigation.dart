import 'package:lifeline/utils/logger.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lifeline/components/custom_bottom_navbar.dart';
import 'package:lifeline/services/donation_service.dart';
import 'package:lifeline/views/main/contact/contacts_screen.dart';
import 'package:lifeline/views/main/home/home_screen.dart';
import 'package:lifeline/views/main/map/map_screen.dart';
import 'package:lifeline/views/main/profile/profile_screen.dart';
import 'package:lifeline/services/global_data_service.dart';
import 'package:lifeline/services/live_location_service.dart';
import 'package:lifeline/services/push_service.dart';
import 'package:lifeline/services/sos_followup.dart';
import 'package:lifeline/views/entry/permission_priming_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final GlobalDataService _globalDataService = GlobalDataService();
  final PushService _pushService = PushService();
  String? _currentUserId; // Track current user

  // In-app notification for donation requests accepted by a donor (no FCM).
  StreamSubscription<List<Map<String, dynamic>>>? _acceptedSub;
  final Set<String> _knownAccepted = {};
  bool _acceptedSeeded = false;

  // Built in `build` (not a const field) so the Map tab can receive an
  // `onExit` callback that routes back to Home instead of popping the root
  // route — popping the root empties the Navigator and leaves a black screen
  // on some Android devices.
  List<Widget> get _screens => [
        const HomeScreen(key: ValueKey("Home")),
        const ContactsPage(key: ValueKey("Contacts")),
        MapScreen(key: const ValueKey("Map"), onExit: () => _onTabTapped(0)),
        const ProfilePage(key: ValueKey("Profile")),
      ];

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    logDebug('🏠 MainNavigationScreen initialized for user: $_currentUserId');
    _initializeGlobalData();
    _listenForAcceptedDonations();
    _initPush();
    // If the app was killed mid live-location-share, bring back the "stop
    // sharing" banner so the user can end it in-app (not only from the
    // system notification).
    if (_currentUserId != null) {
      LiveLocationService.instance.restoreActiveSession(_currentUserId!);
    }
    // Bring back the "I'm safe" follow-up banner if an SOS was active when the
    // app was last killed.
    SosFollowup.restore();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) PermissionPrimingScreen.showIfFirstRun(context);
    });
  }

  /// Notifies the requester in-app when one of their donation posts is accepted.
  void _listenForAcceptedDonations() {
    final uid = _currentUserId;
    if (uid == null) return;
    _acceptedSub?.cancel();
    _acceptedSeeded = false;
    _knownAccepted.clear();
    _acceptedSub =
        DonationService().watchAcceptedRequests(uid).listen((accepted) {
      // Seed on first emission so existing acceptances don't re-notify.
      if (!_acceptedSeeded) {
        _acceptedSeeded = true;
        _knownAccepted
          ..clear()
          ..addAll(accepted.map((p) => p['postId'] as String));
        return;
      }
      for (final post in accepted) {
        final id = post['postId'] as String;
        if (_knownAccepted.add(id) && mounted) {
          final donor = post['acceptedByName'] ?? 'A donor';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$donor accepted your blood donation request 🩸'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    });
  }

  @override
  void didUpdateWidget(MainNavigationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if user has changed
    final newUserId = FirebaseAuth.instance.currentUser?.uid;
    if (_currentUserId != newUserId) {
      logDebug('👤 User changed from $_currentUserId to $newUserId');
      _currentUserId = newUserId;

      // Clear old data and reinitialize for new user
      _clearAndReinitialize();
      _listenForAcceptedDonations();
      _initPush();
    }
  }

  Future<void> _clearAndReinitialize() async {
    try {
      // Clear cached data
      await _globalDataService.clearAllData();
      logDebug('🧹 Cleared old user data');

      // Reinitialize for new user
      await _globalDataService.initializeAllData();
      logDebug('✅ Reinitialized data for new user: $_currentUserId');

      if (mounted) {
        setState(() {}); // Trigger rebuild
      }
    } catch (e) {
      logDebug('Error clearing and reinitializing data: $e');
    }
  }

  /// Registers this device's FCM token and wires foreground/tap handling.
  /// Best-effort — push failures never affect the app.
  Future<void> _initPush() async {
    final uid = _currentUserId;
    if (uid == null) return;
    await _pushService.initForUser(uid);
    await _pushService.attachListeners();
  }

  Future<void> _initializeGlobalData() async {
    try {
      await _globalDataService.initializeAllData();
      logDebug('GlobalDataService: All data initialized successfully');
    } catch (e) {
      logDebug('Error initializing GlobalDataService: $e');
    }
  }

  @override
  void dispose() {
    _acceptedSub?.cancel();
    // Clear data when disposing
    _globalDataService.clearAllData();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // On the root route there is nothing to pop to. Handle the system back
    // button ourselves: from a sub-tab, return to Home; from Home, let the
    // framework pop (which cleanly backgrounds the app). This prevents the
    // black screen caused by popping the empty root Navigator stack.
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _onTabTapped(0);
      },
      child: Scaffold(
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeIn,
          switchOutCurve: Curves.easeOut,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          child: SizedBox.expand(
            key: ValueKey(_currentIndex),
            child: _screens[_currentIndex],
          ),
        ),
        bottomNavigationBar: CustomBottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
        ),
      ),
    );
  }
}
