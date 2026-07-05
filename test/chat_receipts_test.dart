import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeline/models/chat_message.dart';
import 'package:lifeline/services/chat_service.dart';

/// Wraps [ChatService] to count how many times the receipt queries run, so a
/// test can assert they aren't re-fired on snapshots that carry nothing new.
class _CountingChatService extends ChatService {
  _CountingChatService(super.uid, {super.firestore});

  int deliveredCalls = 0;
  int seenCalls = 0;

  @override
  Future<void> markDelivered(String chatId) {
    deliveredCalls++;
    return super.markDelivered(chatId);
  }

  @override
  Future<void> markSeen(String chatId) {
    seenCalls++;
    return super.markSeen(chatId);
  }
}

void main() {
  group('delivery / seen receipts', () {
    late FakeFirebaseFirestore db;
    final chatId = ChatService.chatIdFor('me', 'peer');

    setUp(() => db = FakeFirebaseFirestore());

    Future<MessageStatus> senderStatus() async {
      final msgs =
          await ChatService('me', firestore: db).messages(chatId).first;
      return msgs.first.status;
    }

    test('sent -> delivered -> seen', () async {
      await ChatService('me', firestore: db).send(chatId, 'peer', 'help');
      expect(await senderStatus(), MessageStatus.sent);

      await ChatService('peer', firestore: db).markDelivered(chatId);
      expect(await senderStatus(), MessageStatus.delivered);

      await ChatService('peer', firestore: db).markSeen(chatId);
      expect(await senderStatus(), MessageStatus.read); // 'seen'
    });

    test('markSeen jumps straight from sent to seen', () async {
      await ChatService('me', firestore: db).send(chatId, 'peer', 'help');
      await ChatService('peer', firestore: db).markSeen(chatId);
      expect(await senderStatus(), MessageStatus.read);
    });

    test('recipient does not mark its own outgoing messages', () async {
      await ChatService('peer', firestore: db).send(chatId, 'me', 'on my way');
      // peer marking delivered must not touch peer's own message
      await ChatService('peer', firestore: db).markDelivered(chatId);

      final peerMsgs =
          await ChatService('peer', firestore: db).messages(chatId).first;
      expect(peerMsgs.first.isSent, isTrue);
      expect(peerMsgs.first.status, MessageStatus.sent);
    });

    test('markDelivered fires once per new incoming message, not per snapshot',
        () async {
      final spy = _CountingChatService('me', firestore: db);
      final provider =
          ChatProvider(currentUid: 'me', contactUid: 'peer', service: spy);
      addTearDown(provider.dispose);

      // First incoming message: one delivery pass.
      await ChatService('peer', firestore: db).send(chatId, 'me', 'hi');
      await pumpEventQueue();
      expect(spy.deliveredCalls, 1);

      // 'me' replies. The stream re-emits (own local write ack + server ack),
      // but the snapshot carries no NEW incoming 'sent' message, so the
      // delivery query must NOT run again.
      await ChatService('me', firestore: db).send(chatId, 'peer', 'yo');
      await pumpEventQueue();
      expect(spy.deliveredCalls, 1);

      // A genuinely new incoming message triggers exactly one more pass.
      await ChatService('peer', firestore: db).send(chatId, 'me', 'you there?');
      await pumpEventQueue();
      expect(spy.deliveredCalls, 2);
    });
  });
}
