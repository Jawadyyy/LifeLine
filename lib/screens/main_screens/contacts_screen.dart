import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lifeline/components/bottom_navbar.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  _ContactsPageState createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  int _selectedIndex = 1;
  List<Map<String, dynamic>> contacts = [];
  List<Map<String, dynamic>> filteredContacts = [];
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();

  // Blue theme colors
  final Color _primaryColor = const Color(0xFF1976D2);
  final Color _primaryLightColor = const Color(0xFFE3F2FD);
  final Color _accentColor = const Color(0xFF2196F3);
  final Color _errorColor = const Color(0xFFD32F2F);
  final Color _successColor = const Color(0xFF388E3C);

  @override
  void initState() {
    super.initState();
    _loadStoredContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  User? get currentUser => FirebaseAuth.instance.currentUser;

  CollectionReference<Map<String, dynamic>> get contactsRef {
    if (currentUser == null) {
      throw Exception("User not authenticated");
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .collection('contacts');
  }

  Future<void> _loadStoredContacts() async {
    if (currentUser != null) {
      setState(() => _isLoading = true);
      try {
        final querySnapshot = await contactsRef.get();
        setState(() {
          contacts = querySnapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
          filteredContacts = contacts;
        });
      } catch (e) {
        _showErrorSnackbar('Failed to load contacts');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterContacts(String query) {
    setState(() {
      filteredContacts = contacts
          .where((contact) => (contact['name'] as String)
              .toLowerCase()
              .contains(query.toLowerCase()))
          .toList();
    });
  }

  Future<void> _showContactsDialog() async {
    try {
      bool permissionGranted = await FlutterContacts.requestPermission();
      if (!permissionGranted) {
        _showErrorSnackbar('Contacts permission denied');
        return;
      }

      List<Contact> phoneContacts = await FlutterContacts.getContacts(
        withProperties: true,
      );

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(
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
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Select a Contact",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: phoneContacts.isNotEmpty
                    ? ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: phoneContacts.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          color: Colors.grey.withOpacity(0.1),
                        ),
                        itemBuilder: (context, index) {
                          final contact = phoneContacts[index];
                          return _buildContactListItem(
                            contact.displayName,
                            contact.phones.isNotEmpty
                                ? contact.phones[0].number
                                : 'No phone number',
                            onTap: () {
                              _addContactToFirestore(contact);
                              Navigator.pop(context);
                            },
                          );
                        },
                      )
                    : Center(
                        child: Text(
                          "No contacts found",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      _showErrorSnackbar('Error accessing contacts');
    }
  }

  Future<void> _addContactToFirestore(Contact selectedContact) async {
    if (currentUser != null) {
      setState(() => _isLoading = true);
      try {
        final newContact = {
          'name': selectedContact.displayName,
          'phone': selectedContact.phones.isNotEmpty
              ? selectedContact.phones[0].number
              : 'No Phone Number',
          'createdAt': FieldValue.serverTimestamp(),
        };

        await contactsRef.add(newContact);
        await _loadStoredContacts();
        _showSuccessSnackbar('Contact added successfully');
      } catch (e) {
        _showErrorSnackbar('Failed to add contact');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteContact(String contactId) async {
    if (currentUser != null) {
      setState(() => _isLoading = true);
      try {
        await contactsRef.doc(contactId).delete();
        await _loadStoredContacts();
        _showSuccessSnackbar('Contact deleted');
      } catch (e) {
        _showErrorSnackbar('Failed to delete contact');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _showDeleteDialog(String contactId, String contactName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: Text("Remove $contactName from your emergency contacts?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "CANCEL",
              style: TextStyle(
                color: _primaryColor,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              "DELETE",
              style: TextStyle(color: _errorColor),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteContact(contactId);
      return true;
    }

    return false;
  }

  Widget _buildContactListItem(String name, String phone,
      {VoidCallback? onTap}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _primaryLightColor,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _primaryColor,
            ),
          ),
        ),
      ),
      title: Text(
        name,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(
        phone,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey,
        ),
      ),
      trailing: IconButton(
        icon: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _primaryColor,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.add,
            color: Colors.white,
            size: 20,
          ),
        ),
        onPressed: onTap,
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Emergency Circle',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: _primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showContactsDialog,
            tooltip: 'Add contact',
            color: Colors.white,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              controller: _searchController,
              onChanged: _filterContacts,
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                prefixIcon: Icon(Icons.search, color: _primaryColor),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          if (_isLoading)
            LinearProgressIndicator(
              minHeight: 2,
              color: _primaryColor,
              backgroundColor: _primaryLightColor,
            )
          else
            const SizedBox(height: 2),
          Expanded(
            child: filteredContacts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.contacts,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isEmpty
                              ? 'No emergency contacts'
                              : 'No matching contacts',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (_searchController.text.isEmpty) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _showContactsDialog,
                            style: TextButton.styleFrom(
                              foregroundColor: _primaryColor,
                            ),
                            child: const Text('Add your first contact'),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredContacts.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final contact = filteredContacts[index];
                      return Dismissible(
                        key: Key(contact['id']),
                        background: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: _errorColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: Icon(
                            Icons.delete,
                            color: _errorColor,
                          ),
                        ),
                        confirmDismiss: (direction) async {
                          return await _showDeleteDialog(
                              contact['id'], contact['name']);
                        },
                        child: _buildContactCard(contact),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }

  Widget _buildContactCard(Map<String, dynamic> contact) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _primaryLightColor,
                _primaryColor.withOpacity(0.3),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              contact['name'][0].toUpperCase(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _primaryColor,
              ),
            ),
          ),
        ),
        title: Text(
          contact['name'],
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        subtitle: Text(
          contact['phone'],
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        onTap: () {},
        onLongPress: () => _showDeleteDialog(contact['id'], contact['name']),
      ),
    );
  }
}
