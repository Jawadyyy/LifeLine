import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ProfileSettingScreen extends StatefulWidget {
  const ProfileSettingScreen({super.key});

  @override
  State<ProfileSettingScreen> createState() => _ProfileSettingScreenState();
}

class _ProfileSettingScreenState extends State<ProfileSettingScreen> {
  File? _image; // To store the selected image

  // Function to pick image from gallery
  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
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
              const TextField(
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12.0)),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 20),
                ),
              ),
              const SizedBox(height: 16),

              // Diseases Dropdown
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Diseases (if any)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12.0)),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 20),
                ),
                items: const [
                  DropdownMenuItem(value: 'None', child: Text('None')),
                  DropdownMenuItem(value: 'Diabetes', child: Text('Diabetes')),
                  DropdownMenuItem(value: 'Hypertension', child: Text('Hypertension')),
                  DropdownMenuItem(value: 'Asthma', child: Text('Asthma')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (value) {
                  // Handle change
                },
              ),
              const SizedBox(height: 16),

              // Blood Group Dropdown
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Blood Group',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12.0)),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 20),
                ),
                items: const [
                  DropdownMenuItem(value: 'A+', child: Text('A+')),
                  DropdownMenuItem(value: 'A-', child: Text('A-')),
                  DropdownMenuItem(value: 'B+', child: Text('B+')),
                  DropdownMenuItem(value: 'B-', child: Text('B-')),
                  DropdownMenuItem(value: 'AB+', child: Text('AB+')),
                  DropdownMenuItem(value: 'AB-', child: Text('AB-')),
                  DropdownMenuItem(value: 'O+', child: Text('O+')),
                  DropdownMenuItem(value: 'O-', child: Text('O-')),
                ],
                onChanged: (value) {
                  // Handle change
                },
              ),
              const SizedBox(height: 16),

              // Height TextField
              const TextField(
                decoration: InputDecoration(
                  labelText: 'Height',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12.0)),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 20),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              // Contact TextField
              const TextField(
                decoration: InputDecoration(
                  labelText: 'Contact',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12.0)),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 20),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),

              // Home Address TextField
              const TextField(
                decoration: InputDecoration(
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
                      onPressed: () {
                        // Add your update logic here
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                      ),
                      child: const Text(
                        'Update Setting',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
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
