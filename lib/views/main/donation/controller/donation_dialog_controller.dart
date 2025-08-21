import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lifeline/constants/app_colors.dart';
import 'package:lifeline/views/main/donation/controller/donation_controller.dart';

class DonationDialogController {
  final DonationController _donationController;

  DonationDialogController(this._donationController);

  // Show post details dialog
  void showPostDetailsDialog(
    BuildContext context,
    Map<String, dynamic> data,
    Map<String, dynamic> userData,
    String postId,
    String ownerId,
  ) {
    final donationTime = (data['donation_time'] as Timestamp).toDate();
    final isUpcoming = _donationController.isUpcomingDonation(donationTime);

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
              _buildDialogHeader(context, 'Donation Details'),
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
              _buildDialogActions(context, data, donationTime, userData),
            ],
          ),
        ),
      ),
    );
  }

  // Show edit post dialog
  void showEditPostDialog(
    BuildContext context,
    Map<String, dynamic> postData,
    String userId,
    String postId,
  ) {
    String bloodGroup = postData['blood_group'];
    DateTime donationTime = (postData['donation_time'] as Timestamp).toDate();
    String description = postData['description'] ?? '';
    final descController = TextEditingController(text: description);

    // Create variables to track the updated values
    DateTime updatedDonationTime = donationTime;
    String updatedBloodGroup = bloodGroup;

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
                  _buildEditDialogHeader(context),
                  const SizedBox(height: 24),
                  _buildBloodGroupDropdown(
                    setState,
                    updatedBloodGroup,
                    (newBloodGroup) {
                      setState(() {
                        updatedBloodGroup = newBloodGroup;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildDateTimePicker(
                    context,
                    setState,
                    updatedDonationTime,
                    (newDateTime) {
                      setState(() {
                        updatedDonationTime = newDateTime;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildDescriptionField(descController),
                  const SizedBox(height: 32),
                  _buildSaveButton(context, userId, postId, updatedBloodGroup,
                      updatedDonationTime, descController),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Show create post dialog
  void showCreatePostDialog(BuildContext context) {
    // Create a persistent form key
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing by tapping outside
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
            child: StatefulBuilder(
              builder: (context, setState) => Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCreateDialogHeader(context),
                    const SizedBox(height: 24),
                    _buildCreateBloodGroupDropdown(context, setState),
                    const SizedBox(height: 20),
                    _buildCreateDescriptionField(),
                    const SizedBox(height: 20),
                    _buildCreateDateTimePicker(context, setState),
                    const SizedBox(height: 32),
                    _buildCreatePostButton(context, formKey),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Show delete confirmation dialog
  Future<bool> showDeleteConfirmationDialog(
    BuildContext context,
    String userId,
    String postId,
  ) async {
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
      return await _donationController.deletePost(userId, postId);
    }
    return false;
  }

  // Build dialog header
  Widget _buildDialogHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const SizedBox(width: 24),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textGrey),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // Build edit dialog header
  Widget _buildEditDialogHeader(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 24),
        const Expanded(
          child: Center(
            child: Text(
              "Edit Donation Post",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: AppColors.textGrey),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  // Build create dialog header
  Widget _buildCreateDialogHeader(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 24),
        const Expanded(
          child: Center(
            child: Text(
              "Create Donation Post",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: AppColors.textGrey),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  // Build blood group dropdown for edit dialog
  Widget _buildBloodGroupDropdown(StateSetter setState, String bloodGroup,
      Function(String) onBloodGroupChanged) {
    return DropdownButtonFormField<String>(
      value: bloodGroup,
      items: _donationController.bloodGroups
          .map((bg) => DropdownMenuItem(
                value: bg,
                child: Text(bg),
              ))
          .toList(),
      onChanged: (val) => setState(() => onBloodGroupChanged(val!)),
      decoration: InputDecoration(
        labelText: 'Blood Group',
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        floatingLabelStyle: const TextStyle(color: AppColors.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.tertiary),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.tertiary),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        filled: true,
        fillColor: AppColors.background,
      ),
      dropdownColor: AppColors.surface,
      icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
      style: const TextStyle(color: AppColors.textPrimary),
    );
  }

  // Build blood group dropdown for create dialog
  Widget _buildCreateBloodGroupDropdown(
      BuildContext context, StateSetter setState) {
    return DropdownButtonFormField<String>(
      value: _donationController.selectedBloodGroup,
      items: _donationController.bloodGroups
          .map((bg) => DropdownMenuItem(
                value: bg,
                child: Text(bg),
              ))
          .toList(),
      onChanged: (val) {
        _donationController.updateBloodGroup(val!);
        setState(() {}); // Force rebuild to show updated value
      },
      decoration: InputDecoration(
        labelText: 'Blood Group',
        labelStyle: const TextStyle(color: Colors.grey),
        floatingLabelStyle: const TextStyle(color: AppColors.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.tertiary),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.tertiary),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.tertiary),
        ),
        filled: true,
        fillColor: AppColors.background,
      ),
      dropdownColor: AppColors.surface,
      icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
      style: const TextStyle(color: AppColors.textPrimary),
    );
  }

  // Build date time picker for edit dialog
  Widget _buildDateTimePicker(
    BuildContext context,
    StateSetter setState,
    DateTime donationTime,
    Function(DateTime) onDateTimeChanged,
  ) {
    return InkWell(
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

        final newDateTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );

        setState(() {
          onDateTimeChanged(newDateTime);
        });
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Donation Time',
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          floatingLabelStyle: const TextStyle(color: AppColors.primary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.tertiary),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.tertiary),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
          filled: true,
          fillColor: AppColors.background,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DateFormat.yMd().add_jm().format(donationTime),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            const Icon(Icons.calendar_today, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  // Build date time picker for create dialog
  Widget _buildCreateDateTimePicker(
      BuildContext context, StateSetter setState) {
    return InkWell(
      onTap: () async {
        await _donationController.pickDateTime(context);
        // Force rebuild of the dialog to show updated date/time
        setState(() {});
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Donation Time',
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          floatingLabelStyle: const TextStyle(color: AppColors.primary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.tertiary),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.tertiary),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
          filled: true,
          fillColor: AppColors.background,
          prefixIcon:
              const Icon(Icons.calendar_today, color: AppColors.primary),
        ),
        child: Text(
          _donationController.formattedDateTime,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
      ),
    );
  }

  // Build description field for edit dialog
  Widget _buildDescriptionField(TextEditingController controller) {
    return TextFormField(
      controller: controller,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: 'Description (Optional)',
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        floatingLabelStyle: const TextStyle(color: AppColors.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.tertiary),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.tertiary),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        filled: true,
        fillColor: AppColors.background,
      ),
    );
  }

  // Build description field for create dialog
  Widget _buildCreateDescriptionField() {
    return TextFormField(
      controller: _donationController.descriptionController,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: 'Description',
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        floatingLabelStyle: const TextStyle(color: AppColors.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.tertiary),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.tertiary),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        filled: true,
        fillColor: AppColors.background,
        prefixIcon: const Icon(Icons.description, color: AppColors.primary),
      ),
      validator: (val) =>
          val == null || val.trim().isEmpty ? 'Enter a description' : null,
    );
  }

  // Build save button for edit dialog
  Widget _buildSaveButton(
    BuildContext context,
    String userId,
    String postId,
    String bloodGroup,
    DateTime donationTime,
    TextEditingController descController,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          final success = await _donationController.updatePost(
            userId,
            postId,
            bloodGroup: bloodGroup,
            donationTime: donationTime,
            description: descController.text,
          );

          if (success && context.mounted) {
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
    );
  }

  // Build create post button
  Widget _buildCreatePostButton(
      BuildContext context, GlobalKey<FormState> formKey) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _donationController.isLoading
            ? null
            : () async {
                // Validate form before submitting
                if (formKey.currentState?.validate() == true) {
                  final success = await _donationController.submitPost();
                  if (success && context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Donation post created successfully!"),
                        backgroundColor: AppColors.primary,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: _donationController.isLoading
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
    );
  }

  // Build dialog actions
  Widget _buildDialogActions(
    BuildContext context,
    Map<String, dynamic> data,
    DateTime donationTime,
    Map<String, dynamic> userData,
  ) {
    return Container(
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
                side: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
              child: const Text(
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
                final success = await _donationController.contactViaWhatsApp(
                  phoneRaw,
                  data['location'],
                  donationTime,
                );

                if (!success && context.mounted) {
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
                  SizedBox(width: 8),
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
    );
  }

  // Build donor section
  Widget _buildDonorSection(
    Map<String, dynamic> userData,
    DateTime donationTime,
    bool isUpcoming,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Donor Information',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 12),
        Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.background,
              backgroundImage: userData['profileImageUrl'] != null
                  ? NetworkImage(userData['profileImageUrl'])
                  : null,
              child: userData['profileImageUrl'] == null
                  ? const Icon(Icons.person, color: AppColors.primary, size: 30)
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
                    _donationController.formatDonationTime(donationTime),
                    style: const TextStyle(
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
                      child: const Text(
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

  // Build donation details section
  Widget _buildDonationDetailsSection(
    Map<String, dynamic> data,
    DateTime donationTime,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
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
                value: _donationController.formatDonationDate(donationTime),
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                icon: Icons.access_time_outlined,
                label: 'Time',
                value: _donationController.formatDonationTimeOnly(donationTime),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Build description section
  Widget _buildDescriptionSection(String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
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
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  // Build additional info section
  Widget _buildAdditionalInfoSection(
    Map<String, dynamic> data,
    Map<String, dynamic> userData,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
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
                SizedBox(height: 12),
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

  // Build detail row
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
                style: const TextStyle(
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

  // Build contact row
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
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (isPhone)
          IconButton(
            icon: Icon(Icons.call, color: mainColor, size: 22),
            onPressed: () => _donationController.makePhoneCall(value),
          ),
        if (isEmail)
          IconButton(
            icon: Icon(Icons.email_outlined, color: mainColor, size: 22),
            onPressed: () => _donationController.sendEmail(value),
          ),
      ],
    );
  }
}
