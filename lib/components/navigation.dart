import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lifeline/components/custom_bottom_navbar.dart';
import 'package:lifeline/views/main/contact/contacts_screen.dart';
import 'package:lifeline/views/main/home/home_screen.dart';
import 'package:lifeline/views/main/map/map_screen.dart';
import 'package:lifeline/views/main/profile/profile_screen.dart';
import 'package:lifeline/services/global_data_service.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final GlobalDataService _globalDataService = GlobalDataService();
  String? _currentUserId; // Track current user

  final List<Widget> _screens = const [
    HomeScreen(key: ValueKey("Home")),
    ContactsPage(key: ValueKey("Contacts")),
    MapScreen(key: ValueKey("Map")),
    ProfilePage(key: ValueKey("Profile")),
  ];

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    print('🏠 MainNavigationScreen initialized for user: $_currentUserId');
    _initializeGlobalData();
  }

  @override
  void didUpdateWidget(MainNavigationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if user has changed
    final newUserId = FirebaseAuth.instance.currentUser?.uid;
    if (_currentUserId != newUserId) {
      print('👤 User changed from $_currentUserId to $newUserId');
      _currentUserId = newUserId;

      // Clear old data and reinitialize for new user
      _clearAndReinitialize();
    }
  }

  Future<void> _clearAndReinitialize() async {
    try {
      // Clear cached data
      await _globalDataService.clearAllData();
      print('🧹 Cleared old user data');

      // Reinitialize for new user
      await _globalDataService.initializeAllData();
      print('✅ Reinitialized data for new user: $_currentUserId');

      if (mounted) {
        setState(() {}); // Trigger rebuild
      }
    } catch (e) {
      debugPrint('Error clearing and reinitializing data: $e');
    }
  }

  Future<void> _initializeGlobalData() async {
    try {
      await _globalDataService.initializeAllData();
      debugPrint('GlobalDataService: All data initialized successfully');
    } catch (e) {
      debugPrint('Error initializing GlobalDataService: $e');
    }
  }

  @override
  void dispose() {
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
    return Scaffold(
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
    );
  }
}
