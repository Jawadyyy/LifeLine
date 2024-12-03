import 'package:flutter/material.dart';
import 'package:lifeline/components/bottom_navbar.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ContactsPageState createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  int _selectedIndex = 1;
  List<Map<String, String>> contacts = [];
  List<Map<String, String>> filteredContacts = [];

  @override
  void initState() {
    super.initState();
    _fetchContactsFromBackend();
  }

  void _fetchContactsFromBackend() async {
    await Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        contacts = [];
        filteredContacts = contacts;
      });
    });
  }

  void _filterContacts(String query) {
    setState(() {
      filteredContacts = contacts.where((contact) => contact['name']!.toLowerCase().contains(query.toLowerCase())).toList();
    });
  }

  void _addContact(Map<String, String> newContact) {
    setState(() {
      contacts.add(newContact);
      filteredContacts = contacts;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Circle'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              _addContact({
                "name": "New Contact",
                "image": "https://via.placeholder.com/150"
              });
            },
            child: const Text(
              'Add Contact',
              style: TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
      body: Container(
        color: Colors.white,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                onChanged: _filterContacts,
                decoration: InputDecoration(
                  hintText: 'Search Here',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  filled: true,
                  fillColor: Colors.grey[200],
                ),
              ),
            ),
            Expanded(
              child: filteredContacts.isEmpty
                  ? const Center(child: Text('No contacts available'))
                  : ListView.separated(
                      itemCount: filteredContacts.length,
                      separatorBuilder: (context, index) => const Divider(
                        color: Colors.grey,
                        height: 1,
                      ),
                      itemBuilder: (context, index) {
                        final contact = filteredContacts[index];
                        return Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            leading: CircleAvatar(
                              radius: 30,
                              backgroundImage: NetworkImage(
                                contact['image'] ?? 'https://via.placeholder.com/150',
                              ),
                              child: contact['image'] == null ? const Icon(Icons.person, size: 30) : null,
                            ),
                            title: Text(
                              contact['name']!,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios),
                            onTap: () {},
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
