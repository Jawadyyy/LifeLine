import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:lifeline/models/user_model.dart';
import 'package:lifeline/services/user_service.dart';
import 'package:lifeline/services/location_handler.dart';

class GlobalDataService extends ChangeNotifier {
  static final GlobalDataService _instance = GlobalDataService._internal();
  factory GlobalDataService() => _instance;
  GlobalDataService._internal();

  // Data storage
  List<Map<String, dynamic>> _contacts = [];
  UserModel? _currentUser;
  String _currentAddress = 'Fetching location...';
  bool _isLocationFetched = false;

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
  bool get isLoadingContacts => _isLoadingContacts;
  bool get isLoadingUser => _isLoadingUser;
  bool get isLoadingLocation => _isLoadingLocation;
  bool get hasLoadedContacts => _hasLoadedContacts;
  bool get hasLoadedUser => _hasLoadedUser;
  bool get hasLoadedLocation => _hasLoadedLocation;

  // Initialize all data once
  Future<void> initializeAllData() async {
    debugPrint('GlobalDataService: Initializing all data...');
    await Future.wait([
      loadUserData(),
      loadContactsData(),
      loadLocationData(),
    ]);
    debugPrint('GlobalDataService: All data initialization complete');
  }

  // Load user data once
  Future<void> loadUserData({bool forceReload = false}) async {
    if (_hasLoadedUser && !forceReload) {
      debugPrint('GlobalDataService: User data already loaded, skipping...');
      return;
    }

    debugPrint('GlobalDataService: Loading user data...');
    _isLoadingUser = true;
    notifyListeners();

    try {
      final userService = UserService();
      _currentUser = await userService.loadCurrentUser();
      _hasLoadedUser = true;
      debugPrint('GlobalDataService: User data loaded successfully');
    } catch (e) {
      debugPrint('Error loading user data: $e');
    } finally {
      _isLoadingUser = false;
      notifyListeners();
    }
  }

  // Load contacts data once
  Future<void> loadContactsData({bool forceReload = false}) async {
    if (_hasLoadedContacts && !forceReload) {
      debugPrint(
          'GlobalDataService: Contacts data already loaded, skipping...');
      return;
    }

    debugPrint('GlobalDataService: Loading contacts data...');
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
      }
    } catch (e) {
      debugPrint('Error loading contacts: $e');
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
        _currentAddress = address ?? 'Location unavailable';
        _isLocationFetched = true;
        debugPrint(
            'GlobalDataService: Location data loaded successfully: $_currentAddress');
      } else {
        _currentAddress = 'Location permission denied';
        debugPrint('GlobalDataService: Location permission denied');
      }
      _hasLoadedLocation = true;
    } catch (e) {
      debugPrint('Error loading location: $e');
      _currentAddress = 'Error getting location';
    } finally {
      _isLoadingLocation = false;
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
    await loadLocationData(forceReload: true);
  }

  // Clear all data (useful for logout)
  void clearAllData() {
    _contacts.clear();
    _currentUser = null;
    _currentAddress = 'Fetching location...';
    _isLocationFetched = false;
    _hasLoadedContacts = false;
    _hasLoadedUser = false;
    _hasLoadedLocation = false;
    notifyListeners();
  }

  // Check if all data is loaded
  bool get isAllDataLoaded =>
      _hasLoadedContacts && _hasLoadedUser && _hasLoadedLocation;
}
