import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lifeline/constants/app_colors.dart';
import 'package:lifeline/services/global_data_service.dart';

class DonationController extends ChangeNotifier {
  // Form controllers
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController locationController = TextEditingController();

  // Form state
  DateTime? selectedDateTime;
  String selectedBloodGroup = 'O+';
  bool isLoading = false;

  // Blood groups list
  final List<String> bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-'
  ];

  // Getters
  bool get hasSelectedDateTime => selectedDateTime != null;
  String get formattedDateTime => selectedDateTime != null
      ? DateFormat.yMd().add_jm().format(selectedDateTime!)
      : 'Select date and time';

  // Initialize controller
  void init() {
    // Reset form state
    resetForm();
  }

  // Reset form to initial state
  void resetForm() {
    selectedDateTime = null;
    selectedBloodGroup = 'O+';
    descriptionController.clear();
    locationController.clear();
    notifyListeners();
  }

  // Update blood group
  void updateBloodGroup(String bloodGroup) {
    selectedBloodGroup = bloodGroup;
    notifyListeners();
  }

  // Update selected date time
  void updateSelectedDateTime(DateTime dateTime) {
    selectedDateTime = dateTime;
    notifyListeners();
  }

  // Get current location address
  Future<String> getCurrentAddress() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied');
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get address from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isEmpty) {
        throw Exception('Could not determine location');
      }

      Placemark place = placemarks.first;
      return '${place.locality}, ${place.street}, ${place.country}';
    } catch (e) {
      rethrow;
    }
  }

  // Pick date and time
  Future<void> pickDateTime(BuildContext context) async {
    try {
      // Pick date
      final date = await showDatePicker(
        context: context,
        firstDate: DateTime.now(),
        lastDate: DateTime(2100),
        initialDate: DateTime.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF2196F3), // AppColors.primary
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black87,
              ),
            ),
            child: child!,
          );
        },
      );

      if (date == null) return;

      // Pick time
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF2196F3), // AppColors.primary
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black87,
              ),
            ),
            child: child!,
          );
        },
      );

      if (time == null) return;

      // Update selected date time
      updateSelectedDateTime(
          DateTime(date.year, date.month, date.day, time.hour, time.minute));
    } catch (e) {
      debugPrint('Error picking date time: $e');
    }
  }

  // Submit donation post
  // Submit donation post
  Future<bool> submitPost() async {
    if (selectedDateTime == null) return false;

    setLoading(true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get user data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data();
      if (userData == null) throw Exception('User data not found');

      // Get current position & address
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      String currentAddress = '';
      String city = '';
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        currentAddress =
            "${place.locality ?? ''}, ${place.street ?? ''}, ${place.country ?? ''}";
        city = place.locality ?? '';
      }

      // Create post data
      final post = {
        'blood_group': selectedBloodGroup,
        'location': currentAddress,
        'city': city, // 👈 store city separately
        'donation_time': selectedDateTime,
        'timestamp': Timestamp.now(),
        'description': descriptionController.text.trim(),
      };

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('donation_posts')
          .add(post);

      // Reset form
      resetForm();

      return true;
    } catch (e) {
      debugPrint('Error submitting post: $e');
      return false;
    } finally {
      setLoading(false);
    }
  }

  // Update donation post
  Future<bool> updatePost(
    String userId,
    String postId, {
    required String bloodGroup,
    required DateTime donationTime,
    required String description,
  }) async {
    setLoading(true);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('donation_posts')
          .doc(postId)
          .update({
        'blood_group': bloodGroup,
        'donation_time': donationTime,
        'description': description.trim(),
      });

      return true;
    } catch (e) {
      debugPrint('Error updating post: $e');
      return false;
    } finally {
      setLoading(false);
    }
  }

  // Delete donation post
  Future<bool> deletePost(String userId, String postId) async {
    setLoading(true);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('donation_posts')
          .doc(postId)
          .delete();

      return true;
    } catch (e) {
      debugPrint('Error deleting post: $e');
      return false;
    } finally {
      setLoading(false);
    }
  }

  // Contact via WhatsApp
  Future<bool> contactViaWhatsApp(
      String phone, String location, DateTime donationTime) async {
    try {
      final phoneRaw = phone.replaceAll(RegExp(r'[^\d+]'), '');

      if (phoneRaw.length < 10) {
        throw Exception('Invalid phone number');
      }

      final message = "Hi, I saw your blood donation request on LifeLine.\n"
          "Location: $location\n"
          "Time: ${DateFormat.yMd().add_jm().format(donationTime)}";

      final whatsappUrl =
          'https://wa.me/$phoneRaw?text=${Uri.encodeComponent(message)}';

      try {
        await launchUrl(Uri.parse(whatsappUrl),
            mode: LaunchMode.externalApplication);
        return true;
      } catch (e) {
        debugPrint('Error opening WhatsApp: $e');
        return false;
      }
    } catch (e) {
      debugPrint('Error opening WhatsApp: $e');
      return false;
    }
  }

  // Make phone call
  Future<bool> makePhoneCall(String phone) async {
    try {
      // Clean phone number
      final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');

      if (cleanPhone.isEmpty) {
        throw Exception('Invalid phone number');
      }

      final Uri phoneUri = Uri(scheme: 'tel', path: cleanPhone);

      try {
        final launched =
            await launchUrl(phoneUri, mode: LaunchMode.externalApplication);
        if (!launched) {
          throw Exception('Could not launch phone call');
        }
        return true;
      } catch (e) {
        debugPrint('Error launching phone call: $e');
        return false;
      }
    } catch (e) {
      debugPrint('Error making phone call: $e');
      return false;
    }
  }

  // Send email
  Future<bool> sendEmail(String email) async {
    try {
      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: email,
        queryParameters: {
          'subject': 'Urgent Medical Assistance Needed',
          'body':
              'Hello $email,\n\nI found your contact on the LifeLine app and need urgent assistance. '
                  'Please respond as soon as possible.\n\nThank you.',
        },
      );

      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri, mode: LaunchMode.externalApplication);
        return true;
      } else {
        debugPrint("No email app available.");
        return false;
      }
    } catch (e) {
      debugPrint('Error sending email: $e');
      return false;
    }
  }

  // Open map directions
  Future<bool> openMapDirections(String destination) async {
    try {
      if (destination.isEmpty) {
        throw Exception('Destination is empty');
      }

      // Try to get current location first
      Position? current;
      try {
        current = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
      } catch (e) {
        debugPrint('Could not get current location: $e');
        // Continue without current location
      }

      String url;
      if (current != null) {
        // With current location - use directions
        final dest = Uri.encodeComponent(destination);
        url = 'https://www.google.com/maps/dir/?api=1'
            '&origin=${current.latitude},${current.longitude}'
            '&destination=$dest&travelmode=driving';
      } else {
        // Without current location - just search for destination
        final dest = Uri.encodeComponent(destination);
        url = 'https://www.google.com/maps/search/$dest';
      }

      final uri = Uri.parse(url);
      try {
        final launched =
            await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!launched) {
          throw Exception('Could not launch Google Maps.');
        }
        return true;
      } catch (e) {
        debugPrint('Error launching Google Maps: $e');
        return false;
      }
    } catch (e) {
      debugPrint('Error opening map: $e');
      return false;
    }
  }

  // Get donation posts stream
  Stream<QuerySnapshot> getDonationPostsStream() {
    return FirebaseFirestore.instance.collection('users').snapshots();
  }

  // Get user donation posts stream
  Stream<QuerySnapshot> getUserDonationPostsStream(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('donation_posts')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Check if user is post owner
  bool isPostOwner(String ownerId) {
    final currentUser = FirebaseAuth.instance.currentUser;
    return currentUser?.uid == ownerId;
  }

  // Check if donation is upcoming
  bool isUpcomingDonation(DateTime donationTime) {
    return donationTime.isAfter(DateTime.now());
  }

  // Check if donation is expired
  bool isExpiredDonation(DateTime donationTime) {
    return donationTime.isBefore(DateTime.now());
  }

  // Get donation status
  String getDonationStatus(DateTime donationTime) {
    if (isExpiredDonation(donationTime)) {
      return 'Expired';
    } else if (isUpcomingDonation(donationTime)) {
      return 'Upcoming';
    } else {
      return 'Today';
    }
  }

  // Get donation status color
  Color getDonationStatusColor(DateTime donationTime) {
    if (isExpiredDonation(donationTime)) {
      return Colors.red;
    } else if (isUpcomingDonation(donationTime)) {
      return AppColors.primary;
    } else {
      return Colors.orange;
    }
  }

  // Extract city from address
  String extractCityFromAddress(String address) {
    if (address.isEmpty) return '';

    // Split by comma and get the first part (usually city)
    final parts = address.split(',');
    if (parts.isNotEmpty) {
      return parts.first.trim();
    }
    return address;
  }

  // Check if donation is in user's city
  bool isDonationInUserCity(String donationLocation, String userCity) {
    if (donationLocation.isEmpty || userCity.isEmpty) return false;

    final donationCity = extractCityFromAddress(donationLocation);
    return donationCity.toLowerCase() == userCity.toLowerCase();
  }

  // Get current user's city
  String getCurrentUserCity() {
    // Try to get from GlobalDataService first
    try {
      final globalDataService = GlobalDataService();
      final currentAddress = globalDataService.currentAddress;
      if (currentAddress.isNotEmpty &&
          currentAddress != 'Fetching location...') {
        return extractCityFromAddress(currentAddress);
      }
    } catch (e) {
      debugPrint('Error getting city from GlobalDataService: $e');
    }

    // Fallback: try to get from current user's address in Firestore
    return '';
  }

  // Format donation time
  String formatDonationTime(DateTime donationTime) {
    return DateFormat('MMM d, y • h:mm a').format(donationTime);
  }

  // Format donation date
  String formatDonationDate(DateTime donationTime) {
    return DateFormat('MMMM d, y').format(donationTime);
  }

  // Format donation time only
  String formatDonationTimeOnly(DateTime donationTime) {
    return DateFormat('h:mm a').format(donationTime);
  }

  // Set loading state
  void setLoading(bool loading) {
    isLoading = loading;
    notifyListeners();
  }

  // Validate form
  bool validateForm() {
    return selectedDateTime != null &&
        descriptionController.text.trim().isNotEmpty;
  }

  // Get current user
  User? get currentUser => FirebaseAuth.instance.currentUser;

  // Dispose resources
  @override
  void dispose() {
    descriptionController.dispose();
    locationController.dispose();
    super.dispose();
  }
}
