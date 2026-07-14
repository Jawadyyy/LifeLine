import 'package:lifeline/utils/logger.dart';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lifeline/services/chat_service.dart';

/// Tracks the contacts alerted by the most recent SOS so the user can send a
/// one-tap "I'm safe now" follow-up (`type:'safe'`) to the same threads.
///
/// State drives the contextual home banner. It is persisted to
/// SharedPreferences so the banner survives the app being killed (an emergency
/// is exactly when the OS is most likely to reclaim the process) and is
/// restored on next launch via [restore]. State older than [_ttl] is treated as
/// stale and dropped. [sendSafe] is the testable core (inject a [ChatService]
/// backed by a fake Firestore).
class SosFollowup {
  SosFollowup._();

  /// Uids alerted by the last SOS; empty when there is nothing to follow up.
  static final ValueNotifier<List<String>> alertedContacts =
      ValueNotifier(const []);

  static String _username = 'Your contact';

  static const _prefsKey = 'sos_followup_v1';
  // After this long an un-acted SOS follow-up is considered stale and cleared.
  static const _ttl = Duration(hours: 12);

  /// Records the alerted [uids] (and the sender's [username]) after an SOS, and
  /// persists them so the follow-up survives an app restart.
  static void record(List<String> uids, String username) {
    _username = username;
    alertedContacts.value = List.unmodifiable(uids);
    _persist(uids, username);
  }

  static void clear() {
    alertedContacts.value = const [];
    _clearPersisted();
  }

  /// Restores any non-stale follow-up state persisted by a previous session.
  /// Call once on app start (after the user is known).
  static Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt = DateTime.fromMillisecondsSinceEpoch(
          (data['savedAt'] as num?)?.toInt() ?? 0);
      if (DateTime.now().difference(savedAt) > _ttl) {
        await prefs.remove(_prefsKey);
        return;
      }
      final uids = (data['uids'] as List?)?.cast<String>() ?? const [];
      if (uids.isEmpty) return;
      _username = (data['username'] as String?) ?? _username;
      alertedContacts.value = List.unmodifiable(uids);
    } catch (e) {
      logDebug('SosFollowup.restore failed: $e');
    }
  }

  static Future<void> _persist(List<String> uids, String username) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode({
          'uids': uids,
          'username': username,
          'savedAt': DateTime.now().millisecondsSinceEpoch,
        }),
      );
    } catch (e) {
      logDebug('SosFollowup persist failed: $e');
    }
  }

  static Future<void> _clearPersisted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (e) {
      logDebug('SosFollowup clear-persisted failed: $e');
    }
  }

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
