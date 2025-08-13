import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:lifeline/constants/app_colors.dart';
import 'package:lifeline/services/firestore_service.dart';
import 'package:lifeline/services/location_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../donation_screen.dart';

class HomeController {
  final State state;
  final void Function(void Function()) setStateFn;

  HomeController(this.state, this.setStateFn);

  // Convenience getters
  BuildContext get context => state.context;
  bool get mounted => state.mounted;

  // These require the State to expose the following private fields via callbacks or direct access if placed in same file.
  // We will access them using dynamic calls on the provided State.

  T _getField<T>(String name) => (state as dynamic).__getField(name) as T;
  void _setField(String name, dynamic value) =>
      (state as dynamic).__setField(name, value);

  void getUserLocationIfNeeded() {
    final bool isLocationFetched = _getField<bool>('_isLocationFetched');
    if (!isLocationFetched) {
      getUserLocation();
    }
  }

  Future<void> getUserLocation() async {
    if (!mounted) return;
    setStateFn(() {
      _setField('_isLoadingLocation', true);
    });

    try {
      final position = await LocationHandler.getCurrentPosition();
      if (!mounted) return;

      if (position != null) {
        final address = await LocationHandler.getAddressFromLatLng(position);
        if (!mounted) return;

        setStateFn(() {
          _setField('_currentAddress', address ?? 'Location unavailable');
          _setField('_isLocationFetched', true);
        });
      } else {
        if (!mounted) return;
        setStateFn(() {
          _setField('_currentAddress', 'Location permission denied');
        });
      }
    } catch (e) {
      if (!mounted) return;
      setStateFn(() {
        _setField('_currentAddress', 'Error getting location');
      });
    } finally {
      if (!mounted) return;
      setStateFn(() {
        _setField('_isLoadingLocation', false);
      });
    }
  }

  Future<void> sendEmergencyMessage(String emergencyType) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setStateFn(() {
      _setField('_showEmergencyOptions', false);
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
            Text('Sending emergency alerts...'),
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
          'Address unavailable';

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      String city = placemarks.isNotEmpty
          ? (placemarks.first.locality?.isNotEmpty == true
              ? placemarks.first.locality!
              : placemarks.first.administrativeArea ?? 'Unknown City')
          : 'Unknown City';

      final mapUrl =
          'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';

      final fallbackMessage = '🚨 EMERGENCY: $emergencyType\n'
          '👤 Name: $username\n'
          '📍 Address: $address\n'
          '🌆 City: $city\n'
          '🗺️ Location: $mapUrl\n'
          '🕒 ${DateTime.now().toString().substring(0, 16)}';

      final message = (customMessage == null || customMessage.isEmpty)
          ? fallbackMessage
          : '$customMessage\n📍 Address: $address\n🌆 City: $city\n🗺️ Location: $mapUrl\n🕒 ${DateTime.now().toString().substring(0, 16)}';

      for (String contact in contacts) {
        final whatsappUrl =
            'https://wa.me/$contact?text=${Uri.encodeComponent(message)}';
        try {
          await launch(whatsappUrl);
          await Future.delayed(const Duration(seconds: 2));
        } catch (e) {
          debugPrint('Error sending to $contact: $e');
        }
      }

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Emergency alerts sent for $emergencyType'),
          backgroundColor: AppColors.success,
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
        const SnackBar(
          content: Text('Failed to send emergency alerts'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void toggleEmergencyOptions() {
    final bool show = _getField<bool>('_showEmergencyOptions');
    final animationController =
        _getField<AnimationController>('_animationController');
    setStateFn(() {
      _setField('_showEmergencyOptions', !show);
      if (!show) {
        animationController.forward();
      } else {
        animationController.reverse();
      }
    });
  }

  List<Widget> buildEmergencyOptions() {
    final List<Map<String, dynamic>> emergencyTypes = [
      {
        "image": 'assets/images/icons/ambulance.png',
        "type": 'Medical Emergency',
        "color": AppColors.surface
      },
      {
        "image": 'assets/images/icons/policeman.png',
        "type": 'Police Assistance',
        "color": AppColors.surface
      },
      {
        "image": 'assets/images/icons/fire.png',
        "type": 'Fire Alert',
        "color": AppColors.surface
      },
      {
        "image": 'assets/images/icons/healthcare.png',
        "type": 'Health Issue',
        "color": AppColors.surface
      },
      {
        "image": 'assets/images/icons/warning.png',
        "type": 'SOS',
        "color": AppColors.surface
      },
      {
        "image": 'assets/images/icons/bandage.png',
        "type": 'General Emergency',
        "color": AppColors.surface
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
          onTap: () => sendEmergencyMessage(emergencyTypes[index]["type"]),
          child: Container(
            height: 70,
            width: 70,
            decoration: BoxDecoration(
              color: emergencyTypes[index]["color"],
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.textPrimary.withOpacity(0.2),
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
                      color: AppColors.textPrimary,
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

  Widget buildMainEmergencyButton(BuildContext context,
      {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 180,
        width: 180,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              AppColors.primary.withOpacity(0.9),
              AppColors.primary.withOpacity(0.7),
              AppColors.primary.withOpacity(0.5),
            ],
            stops: const [0.3, 0.7, 1.0],
            radius: 0.85,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.5),
              blurRadius: 35,
              spreadRadius: 8,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(
            color: AppColors.textTertiary.withOpacity(0.3),
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
                color: AppColors.textTertiary.withOpacity(0.95),
              ),
              const SizedBox(height: 10),
              const Text(
                'EMERGENCY',
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: 1.1,
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.error.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: AppColors.primary.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              height: 50,
              width: 50,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Image.asset('assets/images/icons/blood.png'),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Donate Blood, Save Lives',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tap to view donation opportunities near you',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 16, color: AppColors.textGrey),
          ],
        ),
      ),
    );
  }
}
