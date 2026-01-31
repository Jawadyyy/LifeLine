import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:lifeline/constants/app_colors.dart';
import 'package:lifeline/services/global_data_service.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactsScreenController {
  final State state;
  final void Function(void Function()) setStateFn;
  final GlobalDataService _globalDataService = GlobalDataService();

  ContactsScreenController(this.state, this.setStateFn);

  BuildContext get _context => state.context;

  T _getField<T>(String name) {
    return (state as dynamic).getField(name) as T;
  }

  void _setField(String name, dynamic value) {
    (state as dynamic).setField(name, value);
  }

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
    final contacts = _getField<List<Map<String, dynamic>>>('contacts');
    final filtered = contacts
        .where((contact) => (contact['name'] as String)
            .toLowerCase()
            .contains(query.toLowerCase()))
        .toList();
    setStateFn(() => _setField('filteredContacts', filtered));
  }

  /// Fetches all registered phone numbers from the 'users' collection in Firestore.
  Future<Set<String>> _getRegisteredNumbers() async {
    final usersSnapshot =
        await FirebaseFirestore.instance.collection('users').get();

    final registeredNumbers = <String>{};
    for (final doc in usersSnapshot.docs) {
      final phone = doc.data()['phone'] as String?;
      if (phone != null && phone.isNotEmpty) {
        // Normalize: strip all non-digit characters, then store last 10 digits
        final digits = phone.replaceAll(RegExp(r'\D'), '');
        if (digits.length >= 10) {
          registeredNumbers.add(digits.substring(digits.length - 10));
        }
      }
    }
    return registeredNumbers;
  }

  /// Normalizes a phone number to its last 10 digits for comparison.
  String _normalizeTo10Digits(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 10) {
      return digits.substring(digits.length - 10);
    }
    return digits; // return as-is if shorter than 10 digits
  }

  Future<void> showContactsDialog() async {
    try {
      final permissionGranted = await FlutterContacts.requestPermission();
      if (!permissionGranted) {
        _showErrorSnackbar('Contacts permission denied');
        return;
      }

      // Show loading indicator while fetching data
      _showLoadingSnackbar('Finding registered contacts...');

      // Fetch both in parallel for speed
      final results = await Future.wait([
        FlutterContacts.getContacts(withProperties: true),
        _getRegisteredNumbers(),
      ]);

      final List<Contact> phoneContacts = results[0] as List<Contact>;
      final Set<String> registeredNumbers = results[1] as Set<String>;

      // Filter: keep only contacts that have at least one number registered in Firebase
      final filteredContacts = <Map<String, dynamic>>[];

      for (final contact in phoneContacts) {
        for (final phone in contact.phones) {
          final normalized = _normalizeTo10Digits(phone.number);
          if (registeredNumbers.contains(normalized)) {
            filteredContacts.add({
              'contact': contact,
              'matchedPhone': phone.number,
            });
            break; // one match per contact is enough
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

                          return buildContactListItem(
                            contact.displayName,
                            matchedPhone,
                            onTap: () {
                              // Build a temporary Contact-like object with the matched phone
                              addContactToFirestore(contact, matchedPhone);
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
      // ignore: avoid_print
      print('Error in showContactsDialog: $e');
      _showErrorSnackbar('Error accessing contacts');
    }
  }

  Future<void> addContactToFirestore(
      Contact selectedContact, String matchedPhone) async {
    if (_currentUser != null) {
      setStateFn(() => _setField('_isLoading', true));
      try {
        final newContact = {
          'name': selectedContact.displayName,
          'phone': matchedPhone,
          'createdAt': FieldValue.serverTimestamp(),
        };

        await _contactsRef.add(newContact);

        // Reload contacts through GlobalDataService
        await _globalDataService.loadContactsData(forceReload: true);

        _showSuccessSnackbar('Contact added successfully');
      } catch (e) {
        _showErrorSnackbar('Failed to add contact: ${e.toString()}');
        // ignore: avoid_print
        print('Error adding contact: $e');
      } finally {
        setStateFn(() => _setField('_isLoading', false));
      }
    }
  }

  Future<void> deleteContact(String contactId) async {
    if (_currentUser != null) {
      setStateFn(() => _setField('_isLoading', true));
      try {
        await _contactsRef.doc(contactId).delete();

        // Reload contacts through GlobalDataService
        await _globalDataService.loadContactsData(forceReload: true);

        _showSuccessSnackbar('Contact deleted');
      } catch (e) {
        _showErrorSnackbar('Failed to delete contact: ${e.toString()}');
        // ignore: avoid_print
        print('Error deleting contact: $e');
      } finally {
        setStateFn(() => _setField('_isLoading', false));
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

  Widget buildContactListItem(String name, String phone,
      {VoidCallback? onTap}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
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

  Widget buildContactCard(Map<String, dynamic> contact) {
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
          onTap: () {},
          onLongPress: () => showDeleteDialog(contact['id'], contact['name']),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
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
                      (contact['name'] as String).isNotEmpty
                          ? (contact['name'] as String)[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
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
                      // ignore: avoid_print
                      print('Could not launch $phoneUri');
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
