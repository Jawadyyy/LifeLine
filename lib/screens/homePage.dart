import 'package:flutter/material.dart';
import 'package:lifeline/screens/login_screen.dart';
import 'package:lifeline/screens/map_screen.dart';
import 'package:lifeline/services/location_handler.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  String _currentAddress = "Fetching location...";

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
            onPressed: () {},
            icon: const Icon(Icons.notifications, color: Colors.black),
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
      body: Center(
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
                // Emergency button functionality
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
                child:
                    const Icon(Icons.touch_app, size: 40, color: Colors.white),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 32, 34, 160),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                "Go Back to Login",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: "My circle",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: "Map",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
        onTap: (index) {
          if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MapScreen()),
            );
          } else {
            setState(() {
              _selectedIndex = index;
            });
          }
        },
        selectedItemColor: const Color.fromARGB(255, 32, 34, 160),
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}
