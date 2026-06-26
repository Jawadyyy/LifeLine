import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lifeline/models/user_model.dart';
import 'package:lifeline/services/user_service.dart';
import 'package:lifeline/services/location_handler.dart';

class GlobalDataService extends ChangeNotifier {
  static final GlobalDataService _instance = GlobalDataService._internal();
  factory GlobalDataService() => _instance;
  GlobalDataService._internal();

  // Track current user to detect changes
  String? _currentUserId;

  // Data storage
  List<Map<String, dynamic>> _contacts = [];
  UserModel? _currentUser;
  String _currentAddress = 'Fetching location...';
  bool _isLocationFetched = false;
  DateTime? _locationLastUpdated;

  // Loading states
  bool _isLoadingContacts = false;
  bool _isLoadingUser = false;
  bool _isLoadingLocation = false;

  // Flags to track if data has been loaded
  bool _hasLoadedContacts = false;
  bool _hasLoadedUser = false;
  bool _hasLoadedLocation = false;

  // Getters
  List<Map<String, dynamic>> get contacts => _contacts;
  UserModel? get currentUser => _currentUser;
  String get currentAddress => _currentAddress;
  bool get isLocationFetched => _isLocationFetched;
  DateTime? get locationLastUpdated => _locationLastUpdated;
  bool get isLoadingContacts => _isLoadingContacts;
  bool get isLoadingUser => _isLoadingUser;
  bool get isLoadingLocation => _isLoadingLocation;
  bool get hasLoadedContacts => _hasLoadedContacts;
  bool get hasLoadedUser => _hasLoadedUser;
  bool get hasLoadedLocation => _hasLoadedLocation;
  String? get currentUserId => _currentUserId;

  // Initialize all data once
  Future<void> initializeAllData() async {
    final user = FirebaseAuth.instance.currentUser;
    final newUserId = user?.uid;

    // Check if user has changed
    if (_currentUserId != null && _currentUserId != newUserId) {
      debugPrint(
          'GlobalDataService: User changed from $_currentUserId to $newUserId');
      await clearAllData();
    }

    _currentUserId = newUserId;
    debugPrint(
        'GlobalDataService: Initializing all data for user: $_currentUserId');

    await Future.wait([
      loadUserData(),
      loadContactsData(),
      loadLocationData(),
    ]);
    debugPrint('GlobalDataService: All data initialization complete');
  }

  // Load user data once
  Future<void> loadUserData({bool forceReload = false}) async {
    final currentAuthUser = FirebaseAuth.instance.currentUser;

    // Check if user has changed
    if (_currentUserId != null && _currentUserId != currentAuthUser?.uid) {
      debugPrint('GlobalDataService: User changed, clearing user data');
      _currentUser = null;
      _hasLoadedUser = false;
      _currentUserId = currentAuthUser?.uid;
    }

    if (_hasLoadedUser && !forceReload) {
      debugPrint('GlobalDataService: User data already loaded, skipping...');
      return;
    }

    debugPrint(
        'GlobalDataService: Loading user data for user: $_currentUserId');
    _isLoadingUser = true;
    notifyListeners();

    try {
      final userService = UserService();
      _currentUser = await userService.loadCurrentUser();
      _hasLoadedUser = true;
      debugPrint(
          'GlobalDataService: User data loaded successfully - ${_currentUser?.email}');
    } catch (e) {
      debugPrint('Error loading user data: $e');
      _currentUser = null;
      _hasLoadedUser = false;
    } finally {
      _isLoadingUser = false;
      notifyListeners();
    }
  }

  // Load contacts data once
  Future<void> loadContactsData({bool forceReload = false}) async {
    final currentAuthUser = FirebaseAuth.instance.currentUser;

    // Check if user has changed
    if (_currentUserId != null && _currentUserId != currentAuthUser?.uid) {
      debugPrint('GlobalDataService: User changed, clearing contacts data');
      _contacts.clear();
      _hasLoadedContacts = false;
      _currentUserId = currentAuthUser?.uid;
    }

    if (_hasLoadedContacts && !forceReload) {
      debugPrint(
          'GlobalDataService: Contacts data already loaded, skipping...');
      return;
    }

    debugPrint(
        'GlobalDataService: Loading contacts data for user: $_currentUserId');
    _isLoadingContacts = true;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('contacts')
            .get();

        _contacts = querySnapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();

        _hasLoadedContacts = true;
        debugPrint(
            'GlobalDataService: Contacts data loaded successfully (${_contacts.length} contacts)');
      } else {
        debugPrint(
            'GlobalDataService: No authenticated user, cannot load contacts');
        _contacts.clear();
        _hasLoadedContacts = false;
      }
    } catch (e) {
      debugPrint('Error loading contacts: $e');
      _contacts.clear();
      _hasLoadedContacts = false;
    } finally {
      _isLoadingContacts = false;
      notifyListeners();
    }
  }

  // Load location data once
  Future<void> loadLocationData({bool forceReload = false}) async {
    if (_hasLoadedLocation && !forceReload) {
      debugPrint(
          'GlobalDataService: Location data already loaded, skipping...');
      return;
    }

    debugPrint('GlobalDataService: Loading location data...');
    _isLoadingLocation = true;
    notifyListeners();

    try {
      final position = await LocationHandler.getCurrentPosition();
      if (position != null) {
        final address = await LocationHandler.getAddressFromLatLng(position);
        final newAddress = address ?? 'Location unavailable';

        // Only update and notify if the address has actually changed
        if (_currentAddress != newAddress) {
          _currentAddress = newAddress;
          _isLocationFetched = true;
          _locationLastUpdated = DateTime.now();
          debugPrint(
              'GlobalDataService: Location data loaded successfully: $_currentAddress');
        } else {
          debugPrint(
              'GlobalDataService: Location address unchanged, skipping notification');
        }
      } else {
        if (_currentAddress != 'Location permission denied') {
          _currentAddress = 'Location permission denied';
          _isLocationFetched = false;
          debugPrint('GlobalDataService: Location permission denied');
        }
      }
      _hasLoadedLocation = true;
    } catch (e) {
      debugPrint('Error loading location: $e');
      if (_currentAddress != 'Error getting location') {
        _currentAddress = 'Error getting location';
        _isLocationFetched = false;
      }
    } finally {
      _isLoadingLocation = false;
      // Always notify listeners when loading state changes
      notifyListeners();
    }
  }

  // Update contacts (for add/delete operations)
  Future<void> updateContacts() async {
    await loadContactsData(forceReload: true);
  }

  // Update user data
  Future<void> updateUserData() async {
    await loadUserData(forceReload: true);
  }

  // Update user data from external source (e.g., profile updates) without triggering listeners
  void updateUserDataSilently(UserModel user) {
    _currentUser = user;
    _hasLoadedUser = true;
    // Don't call notifyListeners() to avoid loops
  }

  // Update location data
  Future<void> updateLocationData() async {
    // Only update if location data is stale or not available
    if (!_hasLoadedLocation ||
        _currentAddress.isEmpty ||
        _currentAddress == 'Fetching location...') {
      await loadLocationData(forceReload: true);
    } else {
      debugPrint(
          'GlobalDataService: Location data is already fresh, skipping update');
    }
  }

  // Check if location data is fresh (fetched within last 5 minutes)
  bool get isLocationDataFresh {
    if (!_hasLoadedLocation || !_isLocationFetched || _currentAddress.isEmpty) {
      return false;
    }

    // Consider location fresh if it was updated within the last 5 minutes
    if (_locationLastUpdated != null) {
      final timeDifference = DateTime.now().difference(_locationLastUpdated!);
      return timeDifference.inMinutes < 5;
    }

    return false;
  }

  // Clear all data (useful for logout or user change)
  Future<void> clearAllData() async {
    debugPrint(
        'GlobalDataService: Clearing all data for user: $_currentUserId');

    _contacts.clear();
    _currentUser = null;
    _currentAddress = 'Fetching location...';
    _isLocationFetched = false;
    _locationLastUpdated = null;
    _hasLoadedContacts = false;
    _hasLoadedUser = false;
    _hasLoadedLocation = false;
    _currentUserId = null;

    notifyListeners();
    debugPrint('GlobalDataService: All data cleared');
  }

  // Check if all data is loaded
  bool get isAllDataLoaded =>
      _hasLoadedContacts && _hasLoadedUser && _hasLoadedLocation;
}
