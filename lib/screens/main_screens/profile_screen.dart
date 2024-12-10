import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeline/components/bottom_navbar.dart';
import 'package:lifeline/screens/auth_screens/login_screen.dart';
import 'package:lifeline/screens/main_screens/contacts_screen.dart';
import 'package:lifeline/screens/main_screens/homePage.dart';
import 'package:lifeline/screens/main_screens/map_screen.dart';
import 'package:lifeline/screens/main_screens/profile_setting_screen.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: const Text('Profile', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        toolbarHeight: 50,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          // Profile Avatar and Details
          Center(
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 50,
                  backgroundImage: NetworkImage(
                      'https://via.placeholder.com/150'), // Replace with your image URL
                ),
                const SizedBox(height: 10),
                Text(
                  'Maria',
                  style: GoogleFonts.nunito(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                // Health Stats Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatColumn(Icons.favorite, 'Blood Type', 'AB+'),
                    _buildStatColumn(Icons.water_drop, 'Age', '56'),
                    _buildStatColumn(Icons.monitor_weight, 'Weight', '103lbs'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          // Menu List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _buildMenuItem(Icons.person_outline, 'Profile', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ProfileSettingScreen()),
                  );
                }),
                _buildMenuItem(Icons.history, 'History', () {}),
                _buildMenuItem(Icons.settings_outlined, 'Settings', () {}),
                _buildMenuItem(Icons.help_outline, 'FAQs', () {
                  _showFAQDialog(context);
                }),
                _buildMenuItem(Icons.logout, 'Logout', () {
                  // Navigate to login screen
                  Navigator.of(context).pushReplacement(MaterialPageRoute(
                      builder: (context) => const LoginScreen()));
                }),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: 3, // Set 3 for the Profile tab as active
        onTap: (index) {
          // Logic to handle tab changes
          if (index != 3) {
            // Navigate to other pages
            Navigator.of(context).pushReplacement(MaterialPageRoute(
              builder: (context) {
                if (index == 0) return const HomePage();
                if (index == 1) return const ContactsPage();
                if (index == 2) return const MapScreen();
                return const ProfilePage(); // Default to Profile for safety
              },
            ));
          }
        },
      ),
    );
  }

  Widget _buildStatColumn(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue, size: 30),
        const SizedBox(height: 5),
        Text(
          label,
          style: GoogleFonts.nunito(
              fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: GoogleFonts.nunito(
              fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ],
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(
        title,
        style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  void _showFAQDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About the Project'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Contributors:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('1. Jawad Mansoor'),
              Text('2. Sardar Muhammad Ali Khan'),
              Text('3. Muhammad Waqas Siddique'),
              SizedBox(height: 10),
              Text(
                'Licenses:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('MIT License'),
              Text('All rights reserved © 2024'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
