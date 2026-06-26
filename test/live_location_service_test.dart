import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeline/models/live_location_session.dart';
import 'package:lifeline/services/live_location_service.dart';

void main() {
  group('LiveLocationSession', () {
    LiveLocationSession build({
      required DateTime expiresAt,
      bool active = true,
    }) {
      return LiveLocationSession(
        id: 's1',
        ownerUid: 'owner',
        lat: 1,
        lng: 2,
        updatedAt: DateTime.now(),
        expiresAt: expiresAt,
        active: active,
      );
    }

    test('isLive true when active and not expired', () {
      final s = build(expiresAt: DateTime.now().add(const Duration(minutes: 5)));
      expect(s.isExpired, isFalse);
      expect(s.isLive, isTrue);
    });

    test('isLive false when expired', () {
      final s =
          build(expiresAt: DateTime.now().subtract(const Duration(minutes: 1)));
      expect(s.isExpired, isTrue);
      expect(s.isLive, isFalse);
    });

    test('isLive false when inactive even if not expired', () {
      final s = build(
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        active: false,
      );
      expect(s.isLive, isFalse);
    });
  });

  group('LiveLocationService firestore ops', () {
    late FakeFirebaseFirestore db;
    late LiveLocationService service;

    setUp(() {
      db = FakeFirebaseFirestore();
      service = LiveLocationService(firestore: db);
    });

    test('createSession writes an active session owned by the caller',
        () async {
      final id = await service.createSession(
        ownerUid: 'owner',
        lat: 10,
        lng: 20,
      );

      final doc = await db.collection('live_locations').doc(id).get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['ownerUid'], 'owner');
      expect(doc.data()!['active'], isTrue);
      expect(doc.data()!['lat'], 10);
      expect(doc.data()!['expiresAt'], isA<Timestamp>());
    });

    test('updatePosition moves the marker', () async {
      final id = await service.createSession(
          ownerUid: 'owner', lat: 0, lng: 0);
      await service.updatePosition(id, 5.5, 6.6);

      final session =
          await service.watch(id).firstWhere((s) => s != null);
      expect(session!.lat, 5.5);
      expect(session.lng, 6.6);
    });

    test('stopSession marks the session inactive', () async {
      final id = await service.createSession(
          ownerUid: 'owner', lat: 0, lng: 0);
      await service.stopSession(id);

      final session = await service.watch(id).firstWhere((s) => s != null);
      expect(session!.active, isFalse);
      expect(session.isLive, isFalse);
    });

    test('watch emits null for a missing session', () async {
      final session = await service.watch('does-not-exist').first;
      expect(session, isNull);
    });
  });
}
