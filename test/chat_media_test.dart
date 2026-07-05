import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeline/services/chat_service.dart';

void main() {
  group('media messages', () {
    late FakeFirebaseFirestore db;
    final chatId = ChatService.chatIdFor('me', 'peer');

    setUp(() => db = FakeFirebaseFirestore());

    test('image message round-trips type + imageUrl', () async {
      await ChatService('me', firestore: db).send(
        chatId,
        'peer',
        '',
        type: 'image',
        imageUrl: 'https://img.example/pic.jpg',
      );

      final msgs = await ChatService('peer', firestore: db).messages(chatId).first;
      expect(msgs, hasLength(1));
      final m = msgs.first;
      expect(m.isImage, isTrue);
      expect(m.type, 'image');
      expect(m.imageUrl, 'https://img.example/pic.jpg');
      expect(m.isSent, isFalse); // sent by 'me', viewed by 'peer'
    });

    test('image message sets a photo preview as lastMessage', () async {
      await ChatService('me', firestore: db).send(
        chatId,
        'peer',
        '',
        type: 'image',
        imageUrl: 'https://img.example/pic.jpg',
      );

      final snap = await db.doc('chats/$chatId').get();
      expect(snap.data()!['lastMessage'], '📷 Photo');
    });

    test('voice message round-trips type + audioUrl + duration', () async {
      await ChatService('me', firestore: db).send(
        chatId,
        'peer',
        '',
        type: 'voice',
        audioUrl: 'https://audio.example/clip.m4a',
        durationMs: 4200,
      );

      final msgs = await ChatService('peer', firestore: db).messages(chatId).first;
      final m = msgs.first;
      expect(m.isVoice, isTrue);
      expect(m.type, 'voice');
      expect(m.audioUrl, 'https://audio.example/clip.m4a');
      expect(m.durationMs, 4200);
      expect(m.duration, const Duration(milliseconds: 4200));
    });

    test('voice message sets a voice preview as lastMessage', () async {
      await ChatService('me', firestore: db).send(
        chatId,
        'peer',
        '',
        type: 'voice',
        audioUrl: 'https://audio.example/clip.m4a',
        durationMs: 4200,
      );

      final snap = await db.doc('chats/$chatId').get();
      expect(snap.data()!['lastMessage'], '🎤 Voice message');
    });

    test('empty message with no media is ignored', () async {
      await ChatService('me', firestore: db).send(chatId, 'peer', '   ');
      final msgs = await ChatService('me', firestore: db).messages(chatId).first;
      expect(msgs, isEmpty);
    });

    test('text alongside an image is preserved and used as preview', () async {
      await ChatService('me', firestore: db).send(
        chatId,
        'peer',
        'look at this',
        type: 'image',
        imageUrl: 'https://img.example/pic.jpg',
      );

      final msgs = await ChatService('peer', firestore: db).messages(chatId).first;
      expect(msgs.first.text, 'look at this');
      final snap = await db.doc('chats/$chatId').get();
      expect(snap.data()!['lastMessage'], 'look at this');
    });
  });
}
