import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeline/models/chat_message.dart';
import 'package:lifeline/services/chat_service.dart';

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
  });
}
