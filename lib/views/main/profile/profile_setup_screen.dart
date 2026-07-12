import 'package:lifeline/utils/logger.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeline/models/user_model.dart';
import 'package:lifeline/services/user_service.dart';
import 'package:lifeline/views/main/profile/controller/profile_controller.dart';
import 'package:lifeline/views/main/profile/controller/profile_widgets.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final Color _primaryColor = const Color(0xFFFF6F61);
  final Color _secondaryColor = const Color(0xFFF8F9FA);
  final Color _cardColor = Colors.white;

  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _emergencyTextController = TextEditingController();
  final _addressController = TextEditingController();

  String? _selectedDisease = 'None';
  String? _selectedAllergy = 'None';
  String? _selectedBloodGroup = 'None';
  File? _profileImage;
  bool _isLoading = false;

  final _userService = UserService();
  late final ProfileController _profileController;

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _profileImage = File(picked.path));
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _emergencyTextController.dispose();
    _addressController.dispose();
    _profileController.dispose();
    super.dispose();
  }

  Future<String?> _uploadProfileImage(String filePath) async {
    return await _profileController.uploadProfileImage(filePath);
  }

  Future<void> _loadUserData() async {
    final data = await _profileController.loadUserData();
    if (data == null) return;

    setState(() {
      _phoneController.text = data['phone'] ?? '';
      _ageController.text = data['age'] ?? '';
      _heightController.text = data['height'] ?? '';
      _weightController.text = data['weight'] ?? '';
      _addressController.text = data['address'] ?? '';
      _emergencyTextController.text = data['emergencyText'] ?? '';
      _selectedBloodGroup = data['bloodType'] ?? 'None';
      _selectedDisease = data['disease'] ?? 'None';
      _selectedAllergy = data['allergy'] ?? 'None';
      if (data['profileImage'] != null && data['profileImage'] != '') {}
    });
  }

  Future<void> _updateUserData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        setState(() => _isLoading = false);
        return;
      }

      final phone = _phoneController.text.trim();

      // Only check uniqueness if phone is not empty
      if (phone.isNotEmpty) {
        final isUnique = await _profileController.isPhoneNumberUnique(phone,
            excludeUserId: uid);

        if (!isUnique) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context).phoneInUse,
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      final double height = double.tryParse(_heightController.text.trim()) ?? 0;
      final double weight = double.tryParse(_weightController.text.trim()) ?? 0;
      final double bmi = height > 0 && weight > 0
          ? _profileController.calculateBMI(
                  height.toString(), weight.toString()) ??
              0.0
          : 0.0;

      String profileImageUrl = '';
      if (_profileImage != null) {
        final uploadedUrl = await _uploadProfileImage(_profileImage!.path);
        if (uploadedUrl != null) {
          profileImageUrl = uploadedUrl;
        } else {
          throw Exception("Failed to upload profile image.");
        }
      }

      final currentUser = await _userService.loadCurrentUser();

      // No new image picked: keep whatever the account already has (e.g. the
      // Google photo saved at sign-in). Never persist the old
      // via.placeholder.com junk URL — empty means "no picture".
      if (profileImageUrl.isEmpty) {
        final existing = currentUser?.profileImage ?? '';
        profileImageUrl =
            existing.contains('via.placeholder.com') ? '' : existing;
      }

      // Never persist the 'Loading...' placeholder that UserModel.fromMap
      // returns when the username field is missing from the Firestore doc.
      final loadedName = currentUser?.name;
      final resolvedName = (loadedName == null ||
              loadedName.isEmpty ||
              loadedName == 'Loading...')
          ? (FirebaseAuth.instance.currentUser?.displayName ?? 'User')
          : loadedName;

      final newUser = UserModel(
        name: resolvedName,
        bloodType: _selectedBloodGroup ?? 'None',
        height: height.toStringAsFixed(1),
        weight: weight.toStringAsFixed(1),
        profileImage: profileImageUrl,
        email: FirebaseAuth.instance.currentUser?.email ?? '',
        phone: phone,
        age: _ageController.text.trim(),
        bmi: bmi.toStringAsFixed(1),
        disease: _selectedDisease ?? 'None',
        allergy: _selectedAllergy ?? 'None',
        address: _addressController.text.trim(),
        emergencyText: _emergencyTextController.text.trim(),
      );

      await _userService.updateCurrentUser(newUser);

      // ✅ Mark profile as complete
      await _profileController.markProfileComplete();

      if (!mounted) return;

      logDebug('✅ Profile setup complete for user: $uid');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).profileUpdated,
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

      // ❌ REMOVED: Navigator.pushReplacement
      // ✅ AuthWrapper will automatically detect isProfileComplete = true
      // and navigate to MainNavigationScreen
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).errUpdatingProfile(e.toString()),
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _profileController = ProfileController();
    _loadUserData();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: _secondaryColor,
      body: SafeArea(
        child: Column(
          children: [
            Stack(
              children: [
                ClipPath(
                  clipper: WaveClipper(),
                  child: Container(
                    height: 180,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_primaryColor.withOpacity(0.9), _primaryColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 80,
                  left: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white,
                      backgroundImage: _profileImage != null
                          ? FileImage(_profileImage!)
                          : null,
                      child: _profileImage == null
                          ? Icon(Icons.camera_alt,
                              size: 40, color: _primaryColor)
                          : null,
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Form(
                  key: _formKey,
                  child: Column(children: [
                    ProfileWidgets.buildSectionTitle(l.personalInformation,
                        primaryColor: _primaryColor),
                    ProfileWidgets.buildInputField(
                      controller: _phoneController,
                      label: l.fieldPhone,
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                      requiredMessage: l.pleaseEnter(l.fieldPhone),
                    ),
                    const SizedBox(height: 12),
                    ProfileWidgets.buildInputField(
                      controller: _ageController,
                      label: l.age,
                      icon: Icons.cake,
                      keyboardType: TextInputType.number,
                      requiredMessage: l.pleaseEnter(l.age),
                    ),
                    const SizedBox(height: 12),
                    ProfileWidgets.buildInputField(
                      controller: _addressController,
                      label: l.fieldHomeAddress,
                      icon: Icons.home,
                      requiredMessage: l.pleaseEnter(l.fieldHomeAddress),
                    ),
                    ProfileWidgets.buildSectionTitle(l.healthInformation,
                        primaryColor: _primaryColor),
                    Row(
                      children: [
                        Expanded(
                          child: ProfileWidgets.buildInputField(
                            controller: _heightController,
                            label: l.heightCm,
                            icon: Icons.height,
                            keyboardType: TextInputType.number,
                            requiredMessage: l.pleaseEnter(l.heightCm),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ProfileWidgets.buildInputField(
                            controller: _weightController,
                            label: l.weightKg,
                            icon: Icons.monitor_weight,
                            keyboardType: TextInputType.number,
                            requiredMessage: l.pleaseEnter(l.weightKg),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ProfileWidgets.buildDropdown(
                      value: _selectedBloodGroup,
                      label: l.fieldBloodGroup,
                      icon: Icons.bloodtype,
                      items: ProfileController.bloodGroupOptions,
                      onChanged: (val) =>
                          setState(() => _selectedBloodGroup = val),
                    ),
                    const SizedBox(height: 12),
                    ProfileWidgets.buildDropdown(
                      value: _selectedDisease,
                      label: l.diseasesIfAny,
                      icon: Icons.health_and_safety,
                      items: ProfileController.diseaseOptions,
                      onChanged: (val) =>
                          setState(() => _selectedDisease = val),
                    ),
                    const SizedBox(height: 12),
                    ProfileWidgets.buildDropdown(
                      value: _selectedAllergy,
                      label: l.allergiesIfAny,
                      icon: Icons.warning_amber_rounded,
                      items: ProfileController.allergyOptions,
                      onChanged: (val) =>
                          setState(() => _selectedAllergy = val),
                    ),
                    ProfileWidgets.buildSectionTitle(l.emergencyInformation,
                        primaryColor: _primaryColor),
                    ProfileWidgets.buildInputField(
                      controller: _emergencyTextController,
                      label: l.customEmergencyMessage,
                      icon: Icons.sms,
                      isOptional: true,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 30),
                    ProfileWidgets.buildActionButtons(
                      onCancel: () => Navigator.pop(context),
                      onSave: _updateUserData,
                      isLoading: _isLoading,
                      cancelText: l.cancelAction,
                      saveText: l.saveProfile,
                      primaryColor: _primaryColor,
                      surfaceColor: _cardColor,
                    ),
                    const SizedBox(height: 20),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..lineTo(0, size.height - 60)
      ..quadraticBezierTo(size.width * 0.25, size.height - 40, size.width * 0.5,
          size.height - 60)
      ..quadraticBezierTo(
          size.width * 0.75, size.height - 80, size.width, size.height - 60)
      ..lineTo(size.width, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
