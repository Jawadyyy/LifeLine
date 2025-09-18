import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:lifeline/services/hospital_service.dart';
import 'package:lifeline/services/location_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class MapScreenController {
  final State state;
  final void Function(void Function()) setStateFn;

  MapScreenController(this.state, this.setStateFn);

  BuildContext get context => state.context;
  bool get mounted => state.mounted;

  T _getField<T>(String name) => (state as dynamic).getField(name) as T;
  void _setField(String name, dynamic value) =>
      (state as dynamic).setField(name, value);

  Future<void> checkLocationServiceAndLoadLocation() async {
    if (!mounted) return;
    setStateFn(() {
      _setField('_isLoading', true);
      _setField('_showRoute', false);
      _setField('_selectedHospital', null);
      _setField('_routePoints', <LatLng>[]);
    });

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      setStateFn(() => _setField('_isLoading', false));
      await _showLocationServiceDialog();
      return;
    }

    await _loadCurrentLocation();

    if (!mounted) return;
    setStateFn(() => _setField('_isLoading', false));
  }

  Future<void> _showLocationServiceDialog() async {
    final theme = Theme.of(context);
    final Color mainColor = Color(0xFFFF6F61);

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
          _setField('_currentPosition',
              LatLng(position.latitude, position.longitude));
        });

        final address = await LocationHandler.getAddressFromLatLng(position);
        if (!mounted) return;
        if (address != null) {
          setStateFn(() => _setField('_currentAddress', address));
        }

        final isMapReady = _getField<bool>('_isMapReady');
        final current = _getField<LatLng?>('_currentPosition');
        if (isMapReady && current != null) {
          final mapController = _getField<dynamic>('_mapController');
          mapController.move(current, 15.0);
        }

        final hospitals = await HospitalService.getNearbyHospitals(
            _getField<LatLng>('_currentPosition'));
        if (!mounted) return;
        setStateFn(() => _setField('_hospitals', hospitals));
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
