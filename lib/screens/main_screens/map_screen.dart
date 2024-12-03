import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:lifeline/components/bottom_navbar.dart';
import 'package:lifeline/services/location_handler.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  String? _currentAddress;
  int _selectedIndex = 2;

  @override
  void initState() {
    super.initState();
    _checkLocationServiceAndLoadLocation();
  }

  Future<void> _checkLocationServiceAndLoadLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationServiceDialog();
      return;
    }
    _loadCurrentLocation();
  }

  Future<void> _showLocationServiceDialog() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Service Disabled'),
          content: const Text('Your location services are turned off. Please enable them to use the map.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await Geolocator.openLocationSettings();
              },
              child: const Text('Enable'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadCurrentLocation() async {
    Position? position = await LocationHandler.getCurrentPosition();
    if (position != null) {
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
      String? address = await LocationHandler.getAddressFromLatLng(position);
      if (address != null) {
        setState(() {
          _currentAddress = address;
        });
      }
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        15.0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1.0,
          title: Text(
            _currentAddress ?? "Loading location...",
            style: const TextStyle(
              color: Colors.black,
              fontSize: 18.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.black,
            ),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.refresh,
                color: Colors.black,
              ),
              onPressed: _checkLocationServiceAndLoadLocation,
            ),
          ],
        ),
        body: _currentPosition == null
            ? const Center(child: CircularProgressIndicator())
            : FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _currentPosition ?? const LatLng(0.0, 0.0),
                  initialZoom: 15.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _currentPosition ?? const LatLng(0.0, 0.0),
                        width: 50.0,
                        height: 50.0,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 40.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: _checkLocationServiceAndLoadLocation,
          child: const Icon(Icons.my_location),
        ),
        bottomNavigationBar: CustomBottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) {
              setState(() {
                _selectedIndex = index;
              });
            }));
  }
}
