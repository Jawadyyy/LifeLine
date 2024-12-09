import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth package

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Fetch the emergency contacts for the user
  Future<List<String>> getEmergencyContacts(String userId) async {
    try {
      var docSnapshot = await _db.collection('contacts').doc(userId).get();
      if (docSnapshot.exists) {
        // Extract phone numbers from the `contacts` array
        var contactList = docSnapshot['contacts'] as List<dynamic>;
        var phoneNumbers = contactList.map((contact) {
          return contact['phone'] as String;
        }).toList();
        return phoneNumbers;
      } else {
        print("User document does not exist.");
        return [];
      }
    } catch (e) {
      print("Error fetching contacts: $e");
      return [];
    }
  }
}

// Example usage:
Future<void> fetchContacts() async {
  final userId = FirebaseAuth
      .instance.currentUser?.uid; // Get the authenticated user's UID

  if (userId != null) {
    final contacts = await FirestoreService().getEmergencyContacts(userId);
    print("Emergency contacts: $contacts");
  } else {
    print("User is not authenticated");
  }
}
