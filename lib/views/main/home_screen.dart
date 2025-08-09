import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:lifeline/chatbot/screens/chat_home_screen.dart';
import 'package:lifeline/services/location_handler.dart';
import 'package:lifeline/services/firestore_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';
import 'donation_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  String _currentAddress = "Fetching location...";
  bool _showEmergencyOptions = false;
  bool _isLocationFetched = false;
  bool _isLoadingLocation = false;
  final Color _primaryColor = const Color(0xFFFF6F61);
  final Color _primaryLightColor = const Color(0xFFFFE8E5);

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

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
    _getUserLocationIfNeeded();
  }

  void _getUserLocationIfNeeded() {
    if (!_isLocationFetched) {
      _getUserLocation();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    if (!mounted) return;
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      final position = await LocationHandler.getCurrentPosition();
      if (!mounted) return;

      if (position != null) {
        final address = await LocationHandler.getAddressFromLatLng(position);
        if (!mounted) return;

        setState(() {
          _currentAddress = address ?? "Location unavailable";
          _isLocationFetched = true;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _currentAddress = "Location permission denied";
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _currentAddress = "Error getting location";
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _sendEmergencyMessage(String emergencyType) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _showEmergencyOptions = false;
    });

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
        Navigator.pop(context);
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final customMessage =
          userDoc.data()?['emergency_text']?.toString().trim();
      final username = userDoc.data()?['username'] ?? 'User';

      final position = await LocationHandler.getCurrentPosition();
      if (position == null) {
        Navigator.pop(context);
        return;
      }

      final address = await LocationHandler.getAddressFromLatLng(position) ??
          "Address unavailable";

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      String city = placemarks.isNotEmpty
          ? (placemarks.first.locality?.isNotEmpty == true
              ? placemarks.first.locality!
              : placemarks.first.administrativeArea ?? "Unknown City")
          : "Unknown City";

      final mapUrl =
          "https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}";

      final fallbackMessage = "🚨 EMERGENCY: $emergencyType\n"
          "👤 Name: $username\n"
          "📍 Address: $address\n"
          "🌆 City: $city\n"
          "🗺️ Location: $mapUrl\n"
          "🕒 ${DateTime.now().toString().substring(0, 16)}";

      final message = (customMessage == null || customMessage.isEmpty)
          ? fallbackMessage
          : "$customMessage\n📍 Address: $address\n🌆 City: $city\n🗺️ Location: $mapUrl\n🕒 ${DateTime.now().toString().substring(0, 16)}";

      for (String contact in contacts) {
        final whatsappUrl =
            'https://wa.me/$contact?text=${Uri.encodeComponent(message)}';
        try {
          await launch(whatsappUrl);
          await Future.delayed(const Duration(seconds: 2));
        } catch (e) {
          debugPrint("Error sending to $contact: $e");
        }
      }

      Navigator.pop(context);

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
      Navigator.pop(context);
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Image.asset(
            'assets/images/logos/logo1.png',
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
            const SizedBox(height: 4),
            SizedBox(
              width: size.width * 0.6,
              child: _isLoadingLocation
                  ? LinearProgressIndicator(
                      minHeight: 4,
                      color: _primaryColor,
                      backgroundColor: _primaryLightColor,
                      borderRadius: BorderRadius.circular(4),
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
            icon: const Icon(Icons.refresh, color: Colors.black),
            tooltip: "Refresh location",
          ),
        ],
      ),
      body: Stack(
        children: [
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
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: buildMainEmergencyButton(
                      onTap: _toggleEmergencyOptions,
                    ),
                  ),
                  const SizedBox(height: 30),
                  buildBloodDonationCard(context),
                ],
              ),
            ],
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
        backgroundColor: Colors.white,
        elevation: 4,
        child: Image.asset(
          'assets/images/icons/brain.png',
          height: 28,
        ),
      ),
    );
  }

  List<Widget> _buildEmergencyOptions() {
    final List<Map<String, dynamic>> emergencyTypes = [
      {
        "image": 'assets/images/icons/ambulance.png',
        "type": "Medical Emergency",
        "color": Colors.white,
      },
      {
        "image": 'assets/images/icons/policeman.png',
        "type": "Police Assistance",
        "color": Colors.white,
      },
      {
        "image": 'assets/images/icons/fire.png',
        "type": "Fire Alert",
        "color": Colors.white,
      },
      {
        "image": 'assets/images/icons/healthcare.png',
        "type": "Health Issue",
        "color": Colors.white,
      },
      {
        "image": 'assets/images/icons/warning.png',
        "type": "SOS",
        "color": Colors.white,
      },
      {
        "image": 'assets/images/icons/bandage.png',
        "type": "General Emergency",
        "color": Colors.white,
      },
    ];

    final size = MediaQuery.of(context).size;
    const double radius = 155.0;

    final double centerX = size.width / 2;
    final double centerY = size.height * 0.4;

    return List.generate(emergencyTypes.length, (index) {
      final angle = (index * 60) * (pi / 180);
      final offsetX = radius * cos(angle);
      final offsetY = radius * sin(angle);

      return AnimatedPositioned(
        duration: const Duration(milliseconds: 300),
        left: centerX + offsetX - 35,
        top: centerY + offsetY - 35,
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
        height: 180,
        width: 180,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              _primaryColor.withOpacity(0.9),
              _primaryColor.withOpacity(0.7),
              _primaryColor.withOpacity(0.5),
            ],
            stops: const [0.3, 0.7, 1.0],
            radius: 0.85,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _primaryColor.withOpacity(0.5),
              blurRadius: 35,
              spreadRadius: 8,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/icons/tap.png',
                height: 65,
                color: Colors.white.withOpacity(0.95),
              ),
              const SizedBox(height: 10),
              Text(
                _showEmergencyOptions ? "CANCEL" : "EMERGENCY",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: 1.1,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      blurRadius: 2,
                      offset: Offset(1, 1),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildBloodDonationCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(PageRouteBuilder(
          pageBuilder: (_, __, ___) => const DonationScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ));
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 30),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: const Color(0xFFFF6F61).withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              height: 50,
              width: 50,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6F61).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Image.asset(
                'assets/images/icons/blood.png',
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Donate Blood, Save Lives",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Tap to view donation opportunities near you",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
