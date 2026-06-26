import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeline/components/chat_widgets.dart';
import 'package:lifeline/models/chat_message.dart';
import 'package:lifeline/services/chat_service.dart';
import 'package:lifeline/services/sos_followup.dart';

void main() {
  group('SosFollowup', () {
    tearDown(SosFollowup.clear);

    test('sendSafe delivers a safe message to each alerted contact', () async {
      final db = FakeFirebaseFirestore();
      SosFollowup.record(['a', 'b'], 'Ali');

      final count = await SosFollowup.sendSafe(
        currentUid: 'me',
        chatService: ChatService('me', firestore: db),
      );

      expect(count, 2);
      expect(SosFollowup.alertedContacts.value, isEmpty); // cleared after send

      final msgs = await ChatService('a', firestore: db)
          .messages(ChatService.chatIdFor('me', 'a'))
          .first;
      expect(msgs.first.type, 'safe');
      expect(msgs.first.isSafe, isTrue);
      expect(msgs.first.text, contains('Ali'));
    });

    test('sendSafe with no alerted contacts sends nothing', () async {
      final db = FakeFirebaseFirestore();
      final count = await SosFollowup.sendSafe(
        currentUid: 'me',
        chatService: ChatService('me', firestore: db),
      );
      expect(count, 0);
    });
  });

  testWidgets('safe message renders distinctly', (tester) async {
    final msg = ChatMessage(
      id: 's1',
      text: '✅ Ali is safe now.',
      isSent: false,
      time: DateTime(2024, 1, 1, 12),
      type: 'safe',
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: MessageBubble(message: msg))),
    );

    expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    expect(find.textContaining('is safe now'), findsOneWidget);
  });
}
