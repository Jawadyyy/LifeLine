import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth package

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Fetch the emergency contacts for the user
  Future<List<String>> getEmergencyContacts(String userId) async {
    try {
      // Access the subcollection 'contacts' under the user's document
      var contactsSnapshot = await _db.collection('users').doc(userId).collection('contacts').get();

      // Extract phone numbers from the documents
      var phoneNumbers = contactsSnapshot.docs.map((doc) {
        return doc['phone'] as String;
      }).toList();

      return phoneNumbers;
    } catch (e) {
      print("Error fetching contacts: $e");
      return [];
    }
  }

  // Add a contact to the user's subcollection
  Future<void> addEmergencyContact(String userId, String name, String phone) async {
    try {
      await _db.collection('users').doc(userId).collection('contacts').add({
        'name': name,
        'phone': phone
      });
      print("Contact added successfully.");
    } catch (e) {
      print("Error adding contact: $e");
    }
  }
}

// Example usage:
Future<void> fetchContacts() async {
  final userId = FirebaseAuth.instance.currentUser?.uid;

  if (userId != null) {
    final contacts = await FirestoreService().getEmergencyContacts(userId);
    print("Emergency contacts: $contacts");
  } else {
    print("User is not authenticated");
  }
}
