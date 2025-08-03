import 'package:cloud_firestore/cloud_firestore.dart';

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
    } catch (e) {
      return;
    }
  }
}
