import 'package:lifeline/utils/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:lifeline/services/chat_service.dart';

/// Tracks the contacts alerted by the most recent SOS so the user can send a
/// one-tap "I'm safe now" follow-up (`type:'safe'`) to the same threads.
///
/// Process-global state ([alertedContacts]) drives the contextual home button;
/// [sendSafe] is the testable core (inject a [ChatService] backed by a fake
/// Firestore).
class SosFollowup {
  SosFollowup._();

  /// Uids alerted by the last SOS; empty when there is nothing to follow up.
  static final ValueNotifier<List<String>> alertedContacts =
      ValueNotifier(const []);

  static String _username = 'Your contact';

  /// Records the alerted [uids] (and the sender's [username]) after an SOS.
  static void record(List<String> uids, String username) {
    _username = username;
    alertedContacts.value = List.unmodifiable(uids);
  }

  static void clear() => alertedContacts.value = const [];

  /// Sends an "I'm safe" message to every previously-alerted contact and clears
  /// the follow-up state. Returns how many were sent.
  static Future<int> sendSafe({
    required String currentUid,
    ChatService? chatService,
  }) async {
    final uids = alertedContacts.value;
    if (uids.isEmpty) return 0;

    final chat = chatService ?? ChatService(currentUid);
    final message =
        '✅ $_username is safe now. The earlier emergency is resolved.';

    var sent = 0;
    for (final uid in uids) {
      final chatId = ChatService.chatIdFor(currentUid, uid);
      try {
        await chat.send(chatId, uid, message, type: 'safe');
        sent++;
      } catch (e) {
        logDebug('safe follow-up to $uid failed: $e');
      }
    }
    clear();
    return sent;
  }
}
