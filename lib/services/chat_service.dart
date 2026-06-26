import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:lifeline/models/chat_message.dart';

/// Realtime one-to-one chat backed by Firestore.
///
/// Data model:
///   chats/{chatId}                       chatId = sorted(uidA, uidB).join('_')
///     participants: [uidA, uidB]
///     lastMessage: String
///     lastTime: Timestamp
///   chats/{chatId}/messages/{msgId}
///     text: String
///     senderId: uid
///     time: Timestamp
///     status: 'sent' | 'delivered'
class ChatService {
  ChatService(this.currentUid, {FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final String currentUid;
  final FirebaseFirestore _db;

  /// Deterministic chat id shared by both participants.
  static String chatIdFor(String a, String b) {
    final ids = [a, b]..sort();
    return ids.join('_');
  }

  DocumentReference<Map<String, dynamic>> _chatRef(String chatId) =>
      _db.collection('chats').doc(chatId);

  /// Stream of messages for [chatId], oldest first. Metadata changes are
  /// included so pending (offline-queued) writes surface a "sending" state and
  /// flip to "sent" once they reach the server.
  Stream<List<ChatMessage>> messages(String chatId) {
    return _chatRef(chatId)
        .collection('messages')
        .orderBy('time')
        .snapshots(includeMetadataChanges: true)
        .map((snap) => snap.docs.map(_fromDoc).toList());
  }

  ChatMessage _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final rawTime = data['time'];
    // `time` is null for the brief window between a local write and the
    // server resolving the serverTimestamp; fall back to "now" until then.
    final time = rawTime is Timestamp ? rawTime.toDate() : DateTime.now();
    final isSent = data['senderId'] == currentUid;

    // A local write not yet acknowledged by the server is still queued.
    final status = doc.metadata.hasPendingWrites
        ? MessageStatus.sending
        : _statusFrom(data['status'] as String?);

    return ChatMessage(
      id: doc.id,
      text: (data['text'] as String?) ?? '',
      isSent: isSent,
      time: time,
      status: status,
      type: (data['type'] as String?) ?? 'text',
      liveSessionId: data['liveSessionId'] as String?,
    );
  }

  static MessageStatus _statusFrom(String? raw) {
    switch (raw) {
      case 'seen':
        return MessageStatus.read;
      case 'delivered':
        return MessageStatus.delivered;
      default:
        return MessageStatus.sent;
    }
  }

  /// Adds a message and updates the parent chat metadata atomically.
  ///
  /// [type] tags the message kind: `'text'` (default) or `'emergency'` for SOS
  /// location alerts, which the chat UI renders distinctly.
  Future<void> send(
    String chatId,
    String contactUid,
    String text, {
    String type = 'text',
    String? liveSessionId,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final chatRef = _chatRef(chatId);
    final messageRef = chatRef.collection('messages').doc();
    final participants = [currentUid, contactUid]..sort();

    final batch = _db.batch();
    batch.set(
      chatRef,
      {
        'participants': participants,
        'lastMessage': trimmed,
        'lastTime': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(messageRef, {
      'text': trimmed,
      'senderId': currentUid,
      'time': FieldValue.serverTimestamp(),
      'status': 'sent',
      'type': type,
      if (liveSessionId != null) 'liveSessionId': liveSessionId,
    });
    await batch.commit();
  }

  /// Recipient-side: advances the peer's incoming messages from `sent` to
  /// `delivered` (call when the realtime listener first receives them).
  Future<void> markDelivered(String chatId) =>
      _advanceIncoming(chatId, from: const ['sent'], to: 'delivered');

  /// Recipient-side: advances incoming messages to `seen` (call when the chat
  /// screen is opened).
  Future<void> markSeen(String chatId) =>
      _advanceIncoming(chatId, from: const ['sent', 'delivered'], to: 'seen');

  /// Updates the status of messages NOT sent by the current user. senderId is
  /// filtered client-side so no composite index is required.
  Future<void> _advanceIncoming(
    String chatId, {
    required List<String> from,
    required String to,
  }) async {
    final snap = await _chatRef(chatId)
        .collection('messages')
        .where('status', whereIn: from)
        .get();

    final targets =
        snap.docs.where((d) => d.data()['senderId'] != currentUid).toList();
    if (targets.isEmpty) return;

    final batch = _db.batch();
    for (final doc in targets) {
      batch.update(doc.reference, {'status': to});
    }
    await batch.commit();
  }
}

/// Provider that exposes the Firestore message stream to the chat UI.
class ChatProvider extends ChangeNotifier {
  ChatProvider({required String currentUid, required this.contactUid})
      : _service = ChatService(currentUid),
        chatId = ChatService.chatIdFor(currentUid, contactUid) {
    _subscription = _service.messages(chatId).listen(
      (msgs) {
        _messages = msgs;
        _errorMessage = null;
        notifyListeners();
        // Receipt: incoming messages are now delivered to this device.
        unawaited(_service.markDelivered(chatId));
      },
      onError: (Object error) {
        _errorMessage = 'Could not load messages';
        debugPrint('ChatProvider stream error: $error');
        notifyListeners();
      },
    );
  }

  final ChatService _service;
  final String contactUid;
  final String chatId;

  StreamSubscription<List<ChatMessage>>? _subscription;
  List<ChatMessage> _messages = const [];
  String? _errorMessage;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  String? get errorMessage => _errorMessage;

  Future<void> sendMessage(String text) async {
    try {
      await _service.send(chatId, contactUid, text);
    } catch (error) {
      _errorMessage = 'Message failed to send';
      debugPrint('ChatProvider send error: $error');
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
