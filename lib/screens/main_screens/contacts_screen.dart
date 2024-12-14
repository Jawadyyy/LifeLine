import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
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

  @override
  void initState() {
    super.initState();
    _loadStoredContacts();
  }

  // Get the current authenticated user
  User? get currentUser => FirebaseAuth.instance.currentUser;

  // Reference to the Firestore user's contacts subcollection
  CollectionReference<Map<String, dynamic>> get contactsRef {
    if (currentUser == null) {
      throw Exception("User not authenticated");
    }
    return FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).collection('contacts');
  }

  // Load contacts from the subcollection in Firestore
  void _loadStoredContacts() async {
    if (currentUser != null) {
      final querySnapshot = await contactsRef.get();
      setState(() {
        contacts = querySnapshot.docs.map((doc) => doc.data()).toList();
        filteredContacts = contacts;
      });
    }
  }

  // Filter contacts based on the search query
  void _filterContacts(String query) {
    setState(() {
      filteredContacts = contacts.where((contact) => (contact['name'] as String).toLowerCase().contains(query.toLowerCase())).toList();
    });
  }

  // Show a dialog to select a phone contact
  void _showContactsDialog() async {
    try {
      bool permissionGranted = await FlutterContacts.requestPermission();
      if (!permissionGranted) {
        print('Permission to access contacts denied');
        return;
      }

      // Fetch phone contacts
      List<Contact> phoneContacts = await FlutterContacts.getContacts(
        withProperties: true,
      );

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: Colors.white,
            title: Row(
              children: [
                const Icon(Icons.contact_phone, color: Colors.blue),
                const SizedBox(width: 10),
                Text(
                  "Select a Contact",
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              height: 350,
              width: 300,
              child: phoneContacts.isNotEmpty
                  ? ListView.separated(
                      itemCount: phoneContacts.length,
                      separatorBuilder: (context, index) => Divider(
                        color: Colors.grey[300],
                        thickness: 1,
                        height: 10,
                      ),
                      itemBuilder: (context, index) {
                        final contact = phoneContacts[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                          leading: CircleAvatar(
                            backgroundColor: Colors.blueAccent,
                            child: Text(
                              contact.displayName[0].toUpperCase(),
                              style: GoogleFonts.nunito(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          title: Text(
                            contact.displayName,
                            style: GoogleFonts.nunito(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: const Icon(Icons.add_circle, color: Colors.green),
                          onTap: () {
                            _addContactToFirestore(contact);
                            Navigator.pop(context);
                          },
                        );
                      },
                    )
                  : Center(
                      child: Text(
                        "No contacts found.",
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "Cancel",
                  style: GoogleFonts.nunito(
                    color: Colors.red,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      print("Error fetching contacts: $e");
    }
  }

  // Add a selected contact to the Firestore subcollection
  void _addContactToFirestore(Contact selectedContact) async {
    if (currentUser != null) {
      final newContact = {
        'name': selectedContact.displayName,
        'phone': selectedContact.phones.isNotEmpty ? selectedContact.phones[0].number : 'No Phone Number',
      };

      // Add the contact as a new document in the subcollection
      await contactsRef.add(newContact);

      // Update the local state
      setState(() {
        contacts.add(newContact);
        filteredContacts = contacts;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Padding(
          padding: const EdgeInsets.only(left: 6.0),
          child: Text(
            'Emergency Circle',
            style: GoogleFonts.nunito(color: Colors.black),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _showContactsDialog,
            child: Text(
              'Add Contact',
              style: GoogleFonts.nunito(color: Colors.blue),
            ),
          ),
        ],
      ),
      body: Container(
        color: Colors.grey[100],
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                onChanged: _filterContacts,
                decoration: InputDecoration(
                  hintText: 'Search Contacts',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14.0),
                ),
              ),
            ),
            Expanded(
              child: filteredContacts.isEmpty
                  ? Center(
                      child: Text(
                        'No contacts available',
                        style: GoogleFonts.nunito(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredContacts.length,
                      itemBuilder: (context, index) {
                        final contact = filteredContacts[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
                          child: Container(
                            padding: const EdgeInsets.all(12.0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(
                                color: Colors.grey[300]!,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  height: 50,
                                  width: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.blue[100],
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.blue,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      contact['name'],
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      contact['phone'],
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
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
}
