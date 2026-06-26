import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lifeline/services/emergency_service.dart';
import 'package:lifeline/views/main/map/controller/map_screen_controller.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> implements MapScreenView {
  late final MapController _mapController;
  LatLng? _currentPosition;
  String? _currentAddress;
  bool _isLoading = true;
  bool _isMapReady = false;
  bool _showRoute = false;
  bool _isOnline = true;
  Map<String, dynamic>? _selectedLocation;
  List<LatLng> _routePoints = [];
  final Duration _animationDuration = const Duration(milliseconds: 300);
  final Curve _animationCurve = Curves.easeInOut;

  List<Map<String, dynamic>> _emergencyLocations = [];
  EmergencyType _emergencyType = EmergencyType.hospital;
  final Distance _distance = const Distance();
  late MapScreenController screenController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    screenController = MapScreenController(this, setState);
    screenController.checkLocationServiceAndLoadLocation();
  }

  // ─── MapScreenView (typed contract for the controller) ──────────────────────
  @override
  MapController get mapController => _mapController;
  @override
  bool get isMapReady => _isMapReady;
  @override
  LatLng? get currentPosition => _currentPosition;
  @override
  EmergencyType get emergencyType => _emergencyType;

  @override
  set isLoading(bool value) => _isLoading = value;
  @override
  set showRoute(bool value) => _showRoute = value;
  @override
  set selectedLocation(Map<String, dynamic>? value) => _selectedLocation = value;
  @override
  set routePoints(List<LatLng> value) => _routePoints = value;
  @override
  set currentPosition(LatLng? value) => _currentPosition = value;
  @override
  set currentAddress(String? value) => _currentAddress = value;
  @override
  set emergencyLocations(List<Map<String, dynamic>> value) =>
      _emergencyLocations = value;
  @override
  set isOnline(bool value) => _isOnline = value;
  @override
  set emergencyType(EmergencyType value) => _emergencyType = value;

  Color _getEmergencyColor() {
    return _emergencyType == EmergencyType.hospital
        ? Color(0xFFFF6F61) // Red for hospitals
        : Color(0xFF4A90E2); // Blue for police
  }

  IconData _getEmergencyIcon() {
    return _emergencyType == EmergencyType.hospital
        ? Icons.local_hospital
        : Icons.local_police;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final Color mainColor = _getEmergencyColor();

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Column(
          children: [
            AnimatedSwitcher(
              duration: _animationDuration,
              child: _selectedLocation != null
                  ? Text(
                      'Route to ${_selectedLocation!['name']}',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                        shadows: [
                          Shadow(
                            color: colorScheme.surface.withOpacity(0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : Text(
                      _currentAddress ?? "Locating...",
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                        shadows: [
                          Shadow(
                            color: colorScheme.surface.withOpacity(0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
            if (!_isOnline)
              Container(
                margin: EdgeInsets.only(top: 2),
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.offline_bolt, size: 12, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'Offline',
                      style: textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        leading: Container(
          margin: const EdgeInsets.only(left: 8),
          decoration: BoxDecoration(
            color: colorScheme.surface.withOpacity(0.8),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: colorScheme.onSurface,
            ),
            onPressed: () {
              if (_showRoute) {
                setState(() {
                  _showRoute = false;
                  _selectedLocation = null;
                  _routePoints = [];
                });
                _mapController.move(_currentPosition!, 15.0);
              } else {
                Navigator.pop(context);
              }
            },
          ),
        ),
        actions: [
          if (!_showRoute)
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: colorScheme.surface.withOpacity(0.8),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.refresh, color: colorScheme.onSurface),
                onPressed: () =>
                    screenController.checkLocationServiceAndLoadLocation(),
              ),
            ),
        ],
      ),
      body: _isLoading || _currentPosition == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: mainColor,
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _isLoading
                        ? "Finding your location..."
                        : "Location unavailable",
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentPosition!,
                    initialZoom: 15.0,
                    interactionOptions: const InteractionOptions(
                      flags: ~InteractiveFlag.rotate,
                    ),
                    onMapReady: () {
                      setState(() => _isMapReady = true);
                      _mapController.move(_currentPosition!, 15.0);
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
                    if (_showRoute && _routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routePoints,
                            color: mainColor.withOpacity(0.8),
                            strokeWidth: 6,
                            borderColor: Colors.white.withOpacity(0.8),
                            borderStrokeWidth: 2,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _currentPosition!,
                          width: 50,
                          height: 50,
                          child: AnimatedContainer(
                            duration: _animationDuration,
                            curve: _animationCurve,
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 255, 255, 255),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: mainColor,
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
                              color: mainColor,
                              size: 30,
                            ),
                          ),
                        ),
                        ..._emergencyLocations.map((location) => Marker(
                              point: LatLng(location['lat'], location['lon']),
                              width: 40,
                              height: 40,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedLocation = location;
                                    _showRoute = true;
                                    _routePoints = [];
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: _animationDuration,
                                  curve: _animationCurve,
                                  decoration: BoxDecoration(
                                    color: _selectedLocation == location
                                        ? colorScheme.secondaryContainer
                                        : mainColor.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: mainColor,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    _getEmergencyIcon(),
                                    color: mainColor,
                                    size: 20,
                                  ),
                                ),
                              ),
                            )),
                      ],
                    ),
                    if (_selectedLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(
                              _selectedLocation!['lat'],
                              _selectedLocation!['lon'],
                            ),
                            width: 50,
                            height: 50,
                            child: AnimatedContainer(
                              duration: _animationDuration,
                              curve: _animationCurve,
                              decoration: BoxDecoration(
                                color: mainColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
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
                                _getEmergencyIcon(),
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                // Emergency type toggle
                if (!_showRoute)
                  Positioned(
                    top: 100,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => screenController
                                  .switchEmergencyType(EmergencyType.hospital),
                              child: AnimatedContainer(
                                duration: _animationDuration,
                                curve: _animationCurve,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color:
                                      _emergencyType == EmergencyType.hospital
                                          ? Color(0xFFFF6F61)
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.local_hospital,
                                      color: _emergencyType ==
                                              EmergencyType.hospital
                                          ? Colors.white
                                          : colorScheme.onSurface
                                              .withOpacity(0.6),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Hospitals',
                                      style: textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: _emergencyType ==
                                                EmergencyType.hospital
                                            ? Colors.white
                                            : colorScheme.onSurface
                                                .withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => screenController
                                  .switchEmergencyType(EmergencyType.police),
                              child: AnimatedContainer(
                                duration: _animationDuration,
                                curve: _animationCurve,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _emergencyType == EmergencyType.police
                                      ? Color(0xFF4A90E2)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.local_police,
                                      color:
                                          _emergencyType == EmergencyType.police
                                              ? Colors.white
                                              : colorScheme.onSurface
                                                  .withOpacity(0.6),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Police',
                                      style: textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: _emergencyType ==
                                                EmergencyType.police
                                            ? Colors.white
                                            : colorScheme.onSurface
                                                .withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  bottom: _showRoute ? 180 : 100,
                  right: 16,
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      if (_showRoute) ...[
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'center',
                          onPressed: () {
                            if (_selectedLocation != null) {
                              final bounds = LatLngBounds.fromPoints([
                                _currentPosition!,
                                LatLng(_selectedLocation!['lat'],
                                    _selectedLocation!['lon']),
                                ..._routePoints
                              ]);
                              _mapController.fitCamera(
                                CameraFit.bounds(
                                  bounds: bounds,
                                  padding: const EdgeInsets.all(100),
                                ),
                              );
                            }
                          },
                          backgroundColor: mainColor,
                          elevation: 2,
                          child: Icon(Icons.center_focus_strong,
                              color: Colors.white),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_emergencyLocations.isNotEmpty && !_showRoute)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: AnimatedContainer(
                      duration: _animationDuration,
                      curve: _animationCurve,
                      height: 120,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _emergencyLocations.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final location = _emergencyLocations[index];
                          final distanceInKm = _distance.as(
                              LengthUnit.Kilometer,
                              _currentPosition!,
                              LatLng(location['lat'], location['lon']));

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedLocation = location;
                                _showRoute = true;
                                _routePoints = [];
                              });
                            },
                            child: Container(
                              width: 220,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: colorScheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    colorScheme.surface,
                                    colorScheme.surface.withOpacity(0.9),
                                  ],
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    location['name'],
                                    style: textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        color: mainColor,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        "${distanceInKm.toStringAsFixed(1)} km",
                                        style: textTheme.bodyMedium?.copyWith(
                                          color: colorScheme.onSurface
                                              .withOpacity(0.8),
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: mainColor.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          "DIRECTIONS",
                                          style: textTheme.labelSmall?.copyWith(
                                            color: mainColor,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(
                                    value:
                                        (1.0 - (distanceInKm.clamp(0, 10) / 10))
                                            .toDouble(),
                                    backgroundColor:
                                        colorScheme.surfaceContainerHighest,
                                    color: mainColor,
                                    minHeight: 4,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                if (_showRoute && _selectedLocation != null)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: AnimatedContainer(
                      duration: _animationDuration,
                      curve: _animationCurve,
                      height: 220,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colorScheme.surface,
                            colorScheme.surface.withOpacity(0.9),
                          ],
                        ),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _getEmergencyIcon(),
                                  color: mainColor,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _selectedLocation!['name'],
                                    style: textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurface,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: mainColor.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.directions_car,
                                    color: mainColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Distance",
                                      style: textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurface
                                            .withOpacity(0.6),
                                      ),
                                    ),
                                    Text(
                                      "${_distance.as(LengthUnit.Kilometer, _currentPosition!, LatLng(_selectedLocation!['lat'], _selectedLocation!['lon'])).toStringAsFixed(1)} km",
                                      style: textTheme.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: mainColor.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.access_time,
                                    color: mainColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Est. Time",
                                      style: textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurface
                                            .withOpacity(0.6),
                                      ),
                                    ),
                                    Text(
                                      "${(_distance.as(LengthUnit.Kilometer, _currentPosition!, LatLng(_selectedLocation!['lat'], _selectedLocation!['lon'])) ~/ 0.5)} min",
                                      style: textTheme.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: mainColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  elevation: 2,
                                ),
                                onPressed: () => screenController.launchMapsApp(
                                  LatLng(_selectedLocation!['lat'],
                                      _selectedLocation!['lon']),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.directions,
                                      size: 24,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Start Navigation',
                                      style: textTheme.bodyLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
      floatingActionButton: _showRoute
          ? null
          : AnimatedOpacity(
              opacity: _isMapReady ? 1.0 : 0.0,
              duration: _animationDuration,
              child: FloatingActionButton(
                onPressed: () =>
                    screenController.checkLocationServiceAndLoadLocation(),
                backgroundColor: mainColor,
                foregroundColor: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.my_location),
              ),
            ),
    );
  }
}
