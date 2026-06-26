import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:lifeline/constants/app_colors.dart';
import 'package:lifeline/services/global_data_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Typed contract the contacts screen exposes to its controller, replacing the
/// old `(state as dynamic).getField/setField` string reflection.
abstract class ContactsScreenView {
  BuildContext get context;
  List<Map<String, dynamic>> get contacts;
  set filteredContacts(List<Map<String, dynamic>> value);
  set isLoading(bool value);
}

class ContactsScreenController {
  final ContactsScreenView view;
  final void Function(void Function()) setStateFn;
  final GlobalDataService _globalDataService = GlobalDataService();

  ContactsScreenController(this.view, this.setStateFn);

  BuildContext get _context => view.context;

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  CollectionReference<Map<String, dynamic>> get _contactsRef {
    if (_currentUser == null) {
      throw Exception("User not authenticated");
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('contacts');
  }

  void filterContacts(String query) {
    final contacts = view.contacts;
    final filtered = contacts
        .where((contact) => (contact['name'] as String)
            .toLowerCase()
            .contains(query.toLowerCase()))
        .toList();
    setStateFn(() => view.filteredContacts = filtered);
  }

  Future<Map<String, Map<String, dynamic>>> _getRegisteredUsersMap() async {
    final usersSnapshot =
        await FirebaseFirestore.instance.collection('users').get();

    final map = <String, Map<String, dynamic>>{};
    for (final doc in usersSnapshot.docs) {
      final data = doc.data();
      data['uid'] = doc.id;
      final phone = data['phone'] as String?;
      if (phone != null && phone.isNotEmpty) {
        final normalized = _normalizeTo10Digits(phone);
        if (normalized.length == 10) {
          map[normalized] = data;
        }
      }
    }
    return map;
  }

  String _normalizeTo10Digits(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 10) {
      return digits.substring(digits.length - 10);
    }
    return digits;
  }

  Future<void> showContactsDialog() async {
    try {
      final permissionGranted = await FlutterContacts.requestPermission();
      if (!permissionGranted) {
        _showErrorSnackbar('Contacts permission denied');
        return;
      }

      _showLoadingSnackbar('Finding registered contacts...');

      final results = await Future.wait([
        FlutterContacts.getContacts(withProperties: true),
        _getRegisteredUsersMap(),
      ]);

      final List<Contact> phoneContacts = results[0] as List<Contact>;
      final Map<String, Map<String, dynamic>> registeredUsers =
          results[1] as Map<String, Map<String, dynamic>>;

      final filteredContacts = <Map<String, dynamic>>[];

      for (final contact in phoneContacts) {
        for (final phone in contact.phones) {
          final normalized = _normalizeTo10Digits(phone.number);
          if (registeredUsers.containsKey(normalized)) {
            filteredContacts.add({
              'contact': contact,
              'matchedPhone': phone.number,
              'userData': registeredUsers[normalized]!,
            });
            break;
          }
        }
      }

      // ignore: use_build_context_synchronously
      await showModalBottomSheet(
        context: _context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textGrey,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select a Contact',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      color: AppColors.textGrey,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filteredContacts.isNotEmpty
                    ? ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredContacts.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          color: AppColors.textGrey.withOpacity(0.1),
                        ),
                        itemBuilder: (context, index) {
                          final item = filteredContacts[index];
                          final Contact contact = item['contact'] as Contact;
                          final String matchedPhone =
                              item['matchedPhone'] as String;
                          final Map<String, dynamic> userData =
                              item['userData'] as Map<String, dynamic>;
                          final String? profileImageUrl =
                              userData['profileImageUrl'] as String?;

                          return buildContactListItem(
                            contact.displayName,
                            matchedPhone,
                            profileImageUrl: profileImageUrl,
                            onTap: () {
                              addContactToFirestore(
                                  contact, matchedPhone, userData);
                              Navigator.pop(context);
                            },
                          );
                        },
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_search,
                              size: 64,
                              color: AppColors.textGrey,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No registered users found\nin your contacts',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.textGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error in showContactsDialog: $e');
      _showErrorSnackbar('Error accessing contacts');
    }
  }

  Future<void> addContactToFirestore(Contact selectedContact,
      String matchedPhone, Map<String, dynamic> userData) async {
    if (_currentUser != null) {
      setStateFn(() => view.isLoading = true);
      try {
        final newContact = {
          'name': selectedContact.displayName,
          'phone': matchedPhone,
          'profileImageUrl': userData['profileImageUrl'] ?? '',
          'uid': userData['uid'] ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        };

        await _contactsRef.add(newContact);

        await _globalDataService.loadContactsData(forceReload: true);

        _showSuccessSnackbar('Contact added successfully');
      } catch (e) {
        _showErrorSnackbar('Failed to add contact: ${e.toString()}');
        debugPrint('Error adding contact: $e');
      } finally {
        setStateFn(() => view.isLoading = false);
      }
    }
  }

  Future<void> deleteContact(String contactId) async {
    if (_currentUser != null) {
      setStateFn(() => view.isLoading = true);
      try {
        await _contactsRef.doc(contactId).delete();

        await _globalDataService.loadContactsData(forceReload: true);

        _showSuccessSnackbar('Contact deleted');
      } catch (e) {
        _showErrorSnackbar('Failed to delete contact: ${e.toString()}');
        debugPrint('Error deleting contact: $e');
      } finally {
        setStateFn(() => view.isLoading = false);
      }
    }
  }

  Future<bool> showDeleteDialog(String contactId, String contactName) async {
    final confirmed = await showDialog<bool>(
      context: _context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            const SizedBox(width: 8),
            const Text(
              'Remove Contact',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
            children: [
              const TextSpan(text: 'Are you sure you want to remove '),
              TextSpan(
                text: contactName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const TextSpan(text: ' from your emergency contacts?'),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.only(right: 16, bottom: 12),
        actionsAlignment: MainAxisAlignment.end,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'CANCEL',
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
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'DELETE',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await deleteContact(contactId);
      return true;
    }

    return false;
  }

  // ─── Avatar Helper ──────────────────────────────────────────────────────────
  Widget _buildAvatar(
      {required double size,
      String? profileImageUrl,
      required String name,
      double fontSize = 18}) {
    final hasImage = profileImageUrl != null && profileImageUrl.isNotEmpty;

    if (hasImage) {
      return ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: Image.network(
            profileImageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                _letterAvatar(size: size, name: name, fontSize: fontSize),
          ),
        ),
      );
    }

    return _letterAvatar(size: size, name: name, fontSize: fontSize);
  }

  Widget _letterAvatar(
      {required double size, required String name, required double fontSize}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.2),
            AppColors.primary.withOpacity(0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget buildContactListItem(String name, String phone,
      {VoidCallback? onTap, String? profileImageUrl}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _buildAvatar(
        size: 48,
        profileImageUrl: profileImageUrl,
        name: name,
        fontSize: 18,
      ),
      title: Text(
        name,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        phone,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.textGrey,
        ),
      ),
      trailing: IconButton(
        icon: Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.add,
            color: AppColors.textTertiary,
            size: 20,
          ),
        ),
        onPressed: onTap,
      ),
    );
  }

  /// [onTap] is now a required callback — the page passes navigation here.
  /// The InkWell uses this directly, so no outer GestureDetector is needed.
  Widget buildContactCard(Map<String, dynamic> contact,
      {required VoidCallback onTap}) {
    final String? profileImageUrl = contact['profileImageUrl'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.textGrey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap, // ← directly uses the passed callback
          onLongPress: () => showDeleteDialog(contact['id'], contact['name']),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _buildAvatar(
                  size: 56,
                  profileImageUrl: profileImageUrl,
                  name: contact['name'] as String,
                  fontSize: 20,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact['name'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        contact['phone'],
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.phone_outlined,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  onPressed: () async {
                    final Uri phoneUri =
                        Uri(scheme: 'tel', path: contact['phone']);
                    if (!await launchUrl(phoneUri,
                        mode: LaunchMode.externalApplication)) {
                      debugPrint('Could not launch $phoneUri');
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(_context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(_context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showLoadingSnackbar(String message) {
    ScaffoldMessenger.of(_context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
