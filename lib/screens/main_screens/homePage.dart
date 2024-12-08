import 'package:flutter/material.dart';
import 'package:lifeline/components/bottom_navbar.dart';
//import 'package:lifeline/screens/auth_screens/login_screen.dart';
import 'package:lifeline/services/location_handler.dart';
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
                //  const SizedBox(height: 30),
                // ElevatedButton(
                //   onPressed: () {
                //     Navigator.pushReplacement(
                //       context,
                //       MaterialPageRoute(
                //           builder: (context) => const LoginScreen()),
                //     );
                //   },
                //   style: ElevatedButton.styleFrom(
                //     backgroundColor: const Color.fromARGB(255, 32, 34, 160),
                //     shape: RoundedRectangleBorder(
                //       borderRadius: BorderRadius.circular(10),
                //     ),
                //   ),
                //   child: const Text(
                //     "Go Back to Login",
                //     style: TextStyle(color: Colors.white),
                //   ),
                // ),
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
          child: Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFF7E7B), width: 2),
            ),
            child: Icon(emergencyIcons[index], color: const Color(0xFFFF7E7B)),
          ),
        ),
      );
    });
  }
}
