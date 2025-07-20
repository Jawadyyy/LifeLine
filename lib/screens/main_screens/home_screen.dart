import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lifeline/chatbot/screens/home_screen.dart';
import 'package:lifeline/components/bottom_navbar.dart';
import 'package:lifeline/services/location_handler.dart';
import 'package:lifeline/services/firestore_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  String _currentAddress = "Fetching location...";
  bool _showEmergencyOptions = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _getUserLocation();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
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
    } catch (e) {
      setState(() {
        _currentAddress = "Error getting location";
      });
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _sendEmergencyMessage(String emergencyType) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _showEmergencyOptions = false;
    });

    // Show sending indicator immediately
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Sending emergency alerts..."),
          ],
        ),
      ),
    );

    try {
      final contacts = await FirestoreService().getEmergencyContacts(user.uid);
      if (contacts.isEmpty) {
        Navigator.pop(context); // Dismiss loading dialog
        return;
      }

      final position = await LocationHandler.getCurrentPosition();
      if (position == null) {
        Navigator.pop(context); // Dismiss loading dialog
        return;
      }

      final address = await LocationHandler.getAddressFromLatLng(position);
      String message =
          "🚨 EMERGENCY: $emergencyType\n📍 Location: $address\n🕒 ${DateTime.now().toString().substring(0, 16)}";

      // Send messages immediately without confirmation
      for (String contact in contacts) {
        final whatsappUrl =
            'https://wa.me/$contact?text=${Uri.encodeFull(message)}';
        try {
          await launch(whatsappUrl);
          await Future.delayed(const Duration(seconds: 2));
        } catch (e) {
          debugPrint("Error sending to $contact: $e");
        }
      }

      Navigator.pop(context); // Dismiss loading dialog

      // Show brief success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Emergency alerts sent for $emergencyType'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Dismiss loading dialog if still showing
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to send emergency alerts'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  void _toggleEmergencyOptions() {
    setState(() {
      _showEmergencyOptions = !_showEmergencyOptions;
      if (_showEmergencyOptions) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Image.asset(
            "assets/images/logo.png",
            height: 40,
            width: 40,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Current location",
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              width: size.width * 0.6,
              child: _isLoadingLocation
                  ? const SizedBox(
                      height: 20,
                      child: LinearProgressIndicator(),
                    )
                  : Text(
                      _currentAddress,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _getUserLocation,
            icon: Icon(
              Icons.refresh,
              color: theme.colorScheme.primary,
            ),
            tooltip: "Refresh location",
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main content
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Emergency Assistance",
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  "Press the emergency button below to get immediate help",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onBackground.withOpacity(0.7),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Center(
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: buildMainEmergencyButton(
                    onTap: _toggleEmergencyOptions,
                  ),
                ),
              ),
            ],
          ),

          // Emergency options
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
        backgroundColor: theme.colorScheme.surface,
        elevation: 4,
        child: Image.asset(
          'assets/images/icons/brain.png',
          height: 28,
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
    final List<Map<String, dynamic>> emergencyTypes = [
      {
        "image": 'assets/images/icons/ambulance.png',
        "type": "Medical Emergency",
        "color": const Color.fromARGB(255, 255, 255, 255),
      },
      {
        "image": 'assets/images/icons/policeman.png',
        "type": "Police Assistance",
        "color": const Color.fromARGB(255, 255, 255, 255),
      },
      {
        "image": 'assets/images/icons/fire.png',
        "type": "Fire Alert",
        "color": const Color.fromARGB(255, 255, 255, 255),
      },
      {
        "image": 'assets/images/icons/healthcare.png',
        "type": "Health Issue",
        "color": const Color.fromARGB(255, 255, 255, 255),
      },
      {
        "image": 'assets/images/icons/warning.png',
        "type": "SOS",
        "color": const Color.fromARGB(255, 255, 255, 255),
      },
      {
        "image": 'assets/images/icons/bandage.png',
        "type": "General Emergency",
        "color": const Color.fromARGB(255, 255, 255, 255),
      },
    ];

    final size = MediaQuery.of(context).size;
    const double radius = 160.0;

    return List.generate(emergencyTypes.length, (index) {
      final angle = (index * 60) * (pi / 180);
      final offsetX = radius * cos(angle);
      final offsetY = radius * sin(angle);

      return AnimatedPositioned(
        duration: const Duration(milliseconds: 300),
        left: size.width / 2 + offsetX - 35,
        top: size.height / 2 + offsetY - 35,
        child: GestureDetector(
          onTap: () => _sendEmergencyMessage(emergencyTypes[index]["type"]),
          child: Container(
            height: 70,
            width: 70,
            decoration: BoxDecoration(
              color: emergencyTypes[index]["color"],
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    emergencyTypes[index]["image"],
                    height: 30,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    emergencyTypes[index]["type"].toString().split(' ')[0],
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget buildMainEmergencyButton({required Function() onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 160,
        width: 160,
        decoration: BoxDecoration(
          gradient: const RadialGradient(
            colors: [
              Color(0xFFFF5252),
              Color(0xFFFF1744),
            ],
            stops: [0.4, 1.0],
            radius: 0.8,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF1744).withOpacity(0.4),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/icons/tap.png',
                height: 60,
                color: Colors.white,
              ),
              const SizedBox(height: 8),
              Text(
                _showEmergencyOptions ? "CANCEL" : "EMERGENCY",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
