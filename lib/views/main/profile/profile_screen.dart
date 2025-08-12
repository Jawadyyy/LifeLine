import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lifeline/views/auth/change_password.dart';
import 'package:lifeline/views/auth/login_screen.dart';
import 'package:lifeline/views/main/profile/profile_setting_screen.dart';
import 'package:lifeline/services/auth_service.dart';
import 'package:lifeline/models/user_model.dart';
import 'package:lifeline/constants/app_colors.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ImagePicker _picker = ImagePicker();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool isDarkMode = false; // Add dark mode state
  // Remove hardcoded color variables since we'll use AppColors constantszz

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final String userId = AuthService().getCurrentUserId();
      final DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;

        setState(() {
          currentUser = UserModel(
            name: data['username'] ?? 'Unknown',
            bloodType: data['blood_group'] ?? 'N/A',
            height: data['height']?.toString() ?? 'N/A',
            weight: data['weight']?.toString() ?? 'N/A',
            profileImage: data['profile_image'] ?? '',
            email: data['email'] ?? '',
            phone: data['phone'] ?? '',
            age: data['age'] ?? '',
            bmi: data['bmi'] ?? '',
            disease: data['disease'] ?? 'None',
            allergy: data['allergy'] ?? 'None',
            address: data['home_address'] ?? '',
            emergencyText: data['emergency_text'] ?? '',
          );
        });
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
    }
  }

  Future<String?> uploadImageToImgBB(String filePath) async {
    const apiKey = 'b876317f0442b8eec2f8c6ffd701b13d';
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
        return null;
      }
    } catch (e) {
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
            currentUser = UserModel(
              name: currentUser.name,
              bloodType: currentUser.bloodType,
              height: currentUser.height,
              weight: currentUser.weight,
              profileImage: imageUrl,
              email: currentUser.email,
              phone: currentUser.phone,
              age: currentUser.age,
              bmi: currentUser.bmi,
              disease: currentUser.disease,
              allergy: currentUser.allergy,
              address: currentUser.address,
              emergencyText: currentUser.emergencyText,
            );
          });
        }
      }
    } catch (e) {
      debugPrint("Error uploading image: $e");
    }
  }

  void _showThemeDialog(BuildContext context, DynamicColors colors) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.palette, color: colors.primary, size: 24),
              const SizedBox(width: 12),
              Text(
                'Choose Theme',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.light_mode, color: colors.primary),
                title: Text(
                  'Light Mode',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  // Set light mode (isDarkMode = false)
                  setState(() {
                    isDarkMode = false;
                  });
                },
              ),
              ListTile(
                leading: Icon(Icons.dark_mode, color: colors.primary),
                title: Text(
                  'Dark Mode',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  // Set dark mode (isDarkMode = true)
                  setState(() {
                    isDarkMode = true;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: colors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = DynamicColors(isDarkMode);
    return Scaffold(
      backgroundColor: colors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(15),
                  bottomRight: Radius.circular(15),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 2,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    'Profile',
                    style: TextStyle(
                      color: colors.textTertiary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => _showProfileImageOptions(context),
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: colors.surface,
                          child: CircleAvatar(
                            radius: 48,
                            backgroundColor: colors.background,
                            backgroundImage: currentUser.profileImage.isNotEmpty
                                ? NetworkImage(currentUser.profileImage)
                                : null,
                            child: currentUser.profileImage.isEmpty
                                ? Icon(Icons.person,
                                    color: colors.primary, size: 48)
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: colors.primary,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: colors.surface, width: 2),
                            ),
                            child: Icon(Icons.edit,
                                color: colors.textTertiary, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    currentUser.name,
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: colors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    currentUser.email ?? 'No email available',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: colors.textTertiary.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatCard(
                      Icons.cake_outlined, 'Age', currentUser.age ?? 'N/A',
                      colors: colors),
                  _buildStatCard(
                    Icons.monitor_heart_outlined,
                    'BMI',
                    currentUser.bmi ?? '0.0',
                    isBmi: true,
                    colors: colors,
                  ),
                  _buildStatCard(Icons.bloodtype_outlined, 'Blood Type',
                      currentUser.bloodType,
                      colors: colors),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildMenuCard(
                    icon: Icons.person_outline,
                    title: 'Edit Profile',
                    subtitle: 'Update your personal information',
                    onTap: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  const ProfileSettingScreen(),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                          transitionDuration: const Duration(milliseconds: 500),
                        ),
                      ).then((_) {
                        _fetchUserData();
                      });
                    },
                    colors: colors,
                  ),
                  const SizedBox(height: 15),
                  _buildMenuCard(
                    icon: Icons.help_outline,
                    title: 'Help & FAQs',
                    subtitle: 'Get answers to common questions',
                    onTap: () {
                      _showFAQDialog(context);
                    },
                    colors: colors,
                  ),
                  const SizedBox(height: 15),
                  _buildMenuCard(
                    icon: Icons.lock_outline,
                    title: 'Change Password',
                    subtitle: 'Update your account password',
                    onTap: () async {
                      await FirebaseAuth.instance.signOut();

                      Navigator.pushReplacement(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  const ChangePasswordScreen(),
                          transitionsBuilder: (context, animation,
                                  secondaryAnimation, child) =>
                              FadeTransition(opacity: animation, child: child),
                          transitionDuration: const Duration(milliseconds: 500),
                        ),
                      );
                    },
                    colors: colors,
                  ),
                  const SizedBox(height: 15),
                  _buildMenuCard(
                    icon: Icons.dark_mode,
                    title: 'Theme',
                    subtitle: 'Change the theme of the app',
                    onTap: () {
                      _showThemeDialog(context, colors);
                    },
                    colors: colors,
                  ),
                  const SizedBox(height: 15),
                  _buildMenuCard(
                    icon: Icons.logout,
                    title: 'Logout',
                    subtitle: 'Sign out of your account',
                    onTap: () async {
                      await AuthService().signOut();
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    },
                    colors: colors,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String label, String value,
      {bool isBmi = false, required DynamicColors colors}) {
    final double bmi = isBmi ? double.tryParse(value) ?? 0.0 : 0.0;
    final Color bmiColor =
        isBmi ? _getBmiColor(bmi).withOpacity(0.2) : colors.surface;

    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: bmiColor,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: colors.textGrey.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isBmi
                    ? _getBmiColor(bmi).withOpacity(0.3)
                    : AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isBmi ? _getBmiColor(bmi) : colors.primary,
                size: 24,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colors.textGrey,
              ),
            ),
            const SizedBox(height: 5),
            isBmi
                ? _buildBmiValue(value)
                : Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildBmiValue(String value) {
    final bmi = double.tryParse(value) ?? 0.0;

    return Text(
      bmi.toStringAsFixed(1),
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: _getBmiColor(bmi),
      ),
    );
  }

  Color _getBmiColor(double bmi) {
    if (bmi < 18.5) return Colors.orange;
    if (bmi < 25.0) return Colors.green;
    if (bmi < 30.0) return Colors.amber;
    return Colors.red;
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required DynamicColors colors,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: colors.textGrey.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: colors.primary, size: 24),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: colors.textGrey),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colors.textLight),
          ],
        ),
      ),
    );
  }

  void _showProfileImageOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Update Profile Picture",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              _buildImageOption(
                icon: Icons.camera_alt,
                color: AppColors.primary,
                label: "Take Photo",
                onTap: () {
                  Navigator.pop(context);
                  _updateProfileImage(ImageSource.camera);
                },
              ),
              _buildImageOption(
                icon: Icons.photo_library,
                color: AppColors.primary,
                label: "Choose from Gallery",
                onTap: () {
                  Navigator.pop(context);
                  _updateProfileImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 15),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "Cancel",
                  style: GoogleFonts.poppins(
                    color: AppColors.textGrey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageOption({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color)),
      title: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
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
          borderRadius: BorderRadius.circular(25),
        ),
        elevation: 0,
        backgroundColor: AppColors.transparent,
        child: Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'About Lifeline',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Lifeline is a medical emergency response app designed to provide quick access to emergency services and personal health information.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              _buildTeamInfo(
                name: 'Jawad Mansoor',
                role: 'Lead Developer',
              ),
              const SizedBox(height: 20),
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Version 1.0.0',
                  style: GoogleFonts.poppins(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close',
                  style: GoogleFonts.poppins(
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamInfo({
    required String name,
    required String role,
  }) {
    return Column(
      children: [
        Text(
          'Developed By',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: AppColors.textGrey,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          role,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: AppColors.textGrey,
          ),
        ),
      ],
    );
  }
}
