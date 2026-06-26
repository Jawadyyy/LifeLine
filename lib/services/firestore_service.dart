import 'package:cloud_firestore/cloud_firestore.dart';

/// A saved emergency contact with the uid needed to route in-app SOS alerts.
class EmergencyContact {
  final String name;
  final String phone;
  final String uid;

  const EmergencyContact({
    required this.name,
    required this.phone,
    required this.uid,
  });

  bool get hasUid => uid.isNotEmpty;
}

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

  /// Returns emergency contacts with their stored Firebase uid (used to route
  /// SOS alerts into the in-app chat). `uid` may be empty for legacy contacts
  /// saved before uids were stored — callers should skip those.
  Future<List<EmergencyContact>> getEmergencyContactsDetailed(
      String userId) async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('contacts')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return EmergencyContact(
          name: (data['name'] as String?) ?? 'Contact',
          phone: (data['phone'] as String?) ?? '',
          uid: (data['uid'] as String?) ?? '',
        );
      }).toList();
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
