import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lifeline/components/bottom_navbar.dart';
import 'package:lifeline/screens/auth_screens/login_screen.dart';
import 'package:lifeline/screens/main_screens/contacts_screen.dart';
import 'package:lifeline/screens/main_screens/home_screen.dart';
import 'package:lifeline/screens/main_screens/map_screen.dart';
import 'package:lifeline/screens/main_screens/profile_setting_screen.dart';
import 'package:lifeline/services/auth_service.dart';
import 'package:lifeline/models/user_model.dart';

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

  // Refetch user data whenever the profile page is reloaded
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fetchUserData(); // Refresh the user data when navigating back to this page
  }

  // Function to fetch user data from Firebase
  Future<void> _fetchUserData() async {
    try {
      final String userId = AuthService().getCurrentUserId();
      final DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        setState(() {
          currentUser.name = userDoc['username'] ?? 'Unknown';
          currentUser.bloodType = userDoc['blood_group'] ?? 'N/A';
          currentUser.height = userDoc['height'] ?? 'N/A';
          currentUser.weight = userDoc['weight'] ?? 'N/A';
          currentUser.profileImage = userDoc['profileImageUrl'] ?? '';
          currentUser.email = userDoc['email'] ?? '';
          currentUser.phone = userDoc['phone'] ?? '';
        });
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
    }
  }

  Future<String?> uploadImageToImgBB(String filePath) async {
    final apiKey = 'b876317f0442b8eec2f8c6ffd701b13d';
    final url = Uri.parse('https://api.imgbb.com/1/upload?key=$apiKey');

    final request = http.MultipartRequest('POST', url)
      ..files.add(await http.MultipartFile.fromPath('image', filePath));

    try {
      final response = await request.send();
      final res = await http.Response.fromStream(response);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final imageUrl = data['data']['url'];
        return imageUrl;
      } else {
        print('Image upload failed: ${res.body}');
        return null;
      }
    } catch (e) {
      print('Upload error: $e');
      return null;
    }
  }

  Future<void> _updateProfileImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        final imageUrl = await uploadImageToImgBB(pickedFile.path);
        if (imageUrl != null) {
          final String userId = AuthService().getCurrentUserId();
          await _firestore.collection('users').doc(userId).update({
            'profileImageUrl': imageUrl,
          });

          setState(() {
            currentUser.profileImage = imageUrl;
          });
        }
      }
    } catch (e) {
      debugPrint("Error uploading image: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _fetchUserData,
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      primary: false,
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: const Padding(
          padding: EdgeInsets.only(top: 10.0),
          child: Text('Profile', style: TextStyle(color: Colors.black)),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 30),
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => _showProfileImageOptions(context),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage: currentUser.profileImage.isNotEmpty
                        ? NetworkImage(currentUser.profileImage)
                        : const NetworkImage('https://via.placeholder.com/150'),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  currentUser.name,
                  style: GoogleFonts.nunito(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatColumn(
                        Icons.bloodtype, 'Blood Type', currentUser.bloodType),
                    _buildStatColumn(
                        Icons.height_rounded, 'Height', currentUser.height),
                    _buildStatColumn(
                        Icons.line_weight, 'Weight', currentUser.weight),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
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
                _buildMenuItem(Icons.help_outline, 'FAQs', () {
                  _showFAQDialog(context);
                }),
                _buildMenuItem(Icons.logout, 'Logout', () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                        builder: (context) => const LoginScreen()),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: 3,
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
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 16,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 25),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.blue.shade50, Colors.white],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'About Lifeline',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.grey.shade600),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    'Lifeline is a medical emergency response app designed to provide quick access to emergency services and personal health information.',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      height: 1.5,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Developed By',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade800,
                  ),
                ),
                const SizedBox(height: 12),
                _buildTeamMemberCard(
                  name: 'Jawad Mansoor',
                  role: 'Lead Developer',
                  context: context,
                ),
                const SizedBox(height: 24),
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Version 1.0.0',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.blue.shade800,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade800,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      elevation: 2,
                    ),
                    child: Text(
                      'Close',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeamMemberCard({
    required String name,
    required String role,
    required BuildContext context,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            role,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
