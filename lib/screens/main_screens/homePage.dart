import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lifeline/components/bottom_navbar.dart';
import 'package:lifeline/services/location_handler.dart';
import 'package:lifeline/services/firestore_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
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

  // Modify this part of your code where you fetch and pass Position

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
        await Future.delayed(
            const Duration(seconds: 2)); // Add delay for reliability
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
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            "assets/images/logo.png",
            fit: BoxFit.contain,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Current location",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            Text(
              _currentAddress,
              style: const TextStyle(
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
          const Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: CircleAvatar(
              radius: 20,
              backgroundImage: NetworkImage("https://via.placeholder.com/150"),
            ),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Center content inside the Column widget
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Having an Emergency?",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Press the button below\nhelp will arrive soon",
                  textAlign: TextAlign.center,
                  style: TextStyle(
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
                  child: Container(
                    height: 150,
                    width: 150,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF7E7B),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF7E7B).withOpacity(0.5),
                          blurRadius: 10,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.touch_app,
                        size: 40, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          // Animated small buttons
          if (_showEmergencyOptions) ..._buildEmergencyOptions(),
        ],
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
    final List<IconData> emergencyIcons = [
      Icons.local_hospital,
      Icons.local_police,
      Icons.fire_truck,
      Icons.healing,
      Icons.sos,
      Icons.warning,
    ];

    final List<String> emergencyTypes = [
      "Medical Emergency",
      "Police Assistance",
      "Fire Alert",
      "Health Issue",
      "SOS",
      "General Emergency"
    ];

    final double radius = 140.0; // Distance from the main button

    return List.generate(emergencyIcons.length, (index) {
      final angle =
          (index * 60) * (3.141592653589793 / 180); // 60 degrees apart
      final offsetX = radius * cos(angle);
      final offsetY = radius * sin(angle);

      return AnimatedPositioned(
        duration: const Duration(milliseconds: 300),
        left: MediaQuery.of(context).size.width / 2 + offsetX - 30,
        top: MediaQuery.of(context).size.height / 2 + offsetY - 30,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: _showEmergencyOptions ? 1 : 0,
          child: GestureDetector(
            onTap: () {
              // Send the emergency message when an option is selected
              _sendEmergencyMessage(emergencyTypes[index]);
            },
            child: Container(
              height: 60,
              width: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFF7E7B), width: 2),
              ),
              child:
                  Icon(emergencyIcons[index], color: const Color(0xFFFF7E7B)),
            ),
          ),
        ),
      );
    });
  }
}
