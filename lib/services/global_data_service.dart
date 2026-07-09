import 'dart:async';

import 'package:lifeline/utils/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
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
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _contactsSub;
  UserModel? _currentUser;
  String _currentAddress = 'Fetching location...';
  bool _isLocationFetched = false;
  DateTime? _locationLastUpdated;
  Position? _lastPosition;

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
  Position? get lastPosition => _lastPosition;
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
      logDebug(
          'GlobalDataService: User changed from $_currentUserId to $newUserId');
      await clearAllData();
    }

    _currentUserId = newUserId;
    logDebug(
        'GlobalDataService: Initializing all data for user: $_currentUserId');

    await Future.wait([
      loadUserData(),
      loadContactsData(),
      loadLocationData(),
    ]);
    logDebug('GlobalDataService: All data initialization complete');
  }

  // Load user data once
  Future<void> loadUserData({bool forceReload = false}) async {
    final currentAuthUser = FirebaseAuth.instance.currentUser;

    // Check if user has changed
    if (_currentUserId != null && _currentUserId != currentAuthUser?.uid) {
      logDebug('GlobalDataService: User changed, clearing user data');
      _currentUser = null;
      _hasLoadedUser = false;
      _currentUserId = currentAuthUser?.uid;
    }

    if (_hasLoadedUser && !forceReload) {
      logDebug('GlobalDataService: User data already loaded, skipping...');
      return;
    }

    logDebug(
        'GlobalDataService: Loading user data for user: $_currentUserId');
    _isLoadingUser = true;
    notifyListeners();

    try {
      final userService = UserService();
      _currentUser = await userService.loadCurrentUser();
      _hasLoadedUser = true;
      logDebug(
          'GlobalDataService: User data loaded successfully - ${_currentUser?.email}');
    } catch (e) {
      logDebug('Error loading user data: $e');
      _currentUser = null;
      _hasLoadedUser = false;
    } finally {
      _isLoadingUser = false;
      notifyListeners();
    }
  }

  // Attaches a live Firestore listener to the user's contacts subcollection,
  // so additions made by other users (reciprocal adds) show up instantly
  // instead of only after an app restart. The returned future completes when
  // the first snapshot has been applied, preserving the old await semantics.
  Future<void> loadContactsData({bool forceReload = false}) async {
    final currentAuthUser = FirebaseAuth.instance.currentUser;

    // Check if user has changed
    if (_currentUserId != null && _currentUserId != currentAuthUser?.uid) {
      logDebug('GlobalDataService: User changed, clearing contacts data');
      await _contactsSub?.cancel();
      _contactsSub = null;
      _contacts.clear();
      _hasLoadedContacts = false;
      _currentUserId = currentAuthUser?.uid;
    }

    // Listener already attached and streaming — nothing to do. forceReload
    // re-attaches, which immediately re-delivers the current snapshot.
    if (_contactsSub != null && !forceReload) {
      logDebug(
          'GlobalDataService: Contacts listener already active, skipping...');
      return;
    }

    logDebug(
        'GlobalDataService: Loading contacts data for user: $_currentUserId');
    _isLoadingContacts = true;
    notifyListeners();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      logDebug(
          'GlobalDataService: No authenticated user, cannot load contacts');
      _contacts.clear();
      _hasLoadedContacts = false;
      _isLoadingContacts = false;
      notifyListeners();
      return;
    }

    await _contactsSub?.cancel();
    final firstSnapshot = Completer<void>();

    _contactsSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('contacts')
        .snapshots()
        .listen((querySnapshot) async {
      _contacts = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // The profileImageUrl stored on a contact is only a snapshot from when
      // the contact was added. If that app-user later sets/changes their
      // picture, the snapshot goes stale. Refresh it live from users/{uid}.
      await _refreshContactImages();

      _hasLoadedContacts = true;
      _isLoadingContacts = false;
      logDebug(
          'GlobalDataService: Contacts snapshot applied (${_contacts.length} contacts)');
      notifyListeners();
      if (!firstSnapshot.isCompleted) firstSnapshot.complete();
    }, onError: (e) {
      logDebug('Error loading contacts: $e');
      _contacts.clear();
      _hasLoadedContacts = false;
      _isLoadingContacts = false;
      notifyListeners();
      if (!firstSnapshot.isCompleted) firstSnapshot.complete();
    });

    await firstSnapshot.future;
  }

  // The profileImageUrl on a contact is only a snapshot from add-time and goes
  // stale when that app-user later sets/changes their picture. Refresh it live
  // from the users collection. Matches by uid when present, else by normalized
  // phone (older contacts may not have a uid stored), so it's uid-independent.
  Future<void> _refreshContactImages() async {
    if (_contacts.isEmpty) return;

    try {
      final usersSnap =
          await FirebaseFirestore.instance.collection('users').get();

      final imageByUid = <String, String>{};
      final imageByPhone = <String, String>{};
      for (final doc in usersSnap.docs) {
        final data = doc.data();
        final img = (data['profileImageUrl'] as String?) ?? '';
        imageByUid[doc.id] = img;
        final phone = data['phone'] as String?;
        if (phone != null && phone.isNotEmpty) {
          imageByPhone[_normalizePhone(phone)] = img;
        }
      }

      for (final c in _contacts) {
        final uid = c['uid'] as String?;
        if (uid != null && uid.isNotEmpty && imageByUid.containsKey(uid)) {
          c['profileImageUrl'] = imageByUid[uid];
          continue;
        }
        final phone = c['phone'] as String?;
        if (phone != null && phone.isNotEmpty) {
          final match = imageByPhone[_normalizePhone(phone)];
          if (match != null) c['profileImageUrl'] = match;
        }
      }
    } catch (e) {
      logDebug('GlobalDataService: Error refreshing contact images: $e');
    }
  }

  String _normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 10
        ? digits.substring(digits.length - 10)
        : digits;
  }

  // Load location data once
  Future<void> loadLocationData({bool forceReload = false}) async {
    if (_hasLoadedLocation && !forceReload) {
      logDebug(
          'GlobalDataService: Location data already loaded, skipping...');
      return;
    }

    logDebug('GlobalDataService: Loading location data...');
    _isLoadingLocation = true;
    notifyListeners();

    try {
      final position = await LocationHandler.getCurrentPosition();
      if (position != null) {
        _lastPosition = position;
        final address = await LocationHandler.getAddressFromLatLng(position);
        final newAddress = address ?? 'Location unavailable';

        // Only update and notify if the address has actually changed
        if (_currentAddress != newAddress) {
          _currentAddress = newAddress;
          _isLocationFetched = true;
          _locationLastUpdated = DateTime.now();
          logDebug(
              'GlobalDataService: Location data loaded successfully: $_currentAddress');
        } else {
          logDebug(
              'GlobalDataService: Location address unchanged, skipping notification');
        }
      } else {
        if (_currentAddress != 'Location permission denied') {
          _currentAddress = 'Location permission denied';
          _isLocationFetched = false;
          logDebug('GlobalDataService: Location permission denied');
        }
      }
      _hasLoadedLocation = true;
    } catch (e) {
      logDebug('Error loading location: $e');
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

  // Seed the cached position from a screen that fetched it directly
  // (e.g. the donation map), so later navigations reuse it instead of
  // re-running geolocation.
  void cachePosition(Position position) {
    _lastPosition = position;
    _hasLoadedLocation = true;
    _isLocationFetched = true;
    _locationLastUpdated = DateTime.now();
  }

  // Update location data
  Future<void> updateLocationData() async {
    // Only update if location data is stale or not available
    if (!_hasLoadedLocation ||
        _currentAddress.isEmpty ||
        _currentAddress == 'Fetching location...') {
      await loadLocationData(forceReload: true);
    } else {
      logDebug(
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
    logDebug(
        'GlobalDataService: Clearing all data for user: $_currentUserId');

    await _contactsSub?.cancel();
    _contactsSub = null;
    _contacts.clear();
    _currentUser = null;
    _currentAddress = 'Fetching location...';
    _isLocationFetched = false;
    _locationLastUpdated = null;
    _lastPosition = null;
    _hasLoadedContacts = false;
    _hasLoadedUser = false;
    _hasLoadedLocation = false;
    _currentUserId = null;

    notifyListeners();
    logDebug('GlobalDataService: All data cleared');
  }

  // Check if all data is loaded
  bool get isAllDataLoaded =>
      _hasLoadedContacts && _hasLoadedUser && _hasLoadedLocation;
}
