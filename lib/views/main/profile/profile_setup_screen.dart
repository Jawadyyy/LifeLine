import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeline/components/navigation.dart';
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
  final Color _textColor = Colors.black87;
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

  Future<String?> uploadImageToImgBB(String filePath) async {
    return await _profileController.uploadImageToImgBB(filePath);
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
                'This phone number is already in use.',
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

      String profileImageUrl = 'https://via.placeholder.com/150';
      if (_profileImage != null) {
        final uploadedUrl = await uploadImageToImgBB(_profileImage!.path);
        if (uploadedUrl != null) {
          profileImageUrl = uploadedUrl;
        } else {
          throw Exception("Failed to upload profile image.");
        }
      }

      final currentUser = await _userService.loadCurrentUser();

      final newUser = UserModel(
        name: currentUser?.name ?? "User",
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

      await _profileController.markProfileComplete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Profile updated successfully!',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error updating profile: $e',
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
                    ProfileWidgets.buildSectionTitle('Personal Information',
                        primaryColor: _primaryColor),
                    ProfileWidgets.buildInputField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    ProfileWidgets.buildInputField(
                      controller: _ageController,
                      label: 'Age',
                      icon: Icons.cake,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    ProfileWidgets.buildInputField(
                      controller: _addressController,
                      label: 'Home Address',
                      icon: Icons.home,
                    ),
                    ProfileWidgets.buildSectionTitle('Health Information',
                        primaryColor: _primaryColor),
                    Row(
                      children: [
                        Expanded(
                          child: ProfileWidgets.buildInputField(
                            controller: _heightController,
                            label: 'Height (cm)',
                            icon: Icons.height,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ProfileWidgets.buildInputField(
                            controller: _weightController,
                            label: 'Weight (lbs)',
                            icon: Icons.monitor_weight,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ProfileWidgets.buildDropdown(
                      value: _selectedBloodGroup,
                      label: 'Blood Group',
                      icon: Icons.bloodtype,
                      items: ProfileController.bloodGroupOptions,
                      onChanged: (val) =>
                          setState(() => _selectedBloodGroup = val),
                    ),
                    const SizedBox(height: 12),
                    ProfileWidgets.buildDropdown(
                      value: _selectedDisease,
                      label: 'Diseases (if any)',
                      icon: Icons.health_and_safety,
                      items: ProfileController.diseaseOptions,
                      onChanged: (val) =>
                          setState(() => _selectedDisease = val),
                    ),
                    const SizedBox(height: 12),
                    ProfileWidgets.buildDropdown(
                      value: _selectedAllergy,
                      label: 'Allergies (if any)',
                      icon: Icons.warning_amber_rounded,
                      items: ProfileController.allergyOptions,
                      onChanged: (val) =>
                          setState(() => _selectedAllergy = val),
                    ),
                    ProfileWidgets.buildSectionTitle('Emergency Information',
                        primaryColor: _primaryColor),
                    ProfileWidgets.buildInputField(
                      controller: _emergencyTextController,
                      label: 'Custom Emergency Message',
                      icon: Icons.sms,
                      isOptional: true,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 30),
                    ProfileWidgets.buildActionButtons(
                      onCancel: () => Navigator.pop(context),
                      onSave: _updateUserData,
                      isLoading: _isLoading,
                      cancelText: 'CANCEL',
                      saveText: 'SAVE PROFILE',
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
