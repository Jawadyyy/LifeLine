import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore ops for the donation request → accept flow (no paid notify; the
/// requester is notified in-app by listening to their own posts).
///
/// Posts live at `users/{ownerUid}/donation_posts/{postId}` with a `status`
/// of `active` → `accepted` → `completed`. A donor accepting writes only the
/// accept fields (`acceptedBy`, `acceptedByName`, `acceptedAt`, `status`).
class DonationService {
  DonationService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _postRef(
          String ownerUid, String postId) =>
      _db
          .collection('users')
          .doc(ownerUid)
          .collection('donation_posts')
          .doc(postId);

  /// A donor accepts an open request. No-op (returns false) if the post is
  /// already accepted or missing.
  Future<bool> acceptPost({
    required String ownerUid,
    required String postId,
    required String donorUid,
    required String donorName,
  }) async {
    final ref = _postRef(ownerUid, postId);
    final snap = await ref.get();
    if (!snap.exists) return false;

    final data = snap.data()!;
    final already = data['acceptedBy'];
    if (already != null && (already as String).isNotEmpty) return false;

    await ref.update({
      'acceptedBy': donorUid,
      'acceptedByName': donorName,
      'acceptedAt': FieldValue.serverTimestamp(),
      'status': 'accepted',
    });
    return true;
  }

  /// Owner marks an accepted request fulfilled.
  Future<void> completePost(String ownerUid, String postId) =>
      _postRef(ownerUid, postId).update({'status': 'completed'});

  /// Stream of the owner's posts that have just been accepted by a donor — the
  /// in-app "your request was accepted" notification source.
  Stream<List<Map<String, dynamic>>> watchAcceptedRequests(String ownerUid) {
    return _db
        .collection('users')
        .doc(ownerUid)
        .collection('donation_posts')
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {'postId': d.id, ...d.data()})
            .toList());
  }
}
