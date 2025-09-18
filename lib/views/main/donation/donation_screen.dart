import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lifeline/constants/app_colors.dart';
import 'package:lifeline/views/main/donation/controller/donation_controller.dart';
import 'package:lifeline/views/main/donation/controller/donation_dialog_controller.dart';
import 'package:lifeline/services/global_data_service.dart';

class DonationScreen extends StatefulWidget {
  const DonationScreen({super.key});

  @override
  State<DonationScreen> createState() => _DonationScreenState();
}

class _DonationScreenState extends State<DonationScreen> {
  late DonationController _donationController;
  late DonationDialogController _dialogController;
  bool _showOnlyCityDonations = true;

  @override
  void initState() {
    super.initState();
    _donationController = DonationController();
    _dialogController = DonationDialogController(_donationController);
    _donationController.init();
    _refreshLocationData();
  }

  Future<void> _refreshLocationData() async {
    try {
      final globalDataService = GlobalDataService();
      await globalDataService.updateLocationData();
    } catch (e) {
      debugPrint('Error refreshing location data: $e');
    }
  }

  @override
  void dispose() {
    _donationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _donationController,
      child: Scaffold(
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
          iconTheme: const IconThemeData(
            color: AppColors.surface,
          ),
          actions: [
            IconButton(
              onPressed: () {
                setState(() {
                  _showOnlyCityDonations = !_showOnlyCityDonations;
                });
              },
              icon: Icon(
                _showOnlyCityDonations ? Icons.location_city : Icons.public,
                color: AppColors.surface,
              ),
              tooltip: _showOnlyCityDonations
                  ? 'Show all donations'
                  : 'Show city-only donations',
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _dialogController.showCreatePostDialog(context),
          backgroundColor: AppColors.primary,
          child: const Icon(Icons.add, color: AppColors.surface),
        ),
        backgroundColor: AppColors.surface,
        body: Column(children: [
          const SizedBox(height: 20),
          Text(
              _showOnlyCityDonations
                  ? "City Donation Requests"
                  : "All Donation Requests",
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
      ),
    );
  }

  Widget _buildAllDonationPosts() {
    return StreamBuilder<QuerySnapshot>(
      stream: _donationController.getDonationPostsStream(),
      builder: (context, userSnap) {
        if (!userSnap.hasData || userSnap.data!.docs.isEmpty) {
          return const Center(child: Text("No donation requests yet"));
        }

        // Check if there are any donations in user's city
        final userCity = _donationController.getCurrentUserCity();
        if (userCity.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.location_off,
                  size: 64,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  "Location not available",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Please enable location services to see donations in your city",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _refreshLocationData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.surface,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text("Refresh Location"),
                ),
              ],
            ),
          );
        }
        final users = userSnap.data!.docs;
        return ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: users.expand((userDoc) {
            final userData = userDoc.data() as Map<String, dynamic>;
            return [
              StreamBuilder<QuerySnapshot>(
                stream:
                    _donationController.getUserDonationPostsStream(userDoc.id),
                builder: (context, postSnap) {
                  if (!postSnap.hasData || postSnap.data!.docs.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  // Filter donations by city if enabled
                  final filteredPosts = _showOnlyCityDonations
                      ? postSnap.data!.docs.where((postDoc) {
                          final data = postDoc.data() as Map<String, dynamic>;
                          final donationLocation = data['location'] ?? '';
                          final userCity =
                              _donationController.getCurrentUserCity();

                          // Only show donations in user's city
                          return _donationController.isDonationInUserCity(
                              donationLocation, userCity);
                        }).toList()
                      : postSnap.data!.docs.toList();

                  if (filteredPosts.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  // Add city info header for first post
                  final isFirstPost = userDoc == users.first;
                  final cityHeader = isFirstPost
                      ? _buildCityHeader(userCity, _showOnlyCityDonations)
                      : null;

                  // Check if this is the first user and we have no donations in city
                  if (isFirstPost &&
                      filteredPosts.isEmpty &&
                      _showOnlyCityDonations) {
                    return Column(
                      children: [
                        cityHeader!,
                        _buildNoDonationsInCityMessage(userCity),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      if (cityHeader != null) cityHeader,
                      ...filteredPosts.map((postDoc) {
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
                    ],
                  );
                },
              )
            ];
          }).toList(),
        );
      },
    );
  }

  Widget _buildCityHeader(String city, bool showOnlyCity) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            showOnlyCity ? Icons.location_city : Icons.public,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            showOnlyCity
                ? "Showing donations in $city"
                : "Showing all donations",
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDonationsInCityMessage(String city) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.textSecondary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.bloodtype_outlined,
            size: 48,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            "No donations in $city",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "There are currently no blood donation requests in your city.\nBe the first to create one!",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(
    Map<String, dynamic> data,
    Map<String, dynamic> userData, {
    required String postId,
    required String ownerId,
    bool isDetailView = false,
  }) {
    final donationTime = (data['donation_time'] as Timestamp).toDate();
    final isUpcoming = _donationController.isUpcomingDonation(donationTime);
    final isOwner = _donationController.isPostOwner(ownerId);

    return GestureDetector(
      onTap: () {
        if (!isDetailView) {
          _dialogController.showPostDetailsDialog(
              context, data, userData, postId, ownerId);
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
                          _donationController.formatDonationTime(donationTime),
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status label for donation
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _donationController
                          .getDonationStatusColor(donationTime)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _donationController
                            .getDonationStatusColor(donationTime)
                            .withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _donationController.getDonationStatus(donationTime),
                      style: TextStyle(
                        color: _donationController
                            .getDonationStatusColor(donationTime),
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
                            color: AppColors.primary, size: 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: AppColors.textSecondary),
                        ),
                        elevation: 4,
                        color: AppColors.surface,
                        onSelected: (value) {
                          if (value == 'edit') {
                            _dialogController.showEditPostDialog(
                                context, data, ownerId, postId);
                          } else if (value == 'delete') {
                            _handleDeletePost(ownerId, postId);
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
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.tertiary,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 18,
                            color: AppColors.textSecondary,
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
              Column(
                children: [
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
                          onPressed: () =>
                              _handleContact(data, userData, donationTime),
                        ),
                      ),
                      const SizedBox(width: 8),
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
                          onPressed: () => _handleDirections(data['location']),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleDeletePost(String userId, String postId) async {
    final success = await _dialogController.showDeleteConfirmationDialog(
        context, userId, postId);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Post deleted successfully"),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  Future<void> _handleContact(
    Map<String, dynamic> data,
    Map<String, dynamic> userData,
    DateTime donationTime,
  ) async {
    final phoneRaw = userData['phone'] ?? '';

    if (phoneRaw.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("No phone number available for this user"),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.orange,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
      return;
    }

    final success = await _donationController.contactViaWhatsApp(
      phoneRaw,
      data['location'],
      donationTime,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              "Could not open WhatsApp. Please check if WhatsApp is installed."),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _handlePhoneCall(String phone) async {
    if (phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("No phone number available for this user"),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.orange,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
      return;
    }

    final success = await _donationController.makePhoneCall(phone);

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              "Could not make phone call. Please check your phone settings."),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _handleEmail(String email) async {
    if (email.isEmpty || !email.contains('@')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                const Text("No valid email address available for this user"),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.orange,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
      return;
    }

    final success = await _donationController.sendEmail(email);

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              "Could not open email app. Please check your email settings."),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _handleDirections(String destination) async {
    if (destination.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("No location information available"),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.orange,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
      return;
    }

    final success = await _donationController.openMapDirections(destination);

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              "Could not open Google Maps. Please check if Google Maps is installed."),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }
}
