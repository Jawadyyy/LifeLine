import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lifeline/constants/app_colors.dart';

class DonationScreen extends StatefulWidget {
  const DonationScreen({super.key});

  @override
  State<DonationScreen> createState() => _DonationScreenState();
}

class _DonationScreenState extends State<DonationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _selectedDateTime;
  String _selectedBloodGroup = 'O+';
  bool _isLoading = false;

  final List<String> _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-'
  ];

  Future<String> _getCurrentAddress() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('Location services are disabled');

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
    if (placemarks.isEmpty) throw Exception('Could not determine location');

    Placemark place = placemarks.first;

    return '${place.locality}, ${place.street}, ${place.country}';
  }

  void _showPostDetailsDialog(
    Map<String, dynamic> data,
    Map<String, dynamic> userData,
    String postId,
    String ownerId,
  ) {
    final donationTime = (data['donation_time'] as Timestamp).toDate();
    final isUpcoming = donationTime.isAfter(DateTime.now());

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          color: AppColors.surface.withOpacity(0.9),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const SizedBox(width: 24),
                    Expanded(
                      child: Text(
                        'Donation Details',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: AppColors.textGrey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.textGrey.withOpacity(0.2)),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDonorSection(userData, donationTime, isUpcoming),
                      const SizedBox(height: 24),
                      _buildDonationDetailsSection(data, donationTime),
                      const SizedBox(height: 24),
                      if (data['description'] != null &&
                          data['description'].toString().isNotEmpty)
                        _buildDescriptionSection(data['description']),
                      const SizedBox(height: 24),
                      _buildAdditionalInfoSection(data, userData),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          'Close',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final phoneRaw = userData['phone'] ?? '';
                          final sanitizedPhone =
                              phoneRaw.replaceAll(RegExp(r'[^\d+]'), '');

                          if (sanitizedPhone.length < 10) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text("Invalid phone number"),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                            return;
                          }

                          final message =
                              "Hi, I saw your blood donation request on LifeLine.\nLocation: ${data['location']}\nTime: ${DateFormat.yMd().add_jm().format(donationTime)}";
                          final url =
                              'https://wa.me/$sanitizedPhone?text=${Uri.encodeFull(message)}';

                          try {
                            await launch(url);
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text("Could not open WhatsApp"),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          foregroundColor: AppColors.surface,
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.message_outlined,
                              size: 20,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Contact',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDonorSection(
    Map<String, dynamic> userData,
    DateTime donationTime,
    bool isUpcoming,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Donor Information',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.background,
              backgroundImage: userData['profileImageUrl'] != null
                  ? NetworkImage(userData['profileImageUrl'])
                  : null,
              child: userData['profileImageUrl'] == null
                  ? Icon(Icons.person, color: AppColors.primary, size: 30)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userData['username'] ?? 'Anonymous Donor',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMMM d, y • h:mm a').format(donationTime),
                    style: TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 13,
                    ),
                  ),
                  if (isUpcoming) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'Upcoming Donation',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDonationDetailsSection(
    Map<String, dynamic> data,
    DateTime donationTime,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Donation Details',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.textGrey.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              _buildDetailRow(
                icon: Icons.bloodtype,
                label: 'Blood Group',
                value: data['blood_group'],
                isImportant: true,
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                icon: Icons.location_on_outlined,
                label: 'Location',
                value: data['location'],
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                icon: Icons.calendar_today_outlined,
                label: 'Date',
                value: DateFormat('MMMM d, y').format(donationTime),
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                icon: Icons.access_time_outlined,
                label: 'Time',
                value: DateFormat('h:mm a').format(donationTime),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionSection(String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Additional Information',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.textGrey.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdditionalInfoSection(
    Map<String, dynamic> data,
    Map<String, dynamic> userData,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contact Information',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey[200]!,
              width: 1,
            ),
          ),
          child: Column(children: [
            if (userData['phone'] != null && userData['phone'].isNotEmpty)
              _buildContactRow(
                icon: Icons.phone_outlined,
                value: userData['phone'],
                isPhone: true,
                mainColor: AppColors.primary,
              ),
            if (userData['email'] != null && userData['email'].isNotEmpty) ...[
              if (userData['phone'] != null && userData['phone'].isNotEmpty)
                const SizedBox(height: 12),
              _buildContactRow(
                icon: Icons.email_outlined,
                value: userData['email'],
                isEmail: true,
                mainColor: AppColors.primary,
              ),
            ],
          ]),
        ),
      ],
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool isImportant = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: isImportant ? AppColors.primary : AppColors.textGrey,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textGrey,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  color:
                      isImportant ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: isImportant ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContactRow({
    required IconData icon,
    required String value,
    bool isPhone = false,
    bool isEmail = false,
    required Color mainColor,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: AppColors.textGrey,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[800],
            ),
          ),
        ),
        if (isPhone)
          IconButton(
            icon: Icon(Icons.call, color: mainColor, size: 22),
            onPressed: () async {
              final Uri phoneUri = Uri(scheme: 'tel', path: value);
              if (!await launchUrl(phoneUri,
                  mode: LaunchMode.externalApplication)) {
                debugPrint('Could not launch $phoneUri');
              }
            },
          ),
        if (isEmail)
          IconButton(
            icon: Icon(Icons.email_outlined, color: mainColor, size: 22),
            onPressed: () async {
              final Uri emailUri = Uri(
                scheme: 'mailto',
                path: value,
                query:
                    'subject=Urgent Medical Assistance Needed&body=Hello $value,%0D%0A%0D%0AI found your contact on the LifeLine app and need urgent assistance. Please respond as soon as possible.%0D%0A%0D%0AThank you.',
              );
              if (!await launchUrl(emailUri,
                  mode: LaunchMode.externalApplication)) {
                debugPrint('Could not launch $emailUri');
              }
            },
          ),
      ],
    );
  }

  Future<void> _deletePost(String userId, String postId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text(
              "Delete Post",
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Text(
          "Are you sure you want to delete this donation post? This action cannot be undone.",
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
          ),
        ),
        actionsPadding: const EdgeInsets.only(right: 16, bottom: 12),
        actionsAlignment: MainAxisAlignment.end,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              "CANCEL",
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              "DELETE",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('donation_posts')
            .doc(postId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Post deleted successfully"),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.green[600],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Failed to delete post: ${e.toString()}"),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _showEditPostDialog(
      Map<String, dynamic> postData, String userId, String postId) {
    String bloodGroup = postData['blood_group'];
    DateTime donationTime = (postData['donation_time'] as Timestamp).toDate();
    String description = postData['description'] ?? '';
    final descController = TextEditingController(text: description);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 4,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      "Edit Donation Post",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    value: bloodGroup,
                    items: _bloodGroups
                        .map((bg) => DropdownMenuItem(
                              value: bg,
                              child: Text(bg),
                            ))
                        .toList(),
                    onChanged: (val) => setState(() => bloodGroup = val!),
                    decoration: InputDecoration(
                      labelText: 'Blood Group',
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                      floatingLabelStyle:
                          const TextStyle(color: AppColors.primary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.tertiary),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.tertiary),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                    ),
                    dropdownColor: AppColors.surface,
                    icon: const Icon(Icons.arrow_drop_down,
                        color: AppColors.primary),
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: donationTime,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                        builder: (context, child) => Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: AppColors.primary,
                              onPrimary: AppColors.surface,
                              surface: AppColors.surface,
                              onSurface: AppColors.textPrimary,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (date == null) return;

                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(donationTime),
                        builder: (context, child) => Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: AppColors.primary,
                              onPrimary: AppColors.surface,
                              surface: AppColors.surface,
                              onSurface: AppColors.textPrimary,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (time == null) return;

                      setState(() {
                        donationTime = DateTime(date.year, date.month, date.day,
                            time.hour, time.minute);
                      });
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Donation Time',
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                        floatingLabelStyle:
                            const TextStyle(color: AppColors.primary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.tertiary),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.tertiary),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.primary),
                        ),
                        filled: true,
                        fillColor: AppColors.background,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat.yMd().add_jm().format(donationTime),
                            style: TextStyle(color: Colors.grey[800]),
                          ),
                          const Icon(Icons.calendar_today,
                              color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: descController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Description (Optional)',
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                      floatingLabelStyle:
                          const TextStyle(color: AppColors.primary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.tertiary),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.tertiary),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(userId)
                            .collection('donation_posts')
                            .doc(postId)
                            .update({
                          'blood_group': bloodGroup,
                          'donation_time': donationTime,
                          'description': descController.text.trim(),
                        });

                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text("Post updated successfully"),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: AppColors.success,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        "SAVE CHANGES",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate() || _selectedDateTime == null) return;
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data();

      if (userData == null) throw Exception("User data not found");

      final currentAddress = await _getCurrentAddress();

      final post = {
        'blood_group': _selectedBloodGroup,
        'location': currentAddress,
        'donation_time': _selectedDateTime,
        'timestamp': Timestamp.now(),
        'description': _descriptionController.text.trim(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('donation_posts')
          .add(post);

      _locationController.clear();
      _descriptionController.clear();
      _selectedDateTime = null;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Donation post created successfully!"),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDateTime(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      initialDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.surface,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
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
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.surface,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (time == null) return;

    setState(() {
      _selectedDateTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Widget _buildPostCard(
    Map<String, dynamic> data,
    Map<String, dynamic> userData, {
    required String postId,
    required String ownerId,
    bool isDetailView = false,
  }) {
    final donationTime = (data['donation_time'] as Timestamp).toDate();
    final isUpcoming = donationTime.isAfter(DateTime.now());
    final isOwner = FirebaseAuth.instance.currentUser?.uid == ownerId;

    return GestureDetector(
      onTap: () {
        if (!isDetailView) {
          _showPostDetailsDialog(data, userData, postId, ownerId);
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: AppColors.surface.withOpacity(0.56),
        elevation: 2,
        shadowColor: AppColors.primary.withOpacity(0.15),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.grey[100],
                    backgroundImage: userData['profileImageUrl'] != null
                        ? NetworkImage(userData['profileImageUrl'])
                        : null,
                    child: userData['profileImageUrl'] == null
                        ? Icon(Icons.person, color: AppColors.primary, size: 24)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userData['username'] ?? 'Anonymous Donor',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('MMM d, y • h:mm a').format(donationTime),
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isUpcoming)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'Upcoming',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (isOwner)
                    Theme(
                      data: Theme.of(context).copyWith(
                        cardColor: AppColors.surface,
                      ),
                      child: PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert,
                            color: AppColors.tertiary, size: 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: AppColors.textSecondary!),
                        ),
                        elevation: 4,
                        color: AppColors.surface,
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showEditPostDialog(data, ownerId, postId);
                          } else if (value == 'delete') {
                            _deletePost(ownerId, postId);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem<String>(
                            value: 'edit',
                            child: Container(
                              color: AppColors.surface,
                              child: Row(
                                children: [
                                  Icon(Icons.edit,
                                      color: AppColors.primary, size: 20),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Edit',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Container(
                              color: AppColors.surface,
                              child: const Row(
                                children: [
                                  Icon(Icons.delete,
                                      color: AppColors.primary, size: 20),
                                  SizedBox(width: 12),
                                  Text(
                                    'Delete',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bloodtype,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          data['blood_group'],
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background, // was Colors.grey[50]
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.tertiary, // was Colors.grey[200]!
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 18,
                            color:
                                AppColors.textSecondary, // was Colors.grey[600]
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              data['location'],
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textMedium,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(
                        Icons.message_outlined,
                        size: 20,
                        color: AppColors.surface,
                      ),
                      label: const Text(
                        'Contact',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: AppColors.surface,
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                        shadowColor: AppColors.transparent,
                      ),
                      onPressed: () async {
                        final phoneRaw = userData['phone'] ?? '';
                        final sanitizedPhone =
                            phoneRaw.replaceAll(RegExp(r'[^\d+]'), '');

                        if (sanitizedPhone.length < 10) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text("Invalid phone number"),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                          return;
                        }

                        final message =
                            "Hi, I saw your blood donation request on LifeLine.\nLocation: ${data['location']}\nTime: ${DateFormat.yMd().add_jm().format(donationTime)}";
                        final url =
                            'https://wa.me/$sanitizedPhone?text=${Uri.encodeFull(message)}';

                        try {
                          await launch(url);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text("Could not open WhatsApp"),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(
                        Icons.map_outlined,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      label: Text(
                        'Directions',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                      onPressed: () async {
                        try {
                          final current = await Geolocator.getCurrentPosition(
                              desiredAccuracy: LocationAccuracy.high);
                          final dest = Uri.encodeComponent(data['location']);
                          final url =
                              'https://www.google.com/maps/dir/?api=1&origin=${current.latitude},${current.longitude}&destination=$dest&travelmode=driving';
                          await launch(url);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Map error: ${e.toString()}"),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAllDonationPosts() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, userSnap) {
        if (!userSnap.hasData || userSnap.data!.docs.isEmpty) {
          return const Center(child: Text("No donation requests yet"));
        }
        final users = userSnap.data!.docs;
        return ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: users.expand((userDoc) {
            final userData = userDoc.data() as Map<String, dynamic>;
            return [
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(userDoc.id)
                    .collection('donation_posts')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, postSnap) {
                  if (!postSnap.hasData || postSnap.data!.docs.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    children: postSnap.data!.docs.map((postDoc) {
                      final data = postDoc.data() as Map<String, dynamic>;
                      final postId = postDoc.id;
                      final ownerId = userDoc.id;

                      return _buildPostCard(
                        data,
                        userData,
                        postId: postId,
                        ownerId: ownerId,
                        isDetailView: false,
                      );
                    }).toList(),
                  );
                },
              )
            ];
          }).toList(),
        );
      },
    );
  }

  void _showCreatePostDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 4,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      "Create Donation Post",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    value: _selectedBloodGroup,
                    items: _bloodGroups
                        .map((bg) => DropdownMenuItem(
                              value: bg,
                              child: Text(bg),
                            ))
                        .toList(),
                    onChanged: (val) =>
                        setState(() => _selectedBloodGroup = val!),
                    decoration: InputDecoration(
                      labelText: 'Blood Group',
                      labelStyle: TextStyle(color: Colors.grey[600]),
                      floatingLabelStyle:
                          const TextStyle(color: AppColors.primary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.tertiary!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.tertiary!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                    ),
                    dropdownColor: AppColors.surface,
                    icon: const Icon(Icons.arrow_drop_down,
                        color: AppColors.primary),
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                      floatingLabelStyle:
                          const TextStyle(color: AppColors.primary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.tertiary),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.tertiary),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                      prefixIcon: const Icon(Icons.description,
                          color: AppColors.primary),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty
                        ? 'Enter a description'
                        : null,
                  ),
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: () => _pickDateTime(context),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Donation Time',
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                        floatingLabelStyle:
                            const TextStyle(color: AppColors.primary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.tertiary),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.tertiary),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.primary),
                        ),
                        filled: true,
                        fillColor: AppColors.background,
                        prefixIcon: const Icon(Icons.calendar_today,
                            color: AppColors.primary),
                      ),
                      child: Text(
                        _selectedDateTime == null
                            ? 'Select date and time'
                            : DateFormat.yMd()
                                .add_jm()
                                .format(_selectedDateTime!),
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitPost,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
                          : const Text(
                              "CREATE POST",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Blood Donation',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.surface,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(
          color: AppColors.surface,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreatePostDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: AppColors.surface),
      ),
      backgroundColor: AppColors.surface,
      body: Column(children: [
        const SizedBox(height: 20),
        const Text("Active Donation Requests",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => setState(() {}),
            color: AppColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 80),
              child: _buildAllDonationPosts(),
            ),
          ),
        )
      ]),
    );
  }
}
