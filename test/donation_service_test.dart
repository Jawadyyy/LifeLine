import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeline/services/donation_service.dart';

void main() {
  group('DonationService accept flow', () {
    late FakeFirebaseFirestore db;
    late DonationService service;

    setUp(() {
      db = FakeFirebaseFirestore();
      service = DonationService(firestore: db);
    });

    Future<String> seedPost(String owner) async {
      final ref = await db
          .collection('users')
          .doc(owner)
          .collection('donation_posts')
          .add({'blood_group': 'A+', 'status': 'active'});
      return ref.id;
    }

    test('a donor accepts an open request', () async {
      final postId = await seedPost('owner');

      final ok = await service.acceptPost(
        ownerUid: 'owner',
        postId: postId,
        donorUid: 'donor',
        donorName: 'Sara',
      );

      expect(ok, isTrue);
      final doc = await db
          .collection('users')
          .doc('owner')
          .collection('donation_posts')
          .doc(postId)
          .get();
      expect(doc.data()!['status'], 'accepted');
      expect(doc.data()!['acceptedBy'], 'donor');
      expect(doc.data()!['acceptedByName'], 'Sara');
    });

    test('a second acceptance is rejected and does not overwrite', () async {
      final postId = await seedPost('owner');
      await service.acceptPost(
          ownerUid: 'owner',
          postId: postId,
          donorUid: 'donor1',
          donorName: 'A');

      final ok = await service.acceptPost(
          ownerUid: 'owner',
          postId: postId,
          donorUid: 'donor2',
          donorName: 'B');

      expect(ok, isFalse);
      final doc = await db
          .collection('users')
          .doc('owner')
          .collection('donation_posts')
          .doc(postId)
          .get();
      expect(doc.data()!['acceptedBy'], 'donor1'); // unchanged
    });

    test('accepting a missing post returns false', () async {
      final ok = await service.acceptPost(
        ownerUid: 'owner',
        postId: 'nope',
        donorUid: 'donor',
        donorName: 'X',
      );
      expect(ok, isFalse);
    });

    test('watchAcceptedRequests surfaces accepted posts to the owner',
        () async {
      final postId = await seedPost('owner');
      await service.acceptPost(
          ownerUid: 'owner',
          postId: postId,
          donorUid: 'donor',
          donorName: 'Sara');

      final accepted =
          await service.watchAcceptedRequests('owner').first;
      expect(accepted, hasLength(1));
      expect(accepted.first['postId'], postId);
      expect(accepted.first['acceptedByName'], 'Sara');
    });
  });
}
