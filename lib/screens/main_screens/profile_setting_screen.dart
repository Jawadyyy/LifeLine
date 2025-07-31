import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

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

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final Color _primaryColor = const Color(0xFFFF6F61);
  final Color _backgroundColor = const Color(0xFFF9F9F9);
  final Color _cardColor = Colors.white;
  final Color _textColor = const Color(0xFF333333);

  @override
  void initState() {
    super.initState();
    _loadUserData();
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
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final data = userDoc.data()!;
          setState(() {
            _addressController.text = data['home_address'] ?? '';
            _heightController.text = data['height'] ?? '';
            _weightController.text = data['weight'] ?? '';
            _usernameController.text = data['username'] ?? '';
            _phone = data['phone'] ?? '';
            _phoneController.text = _phone ?? '';
            _selectedDisease = data['disease'] ?? 'None';
            _selectedBloodGroup = data['blood_group'] ?? 'None';
            _selectedAllergy = data['allergy'] ?? 'None';
            _emergencyTextController.text = data['emergency_text'] ?? '';
            _ageController.text = data['age'] ?? '';
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _updateUserData() async {
    try {
      final userId = _auth.currentUser?.uid;
      final bmi = _calculateBMI();
      if (userId != null) {
        Map<String, dynamic> userData = {
          'home_address': _addressController.text.trim(),
          'height': _heightController.text.trim(),
          'weight': _weightController.text.trim(),
          'username': _usernameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'disease': _selectedDisease,
          'blood_group': _selectedBloodGroup,
          'allergy': _selectedAllergy,
          'emergency_text': _emergencyTextController.text.trim(),
          'age': _ageController.text.trim(),
        };

        if (bmi != null) {
          userData['bmi'] = bmi.toStringAsFixed(2);
        }

        await _firestore.collection('users').doc(userId).update(userData);

        await _loadUserData();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated successfully!'),
            backgroundColor: _primaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      print('Error updating user data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to update profile.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profile Settings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
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
            _buildInputField(
              controller: _usernameController,
              label: 'Username',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 16),
            _buildInputField(
              controller: _phoneController,
              label: 'Phone Number',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            _buildInputField(
              controller: _ageController,
              label: 'Age',
              icon: Icons.cake,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              value: _selectedDisease,
              items: const [
                'None',
                'Diabetes',
                'Hypertension',
                'Asthma',
                'Heart Disease',
                'Thyroid Disorder',
                'Kidney Disease',
                'Cancer',
                'Liver Disease',
                'Anemia',
                'Epilepsy',
                'HIV/AIDS',
                'Tuberculosis',
                'Arthritis',
                'Mental Health Conditions',
                'Other',
              ],
              label: 'Diseases (if any)',
              icon: Icons.health_and_safety,
              onChanged: (value) => setState(() => _selectedDisease = value),
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              value: _selectedAllergy,
              items: const [
                'None',
                'Pollen',
                'Dust Mites',
                'Mold',
                'Pet Dander',
                'Food - Peanuts',
                'Food - Shellfish',
                'Food - Eggs',
                'Food - Milk',
                'Food - Wheat',
                'Food - Soy',
                'Insect Stings',
                'Latex',
                'Medications',
                'Other',
              ],
              label: 'Allergies (if any)',
              icon: Icons.warning_amber_rounded,
              onChanged: (value) => setState(() => _selectedAllergy = value),
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              value: _selectedBloodGroup,
              items: const [
                'None',
                'A+',
                'A-',
                'B+',
                'B-',
                'AB+',
                'AB-',
                'O+',
                'O-'
              ],
              label: 'Blood Group',
              icon: Icons.bloodtype,
              onChanged: (value) => setState(() => _selectedBloodGroup = value),
            ),
            const SizedBox(height: 16),
            _buildInputField(
              controller: _heightController,
              label: 'Height (cm)',
              icon: Icons.height,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            _buildInputField(
              controller: _weightController,
              label: 'Weight (lbs)',
              icon: Icons.monitor_weight,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            _buildInputField(
              controller: _emergencyTextController,
              label: 'Custom Emergency Message',
              icon: Icons.sms,
            ),
            const SizedBox(height: 16),
            _buildInputField(
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
                      side: BorderSide(color: _primaryColor, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'CANCEL',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _updateUserData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
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
                        color: Colors.white,
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

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(color: _textColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.grey.shade600),
        prefixIcon: Icon(icon, color: _primaryColor),
        filled: true,
        fillColor: _cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required String label,
    required IconData icon,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 6,
            spreadRadius: 2,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(color: Colors.grey.shade600),
          border: InputBorder.none,
          prefixIcon: Icon(icon, color: _primaryColor),
        ),
        dropdownColor: _cardColor,
        icon: Icon(Icons.arrow_drop_down, color: _primaryColor),
        style: GoogleFonts.poppins(color: _textColor),
        items: items.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}
