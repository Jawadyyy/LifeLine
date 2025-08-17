import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeline/constants/app_colors.dart';
import 'package:lifeline/views/main/profile/controller/profile_controller.dart';
import 'package:lifeline/views/main/profile/controller/profile_widgets.dart';

class ProfileSettingScreen extends StatefulWidget {
  const ProfileSettingScreen({super.key});

  @override
  State<ProfileSettingScreen> createState() => _ProfileSettingScreenState();
}

class _ProfileSettingScreenState extends State<ProfileSettingScreen> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _emergencyTextController =
      TextEditingController();
  String? _selectedDisease;
  String? _selectedBloodGroup;
  String? _selectedAllergy;
  String? _phone;

  late final ProfileController _profileController;

  @override
  void initState() {
    super.initState();
    _profileController = ProfileController();
    _loadUserData();
  }

  @override
  void dispose() {
    _profileController.dispose();
    super.dispose();
  }

  double? _calculateBMI() {
    try {
      final double heightCm = double.parse(_heightController.text.trim());
      final double weightLbs = double.parse(_weightController.text.trim());
      final double heightM = heightCm / 100;
      final double weightKg = weightLbs * 0.453592;

      if (heightM <= 0 || weightKg <= 0) return null;

      return weightKg / (heightM * heightM);
    } catch (e) {
      return null;
    }
  }

  Future<void> _loadUserData() async {
    try {
      final data = await _profileController.loadUserData();
      if (data == null) return;

      setState(() {
        _addressController.text = data['home_address'] ?? '';
        _heightController.text = data['height']?.toString() ?? '';
        _weightController.text = data['weight']?.toString() ?? '';
        _usernameController.text = data['username'] ?? '';
        _phone = data['phone'] ?? '';
        _phoneController.text = _phone ?? '';
        _selectedDisease = data['disease'] ?? 'None';
        _selectedBloodGroup = data['blood_group'] ?? 'None';
        _selectedAllergy = data['allergy'] ?? 'None';
        _emergencyTextController.text = data['emergency_text'] ?? '';
        _ageController.text = data['age'] ?? '';
      });
    } catch (e) {
      return;
    }
  }

  Future<void> _updateUserData() async {
    try {
      final bmi = _calculateBMI();

      final Map<String, dynamic> userData = {
        'home_address': _addressController.text.trim(),
        'height': _heightController.text.trim(),
        'weight': _weightController.text.trim(),
        'username': _usernameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'disease': _selectedDisease ?? 'None',
        'blood_group': _selectedBloodGroup ?? 'None',
        'allergy': _selectedAllergy ?? 'None',
        'emergency_text': _emergencyTextController.text.trim(),
        'age': _ageController.text.trim(),
      };

      if (bmi != null) {
        userData['bmi'] = bmi.toStringAsFixed(1);
      }

      final success = await _profileController.updateUserData(userData);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Profile updated successfully!',
              style: GoogleFonts.poppins(color: AppColors.textTertiary),
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        Navigator.pop(context);
      } else if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update profile.',
              style: GoogleFonts.poppins(color: AppColors.textTertiary),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update profile.',
              style: GoogleFonts.poppins(color: AppColors.textTertiary),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textTertiary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profile Settings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textTertiary,
          ),
        ),
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ProfileWidgets.buildInputField(
              controller: _usernameController,
              label: 'Username',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 16),
            ProfileWidgets.buildInputField(
              controller: _phoneController,
              label: 'Phone Number',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            ProfileWidgets.buildInputField(
              controller: _ageController,
              label: 'Age',
              icon: Icons.cake,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            ProfileWidgets.buildDropdown(
              value: _selectedDisease,
              items: ProfileController.diseaseOptions,
              label: 'Diseases (if any)',
              icon: Icons.health_and_safety,
              onChanged: (value) => setState(() => _selectedDisease = value),
            ),
            const SizedBox(height: 16),
            ProfileWidgets.buildDropdown(
              value: _selectedAllergy,
              items: ProfileController.allergyOptions,
              label: 'Allergies (if any)',
              icon: Icons.warning_amber_rounded,
              onChanged: (value) => setState(() => _selectedAllergy = value),
            ),
            const SizedBox(height: 16),
            ProfileWidgets.buildDropdown(
              value: _selectedBloodGroup,
              items: ProfileController.bloodGroupOptions,
              label: 'Blood Group',
              icon: Icons.bloodtype,
              onChanged: (value) => setState(() => _selectedBloodGroup = value),
            ),
            const SizedBox(height: 16),
            ProfileWidgets.buildInputField(
              controller: _heightController,
              label: 'Height (cm)',
              icon: Icons.height,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            ProfileWidgets.buildInputField(
              controller: _weightController,
              label: 'Weight (lbs)',
              icon: Icons.monitor_weight,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            ProfileWidgets.buildInputField(
              controller: _emergencyTextController,
              label: 'Custom Emergency Message',
              icon: Icons.sms,
            ),
            const SizedBox(height: 16),
            ProfileWidgets.buildInputField(
              controller: _addressController,
              label: 'Home Address',
              icon: Icons.home,
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: AppColors.primary, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'CANCEL',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _updateUserData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: Text(
                      'UPDATE PROFILE',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
