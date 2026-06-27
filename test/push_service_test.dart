import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lifeline/services/push_service.dart';

void main() {
  group('PushService token storage', () {
    late FakeFirebaseFirestore db;
    late PushService push;

    setUp(() {
      db = FakeFirebaseFirestore();
      push = PushService(firestore: db);
    });

    Future<List<dynamic>> tokensFor(String uid) async {
      final snap = await db.collection('users').doc(uid).get();
      return (snap.data()?['fcmTokens'] as List<dynamic>?) ?? const [];
    }

    test('saveToken creates and adds the token', () async {
      await push.saveToken('u1', 'tok-A');
      expect(await tokensFor('u1'), ['tok-A']);
    });

    test('saveToken is multi-device safe and dedups (arrayUnion)', () async {
      await push.saveToken('u1', 'tok-A');
      await push.saveToken('u1', 'tok-B'); // second device
      await push.saveToken('u1', 'tok-A'); // refresh of same token
      final tokens = await tokensFor('u1');
      expect(tokens, containsAll(['tok-A', 'tok-B']));
      expect(tokens.length, 2);
    });

    test('removeToken drops only that device token', () async {
      await push.saveToken('u1', 'tok-A');
      await push.saveToken('u1', 'tok-B');
      await push.removeToken('u1', 'tok-A');
      expect(await tokensFor('u1'), ['tok-B']);
    });

    test('removeToken on a missing doc is a no-op', () async {
      await push.removeToken('ghost', 'tok-X');
      expect(await tokensFor('ghost'), isEmpty);
    });
  });

  group('PushService.notify payload', () {
    test('posts to /api/send with bearer token and correct body', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response('{"sent":2,"failed":1}', 200);
      });

      final push = PushService(
        httpClient: client,
        firestore: FakeFirebaseFirestore(),
        relayBaseUrl: 'https://relay.example.com/', // trailing slash stripped
        idTokenProvider: () async => 'id-token-123',
      );

      final result = await push.notify(
        recipientUid: 'recip',
        kind: 'emergency',
        chatId: 'a_b',
        payload: {'senderUid': 'me', 'senderName': 'Ali', 'sessionId': 's1'},
      );

      expect(result, isNotNull);
      expect(result!.sent, 2);
      expect(result.failed, 1);

      expect(captured.url.toString(), 'https://relay.example.com/api/send');
      expect(captured.headers['Authorization'], 'Bearer id-token-123');
      expect(captured.headers['Content-Type'], contains('application/json'));

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['recipientUid'], 'recip');
      expect(body['kind'], 'emergency');
      expect(body['chatId'], 'a_b');
      expect(body['payload']['senderName'], 'Ali');
      expect(body['payload']['sessionId'], 's1');
    });

    test('returns null when no relay URL is configured', () async {
      final client = MockClient((req) async => http.Response('{}', 200));
      final push = PushService(
        httpClient: client,
        firestore: FakeFirebaseFirestore(),
        relayBaseUrl: '',
        idTokenProvider: () async => 'id-token',
      );
      expect(
        await push.notify(recipientUid: 'r', kind: 'safe'),
        isNull,
      );
    });

    test('returns null when there is no ID token', () async {
      final client = MockClient((req) async => http.Response('{}', 200));
      final push = PushService(
        httpClient: client,
        firestore: FakeFirebaseFirestore(),
        relayBaseUrl: 'https://relay.example.com',
        idTokenProvider: () async => null,
      );
      expect(
        await push.notify(recipientUid: 'r', kind: 'safe'),
        isNull,
      );
    });

    test('returns null on a non-200 relay response', () async {
      final client = MockClient((req) async => http.Response('nope', 403));
      final push = PushService(
        httpClient: client,
        firestore: FakeFirebaseFirestore(),
        relayBaseUrl: 'https://relay.example.com',
        idTokenProvider: () async => 'id-token',
      );
      expect(
        await push.notify(recipientUid: 'r', kind: 'emergency', chatId: 'a_b'),
        isNull,
      );
    });
  });

  group('PushService.routeFor tap routing', () {
    test('emergency routes to chat with sender details', () {
      final dest = PushService.routeFor({
        'type': 'emergency',
        'senderUid': 'u9',
        'senderName': 'Sara',
        'chatId': 'me_u9',
        'sessionId': 'sess1',
      });
      expect(dest.type, PushDestinationType.chat);
      expect(dest.peerUid, 'u9');
      expect(dest.peerName, 'Sara');
      expect(dest.chatId, 'me_u9');
      expect(dest.sessionId, 'sess1');
    });

    test('safe also routes to chat', () {
      final dest = PushService.routeFor({'type': 'safe', 'senderUid': 'u1'});
      expect(dest.type, PushDestinationType.chat);
      expect(dest.peerUid, 'u1');
    });

    test('donation_accept routes to donation', () {
      final dest = PushService.routeFor({'type': 'donation_accept'});
      expect(dest.type, PushDestinationType.donation);
    });

    test('unknown / missing type routes to unknown', () {
      expect(PushService.routeFor({}).type, PushDestinationType.unknown);
      expect(
        PushService.routeFor({'type': 'something'}).type,
        PushDestinationType.unknown,
      );
    });
  });
}
