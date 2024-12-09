import 'package:flutter/material.dart';
import 'package:lifeline/components/bottom_navbar.dart';
import 'package:lifeline/screens/auth_screens/login_screen.dart';
import 'package:google_fonts/google_fonts.dart';


class ProfileApp extends StatelessWidget {
  const ProfileApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const ProfilePage(),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Profile',
          style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: const NetworkImage('https://via.placeholder.com/150'),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sabrina Aryan',
                      style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'sabrina@example.com',
                      style: GoogleFonts.nunito(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '+123456789',
                      style: GoogleFonts.nunito(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 30),

            _buildMenuItem(
              icon: Icons.edit,
              title: "Edit Profile",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EditProfilePage()),
                );
              },
            ),
            _buildMenuItem(
              icon: Icons.help_outline,
              title: "FAQs",
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: "FAQs",
                  applicationVersion: "1.0.0",
                  children: [
                    const Text("Created by Jawad Mansoor, Waqas Siddique, and Sardar Muhammad Ali Khan."),
                  ],
                );
              },
            ),
            _buildMenuItem(
              icon: Icons.logout,
              title: "Log Out",
              onTap: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (Route<dynamic> route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: ListTile(
        leading: Icon(icon),
        title: Text(
          title,
          style: GoogleFonts.nunito(fontSize: 18),
        ),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}

class EditProfilePage extends StatelessWidget {
  const EditProfilePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile', style: GoogleFonts.nunito()),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField(
              items: [
                DropdownMenuItem(child: Text('A+'), value: 'A+'),
                DropdownMenuItem(child: Text('B+'), value: 'B+'),
                DropdownMenuItem(child: Text('AB+'), value: 'AB+'),
                DropdownMenuItem(child: Text('O+'), value: 'O+'),
              ],
              onChanged: (value) {},
              decoration: const InputDecoration(
                labelText: 'Blood Group',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField(
              items: [
                DropdownMenuItem(child: Text('Diabetes'), value: 'Diabetes'),
                DropdownMenuItem(child: Text('Hypertension'), value: 'Hypertension'),
                DropdownMenuItem(child: Text('Asthma'), value: 'Asthma'),
                DropdownMenuItem(child: Text('Heart Disease'), value: 'Heart Disease'),
                DropdownMenuItem(child: Text('Obesity'), value: 'Obesity'),
                DropdownMenuItem(child: Text('Arthritis'), value: 'Arthritis'),
                DropdownMenuItem(child: Text('Kidney Disease'), value: 'Kidney Disease'),
                DropdownMenuItem(child: Text('Cancer'), value: 'Cancer'),
                DropdownMenuItem(child: Text('Thyroid'), value: 'Thyroid'),
              ],
              onChanged: (value) {},
              decoration: const InputDecoration(
                labelText: 'Diseases',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}


