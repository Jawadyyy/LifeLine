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
  String? currentUserCity;
  String? currentUserAddress;

  // Filter state
  String selectedBloodFilter = 'All';
  bool showOnlyCityDonations = true;
  String searchQuery = '';

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
  void init() async {
    resetForm();
    await loadUserLocation();
  }

  // Load user location
  Future<void> loadUserLocation() async {
    try {
      final globalDataService = GlobalDataService();
      currentUserAddress = globalDataService.currentAddress;

      if (currentUserAddress != null &&
          currentUserAddress!.isNotEmpty &&
          currentUserAddress != 'Fetching location...') {
        currentUserCity = extractCityFromAddress(currentUserAddress!);
        notifyListeners();
      } else {
        // Try to get location directly
        await refreshUserLocation();
      }
    } catch (e) {
      debugPrint('Error loading user location: $e');
    }
  }

  // Refresh user location
  Future<void> refreshUserLocation() async {
    try {
      final address = await getCurrentAddress();
      currentUserAddress = address;
      currentUserCity = extractCityFromAddress(address);
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing location: $e');
      rethrow;
    }
  }

  // Update filter settings
  void updateBloodFilter(String bloodGroup) {
    selectedBloodFilter = bloodGroup;
    notifyListeners();
  }

  void toggleCityFilter() {
    showOnlyCityDonations = !showOnlyCityDonations;
    notifyListeners();
  }

  void updateSearchQuery(String query) {
    searchQuery = query.toLowerCase();
    notifyListeners();
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
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

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

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isEmpty) {
        throw Exception('Could not determine location');
      }

      Placemark place = placemarks.first;

      // Build address with available components, prioritizing readable location
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
            'Location: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      }

      return address;
    } catch (e) {
      rethrow;
    }
  }

  // Pick date and time
  Future<void> pickDateTime(BuildContext context) async {
    try {
      final date = await showDatePicker(
        context: context,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        initialDate: DateTime.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: AppColors.primary,
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

      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: AppColors.primary,
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

      updateSelectedDateTime(
          DateTime(date.year, date.month, date.day, time.hour, time.minute));
    } catch (e) {
      debugPrint('Error picking date time: $e');
    }
  }

  // Submit donation post
  Future<bool> submitPost() async {
    if (selectedDateTime == null) return false;

    setLoading(true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data();
      if (userData == null) throw Exception('User data not found');

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      String currentAddress = '';
      String city = '';
      String subLocality = '';

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;

        // Get city
        city = place.locality ??
            place.subAdministrativeArea ??
            place.administrativeArea ??
            '';

        // Get sub-locality
        subLocality = place.subLocality ?? place.thoroughfare ?? '';

        // Build readable address
        currentAddress = '';
        if (city.isNotEmpty) {
          currentAddress = city;
        }
        if (subLocality.isNotEmpty) {
          currentAddress +=
              currentAddress.isNotEmpty ? ', $subLocality' : subLocality;
        }
        if (place.country != null && place.country!.isNotEmpty) {
          currentAddress +=
              currentAddress.isNotEmpty ? ', ${place.country}' : place.country!;
        }

        // Fallback
        if (currentAddress.isEmpty) {
          currentAddress =
              'Location: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
        }
      }

      final post = {
        'blood_group': selectedBloodGroup,
        'location': currentAddress,
        'city': city,
        'sub_locality': subLocality,
        'donation_time': selectedDateTime,
        'timestamp': Timestamp.now(),
        'description': descriptionController.text.trim(),
        'status': 'active', // active, completed, expired
        'latitude': position.latitude,
        'longitude': position.longitude,
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('donation_posts')
          .add(post);

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

  // Mark donation as completed
  Future<bool> markAsCompleted(String userId, String postId) async {
    setLoading(true);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('donation_posts')
          .doc(postId)
          .update({
        'status': 'completed',
        'completed_at': Timestamp.now(),
      });

      return true;
    } catch (e) {
      debugPrint('Error marking as completed: $e');
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

      await launchUrl(Uri.parse(whatsappUrl),
          mode: LaunchMode.externalApplication);
      return true;
    } catch (e) {
      debugPrint('Error opening WhatsApp: $e');
      return false;
    }
  }

  // Make phone call
  Future<bool> makePhoneCall(String phone) async {
    try {
      final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');

      if (cleanPhone.isEmpty) {
        throw Exception('Invalid phone number');
      }

      final Uri phoneUri = Uri(scheme: 'tel', path: cleanPhone);

      final launched =
          await launchUrl(phoneUri, mode: LaunchMode.externalApplication);
      return launched;
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
          'subject': 'Blood Donation Request - LifeLine',
          'body':
              'Hello,\n\nI found your blood donation request on the LifeLine app and would like to help. '
                  'Please let me know how I can assist.\n\nThank you.',
        },
      );

      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri, mode: LaunchMode.externalApplication);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error sending email: $e');
      return false;
    }
  }

  // Open map directions
  Future<bool> openMapDirections(String destination,
      {double? lat, double? lng}) async {
    try {
      if (destination.isEmpty) {
        throw Exception('Destination is empty');
      }

      Position? current;
      try {
        current = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
      } catch (e) {
        debugPrint('Could not get current location: $e');
      }

      String url;
      if (current != null && lat != null && lng != null) {
        url = 'https://www.google.com/maps/dir/?api=1'
            '&origin=${current.latitude},${current.longitude}'
            '&destination=$lat,$lng&travelmode=driving';
      } else if (current != null) {
        final dest = Uri.encodeComponent(destination);
        url = 'https://www.google.com/maps/dir/?api=1'
            '&origin=${current.latitude},${current.longitude}'
            '&destination=$dest&travelmode=driving';
      } else {
        final dest = Uri.encodeComponent(destination);
        url = 'https://www.google.com/maps/search/$dest';
      }

      final uri = Uri.parse(url);
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      return launched;
    } catch (e) {
      debugPrint('Error opening map: $e');
      return false;
    }
  }

  // Get donation posts stream with filters
  Stream<List<Map<String, dynamic>>> getFilteredDonationPostsStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .asyncMap((userSnapshot) async {
      List<Map<String, dynamic>> allPosts = [];

      for (var userDoc in userSnapshot.docs) {
        final userData = userDoc.data();
        final postsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userDoc.id)
            .collection('donation_posts')
            .orderBy('timestamp', descending: true)
            .get();

        for (var postDoc in postsSnapshot.docs) {
          final postData = postDoc.data();

          // Apply filters
          bool matchesCity = true;
          if (showOnlyCityDonations && currentUserCity != null) {
            final postCity = postData['city'] ?? '';
            matchesCity =
                postCity.toLowerCase() == currentUserCity!.toLowerCase();
          }

          bool matchesBlood = selectedBloodFilter == 'All' ||
              postData['blood_group'] == selectedBloodFilter;

          bool matchesSearch = searchQuery.isEmpty ||
              postData['blood_group']
                  .toString()
                  .toLowerCase()
                  .contains(searchQuery) ||
              postData['location']
                  .toString()
                  .toLowerCase()
                  .contains(searchQuery) ||
              (userData['username'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains(searchQuery);

          // Only include active and upcoming donations
          final donationTime =
              (postData['donation_time'] as Timestamp).toDate();
          bool isActive = donationTime
              .isAfter(DateTime.now().subtract(const Duration(hours: 24)));

          if (matchesCity && matchesBlood && matchesSearch && isActive) {
            allPosts.add({
              'postId': postDoc.id,
              'ownerId': userDoc.id,
              'userData': userData,
              'postData': postData,
            });
          }
        }
      }

      return allPosts;
    });
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
    final now = DateTime.now();
    final difference = donationTime.difference(now);

    if (difference.isNegative) {
      return 'Expired';
    } else if (difference.inHours < 24) {
      return 'Today';
    } else if (difference.inDays < 7) {
      return 'This Week';
    } else {
      return 'Upcoming';
    }
  }

  // Get donation status color
  Color getDonationStatusColor(DateTime donationTime) {
    final status = getDonationStatus(donationTime);
    switch (status) {
      case 'Expired':
        return Colors.red;
      case 'Today':
        return Colors.orange;
      case 'This Week':
        return Colors.blue;
      default:
        return AppColors.primary;
    }
  }

  // Extract city from address
  String extractCityFromAddress(String address) {
    if (address.isEmpty) return '';

    final parts = address.split(',');
    if (parts.isNotEmpty) {
      return parts.first.trim();
    }
    return address;
  }

  // Check if donation is in user's city
  bool isDonationInUserCity(String donationCity) {
    if (donationCity.isEmpty ||
        currentUserCity == null ||
        currentUserCity!.isEmpty) {
      return false;
    }

    return donationCity.toLowerCase() == currentUserCity!.toLowerCase();
  }

  // Calculate distance between two locations (simplified)
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000; // in km
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

  // Get relative time
  String getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);

    if (difference.isNegative) {
      return 'Expired';
    } else if (difference.inMinutes < 60) {
      return 'In ${difference.inMinutes} minutes';
    } else if (difference.inHours < 24) {
      return 'In ${difference.inHours} hours';
    } else if (difference.inDays < 7) {
      return 'In ${difference.inDays} days';
    } else {
      return formatDonationDate(dateTime);
    }
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
