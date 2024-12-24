import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lifeline/chatbot/screens/home_screen.dart';
import 'package:lifeline/components/bottom_navbar.dart';
import 'package:lifeline/services/location_handler.dart';
import 'package:lifeline/services/firestore_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String _currentAddress = "Fetching location...";
  bool _showEmergencyOptions = false;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    final position = await LocationHandler.getCurrentPosition();
    if (position != null) {
      final address = await LocationHandler.getAddressFromLatLng(position);
      setState(() {
        _currentAddress = address ?? "Location unavailable";
      });
    } else {
      setState(() {
        _currentAddress = "Location permission denied";
      });
    }
  }

  Future<void> _sendEmergencyMessage(String emergencyType) async {
    // Get the current user's ID
    final user = FirebaseAuth.instance.currentUser;

    // Ensure the user is authenticated
    if (user == null) {
      print("User is not authenticated");
      return;
    }

    final userId = user.uid; // Use the authenticated user's ID

    // Fetch emergency contacts from Firestore
    final contacts = await FirestoreService().getEmergencyContacts(userId);

    // Check if there are any emergency contacts
    if (contacts.isEmpty) {
      print("No emergency contacts found");
      return;
    }

    // Get the current location
    final position = await LocationHandler.getCurrentPosition();

    // Check if the position is null and handle the case
    if (position == null) {
      print("Location not available");
      return;
    }

    // Get the address from the latitude and longitude
    final address = await LocationHandler.getAddressFromLatLng(position);

    // Prepare the emergency message with the type of emergency
    String message =
        "🚨 I am in an emergency: $emergencyType. My location is: $address";

    // Notify each contact
    for (String contact in contacts) {
      final whatsappUrl =
          'https://wa.me/$contact?text=${Uri.encodeFull(message)}';

      try {
        await launch(whatsappUrl);
        await Future.delayed(const Duration(seconds: 2));
      } catch (e) {
        print("Could not open WhatsApp for contact $contact. Error: $e");
      }
    }

    print("Emergency message sent to all contacts.");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 15.0),
          child: Image.asset(
            "assets/images/logo.png",
            fit: BoxFit.contain,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Current location",
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            Text(
              _currentAddress,
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _getUserLocation,
            icon: const Icon(Icons.refresh, color: Colors.black),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Having an Emergency?",
                  style: GoogleFonts.nunito(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Press the button below\nhelp will arrive soon",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    color: Color.fromARGB(255, 105, 105, 105),
                  ),
                ),
                const SizedBox(height: 40),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showEmergencyOptions = !_showEmergencyOptions;
                    });
                  },
                  child: buildMainEmergencyButton(onTap: () {
                    setState(() {
                      _showEmergencyOptions = !_showEmergencyOptions;
                    });
                  }),
                )
              ],
            ),
          ),
          if (_showEmergencyOptions) ..._buildEmergencyOptions(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ChatHomeScreen()),
          );
        },
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        elevation: 4.0,
        child: SizedBox(
          width: 40.0, // Adjust width as needed
          height: 40.0, // Adjust height as needed
          child: Image.asset(
            'assets/images/icons/brain.png',
            fit: BoxFit
                .contain, // Ensures the image fits within the specified size
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }

  List<Widget> _buildEmergencyOptions() {
    final List<String> emergencyImages = [
      'assets/images/icons/ambulance.png',
      'assets/images/icons/policeman.png',
      'assets/images/icons/avatar.png',
      'assets/images/icons/healthcare.png',
      'assets/images/icons/warning.png',
      'assets/images/icons/bandage.png',
    ];

    final List<String> emergencyTypes = [
      "Medical Emergency",
      "Police Assistance",
      "Fire Alert",
      "Health Issue",
      "SOS",
      "General Emergency",
    ];

    const double radius = 140.0; // Distance from the main button

    return List.generate(emergencyImages.length, (index) {
      final angle =
          (index * 60) * (3.141592653589793 / 180); // 60 degrees apart
      final offsetX = radius * cos(angle);
      final offsetY = radius * sin(angle);

      return AnimatedPositioned(
        duration: const Duration(milliseconds: 300),
        left: MediaQuery.of(context).size.width / 2 + offsetX - 35, // Centered
        top: MediaQuery.of(context).size.height / 2 + offsetY - 35,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: _showEmergencyOptions ? 1 : 0,
          child: GestureDetector(
            onTap: () {
              _sendEmergencyMessage(emergencyTypes[index]);
            },
            child: Container(
              height: 70, // Slightly larger for better visibility
              width: 70,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFFAD59),
                    Color(0xFFFF7E7B)
                  ], // Gradient colors
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    spreadRadius: 2,
                    offset: const Offset(0, 3),
                  ),
                ],
                border: Border.all(color: const Color(0xFFFF7E7B), width: 2),
              ),
              child: Center(
                child: TweenAnimationBuilder(
                  tween: Tween<double>(
                      begin: 1.0, end: _showEmergencyOptions ? 1.1 : 1.0),
                  duration: const Duration(milliseconds: 300),
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: Image.asset(
                        emergencyImages[index],
                        fit: BoxFit.contain,
                        height: 30, // Adjust the image size if necessary
                        width: 30,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  GestureDetector buildMainEmergencyButton({required Function() onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 150,
        width: 150,
        decoration: BoxDecoration(
          gradient: const RadialGradient(
            center: Alignment(-0.3, -0.3),
            colors: [
              Color(0xFFFFAD59), // Light gradient color
              Color(0xFFFF7E7B), // Dark gradient color
            ],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF7E7B).withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Center(
          child: Image.asset(
            'assets/images/icons/tap.png',
            height: 75,
            width: 75,
          ),
        ),
      ),
    );
  }
}
