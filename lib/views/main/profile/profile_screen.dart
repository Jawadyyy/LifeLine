import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:lifeline/services/locale_controller.dart';
import 'package:lifeline/views/auth/change_password.dart';
import 'package:lifeline/views/auth/login_screen.dart';
import 'package:lifeline/views/main/profile/profile_setting_screen.dart';
import 'package:lifeline/views/main/medical_id/medical_id_screen.dart';
import 'package:lifeline/views/main/profile/controller/profile_controller.dart';
import 'package:lifeline/views/main/profile/controller/profile_widgets.dart';
import 'package:lifeline/constants/app_colors.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lifeline/services/global_data_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final ProfileController _profileController;
  final GlobalDataService _globalDataService = GlobalDataService();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();

    _profileController = ProfileController();
    _profileController.addListener(_onProfileControllerChanged);

    // Listen to global data service for user data updates
    _globalDataService.addListener(_onGlobalDataChanged);

    // Initialize data once
    _initializeData();
  }

  void _onProfileControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initializeData() async {
    if (_isInitialized) return;

    // Get user data from global service (already loaded)
    _updateUserFromGlobal();

    // If global service doesn't have user data yet, fetch it directly
    if (_globalDataService.currentUser == null) {
      debugPrint('ProfileScreen: No global data, fetching directly...');
      await _profileController.fetchUserData();
    }

    _isInitialized = true;
  }

  void _onGlobalDataChanged() {
    if (mounted) {
      _updateUserFromGlobal();
    }
  }

  void _updateUserFromGlobal() {
    if (_globalDataService.currentUser != null) {
      // Only update if the user data is different to prevent infinite loops
      final globalUser = _globalDataService.currentUser!;
      final currentUser = _profileController.currentUser;

      if (currentUser == null ||
          currentUser.name != globalUser.name ||
          currentUser.email != globalUser.email ||
          currentUser.profileImage != globalUser.profileImage) {
        debugPrint('ProfileScreen: Updating user data from global service');
        _profileController.setCurrentUser(globalUser);
      }
    }
  }

  @override
  void dispose() {
    _profileController.removeListener(_onProfileControllerChanged);
    _globalDataService.removeListener(_onGlobalDataChanged);
    _profileController.dispose();
    super.dispose();
  }

  Future<void> _updateProfileImage(ImageSource source) async {
    final success = await _profileController.updateProfileImage(source);
    if (success) {
      // Force refresh user data from GlobalDataService to ensure consistency
      await _globalDataService.updateUserData();
      if (mounted) setState(() {}); // Trigger rebuild to show updated image
    }
  }

  @override
  Widget build(BuildContext context) {
    final DynamicColors colors = DynamicColors(false);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(15),
                  bottomRight: Radius.circular(15),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.2),
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
                      color: AppColors.textTertiary,
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
                          backgroundColor: AppColors.surface,
                          child: _buildProfileImage(),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.surface, width: 2),
                            ),
                            child: Icon(Icons.edit,
                                color: AppColors.textTertiary, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    _profileController.currentUser?.name ?? 'Unknown',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _profileController.currentUser?.email ??
                        'No email available',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppColors.textTertiary.withOpacity(0.8),
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
                  ProfileWidgets.buildStatCard(
                      icon: Icons.cake_outlined,
                      label: 'Age',
                      value: _profileController.currentUser?.age ?? 'N/A',
                      colors: colors),
                  ProfileWidgets.buildStatCard(
                      icon: Icons.monitor_heart_outlined,
                      label: 'BMI',
                      value: _profileController.currentUser?.bmi ?? '0.0',
                      isBmi: true,
                      colors: colors,
                      bmiColor: _getBmiColor(double.tryParse(
                              _profileController.currentUser?.bmi ?? '0.0') ??
                          0.0)),
                  ProfileWidgets.buildStatCard(
                      icon: Icons.bloodtype_outlined,
                      label: 'Blood Type',
                      value: _profileController.currentUser?.bloodType ?? 'N/A',
                      colors: colors),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  ProfileWidgets.buildMenuCard(
                    icon: Icons.person_outline,
                    title: 'Edit Profile',
                    subtitle: 'Update your personal information',
                    onTap: () async {
                      await Navigator.push(
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
                      );
                      // Refresh from global service after returning
                      _updateUserFromGlobal();
                    },
                    colors: colors,
                  ),
                  const SizedBox(height: 15),
                  ProfileWidgets.buildMenuCard(
                    icon: Icons.medical_information_outlined,
                    title: 'Medical ID',
                    subtitle: 'Blood type, allergies & emergency contact',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MedicalIdScreen()),
                    ),
                    colors: colors,
                  ),
                  const SizedBox(height: 15),
                  ProfileWidgets.buildMenuCard(
                    icon: Icons.language,
                    title: 'Language',
                    subtitle: 'Choose your preferred language',
                    onTap: () => _showLanguageDialog(context),
                    colors: colors,
                  ),
                  const SizedBox(height: 15),
                  ProfileWidgets.buildMenuCard(
                    icon: Icons.help_outline,
                    title: 'Help & FAQs',
                    subtitle: 'Get answers to common questions',
                    onTap: () {
                      _showFAQDialog(context);
                    },
                    colors: colors,
                  ),
                  const SizedBox(height: 15),
                  ProfileWidgets.buildMenuCard(
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
                  ProfileWidgets.buildMenuCard(
                    icon: Icons.logout,
                    title: 'Logout',
                    subtitle: 'Sign out of your account',
                    onTap: () async {
                      await _profileController.signOut();
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

  // Build profile image with caching
  Widget _buildProfileImage() {
    final imageUrl = _profileController.currentUser?.profileImage ?? '';

    if (imageUrl.isEmpty) {
      return CircleAvatar(
        radius: 48,
        backgroundColor: AppColors.background,
        child: Icon(Icons.person, color: AppColors.primary, size: 48),
      );
    }

    return CircleAvatar(
      radius: 48,
      backgroundColor: AppColors.background,
      // Cached provider keeps the image in memory + on disk, so revisiting
      // the profile reuses it instead of re-downloading every time.
      backgroundImage: CachedNetworkImageProvider(imageUrl),
      onBackgroundImageError: (exception, stackTrace) {
        debugPrint('Error loading profile image: $exception');
      },
      child: null,
    );
  }

  Color _getBmiColor(double bmi) {
    if (bmi < 18.5) return Colors.orange;
    if (bmi < 25.0) return Colors.green;
    if (bmi < 30.0) return Colors.amber;
    return Colors.red;
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
              ProfileWidgets.buildImageOption(
                icon: Icons.camera_alt,
                color: AppColors.primary,
                label: "Take Photo",
                onTap: () {
                  Navigator.pop(context);
                  _updateProfileImage(ImageSource.camera);
                },
              ),
              ProfileWidgets.buildImageOption(
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

  void _showLanguageDialog(BuildContext context) {
    final controller = context.read<LocaleController>();
    final l = AppLocalizations.of(context);
    final current = controller.locale.languageCode;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l.language),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              value: 'en',
              groupValue: current,
              title: Text(l.english),
              activeColor: AppColors.primary,
              onChanged: (v) {
                controller.setLocale(const Locale('en'));
                Navigator.pop(dialogContext);
              },
            ),
            RadioListTile<String>(
              value: 'ur',
              groupValue: current,
              title: Text(l.urdu),
              activeColor: AppColors.primary,
              onChanged: (v) {
                controller.setLocale(const Locale('ur'));
                Navigator.pop(dialogContext);
              },
            ),
          ],
        ),
      ),
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
              ProfileWidgets.buildTeamInfo(
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
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
