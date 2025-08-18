import 'package:flutter/material.dart';
import 'package:lifeline/constants/app_colors.dart';
import 'package:lifeline/views/main/contact/controller/contacts_screen_controller.dart';
import 'package:lifeline/services/global_data_service.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  _ContactsPageState createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  List<Map<String, dynamic>> contacts = [];
  List<Map<String, dynamic>> filteredContacts = [];
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();
  ContactsScreenController? controller;
  final GlobalDataService _globalDataService = GlobalDataService();

  @override
  void initState() {
    super.initState();
    controller = ContactsScreenController(this, setState);

    // Listen to global data service for contacts updates
    _globalDataService.addListener(_onGlobalDataChanged);

    // Get contacts from global service (already loaded)
    _updateContactsFromGlobal();
  }

  void _onGlobalDataChanged() {
    if (mounted) {
      _updateContactsFromGlobal();
    }
  }

  void _updateContactsFromGlobal() {
    setState(() {
      contacts = _globalDataService.contacts;
      filteredContacts = contacts;
      _isLoading = _globalDataService.isLoadingContacts;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _globalDataService.removeListener(_onGlobalDataChanged);
    super.dispose();
  }

  // Expose fields for controller access
  dynamic getField(String name) => {
        'contacts': contacts,
        'filteredContacts': filteredContacts,
        '_isLoading': _isLoading,
      }[name];

  void setField(String name, dynamic value) {
    switch (name) {
      case 'contacts':
        contacts = value as List<Map<String, dynamic>>;
        break;
      case 'filteredContacts':
        filteredContacts = value as List<Map<String, dynamic>>;
        break;
      case '_isLoading':
        _isLoading = value as bool;
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Emergency Circle',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textTertiary,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: controller?.showContactsDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: AppColors.textTertiary),
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: controller?.filterContacts,
                decoration: InputDecoration(
                  hintText: 'Search contacts...',
                  prefixIcon: Icon(Icons.search, color: AppColors.primary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  filled: true,
                  fillColor: AppColors.surface,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_isLoading)
            LinearProgressIndicator(
              minHeight: 2,
              color: AppColors.primary,
              backgroundColor: AppColors.primary.withOpacity(0.1),
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
                          color: AppColors.textGrey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isEmpty
                              ? 'No emergency contacts'
                              : 'No matching contacts',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textGrey,
                          ),
                        ),
                        if (_searchController.text.isEmpty) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: controller?.showContactsDialog,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
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
                            color: AppColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: Icon(
                            Icons.delete,
                            color: AppColors.error,
                          ),
                        ),
                        confirmDismiss: (direction) async {
                          if (controller == null) return false;
                          return await controller!
                              .showDeleteDialog(contact['id'], contact['name']);
                        },
                        child: controller?.buildContactCard(contact) ??
                            ListTile(
                              title: Text(contact['name'] ?? ''),
                              subtitle: Text(contact['phone'] ?? ''),
                            ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
