import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  String? _selectedDisease;
  String? _selectedBloodGroup;
  String? _phone;

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadUserData();
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
      if (userId != null) {
        await _firestore.collection('users').doc(userId).update({
          'home_address': _addressController.text.trim(),
          'height': _heightController.text.trim(),
          'weight': _weightController.text.trim(),
          'username': _usernameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'disease': _selectedDisease,
          'blood_group': _selectedBloodGroup,
        });

        // Reload user data after successful update
        await _loadUserData();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      }
    } catch (e) {
      print('Error updating user data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update profile.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Profile Settings',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Username
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12.0)),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 20),
                ),
              ),
              const SizedBox(height: 16),

              // Phone Number TextField with country code
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number (with country code)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12.0)),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 20),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedDisease,
                decoration: InputDecoration(
                  labelText: 'Diseases (if any)',
                  labelStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue, width: 2.0),
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey, width: 1.0),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  filled: true,
                  fillColor: Colors.grey[200],
                ),
                dropdownColor: Colors.white,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.blue),
                style: const TextStyle(color: Colors.black, fontSize: 16),
                items: const [
                  DropdownMenuItem(
                    value: 'None',
                    child: Text('None',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                  ),
                  DropdownMenuItem(
                    value: 'Diabetes',
                    child: Text('Diabetes',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                  ),
                  DropdownMenuItem(
                    value: 'Hypertension',
                    child: Text('Hypertension',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                  ),
                  DropdownMenuItem(
                    value: 'Asthma',
                    child: Text('Asthma',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                  ),
                  DropdownMenuItem(
                    value: 'Other',
                    child: Text('Other',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedDisease = value;
                  });
                },
              ),

              const SizedBox(height: 16),

              // Blood Group Dropdown
              DropdownButtonFormField<String>(
                value: _selectedBloodGroup,
                decoration: InputDecoration(
                  labelText: 'Blood Group',
                  labelStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.red),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red, width: 2.0),
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey, width: 1.0),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  filled: true,
                  fillColor: Colors.grey[200],
                ),
                dropdownColor: Colors.white,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.red),
                style: const TextStyle(color: Colors.black, fontSize: 16),
                items: const [
                  DropdownMenuItem(
                    value: 'None',
                    child: Text('None',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                  ),
                  DropdownMenuItem(
                    value: 'A+',
                    child: Text('A+',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                  ),
                  DropdownMenuItem(
                    value: 'A-',
                    child: Text('A-',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                  ),
                  DropdownMenuItem(
                    value: 'B+',
                    child: Text('B+',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                  ),
                  DropdownMenuItem(
                    value: 'B-',
                    child: Text('B-',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                  ),
                  DropdownMenuItem(
                    value: 'AB+',
                    child: Text('AB+',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                  ),
                  DropdownMenuItem(
                    value: 'AB-',
                    child: Text('AB-',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                  ),
                  DropdownMenuItem(
                    value: 'O+',
                    child: Text('O+',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                  ),
                  DropdownMenuItem(
                    value: 'O-',
                    child: Text('O-',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedBloodGroup = value!;
                  });
                },
              ),

              const SizedBox(height: 16),

              // Height (in cm)
              TextField(
                controller: _heightController,
                decoration: const InputDecoration(
                  labelText: 'Height (in cm)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12.0)),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 20),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              // Weight (in pounds)
              TextField(
                controller: _weightController,
                decoration: const InputDecoration(
                  labelText: 'Weight (in pounds)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12.0)),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 20),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              // Home Address
              TextField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Home Address',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12.0)),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 20),
                ),
              ),
              const SizedBox(height: 32),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.blueAccent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _updateUserData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                      ),
                      child: const Text(
                        'Update Setting',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
