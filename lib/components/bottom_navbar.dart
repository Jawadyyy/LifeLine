import 'package:flutter/material.dart';
import 'package:lifeline/screens/main_screens/contacts_screen.dart';
import 'package:lifeline/screens/main_screens/home_screen.dart';
import 'package:lifeline/screens/main_screens/map_screen.dart';
import 'package:lifeline/screens/main_screens/profile_screen.dart';

class CustomBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildBarItem(
            context,
            index: 0,
            iconPath: "assets/images/navbar/home.png",
            label: "Home",
            isActive: currentIndex == 0,
          ),
          _buildBarItem(
            context,
            index: 1,
            iconPath: "assets/images/navbar/circle.png",
            label: "Contacts",
            isActive: currentIndex == 1,
          ),
          _buildBarItem(
            context,
            index: 2,
            iconPath: "assets/images/navbar/map.png",
            label: "Map",
            isActive: currentIndex == 2,
          ),
          _buildBarItem(
            context,
            index: 3,
            iconPath: "assets/images/navbar/profile.png",
            label: "Profile",
            isActive: currentIndex == 3,
          ),
        ],
      ),
    );
  }

  Widget _buildBarItem(
    BuildContext context, {
    required int index,
    required String iconPath,
    required String label,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: () {
        if (index == 3) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProfilePage()),
          );
        } else if (index == 2) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MapScreen()),
          );
        } else if (index == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ContactsPage()),
          );
        } else if (index == 0) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        } else {
          onTap(index);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: isActive ? 140 : 40,
        height: isActive ? 50 : 40,
        padding: EdgeInsets.symmetric(horizontal: isActive ? 12 : 4, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF1565C0).withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconTheme(
              data: IconThemeData(
                color: isActive ? const Color(0xFF1565C0) : Colors.grey,
              ),
              child: Image.asset(iconPath, color: isActive ? const Color(0xFF1565C0) : Colors.grey),
            ),
            if (isActive) const SizedBox(width: 6),
            if (isActive)
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1565C0),
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
