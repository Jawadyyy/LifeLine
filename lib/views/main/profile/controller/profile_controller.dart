import 'package:lifeline/utils/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lifeline/models/user_model.dart';
import 'package:lifeline/services/auth_service.dart';
import 'package:lifeline/services/global_data_service.dart';
import 'package:lifeline/services/media_upload_service.dart';

class ProfileController extends ChangeNotifier {
  final ImagePicker _picker = ImagePicker();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  final GlobalDataService _globalDataService = GlobalDataService();

  // Common dropdown options
  static const List<String> diseaseOptions = [
    'None',
    'Diabetes',
    'Hypertension',
    'Asthma',
    'Heart Disease',
    'Thyroid Disorder',
    'Kidney Disease',
    'Cancer',
    'Liver Disease',
    'Anemia',
    'Epilepsy',
    'HIV/AIDS',
    'Tuberculosis',
    'Arthritis',
    'Mental Health Conditions',
    'Other',
  ];

  static const List<String> allergyOptions = [
    'None',
    'Pollen',
    'Dust Mites',
    'Mold',
    'Pet Dander',
    'Food - Peanuts',
    'Food - Shellfish',
    'Food - Eggs',
    'Food - Milk',
    'Food - Wheat',
    'Food - Soy',
    'Insect Stings',
    'Latex',
    'Medications',
    'Other',
  ];

  static const List<String> bloodGroupOptions = [
    'None',
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-'
  ];

  // User data
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  // Track if initial data has been loaded
  bool _hasLoadedInitialData = false;

  // Getters
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasLoadedInitialData => _hasLoadedInitialData;

  // Set current user (for external updates from GlobalDataService)
  void setCurrentUser(UserModel user) {
    _currentUser = user;
    _hasLoadedInitialData = true;
    notifyListeners();
  }

  // Refresh user data from GlobalDataService
  Future<void> refreshUserData() async {
    final globalUser = _globalDataService.currentUser;
    if (globalUser != null) {
      _currentUser = globalUser;
      _hasLoadedInitialData = true;
      notifyListeners();
    }
  }

  // Only refresh profile image when explicitly needed (after upload)
  Future<void> refreshProfileImage() async {
    if (!_hasLoadedInitialData) {
      // Only fetch if we haven't loaded data yet
      await fetchUserData();
    }
  }

  // Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Set error message
  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Fetch user data from Firestore
  Future<void> fetchUserData() async {
    try {
      _setLoading(true);
      _setError(null);

      final String userId = _authService.getCurrentUserId();
      final DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;

        _currentUser = UserModel(
          name: data['username'] ?? 'Unknown',
          bloodType: data['blood_group'] ?? 'N/A',
          height: data['height']?.toString() ?? 'N/A',
          weight: data['weight']?.toString() ?? 'N/A',
          profileImage: data['profileImageUrl'] ?? '',
          email: data['email'] ?? '',
          phone: data['phone'] ?? '',
          age: data['age'] ?? '',
          bmi: data['bmi'] ?? '',
          disease: data['disease'] ?? 'None',
          allergy: data['allergy'] ?? 'None',
          address: data['home_address'] ?? '',
          emergencyText: data['emergency_text'] ?? '',
        );

        _hasLoadedInitialData = true;

        // Update global service silently to avoid loops
        _globalDataService.updateUserDataSilently(_currentUser!);
      }
    } catch (e) {
      _setError("Error fetching user data: $e");
      logDebug("Error fetching user data: $e");
    } finally {
      _setLoading(false);
    }
  }

  // Load user data for profile setup/settings
  Future<Map<String, dynamic>?> loadUserData() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return null;

      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return null;

      return userDoc.data() as Map<String, dynamic>;
    } catch (e) {
      _setError("Error loading user data: $e");
      return null;
    }
  }

  // Update user data in Firestore
  Future<bool> updateUserData(Map<String, dynamic> userData) async {
    try {
      _setLoading(true);
      _setError(null);

      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        _setError("User not authenticated");
        return false;
      }

      await _firestore.collection('users').doc(userId).update(userData);

      // Refresh user data
      await fetchUserData();

      return true;
    } catch (e) {
      _setError("Error updating user data: $e");
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Upload profile picture to Supabase Storage
  Future<String?> uploadProfileImage(String filePath) async {
    final String userId = _authService.getCurrentUserId();
    final url =
        await MediaUploadService().uploadProfileImage(filePath, uid: userId);
    if (url == null) _setError("Image upload failed");
    return url;
  }

  // Update profile image
  Future<bool> updateProfileImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile == null) return false;

      final imageUrl = await uploadProfileImage(pickedFile.path);
      if (imageUrl == null) return false;

      final String userId = _authService.getCurrentUserId();
      await _firestore.collection('users').doc(userId).update({
        'profileImageUrl': imageUrl,
      });

      // Update local user model
      if (_currentUser != null) {
        _currentUser = UserModel(
          name: _currentUser!.name,
          bloodType: _currentUser!.bloodType,
          height: _currentUser!.height,
          weight: _currentUser!.weight,
          profileImage: imageUrl,
          email: _currentUser!.email,
          phone: _currentUser!.phone,
          age: _currentUser!.age,
          bmi: _currentUser!.bmi,
          disease: _currentUser!.disease,
          allergy: _currentUser!.allergy,
          address: _currentUser!.address,
          emergencyText: _currentUser!.emergencyText,
        );

        // Update GlobalDataService to keep it in sync
        _globalDataService.updateUserDataSilently(_currentUser!);

        notifyListeners();
      }

      return true;
    } catch (e) {
      _setError("Error updating profile image: $e");
      return false;
    }
  }

  // Calculate BMI (weight is stored in kilograms)
  double? calculateBMI(String heightCm, String weightKg) {
    try {
      final double height = double.parse(heightCm.trim());
      final double weight = double.parse(weightKg.trim());

      if (height <= 0 || weight <= 0) return null;

      final double heightM = height / 100;

      return weight / (heightM * heightM);
    } catch (e) {
      return null;
    }
  }

  // Get BMI color based on value
  Color getBmiColor(double bmi) {
    if (bmi < 18.5) return Colors.orange;
    if (bmi < 25.0) return Colors.green;
    if (bmi < 30.0) return Colors.amber;
    return Colors.red;
  }

  // Validate phone number uniqueness
  Future<bool> isPhoneNumberUnique(String phone,
      {String? excludeUserId}) async {
    try {
      // If phone is empty, consider it unique (allow empty phones)
      if (phone.isEmpty) return true;

      final query =
          _firestore.collection('users').where('phone', isEqualTo: phone);

      final snapshot = await query.get();

      if (excludeUserId != null) {
        return !snapshot.docs.any((doc) => doc.id != excludeUserId);
      }

      return snapshot.docs.isEmpty;
    } catch (e) {
      _setError("Error checking phone number: $e");
      return true;
    }
  }

  // Sign out user
  Future<void> signOut() async {
    try {
      await _authService.signOut();
      _currentUser = null;
      _hasLoadedInitialData = false;
    } catch (e) {
      _setError("Error signing out: $e");
    }
  }

  // Check if profile is complete
  Future<bool> isProfileComplete() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return false;

      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return false;

      final data = doc.data() as Map<String, dynamic>;
      return data['isProfileComplete'] == true;
    } catch (e) {
      return false;
    }
  }

  // Mark profile as complete
  Future<void> markProfileComplete() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        await _firestore
            .collection('users')
            .doc(userId)
            .update({'isProfileComplete': true});
      }
    } catch (e) {
      _setError("Error marking profile complete: $e");
    }
  }

}
