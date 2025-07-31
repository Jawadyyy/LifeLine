import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<String>> getEmergencyContacts(String userId) async {
    try {
      var contactsSnapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('contacts')
          .get();

      var phoneNumbers = contactsSnapshot.docs.map((doc) {
        return doc['phone'] as String;
      }).toList();

      return phoneNumbers;
    } catch (e) {
      print("Error fetching contacts: $e");
      return [];
    }
  }

  Future<void> addEmergencyContact(
      String userId, String name, String phone) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('contacts')
          .add({'name': name, 'phone': phone});
      print("Contact added successfully.");
    } catch (e) {
      print("Error adding contact: $e");
    }
  }
}

Future<void> fetchContacts() async {
  final userId = FirebaseAuth.instance.currentUser?.uid;

  if (userId != null) {
    final contacts = await FirestoreService().getEmergencyContacts(userId);
    print("Emergency contacts: $contacts");
  } else {
    print("User is not authenticated");
  }
}
