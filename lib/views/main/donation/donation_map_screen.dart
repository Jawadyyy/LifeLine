import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';
import 'package:lifeline/constants/app_colors.dart';
import 'package:lifeline/views/main/donation/controller/donation_controller.dart';
import 'package:lifeline/views/main/donation/controller/donation_dialog_controller.dart';

class DonationMapScreen extends StatefulWidget {
  const DonationMapScreen({super.key});

  @override
  State<DonationMapScreen> createState() => _DonationMapOnlyScreenState();
}

class _DonationMapOnlyScreenState extends State<DonationMapScreen> {
  late DonationController _donationController;
  late DonationDialogController _dialogController;

  late MapController _mapController;
  Position? _currentPosition;
  bool _isLoadingLocation = false;
  bool _isMapReady = false;
  String? _currentAddress;

  // Selected donation for bottom sheet
  Map<String, dynamic>? _selectedDonation;

  // Animation settings
  final Duration _animationDuration = const Duration(milliseconds: 300);
  final Curve _animationCurve = Curves.easeInOut;
  final Distance _distance = const Distance();

  // Default map position (Rawalpindi/Islamabad)
  static const LatLng _defaultPosition = LatLng(33.6844, 73.0479);

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _donationController = DonationController();
    _dialogController = DonationDialogController(_donationController);
    _donationController.init();
    _checkLocationAndLoad();
  }

  @override
  void dispose() {
    _donationController.dispose();
    super.dispose();
  }

  Future<void> _checkLocationAndLoad() async {
    if (mounted) {
      setState(() => _isLoadingLocation = true);
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() => _isLoadingLocation = false);
          await _showLocationServiceDialog();
        }
        return;
      }

      await _getCurrentLocation();
    } catch (e) {
      debugPrint('Error in checkLocationAndLoad: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  Future<void> _showLocationServiceDialog() async {
    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.only(top: 20, left: 20, right: 20),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          actionsPadding: const EdgeInsets.only(bottom: 10, right: 10),
          title: Row(
            children: [
              Icon(Icons.location_on, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(
                'Location Required',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          content: const Text(
            'To show nearby donations and create requests, we need access to your location. Please enable location services.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Not Now'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await Geolocator.openLocationSettings();
                await _checkLocationAndLoad();
              },
              child: const Text('Enable'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permission denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permission permanently denied');
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }

      // Get address
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          String address = '';

          if (place.locality != null && place.locality!.isNotEmpty) {
            address = place.locality!;
          }
          if (place.subLocality != null && place.subLocality!.isNotEmpty) {
            address += address.isNotEmpty
                ? ', ${place.subLocality}'
                : place.subLocality!;
          }

          if (mounted) {
            setState(() => _currentAddress = address);
          }
        }
      } catch (e) {
        debugPrint('Error getting address: $e');
      }

      // Move camera to current location
      if (_isMapReady && mounted) {
        _mapController.move(
          LatLng(position.latitude, position.longitude),
          14,
        );
      }
    } catch (e) {
      debugPrint('Error getting location: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not get your location: $e'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Color _getBloodGroupColor(String bloodGroup) {
    switch (bloodGroup) {
      case 'O+':
      case 'O-':
        return Colors.red;
      case 'A+':
      case 'A-':
        return Colors.orange;
      case 'B+':
      case 'B-':
        return Colors.yellow.shade700;
      case 'AB+':
      case 'AB-':
        return Colors.green;
      default:
        return AppColors.primary;
    }
  }

  void _onMarkerTapped(Map<String, dynamic> donation) {
    setState(() {
      _selectedDonation = donation;
    });

    // Animate camera to selected marker
    final postData = donation['postData'] as Map<String, dynamic>;
    final latitude = postData['latitude'] as double;
    final longitude = postData['longitude'] as double;

    _mapController.move(LatLng(latitude, longitude), 15);
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    return _distance.as(
      LengthUnit.Kilometer,
      LatLng(lat1, lon1),
      LatLng(lat2, lon2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _donationController,
      child: Scaffold(
        backgroundColor: Colors.white,
        extendBodyBehindAppBar: true,
        appBar: _buildAppBar(),
        body: _buildBody(),
        floatingActionButton: _buildFloatingButtons(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      title: AnimatedSwitcher(
        duration: _animationDuration,
        child: _selectedDonation != null
            ? Text(
                'Donation Request',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  shadows: [
                    Shadow(
                      color: Colors.white.withOpacity(0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
              )
            : Text(
                _currentAddress ?? "Finding location...",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  shadows: [
                    Shadow(
                      color: Colors.white.withOpacity(0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
      ),
      leading: Container(
        margin: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: Icon(
            _selectedDonation != null ? Icons.close : Icons.arrow_back,
            color: Colors.black87,
          ),
          onPressed: () {
            if (_selectedDonation != null) {
              setState(() => _selectedDonation = null);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _checkLocationAndLoad,
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    // Show loading only initially
    if (_isLoadingLocation && _currentPosition == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
            const SizedBox(height: 20),
            Text(
              "Finding your location...",
              style: TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      );
    }

    return Consumer<DonationController>(
      builder: (context, controller, child) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: controller.getFilteredDonationPostsStream(),
          builder: (context, snapshot) {
            final donations = snapshot.data ?? [];

            return Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentPosition != null
                        ? LatLng(_currentPosition!.latitude,
                            _currentPosition!.longitude)
                        : _defaultPosition,
                    initialZoom: 14.0,
                    interactionOptions: const InteractionOptions(
                      flags: ~InteractiveFlag.rotate,
                    ),
                    onMapReady: () {
                      setState(() => _isMapReady = true);
                      if (_currentPosition != null) {
                        _mapController.move(
                          LatLng(_currentPosition!.latitude,
                              _currentPosition!.longitude),
                          14,
                        );
                      }
                    },
                    onTap: (_, __) {
                      if (mounted) {
                        setState(() => _selectedDonation = null);
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      retinaMode: RetinaMode.isHighDensity(context),
                      urlTemplate:
                          'https://{s}.tile.jawg.io/jawg-terrain/{z}/{x}/{y}{r}.png?access-token=FQfie4AAncNFaqSo02Dqzm6tGnV1YLuUtHbAnfneft9fXOZx6c4OKhq2bKDtbvSf',
                      subdomains: const ['a', 'b', 'c'],
                      userAgentPackageName: 'com.example.lifeline',
                    ),
                    MarkerLayer(
                      markers: [
                        // Current location marker
                        if (_currentPosition != null)
                          Marker(
                            point: LatLng(_currentPosition!.latitude,
                                _currentPosition!.longitude),
                            width: 50,
                            height: 50,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.primary,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.person_pin_circle,
                                color: AppColors.primary,
                                size: 30,
                              ),
                            ),
                          ),
                        // Donation markers
                        ...donations.map((donation) {
                          final postData =
                              donation['postData'] as Map<String, dynamic>;
                          final userData =
                              donation['userData'] as Map<String, dynamic>;
                          final latitude = postData['latitude'] as double?;
                          final longitude = postData['longitude'] as double?;

                          if (latitude == null || longitude == null) {
                            return Marker(
                              point: _defaultPosition,
                              width: 0,
                              height: 0,
                              child: SizedBox.shrink(),
                            );
                          }

                          final bloodGroup = postData['blood_group'] as String;
                          final isSelected = _selectedDonation == donation;

                          return Marker(
                            point: LatLng(latitude, longitude),
                            width: 50,
                            height: 50,
                            child: GestureDetector(
                              onTap: () => _onMarkerTapped(donation),
                              child: AnimatedContainer(
                                duration: _animationDuration,
                                curve: _animationCurve,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? _getBloodGroupColor(bloodGroup)
                                      : _getBloodGroupColor(bloodGroup)
                                          .withOpacity(0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _getBloodGroupColor(bloodGroup),
                                    width: isSelected ? 3 : 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: isSelected ? 10 : 6,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    bloodGroup,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : _getBloodGroupColor(bloodGroup),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ],
                ),
                _buildFilterPanel(controller),
                if (_selectedDonation != null) _buildBottomSheet(),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFilterPanel(DonationController controller) {
    return Positioned(
      top: 100,
      left: 16,
      right: 16,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Blood group filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _buildFilterChip(
                      'All', controller.selectedBloodFilter == 'All'),
                  ...controller.bloodGroups.map(
                    (bg) => _buildFilterChip(
                        bg, controller.selectedBloodFilter == bg),
                  ),
                ],
              ),
            ),
            // City filter toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.tertiary.withOpacity(0.3)),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_city,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      controller.currentUserCity != null
                          ? 'Show only ${controller.currentUserCity}'
                          : 'Show only my city',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Switch(
                    value: controller.showOnlyCityDonations,
                    onChanged: (value) => controller.toggleCityFilter(),
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          _donationController.updateBloodFilter(selected ? label : 'All');
        },
        selectedColor: AppColors.primary,
        backgroundColor: Colors.white,
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppColors.textPrimary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          fontSize: 13,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        showCheckmark: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? AppColors.primary : AppColors.tertiary,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSheet() {
    if (_selectedDonation == null) return const SizedBox.shrink();

    final postData = _selectedDonation!['postData'] as Map<String, dynamic>;
    final userData = _selectedDonation!['userData'] as Map<String, dynamic>;
    final postId = _selectedDonation!['postId'] as String;
    final ownerId = _selectedDonation!['ownerId'] as String;

    final donationTime = (postData['donation_time'] as Timestamp).toDate();
    final bloodGroup = postData['blood_group'] as String;
    final location = postData['location'] as String;
    final description = postData['description'] as String?;
    final username = userData['username'] ?? 'Anonymous Donor';
    final profileImageUrl = userData['profileImageUrl'] as String?;
    final latitude = postData['latitude'] as double?;
    final longitude = postData['longitude'] as double?;

    double? distance;
    if (_currentPosition != null && latitude != null && longitude != null) {
      distance = _calculateDistance(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        latitude,
        longitude,
      );
    }

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedContainer(
        duration: _animationDuration,
        curve: _animationCurve,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textGrey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with user info
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        backgroundImage: profileImageUrl != null
                            ? NetworkImage(profileImageUrl)
                            : null,
                        child: profileImageUrl == null
                            ? const Icon(Icons.person,
                                color: AppColors.primary, size: 24)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              username,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              _donationController.getRelativeTime(donationTime),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Blood group badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          bloodGroup,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Location and distance
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                location,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (distance != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.directions_car,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${distance.toStringAsFixed(1)} km away',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Time
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _donationController.formatDonationTime(donationTime),
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMedium,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.message, size: 18),
                          label: const Text('Contact'),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: AppColors.surface,
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () async {
                            final phoneRaw = userData['phone'] ?? '';
                            final success =
                                await _donationController.contactViaWhatsApp(
                              phoneRaw,
                              location,
                              donationTime,
                            );

                            if (!success && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Could not open WhatsApp'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.directions, size: 18),
                          label: const Text('Navigate'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            side: const BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                          onPressed: () async {
                            if (latitude != null && longitude != null) {
                              final success =
                                  await _donationController.openMapDirections(
                                location,
                                lat: latitude,
                                lng: longitude,
                              );

                              if (!success && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Could not open Google Maps'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // View full details button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        _dialogController.showPostDetailsDialog(
                          context,
                          postData,
                          userData,
                          postId,
                          ownerId,
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                      child: const Text('View Full Details'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingButtons() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // My location button
        FloatingActionButton.small(
          heroTag: 'my_location',
          backgroundColor: Colors.white,
          onPressed: () async {
            if (_currentPosition != null) {
              _mapController.move(
                LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                15,
              );
            } else {
              await _checkLocationAndLoad();
            }
          },
          child: const Icon(Icons.my_location, color: AppColors.primary),
        ),
        const SizedBox(height: 8),
        // Create request button
        FloatingActionButton.extended(
          heroTag: 'create_request',
          onPressed: () => _dialogController.showCreatePostDialog(context),
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add, color: AppColors.surface),
          label: const Text(
            'Create Request',
            style: TextStyle(
              color: AppColors.surface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
