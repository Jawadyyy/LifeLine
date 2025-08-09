import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeline/components/navigation.dart';
import 'package:lifeline/models/user_model.dart';
import 'package:lifeline/services/user_service.dart';

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

  @override
  void dispose() {
    _phoneController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _emergencyTextController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _profileImage = File(picked.path));
    }
  }

  double _calculateBMI(double heightCm, double weightLbs) {
    final heightM = heightCm / 100;
    final weightKg = weightLbs * 0.453592;
    return weightKg / (heightM * heightM);
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
        return data['data']['url'];
      } else {
        debugPrint('Image upload failed: ${res.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    }
  }

  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!doc.exists) return;

    final data = doc.data()!;

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
      if (uid == null) return;

      final phone = _phoneController.text.trim();

      final existing = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phone)
          .get();

      final alreadyExists = existing.docs.any((doc) => doc.id != uid);

      if (alreadyExists) {
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
        return;
      }

      final double height = double.tryParse(_heightController.text.trim()) ?? 0;
      final double weight = double.tryParse(_weightController.text.trim()) ?? 0;
      final double bmi =
          height > 0 && weight > 0 ? _calculateBMI(height, weight) : 0.0;

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

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'isProfileComplete': true});

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
                    _buildSectionTitle('Personal Information'),
                    _buildInputField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    _buildInputField(
                      controller: _ageController,
                      label: 'Age',
                      icon: Icons.cake,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    _buildInputField(
                      controller: _addressController,
                      label: 'Home Address',
                      icon: Icons.home,
                    ),
                    _buildSectionTitle('Health Information'),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInputField(
                            controller: _heightController,
                            label: 'Height (cm)',
                            icon: Icons.height,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInputField(
                            controller: _weightController,
                            label: 'Weight (lbs)',
                            icon: Icons.monitor_weight,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildDropdown(
                      value: _selectedBloodGroup,
                      label: 'Blood Group',
                      icon: Icons.bloodtype,
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
                      onChanged: (val) =>
                          setState(() => _selectedBloodGroup = val),
                    ),
                    const SizedBox(height: 12),
                    _buildDropdown(
                      value: _selectedDisease,
                      label: 'Diseases (if any)',
                      icon: Icons.health_and_safety,
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
                      onChanged: (val) =>
                          setState(() => _selectedDisease = val),
                    ),
                    const SizedBox(height: 12),
                    _buildDropdown(
                      value: _selectedAllergy,
                      label: 'Allergies (if any)',
                      icon: Icons.warning_amber_rounded,
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
                      onChanged: (val) =>
                          setState(() => _selectedAllergy = val),
                    ),
                    _buildSectionTitle('Emergency Information'),
                    _buildInputField(
                      controller: _emergencyTextController,
                      label: 'Custom Emergency Message',
                      icon: Icons.sms,
                      isOptional: true,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 30),
                    _buildActionButtons(),
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _primaryColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(
              color: _primaryColor.withOpacity(0.3),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isOptional = false,
    int maxLines = 1,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: GoogleFonts.poppins(color: _textColor),
        validator: (value) {
          if (!isOptional && (value == null || value.trim().isEmpty)) {
            return 'Please enter $label';
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 14),
          prefixIcon: Icon(icon, color: _primaryColor.withOpacity(0.7)),
          filled: true,
          fillColor: _cardColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _primaryColor, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
        ),
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
      margin: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 14),
          prefixIcon: Icon(icon, color: _primaryColor.withOpacity(0.7)),
          filled: true,
          fillColor: _cardColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _primaryColor, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        dropdownColor: _cardColor,
        icon: Icon(Icons.arrow_drop_down, color: _primaryColor),
        style: GoogleFonts.poppins(color: _textColor, fontSize: 14),
        items: items
            .map((item) => DropdownMenuItem(
                  value: item,
                  child: Text(item, style: GoogleFonts.poppins()),
                ))
            .toList(),
        onChanged: onChanged,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: _primaryColor, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: _cardColor,
            ),
            child: Text('CANCEL',
                style: GoogleFonts.poppins(
                    color: _primaryColor, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _updateUserData,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
              shadowColor: _primaryColor.withOpacity(0.3),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Text('SAVE PROFILE',
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
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
