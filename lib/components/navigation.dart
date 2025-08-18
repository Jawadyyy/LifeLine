import 'package:flutter/material.dart';
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

  final List<Widget> _screens = const [
    HomeScreen(key: ValueKey("Home")),
    ContactsPage(key: ValueKey("Contacts")),
    MapScreen(key: ValueKey("Map")),
    ProfilePage(key: ValueKey("Profile")),
  ];

  @override
  void initState() {
    super.initState();
    // Initialize all data once when the navigation screen is created
    _globalDataService.initializeAllData();
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
