import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lifeline/constants/app_design.dart';
import 'package:lifeline/services/emergency_service.dart';
import 'package:lifeline/views/main/map/controller/map_screen_controller.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> implements MapScreenView {
  // Process-level cache so the resolved map (position, address, nearby places,
  // selected type) survives this tab being disposed/re-mounted on navigation —
  // avoids the "Finding your location…" spinner on every return visit.
  static LatLng? _cachedPosition;
  static String? _cachedAddress;
  static List<Map<String, dynamic>> _cachedLocations = [];
  static EmergencyType _cachedType = EmergencyType.hospital;

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
    if (_cachedPosition != null) {
      // Re-mount: paint the cached map instantly, no spinner.
      _currentPosition = _cachedPosition;
      _currentAddress = _cachedAddress;
      _emergencyLocations = _cachedLocations;
      _emergencyType = _cachedType;
      _isLoading = false;
    } else {
      screenController.checkLocationServiceAndLoadLocation();
    }
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
  set currentPosition(LatLng? value) {
    _currentPosition = value;
    _cachedPosition = value;
  }

  @override
  set currentAddress(String? value) {
    _currentAddress = value;
    _cachedAddress = value;
  }

  @override
  set emergencyLocations(List<Map<String, dynamic>> value) {
    _emergencyLocations = value;
    _cachedLocations = value;
  }

  @override
  set isOnline(bool value) => _isOnline = value;
  @override
  set emergencyType(EmergencyType value) {
    _emergencyType = value;
    _cachedType = value;
  }

  Color _getEmergencyColor() {
    return _emergencyType == EmergencyType.hospital
        ? LL.orange // Orange for hospitals
        : const Color(0xFF2563EB); // Blue for police
  }

  /// Gradient that matches the active emergency type — deep orange for
  /// hospitals, deep blue for police. Used on the active toggle segment, the
  /// locate button and the nearby-card action button so the whole map's chrome
  /// stays one colour family.
  LinearGradient get _accentGrad => _emergencyType == EmergencyType.hospital
      ? LL.sosGrad
      : const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4F9BFF), Color(0xFF1D4ED8)],
        );

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
      body: _isLoading || _currentPosition == null
          ? Stack(
              children: [
                Center(
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
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: _glass(
                          child: const SizedBox(
                            width: 46,
                            height: 46,
                            child: Icon(Icons.arrow_back_ios_new_rounded,
                                color: LL.ink, size: 20),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
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
                // Glass top bar + segmented toggle
                _buildTopOverlay(),
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
                      height: 88,
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
                              width: 280,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: LL.card,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: LL.border),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF141828)
                                        .withOpacity(0.10),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: mainColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(_getEmergencyIcon(),
                                        color: mainColor, size: 22),
                                  ),
                                  const SizedBox(width: 13),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          location['name'],
                                          style: LL.body(15.5,
                                              weight: FontWeight.w700),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            Text('Open',
                                                style: LL.body(12.5,
                                                    weight: FontWeight.w700,
                                                    color: LL.green)),
                                            Text('  ·  ',
                                                style: LL.body(12.5,
                                                    color: const Color(
                                                        0xFFC7CAD2))),
                                            Text(
                                                "${distanceInKm.toStringAsFixed(1)} km",
                                                style: LL.body(12.5,
                                                    weight: FontWeight.w600,
                                                    color: LL.muted)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      gradient: _accentGrad,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: mainColor.withOpacity(0.3),
                                          blurRadius: 14,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(Icons.navigation_rounded,
                                        color: Colors.white, size: 20),
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
                backgroundColor: Colors.transparent,
                elevation: 0,
                highlightElevation: 0,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: _accentGrad,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: mainColor.withOpacity(0.36),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.my_location, color: Colors.white),
                ),
              ),
            ),
    );
  }

  // ── Glass top bar (back + location pill) + segmented toggle ────────────────
  void _handleBack() {
    if (_showRoute) {
      setState(() {
        _showRoute = false;
        _selectedLocation = null;
        _routePoints = [];
      });
      if (_currentPosition != null) {
        _mapController.move(_currentPosition!, 15.0);
      }
    } else {
      Navigator.pop(context);
    }
  }

  Widget _glass({required Widget child, double radius = 16}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.78),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withOpacity(0.7)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF141828).withOpacity(0.14),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildTopOverlay() {
    final pillText = _selectedLocation != null
        ? 'Route to ${_selectedLocation!['name']}'
        : (_currentAddress ?? 'Locating…');
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: _handleBack,
                    child: _glass(
                      child: const SizedBox(
                        width: 46,
                        height: 46,
                        child: Icon(Icons.arrow_back_ios_new_rounded,
                            color: LL.ink, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _glass(
                      child: Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on,
                                color: LL.orange, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                pillText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: LL.body(14, weight: FontWeight.w600),
                              ),
                            ),
                            if (!_isOnline) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('Offline',
                                    style: LL.body(10,
                                        weight: FontWeight.w700,
                                        color: Colors.white)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (!_showRoute) ...[
                const SizedBox(height: 12),
                _glass(
                  radius: 25,
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: Row(
                      children: [
                        _segment(
                          type: EmergencyType.hospital,
                          icon: Icons.local_hospital,
                          label: 'Hospitals',
                        ),
                        const SizedBox(width: 4),
                        _segment(
                          type: EmergencyType.police,
                          icon: Icons.local_police,
                          label: 'Police',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _segment({
    required EmergencyType type,
    required IconData icon,
    required String label,
  }) {
    final selected = _emergencyType == type;
    final activeColor =
        type == EmergencyType.hospital ? LL.orange : const Color(0xFF2563EB);
    final count = _emergencyLocations.length;
    return Expanded(
      child: GestureDetector(
        onTap: () => screenController.switchEmergencyType(type),
        child: AnimatedContainer(
          duration: _animationDuration,
          curve: _animationCurve,
          height: 40,
          decoration: BoxDecoration(
            gradient: selected ? _accentGrad : null,
            borderRadius: BorderRadius.circular(21),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: activeColor.withOpacity(0.36),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  color: selected ? Colors.white : const Color(0xFF7A7E88),
                  size: 17),
              const SizedBox(width: 8),
              Text(label,
                  style: LL.body(14,
                      weight: FontWeight.w700,
                      color: selected ? Colors.white : const Color(0xFF7A7E88))),
              if (selected && count > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.26),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$count',
                      style: LL.body(11,
                          weight: FontWeight.w800, color: Colors.white)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
