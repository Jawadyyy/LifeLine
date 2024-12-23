import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lifeline/components/bottom_navbar.dart';
import 'package:lifeline/screens/auth_screens/login_screen.dart';
import 'package:lifeline/screens/main_screens/contacts_screen.dart';
import 'package:lifeline/screens/main_screens/home_screen.dart';
import 'package:lifeline/screens/main_screens/map_screen.dart';
import 'package:lifeline/screens/main_screens/profile_setting_screen.dart';
import 'package:lifeline/services/auth_service.dart';

// Simulating a logged-in user
class User {
  String name;
  String bloodType;
  String age;
  String weight;
  String profileImage;

  User({
    required this.name,
    required this.bloodType,
    required this.age,
    required this.weight,
    required this.profileImage,
  });
}

// Global user object
User currentUser = User(
  name: "Loading...",
  bloodType: "N/A",
  age: "N/A",
  weight: "N/A",
  profileImage: "", // Initially no profile image
);

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ImagePicker _picker = ImagePicker();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  // Function to fetch user data from Firebase
  Future<void> _fetchUserData() async {
    try {
      final String userId = AuthService().getCurrentUserId(); // Replace with your method to get user ID
      final DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        setState(() {
          currentUser.name = userDoc['username'] ?? 'Unknown';
          currentUser.bloodType = userDoc['bloodType'] ?? 'N/A';
          currentUser.age = userDoc['age'] ?? 'N/A';
          currentUser.weight = userDoc['weight'] ?? 'N/A';
          currentUser.profileImage = userDoc['profileImage'] ?? '';
        });
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
    }
  }

  // Function to update the profile image
  Future<void> _updateProfileImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          currentUser.profileImage = pickedFile.path;
        });
        // Optionally, upload the image to Firebase Storage and update Firestore
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      primary: false,
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: const Padding(
          padding: EdgeInsets.only(top: 8.0),
          child: Text('Profile', style: TextStyle(color: Colors.black)),
        ),
        centerTitle: true,
        toolbarHeight: 50,
      ),
      body: Column(
        children: [
          const SizedBox(height: 30),
          // Profile Avatar and Details
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => _showProfileImageOptions(context),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage: currentUser.profileImage.isNotEmpty ? FileImage(File(currentUser.profileImage)) : const NetworkImage('https://via.placeholder.com/150') as ImageProvider,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  currentUser.name,
                  style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                // Health Stats Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatColumn(Icons.favorite, 'Blood Type', currentUser.bloodType),
                    _buildStatColumn(Icons.water_drop, 'Age', currentUser.age),
                    _buildStatColumn(Icons.monitor_weight, 'Weight', currentUser.weight),
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
                    MaterialPageRoute(builder: (context) => const ProfileSettingScreen()),
                  );
                }),
                _buildMenuItem(Icons.settings_outlined, 'Settings', () {}),
                _buildMenuItem(Icons.help_outline, 'FAQs', () {
                  _showFAQDialog(context);
                }),
                _buildMenuItem(Icons.logout, 'Logout', () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: 3, // Set 3 for the Profile tab as active
        onTap: (index) {
          if (index != 3) {
            Navigator.of(context).pushReplacement(MaterialPageRoute(
              builder: (context) {
                if (index == 0) return const HomeScreen();
                if (index == 1) return const ContactsPage();
                if (index == 2) return const MapScreen();
                return const ProfilePage();
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
          style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
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

  void _showProfileImageOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Text(
              "Choose an Action",
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const Divider(thickness: 1, color: Colors.grey),
            const SizedBox(height: 5),
            _buildBottomSheetOption(
              icon: Icons.photo_camera,
              color: Colors.green,
              title: "Take Picture From Camera",
              onTap: () {
                Navigator.of(context).pop();
                _updateProfileImage(ImageSource.camera);
              },
            ),
            _buildBottomSheetOption(
              icon: Icons.image,
              color: Colors.blue,
              title: "Choose from Gallery",
              onTap: () {
                Navigator.of(context).pop();
                _updateProfileImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 10),
            // Cancel Button
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.cancel, size: 24),
                label: const Text(
                  "Cancel",
                  style: TextStyle(fontSize: 16),
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottomSheetOption({
    required IconData icon,
    required Color color,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      onTap: onTap,
    );
  }

  void _showFAQDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        title: const Text(
          'About the Project',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        contentPadding: const EdgeInsets.all(16.0),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              _buildSectionTitle('Contributors'),
              _buildListItem('1. Jawad Mansoor'),
              _buildListItem('2. Sardar Muhammad Ali Khan'),
              _buildListItem('3. Muhammad Waqas Siddique'),
              const SizedBox(height: 16),
              _buildSectionTitle('Licenses'),
              _buildListItem('MIT License'),
              _buildListItem('All rights reserved © 2024'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Close',
              style: TextStyle(fontSize: 16, color: Colors.blueAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.blueGrey,
        ),
      ),
    );
  }

  Widget _buildListItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, color: Colors.black),
      ),
    );
  }
}
