import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:lifeline/constants/app_colors.dart';

class LocationPickerWidget extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final Function(double latitude, double longitude, String address)
      onLocationSelected;

  const LocationPickerWidget({
    Key? key,
    this.initialLatitude,
    this.initialLongitude,
    required this.onLocationSelected,
  }) : super(key: key);

  @override
  State<LocationPickerWidget> createState() => _LocationPickerWidgetState();
}

class _LocationPickerWidgetState extends State<LocationPickerWidget> {
  late MapController _mapController;
  final TextEditingController _searchController = TextEditingController();
  LatLng? _selectedLocation;
  LatLng? _currentLocation;
  bool _isLoading = true;
  bool _isMoving = false;
  bool _isMapReady = false;
  bool _isSearching = false;
  String _selectedAddress = 'Select a location';
  List<Location> _searchResults = [];
  bool _showSearchResults = false;

  // Default location (Rawalpindi coordinates)
  static const LatLng _defaultLocation = LatLng(33.6844, 73.0479);

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _initializeLocation();

    // Add listener to search controller
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (_searchController.text.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
    } else {
      // Debounce search
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_searchController.text.trim().isNotEmpty) {
          _searchLocation(_searchController.text);
        }
      });
    }
  }

  Future<void> _initializeLocation() async {
    try {
      // Check if initial location is provided
      if (widget.initialLatitude != null && widget.initialLongitude != null) {
        setState(() {
          _selectedLocation = LatLng(
            widget.initialLatitude!,
            widget.initialLongitude!,
          );
          _currentLocation = _selectedLocation;
          _isLoading = false;
        });

        // Wait for map to be ready before moving
        await Future.delayed(const Duration(milliseconds: 300));
        if (_isMapReady && mounted) {
          _mapController.move(_selectedLocation!, 15);
        }
        return;
      }

      // Get current location
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError('Location services are disabled');
        _setDefaultLocation();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('Location permission denied');
          _setDefaultLocation();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showError('Location permission permanently denied');
        _setDefaultLocation();
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _selectedLocation = _currentLocation;
        _isLoading = false;
      });

      // Move camera to current location after map is ready
      await Future.delayed(const Duration(milliseconds: 300));
      if (_isMapReady && mounted) {
        _mapController.move(_currentLocation!, 15);
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      _showError('Could not get your location');
      _setDefaultLocation();
    }
  }

  void _setDefaultLocation() {
    setState(() {
      _selectedLocation = _defaultLocation;
      _currentLocation = _selectedLocation;
      _isLoading = false;
    });
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _onMapEvent(MapEvent event) {
    if (event is MapEventMove || event is MapEventMoveEnd) {
      final center = _mapController.camera.center;
      setState(() {
        _selectedLocation = center;
        _isMoving = event is MapEventMove;
      });
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _showSearchResults = true;
    });

    try {
      final locations = await locationFromAddress(query);

      setState(() {
        _searchResults = locations;
        _isSearching = false;
      });
    } catch (e) {
      debugPrint('Error searching location: $e');
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  Future<void> _selectSearchResult(Location location) async {
    setState(() {
      _showSearchResults = false;
      _isLoading = true;
    });

    try {
      final latLng = LatLng(location.latitude, location.longitude);

      // Move map to selected location
      _mapController.move(latLng, 15);

      setState(() {
        _selectedLocation = latLng;
        _isLoading = false;
      });

      // Get address for the location
      final address = await _getAddressFromCoordinates(
        location.latitude,
        location.longitude,
      );

      setState(() {
        _selectedAddress = address;
      });

      // Clear search
      _searchController.clear();
    } catch (e) {
      debugPrint('Error selecting search result: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmLocation() async {
    if (_selectedLocation == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get address for selected location
      String address = await _getAddressFromCoordinates(
        _selectedLocation!.latitude,
        _selectedLocation!.longitude,
      );

      widget.onLocationSelected(
        _selectedLocation!.latitude,
        _selectedLocation!.longitude,
        address,
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error confirming location: $e');
      _showError('Could not confirm location');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<String> _getAddressFromCoordinates(
      double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isEmpty) {
        return 'Lat: ${latitude.toStringAsFixed(4)}, Lng: ${longitude.toStringAsFixed(4)}';
      }

      Placemark place = placemarks.first;

      // Build address with available components
      String address = '';

      if (place.locality != null && place.locality!.isNotEmpty) {
        address = place.locality!;
      } else if (place.subAdministrativeArea != null &&
          place.subAdministrativeArea!.isNotEmpty) {
        address = place.subAdministrativeArea!;
      } else if (place.administrativeArea != null &&
          place.administrativeArea!.isNotEmpty) {
        address = place.administrativeArea!;
      }

      if (place.subLocality != null && place.subLocality!.isNotEmpty) {
        address +=
            address.isNotEmpty ? ', ${place.subLocality}' : place.subLocality!;
      } else if (place.thoroughfare != null && place.thoroughfare!.isNotEmpty) {
        address += address.isNotEmpty
            ? ', ${place.thoroughfare}'
            : place.thoroughfare!;
      }

      if (place.country != null && place.country!.isNotEmpty) {
        address += address.isNotEmpty ? ', ${place.country}' : place.country!;
      }

      // Fallback if no proper address found
      if (address.isEmpty) {
        address =
            'Lat: ${latitude.toStringAsFixed(4)}, Lng: ${longitude.toStringAsFixed(4)}';
      }

      return address;
    } catch (e) {
      debugPrint('Error getting address: $e');
      return 'Lat: ${latitude.toStringAsFixed(4)}, Lng: ${longitude.toStringAsFixed(4)}';
    }
  }

  Future<void> _goToCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final location = LatLng(position.latitude, position.longitude);

      _mapController.move(location, 15);

      setState(() {
        _currentLocation = location;
        _selectedLocation = location;
      });
    } catch (e) {
      debugPrint('Error getting current location: $e');
      _showError('Could not get your location');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatAddress(Placemark place) {
    List<String> parts = [];

    if (place.name != null && place.name!.isNotEmpty) {
      parts.add(place.name!);
    }
    if (place.locality != null && place.locality!.isNotEmpty) {
      parts.add(place.locality!);
    }
    if (place.administrativeArea != null &&
        place.administrativeArea!.isNotEmpty) {
      parts.add(place.administrativeArea!);
    }

    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Select Location',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading && _selectedLocation == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Loading map...',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                // Map
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selectedLocation ?? _defaultLocation,
                    initialZoom: 15.0,
                    onMapEvent: _onMapEvent,
                    onMapReady: () {
                      setState(() => _isMapReady = true);
                    },
                    interactionOptions: const InteractionOptions(
                      flags: ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      retinaMode: RetinaMode.isHighDensity(context),
                      urlTemplate:
                          'https://{s}.tile.jawg.io/jawg-terrain/{z}/{x}/{y}{r}.png?access-token=FQfie4AAncNFaqSo02Dqzm6tGnV1YLuUtHbAnfneft9fXOZx6c4OKhq2bKDtbvSf',
                      subdomains: const ['a', 'b', 'c'],
                      userAgentPackageName: 'com.example.lifeline',
                    ),
                  ],
                ),

                // Center marker (pin)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        child: Icon(
                          Icons.location_pin,
                          size: _isMoving ? 55 : 50,
                          color: _isMoving
                              ? AppColors.primary.withOpacity(0.7)
                              : AppColors.primary,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 50), // Offset for pin point
                    ],
                  ),
                ),

                // Search bar with auto-suggestions
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search location...',
                            hintStyle: const TextStyle(
                              color: AppColors.textGrey,
                              fontSize: 14,
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: AppColors.primary,
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.clear,
                                      color: AppColors.textGrey,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchResults = [];
                                        _showSearchResults = false;
                                      });
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          onChanged: (value) {
                            setState(() {});
                          },
                        ),
                      ),

                      // Search results with live suggestions
                      if (_showSearchResults)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          constraints: const BoxConstraints(maxHeight: 250),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: _isSearching
                              ? const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                )
                              : _searchResults.isEmpty
                                  ? const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Text(
                                        'No results found',
                                        style: TextStyle(
                                          color: AppColors.textGrey,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    )
                                  : ListView.separated(
                                      shrinkWrap: true,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      itemCount: _searchResults.length,
                                      separatorBuilder: (context, index) =>
                                          Divider(
                                        height: 1,
                                        color:
                                            AppColors.textGrey.withOpacity(0.2),
                                      ),
                                      itemBuilder: (context, index) {
                                        final location = _searchResults[index];
                                        return FutureBuilder<List<Placemark>>(
                                          future: placemarkFromCoordinates(
                                            location.latitude,
                                            location.longitude,
                                          ),
                                          builder: (context, snapshot) {
                                            String displayName =
                                                'Location ${index + 1}';
                                            String subtitle =
                                                'Lat: ${location.latitude.toStringAsFixed(4)}, '
                                                'Lng: ${location.longitude.toStringAsFixed(4)}';

                                            if (snapshot.hasData &&
                                                snapshot.data!.isNotEmpty) {
                                              final place =
                                                  snapshot.data!.first;
                                              displayName =
                                                  _formatAddress(place);
                                            }

                                            return ListTile(
                                              leading: const Icon(
                                                Icons.location_on,
                                                color: AppColors.primary,
                                              ),
                                              title: Text(
                                                displayName,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              subtitle: Text(
                                                subtitle,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.textGrey,
                                                ),
                                              ),
                                              onTap: () =>
                                                  _selectSearchResult(location),
                                            );
                                          },
                                        );
                                      },
                                    ),
                        ),
                    ],
                  ),
                ),

                // Location info card
                Positioned(
                  top: _showSearchResults ? 280 : 100,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Selected Location',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textGrey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _selectedLocation != null
                                    ? 'Lat: ${_selectedLocation!.latitude.toStringAsFixed(4)}, '
                                        'Lng: ${_selectedLocation!.longitude.toStringAsFixed(4)}'
                                    : 'Move map to select',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_isMoving)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Bottom sheet with actions
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Drag indicator
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Instructions
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: AppColors.textSecondary,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Search or drag the map to select your location',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Confirm button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _confirmLocation,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                                disabledBackgroundColor:
                                    AppColors.primary.withOpacity(0.5),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.check_circle,
                                            size: 20),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Confirm Location',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
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

                // Current location button
                Positioned(
                  right: 16,
                  bottom: 200,
                  child: FloatingActionButton(
                    heroTag: 'current_location',
                    onPressed: _goToCurrentLocation,
                    backgroundColor: Colors.white,
                    elevation: 4,
                    child: const Icon(
                      Icons.my_location,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }
}
