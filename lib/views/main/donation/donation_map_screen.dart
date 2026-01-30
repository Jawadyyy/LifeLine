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
  State<DonationMapScreen> createState() => _DonationMapScreenState();
}

class _DonationMapScreenState extends State<DonationMapScreen>
    with TickerProviderStateMixin {
  late DonationController _donationController;
  late DonationDialogController _dialogController;
  late MapController _mapController;

  Position? _currentPosition;
  bool _isLoadingLocation = false;
  bool _isMapReady = false;
  String? _currentAddress;
  Map<String, dynamic>? _selectedDonation;

  // Animation controllers
  late AnimationController _fabAnimationController;
  late AnimationController _cardAnimationController;
  late AnimationController _pulseAnimationController;
  late Animation<double> _fabAnimation;
  late Animation<Offset> _cardSlideAnimation;
  late Animation<double> _cardFadeAnimation;
  late Animation<double> _pulseAnimation;

  // Optimized constants
  static const Duration _animationDuration = Duration(milliseconds: 350);
  static const Duration _fastAnimationDuration = Duration(milliseconds: 200);
  static const Curve _animationCurve = Curves.easeOutCubic;
  static const Distance _distance = Distance();
  static const LatLng _defaultPosition = LatLng(33.6844, 73.0479);
  static const double _mapZoom = 14.0;
  static const double _selectedMarkerZoom = 15.0;

  // Performance optimization: Cache
  final Map<String, Color> _bloodGroupColorCache = {};

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeAnimations();
    _checkLocationAndLoad();
  }

  void _initializeControllers() {
    _mapController = MapController();
    _donationController = DonationController();
    _dialogController = DonationDialogController(_donationController);
    _donationController.init();
  }

  void _initializeAnimations() {
    // FAB animation
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: _animationDuration,
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.elasticOut,
    );

    // Card animation
    _cardAnimationController = AnimationController(
      vsync: this,
      duration: _animationDuration,
    );
    _cardSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _cardAnimationController,
      curve: _animationCurve,
    ));
    _cardFadeAnimation = CurvedAnimation(
      parent: _cardAnimationController,
      curve: _animationCurve,
    );

    // Pulse animation for current location marker
    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _pulseAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _fabAnimationController.forward();
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _cardAnimationController.dispose();
    _pulseAnimationController.dispose();
    _donationController.dispose();
    super.dispose();
  }

  Future<void> _checkLocationAndLoad() async {
    if (!mounted) return;

    setState(() => _isLoadingLocation = true);

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
    return showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (BuildContext dialogContext) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: _fastAnimationDuration,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Opacity(
                opacity: value,
                child: AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  backgroundColor: Colors.white,
                  elevation: 8,
                  titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.location_on,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Location Required',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  content: const Text(
                    'To show nearby donations and create requests, we need access to your location. Please enable location services.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('Not Now'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.of(dialogContext).pop();
                        await Geolocator.openLocationSettings();
                        await _checkLocationAndLoad();
                      },
                      child: const Text(
                        'Enable',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;

      setState(() => _currentPosition = position);
      _donationController.currentUserPosition = position;

      // Get address in background
      _getAddressFromCoordinates(position);

      // Animate camera to current location
      if (_isMapReady && mounted) {
        _mapController.move(
          LatLng(position.latitude, position.longitude),
          _mapZoom,
        );
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (mounted) {
        _showSnackBar(
          'Could not get your location',
          isError: true,
        );
      }
    }
  }

  Future<void> _getAddressFromCoordinates(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty && mounted) {
        final place = placemarks.first;
        String address = '';

        if (place.locality?.isNotEmpty ?? false) {
          address = place.locality!;
        }
        if (place.subLocality?.isNotEmpty ?? false) {
          address += address.isNotEmpty
              ? ', ${place.subLocality}'
              : place.subLocality!;
        }

        setState(() => _currentAddress = address);
      }
    } catch (e) {
      debugPrint('Error getting address: $e');
    }
  }

  Color _getBloodGroupColor(String bloodGroup) {
    // Use cache to avoid repeated color calculations
    return _bloodGroupColorCache.putIfAbsent(bloodGroup, () {
      switch (bloodGroup) {
        case 'O+':
        case 'O-':
          return const Color(0xFFE53935); // Material Red 600
        case 'A+':
        case 'A-':
          return const Color(0xFFFB8C00); // Material Orange 600
        case 'B+':
        case 'B-':
          return const Color(0xFFFDD835); // Material Yellow 600
        case 'AB+':
        case 'AB-':
          return const Color(0xFF43A047); // Material Green 600
        default:
          return AppColors.primary;
      }
    });
  }

  void _onMarkerTapped(Map<String, dynamic> donation) {
    if (_selectedDonation == donation) return; // Prevent redundant animations

    setState(() => _selectedDonation = donation);
    _cardAnimationController.forward(from: 0);

    final postData = donation['postData'] as Map<String, dynamic>;
    final latitude = postData['latitude'] as double;
    final longitude = postData['longitude'] as double;

    _mapController.move(
      LatLng(latitude, longitude),
      _selectedMarkerZoom,
    );
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    return _distance.as(
      LengthUnit.Kilometer,
      LatLng(lat1, lon1),
      LatLng(lat2, lon2),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade400 : AppColors.success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 3),
      ),
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
        duration: _fastAnimationDuration,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.5),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: Container(
          key: ValueKey<String>(
              _selectedDonation != null ? 'selected' : 'location'),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            _selectedDonation != null
                ? 'Donation Request'
                : _currentAddress ?? "Finding location...",
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      leading: _buildAppBarButton(
        icon: _selectedDonation != null ? Icons.close : Icons.arrow_back,
        onPressed: () {
          if (_selectedDonation != null) {
            setState(() => _selectedDonation = null);
            _cardAnimationController.reverse();
          } else {
            Navigator.pop(context);
          }
        },
      ),
      actions: [
        _buildAppBarButton(
          icon: Icons.refresh,
          onPressed: _isLoadingLocation ? null : _checkLocationAndLoad,
        ),
      ],
    );
  }

  Widget _buildAppBarButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: AppColors.textPrimary, size: 22),
        onPressed: onPressed,
        splashRadius: 20,
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoadingLocation && _currentPosition == null) {
      return _buildLoadingState();
    }

    return Consumer<DonationController>(
      builder: (context, controller, _) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: controller.getFilteredDonationPostsStream(),
          builder: (context, snapshot) {
            final donations = snapshot.data ?? [];

            return Stack(
              children: [
                _buildMap(donations),
                _buildFilterPanel(controller),
                if (donations.isNotEmpty && _selectedDonation == null)
                  _buildNearestDonationsTiles(donations),
                if (_selectedDonation != null) _buildSelectedDonationCard(),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 600),
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 3,
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: const Text(
                  "Finding your location...",
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMap(List<Map<String, dynamic>> donations) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentPosition != null
            ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
            : _defaultPosition,
        initialZoom: _mapZoom,
        minZoom: 5,
        maxZoom: 18,
        interactionOptions: const InteractionOptions(
          flags: ~InteractiveFlag.rotate,
        ),
        onMapReady: () {
          setState(() => _isMapReady = true);
          if (_currentPosition != null) {
            _mapController.move(
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
              _mapZoom,
            );
          }
        },
        onTap: (_, __) {
          if (mounted && _selectedDonation != null) {
            setState(() => _selectedDonation = null);
            _cardAnimationController.reverse();
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
            if (_currentPosition != null) _buildCurrentLocationMarker(),
            ...donations.map((donation) => _buildDonationMarker(donation)),
          ],
        ),
      ],
    );
  }

  Marker _buildCurrentLocationMarker() {
    return Marker(
      point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      width: 60,
      height: 60,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Pulse effect
              Container(
                width: 50 * _pulseAnimation.value,
                height: 50 * _pulseAnimation.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(
                    0.3 * (1 - (_pulseAnimation.value - 1) / 0.3),
                  ),
                ),
              ),
              // Main marker
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary,
                    width: 3.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.person_pin_circle,
                  color: AppColors.primary,
                  size: 32,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Marker _buildDonationMarker(Map<String, dynamic> donation) {
    final postData = donation['postData'] as Map<String, dynamic>;
    final latitude = postData['latitude'] as double?;
    final longitude = postData['longitude'] as double?;

    if (latitude == null || longitude == null) {
      return Marker(
        point: _defaultPosition,
        width: 0,
        height: 0,
        child: const SizedBox.shrink(),
      );
    }

    final bloodGroup = postData['blood_group'] as String;
    final isSelected = _selectedDonation == donation;
    final color = _getBloodGroupColor(bloodGroup);

    return Marker(
      point: LatLng(latitude, longitude),
      width: isSelected ? 60 : 50,
      height: isSelected ? 60 : 50,
      child: GestureDetector(
        onTap: () => _onMarkerTapped(donation),
        child: AnimatedContainer(
          duration: _fastAnimationDuration,
          curve: _animationCurve,
          decoration: BoxDecoration(
            color: isSelected ? color : color.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: color,
              width: isSelected ? 3.5 : 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(isSelected ? 0.4 : 0.2),
                blurRadius: isSelected ? 14 : 8,
                spreadRadius: isSelected ? 3 : 1,
              ),
            ],
          ),
          child: Center(
            child: Text(
              bloodGroup,
              style: TextStyle(
                color: isSelected ? Colors.white : color,
                fontWeight: FontWeight.bold,
                fontSize: isSelected ? 14 : 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterPanel(DonationController controller) {
    return Positioned(
      top: 100,
      left: 12,
      right: 12,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, -20 * (1 - value)),
            child: Opacity(
              opacity: value,
              child: child,
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: AnimatedContainer(
        duration: _fastAnimationDuration,
        child: FilterChip(
          label: Text(label),
          selected: isSelected,
          onSelected: (selected) {
            _donationController.updateBloodFilter(selected ? label : 'All');
          },
          selectedColor: AppColors.primary,
          backgroundColor: AppColors.background,
          checkmarkColor: Colors.white,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          showCheckmark: false,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: isSelected ? AppColors.primary : AppColors.tertiary,
              width: isSelected ? 2 : 1.5,
            ),
          ),
          elevation: isSelected ? 2 : 0,
          pressElevation: 4,
        ),
      ),
    );
  }

  Widget _buildNearestDonationsTiles(List<Map<String, dynamic>> donations) {
    return Positioned(
      bottom: 16,
      left: 0,
      right: 0,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, 50 * (1 - value)),
            child: Opacity(
              opacity: value,
              child: child,
            ),
          );
        },
        child: SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: donations.length > 10 ? 10 : donations.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return _buildDonationTile(donations[index], index);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDonationTile(Map<String, dynamic> donation, int index) {
    final postData = donation['postData'] as Map<String, dynamic>;
    final userData = donation['userData'] as Map<String, dynamic>;
    final bloodGroup = postData['blood_group'] as String;
    final location = postData['location'] as String;
    final username = userData['username'] ?? 'Anonymous';
    final distance = donation['distance'] as double?;
    final donationTime = (postData['donation_time'] as Timestamp).toDate();
    final color = _getBloodGroupColor(bloodGroup);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 50)),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: GestureDetector(
        onTap: () => _onMarkerTapped(donation),
        child: Container(
          width: 250,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, color.withOpacity(0.8)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      bloodGroup,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      username,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    color: AppColors.primary,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      location,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  if (distance != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.directions_car,
                            color: AppColors.textGrey,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "${distance.toStringAsFixed(1)} km",
                            style: const TextStyle(
                              color: AppColors.textMedium,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _donationController.getRelativeTime(donationTime),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
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

  Widget _buildSelectedDonationCard() {
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
    final isOwnPost = _donationController.isPostOwner(ownerId);

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
      child: SlideTransition(
        position: _cardSlideAnimation,
        child: FadeTransition(
          opacity: _cardFadeAnimation,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textGrey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCardHeader(
                        username,
                        profileImageUrl,
                        donationTime,
                        bloodGroup,
                        isOwnPost,
                      ),
                      const SizedBox(height: 16),
                      _buildCardLocation(location, distance, isOwnPost),
                      const SizedBox(height: 12),
                      _buildCardTime(donationTime),
                      if (description?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 12),
                        _buildCardDescription(description!),
                      ],
                      const SizedBox(height: 20),
                      _buildCardActions(
                        isOwnPost,
                        postData,
                        ownerId,
                        postId,
                        userData,
                        location,
                        donationTime,
                        latitude,
                        longitude,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardHeader(
    String username,
    String? profileImageUrl,
    DateTime donationTime,
    String bloodGroup,
    bool isOwnPost,
  ) {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            backgroundImage:
                profileImageUrl != null ? NetworkImage(profileImageUrl) : null,
            child: profileImageUrl == null
                ? const Icon(Icons.person, color: AppColors.primary, size: 28)
                : null,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      username,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isOwnPost) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'You',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                _donationController.getRelativeTime(donationTime),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _getBloodGroupColor(bloodGroup),
                _getBloodGroupColor(bloodGroup).withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _getBloodGroupColor(bloodGroup).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            bloodGroup,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCardLocation(String location, double? distance, bool isOwnPost) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.tertiary.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.location_on,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  location,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (distance != null && !isOwnPost) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.directions_car,
                    color: AppColors.textSecondary,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${distance.toStringAsFixed(1)} km away',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCardTime(DateTime donationTime) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.tertiary.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.access_time,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _donationController.formatDonationTime(donationTime),
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardDescription(String description) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.tertiary.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Text(
        description,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.textMedium,
          height: 1.5,
        ),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildCardActions(
    bool isOwnPost,
    Map<String, dynamic> postData,
    String ownerId,
    String postId,
    Map<String, dynamic> userData,
    String location,
    DateTime donationTime,
    double? latitude,
    double? longitude,
  ) {
    if (isOwnPost) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.edit, size: 20),
              label: const Text('Edit'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: const BorderSide(color: AppColors.primary, width: 2),
              ),
              onPressed: () {
                setState(() => _selectedDonation = null);
                _cardAnimationController.reverse();
                _dialogController.showEditPostDialog(
                  context,
                  postData,
                  ownerId,
                  postId,
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.delete, size: 20),
              label: const Text('Delete'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                final success = await _dialogController
                    .showDeleteConfirmationDialog(context, ownerId, postId);

                if (success && mounted) {
                  setState(() => _selectedDonation = null);
                  _cardAnimationController.reverse();
                  _showSnackBar('Donation request deleted');
                }
              },
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.message, size: 20),
                label: const Text('Contact'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  final phoneRaw = userData['phone'] ?? '';
                  final success = await _donationController.contactViaWhatsApp(
                    phoneRaw,
                    location,
                    donationTime,
                  );

                  if (!success && mounted) {
                    _showSnackBar('Could not open WhatsApp', isError: true);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.directions, size: 20),
                label: const Text('Navigate'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: AppColors.primary, width: 2),
                ),
                onPressed: () async {
                  if (latitude != null && longitude != null) {
                    final success = await _donationController.openMapDirections(
                      location,
                      lat: latitude,
                      lng: longitude,
                    );

                    if (!success && mounted) {
                      _showSnackBar('Could not open Google Maps',
                          isError: true);
                    }
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
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
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text(
              'View Full Details',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingButtons() {
    return ScaleTransition(
      scale: _fabAnimation,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'my_location',
            backgroundColor: Colors.white,
            elevation: 4,
            onPressed: () async {
              if (_currentPosition != null) {
                _mapController.move(
                  LatLng(
                      _currentPosition!.latitude, _currentPosition!.longitude),
                  _selectedMarkerZoom,
                );
              } else {
                await _checkLocationAndLoad();
              }
            },
            child: const Icon(Icons.my_location,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'create_request',
            onPressed: () => _dialogController.showCreatePostDialog(context),
            backgroundColor: AppColors.primary,
            elevation: 6,
            icon: const Icon(Icons.add, color: Colors.white, size: 24),
            label: const Text(
              'Create Request',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
