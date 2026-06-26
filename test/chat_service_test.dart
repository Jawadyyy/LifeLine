import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeline/models/chat_message.dart';
import 'package:lifeline/services/chat_service.dart';

void main() {
  group('ChatService', () {
    test('chatIdFor is deterministic regardless of argument order', () {
      expect(ChatService.chatIdFor('b', 'a'), 'a_b');
      expect(ChatService.chatIdFor('a', 'b'), 'a_b');
    });

    test('send persists a text message readable by the peer', () async {
      final db = FakeFirebaseFirestore();
      final chatId = ChatService.chatIdFor('me', 'peer');

      await ChatService('me', firestore: db).send(chatId, 'peer', 'hello');

      // Peer reads the same thread.
      final peerView = ChatService('peer', firestore: db);
      final msgs = await peerView.messages(chatId).first;
      expect(msgs, hasLength(1));
      expect(msgs.first.text, 'hello');
      expect(msgs.first.isSent, isFalse); // sent by 'me', not 'peer'
      expect(msgs.first.type, 'text');
    });

    test('emergency send carries type and liveSessionId', () async {
      final db = FakeFirebaseFirestore();
      final chatId = ChatService.chatIdFor('me', 'peer');

      await ChatService('me', firestore: db).send(
        chatId,
        'peer',
        '🚨 EMERGENCY',
        type: 'emergency',
        liveSessionId: 'sess-1',
      );

      final msgs = await ChatService('peer', firestore: db)
          .messages(chatId)
          .first;
      expect(msgs.first.type, 'emergency');
      expect(msgs.first.isEmergency, isTrue);
      expect(msgs.first.liveSessionId, 'sess-1');
    });

    test('empty messages are ignored', () async {
      final db = FakeFirebaseFirestore();
      final chatId = ChatService.chatIdFor('me', 'peer');
      await ChatService('me', firestore: db).send(chatId, 'peer', '   ');

      final msgs = await ChatService('me', firestore: db)
          .messages(chatId)
          .first;
      expect(msgs, isEmpty);
    });

    test("sender's own message round-trips as sent", () async {
      final db = FakeFirebaseFirestore();
      final chatId = ChatService.chatIdFor('me', 'peer');
      await ChatService('me', firestore: db).send(chatId, 'peer', 'hi');

      final msgs = await ChatService('me', firestore: db)
          .messages(chatId)
          .first;
      expect(msgs.first.isSent, isTrue);
      expect(msgs.first.status, MessageStatus.sent);
    });
  });
}
