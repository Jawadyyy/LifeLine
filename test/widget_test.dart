// Smoke tests for LifeLine.
//
// `MyApp`'s home is `SplashScreen`, which talks to Firebase, so it can't be
// pumped without an initialized Firebase app. Instead we smoke-test
// self-contained widgets that exercise the app's shared UI building blocks.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lifeline/components/chat_widgets.dart';
import 'package:lifeline/models/chat_message.dart';

void main() {
  testWidgets('ChatEmptyState builds and shows the contact name',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChatEmptyState(contactName: 'Jane Doe', contactImageUrl: null),
        ),
      ),
    );

    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.textContaining('Start a conversation'), findsOneWidget);
  });

  testWidgets('MessageBubble renders sent message text',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            message: ChatMessage(
              id: '1',
              text: 'Hello there',
              isSent: true,
              time: DateTime(2024, 1, 1, 9, 30),
              status: MessageStatus.sent,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Hello there'), findsOneWidget);
  });
}
