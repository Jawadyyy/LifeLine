import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:lifeline/constants/app_colors.dart';
import 'package:lifeline/services/emergency_service.dart';
import 'package:lifeline/services/location_handler.dart';
import 'package:url_launcher/url_launcher.dart';

/// Typed contract the map screen exposes to its controller, replacing the old
/// `(state as dynamic).getField/setField` string reflection.
abstract class MapScreenView {
  BuildContext get context;
  bool get mounted;

  bool get isMapReady;
  MapController get mapController;
  LatLng? get currentPosition;
  EmergencyType get emergencyType;

  set isLoading(bool value);
  set showRoute(bool value);
  set selectedLocation(Map<String, dynamic>? value);
  set routePoints(List<LatLng> value);
  set currentPosition(LatLng? value);
  set currentAddress(String? value);
  set emergencyLocations(List<Map<String, dynamic>> value);
  set isOnline(bool value);
  set emergencyType(EmergencyType value);
}

class MapScreenController {
  final MapScreenView view;
  final void Function(void Function()) setStateFn;

  MapScreenController(this.view, this.setStateFn);

  BuildContext get context => view.context;
  bool get mounted => view.mounted;

  Future<void> checkLocationServiceAndLoadLocation() async {
    if (!mounted) return;
    setStateFn(() {
      view.isLoading = true;
      view.showRoute = false;
      view.selectedLocation = null;
      view.routePoints = <LatLng>[];
    });

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      setStateFn(() => view.isLoading = false);
      await _showLocationServiceDialog();
      return;
    }

    await _loadCurrentLocation();

    if (!mounted) return;
    setStateFn(() => view.isLoading = false);
  }

  Future<void> _showLocationServiceDialog() async {
    final theme = Theme.of(context);
    const Color mainColor = AppColors.primary;

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
              Icon(Icons.location_on, color: mainColor),
              const SizedBox(width: 10),
              Text(
                'Location Required',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: mainColor,
                ),
              ),
            ],
          ),
          content: Text(
            'To provide accurate directions, we need access to your location. Please enable location services in your device settings.',
            style: theme.textTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Not Now',
                  style: TextStyle(color: theme.colorScheme.onSurface)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: mainColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await Geolocator.openLocationSettings();
                await checkLocationServiceAndLoadLocation();
              },
              child: const Text('Enable'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadCurrentLocation() async {
    try {
      final position = await LocationHandler.getCurrentPosition();
      if (!mounted) return;

      if (position != null) {
        setStateFn(() {
          view.currentPosition =
              LatLng(position.latitude, position.longitude);
        });

        final address = await LocationHandler.getAddressFromLatLng(position);
        if (!mounted) return;
        if (address != null) {
          setStateFn(() => view.currentAddress = address);
        }

        final current = view.currentPosition;
        if (view.isMapReady && current != null) {
          view.mapController.move(current, 15.0);
        }

        // Load emergency locations based on selected type
        await loadEmergencyLocations();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading location: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> loadEmergencyLocations() async {
    final currentPosition = view.currentPosition;
    if (currentPosition == null) return;

    final emergencyType = view.emergencyType;
    final isOnline = await EmergencyService.isOnline();

    if (!mounted) return;

    try {
      final locations = await EmergencyService.getNearbyEmergencyLocations(
        currentPosition,
        emergencyType,
      );

      if (!mounted) return;

      setStateFn(() {
        view.emergencyLocations = locations;
        view.isOnline = isOnline;
      });

      // Show offline indicator if using cached data
      if (!isOnline && locations.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.offline_bolt, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Offline mode: Showing cached locations'),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No cached data available. Connect to internet.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> switchEmergencyType(EmergencyType newType) async {
    if (!mounted) return;

    setStateFn(() {
      view.emergencyType = newType;
      view.isLoading = true;
      view.showRoute = false;
      view.selectedLocation = null;
      view.routePoints = <LatLng>[];
    });

    await loadEmergencyLocations();

    if (!mounted) return;
    setStateFn(() => view.isLoading = false);
  }

  Future<void> launchMapsApp(LatLng destination) async {
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=${destination.latitude},${destination.longitude}';
    final uri = Uri.parse(url);
    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        throw Exception('Could not launch Google Maps.');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open Maps: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
}
