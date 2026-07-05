import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:lifeline/models/chat_message.dart';
import 'package:lifeline/services/media_upload_service.dart';

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

  /// Number of messages fetched per pagination chunk.
  static const int defaultPageSize = 30;

  /// Upper bound on how many not-yet-advanced messages a single receipt pass
  /// scans, so [_advanceIncoming] can't rescan an unbounded backlog. In steady
  /// state only a handful of messages sit in `sent`/`delivered`, so this cap is
  /// never hit; it only guards a large first-open backlog, which self-heals on
  /// the next receipt pass.
  static const int _receiptScanLimit = 100;

  DocumentReference<Map<String, dynamic>> _chatRef(String chatId) =>
      _db.collection('chats').doc(chatId);

  /// Stream of messages for [chatId], oldest first. Metadata changes are
  /// included so pending (offline-queued) writes surface a "sending" state and
  /// flip to "sent" once they reach the server.
  ///
  /// When [limit] is set, only the most recent [limit] messages are streamed
  /// (a sliding window from the newest). Widening [limit] loads older chunks
  /// while keeping new messages live. Newest are fetched first then reversed so
  /// the UI still receives them oldest-first.
  Stream<List<ChatMessage>> messages(String chatId, {int? limit}) {
    Query<Map<String, dynamic>> query = _chatRef(chatId)
        .collection('messages')
        .orderBy('time', descending: true);
    if (limit != null) query = query.limit(limit);
    return query
        .snapshots(includeMetadataChanges: true)
        .map((snap) => snap.docs.reversed.map(_fromDoc).toList());
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
      imageUrl: data['imageUrl'] as String?,
      audioUrl: data['audioUrl'] as String?,
      durationMs: (data['durationMs'] as num?)?.toInt(),
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
  /// [type] tags the message kind: `'text'` (default), `'emergency'` for SOS
  /// location alerts, `'image'` for a photo ([imageUrl]), or `'voice'` for an
  /// audio note ([audioUrl] + [durationMs]). The chat UI renders each
  /// distinctly. Text may be empty for media messages; the chat-list preview
  /// (`lastMessage`) falls back to a media label in that case.
  Future<void> send(
    String chatId,
    String contactUid,
    String text, {
    String type = 'text',
    String? liveSessionId,
    String? imageUrl,
    String? audioUrl,
    int? durationMs,
  }) async {
    final trimmed = text.trim();
    // A message needs either text or a media payload to be worth sending.
    final hasMedia = imageUrl != null || audioUrl != null;
    if (trimmed.isEmpty && !hasMedia) return;

    final preview = trimmed.isNotEmpty
        ? trimmed
        : imageUrl != null
            ? '📷 Photo'
            : audioUrl != null
                ? '🎤 Voice message'
                : '';

    final chatRef = _chatRef(chatId);
    final messageRef = chatRef.collection('messages').doc();
    final participants = [currentUid, contactUid]..sort();

    final batch = _db.batch();
    batch.set(
      chatRef,
      {
        'participants': participants,
        'lastMessage': preview,
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
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (audioUrl != null) 'audioUrl': audioUrl,
      if (durationMs != null) 'durationMs': durationMs,
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
        .limit(_receiptScanLimit)
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
  ChatProvider({
    required String currentUid,
    required this.contactUid,
    ChatService? service,
    MediaUploadService? uploads,
  })  : _service = service ?? ChatService(currentUid),
        _uploads = uploads ?? MediaUploadService(),
        chatId = ChatService.chatIdFor(currentUid, contactUid) {
    _subscribe();
  }

  final ChatService _service;
  final MediaUploadService _uploads;
  final String contactUid;
  final String chatId;

  static const int _pageSize = ChatService.defaultPageSize;

  StreamSubscription<List<ChatMessage>>? _subscription;
  List<ChatMessage> _messages = const [];
  String? _errorMessage;
  bool _loaded = false;
  int _limit = _pageSize;
  bool _hasMore = true;
  bool _loadingMore = false;

  /// Ids of incoming messages we've already fired a delivery receipt for, so a
  /// re-emitted snapshot (local write acks, metadata-only changes, unrelated
  /// updates) doesn't re-run the delivery query when nothing new arrived.
  final Set<String> _deliveredFor = <String>{};

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  String? get errorMessage => _errorMessage;

  /// True once the first snapshot (cached or server) has arrived. Lets the UI
  /// distinguish "still loading" from "genuinely empty conversation".
  bool get loaded => _loaded;

  /// Whether older messages may exist beyond the current window.
  bool get hasMore => _hasMore;

  /// Whether an older chunk is currently being fetched.
  bool get loadingMore => _loadingMore;

  void _subscribe() {
    _subscription?.cancel();
    _subscription = _service.messages(chatId, limit: _limit).listen(
      (msgs) {
        _messages = msgs;
        _errorMessage = null;
        _loaded = true;
        _loadingMore = false;
        // Window filled exactly to the limit ⇒ older messages likely remain.
        _hasMore = msgs.length >= _limit;
        notifyListeners();
        // Receipt: only fire when this snapshot actually carries a new incoming
        // message still in `sent` state. Re-emissions with nothing new (local
        // ack flips, metadata-only changes) are skipped, so the delivery query
        // no longer runs on every snapshot.
        final newIncoming = msgs.where((m) =>
            !m.isSent &&
            m.status == MessageStatus.sent &&
            !_deliveredFor.contains(m.id));
        if (newIncoming.isNotEmpty) {
          _deliveredFor.addAll(newIncoming.map((m) => m.id));
          unawaited(_service.markDelivered(chatId));
        }
      },
      onError: (Object error) {
        _errorMessage = 'Could not load messages';
        _loaded = true;
        _loadingMore = false;
        debugPrint('ChatProvider stream error: $error');
        notifyListeners();
      },
    );
  }

  /// Loads an older chunk by widening the live window by one page. New messages
  /// keep arriving in realtime; already-loaded ones stay visible meanwhile.
  void loadMore() {
    if (!_hasMore || _loadingMore) return;
    _loadingMore = true;
    _limit += _pageSize;
    notifyListeners();
    _subscribe();
  }

  Future<void> sendMessage(String text) async {
    try {
      await _service.send(chatId, contactUid, text);
    } catch (error) {
      _errorMessage = 'Message failed to send';
      debugPrint('ChatProvider send error: $error');
      notifyListeners();
    }
  }

  /// True while a picked image / recorded clip is uploading, so the input bar
  /// can show a spinner instead of letting the user fire duplicates.
  bool _sendingMedia = false;
  bool get sendingMedia => _sendingMedia;

  /// Uploads a picked image then sends it as a `type: 'image'` message.
  Future<void> sendImage(String localPath) async {
    _sendingMedia = true;
    notifyListeners();
    try {
      final url = await _uploads.uploadImage(localPath);
      if (url == null) {
        _errorMessage = 'Image upload failed';
      } else {
        await _service.send(chatId, contactUid, '',
            type: 'image', imageUrl: url);
      }
    } catch (error) {
      _errorMessage = 'Image failed to send';
      debugPrint('ChatProvider sendImage error: $error');
    } finally {
      _sendingMedia = false;
      notifyListeners();
    }
  }

  /// Uploads a recorded voice clip then sends it as a `type: 'voice'` message.
  Future<void> sendVoice(String localPath, int durationMs) async {
    _sendingMedia = true;
    notifyListeners();
    try {
      final url = await _uploads.uploadAudio(localPath, chatId: chatId);
      if (url == null) {
        _errorMessage = 'Voice upload failed';
      } else {
        await _service.send(chatId, contactUid, '',
            type: 'voice', audioUrl: url, durationMs: durationMs);
      }
    } catch (error) {
      _errorMessage = 'Voice note failed to send';
      debugPrint('ChatProvider sendVoice error: $error');
    } finally {
      _sendingMedia = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Keeps [ChatProvider] instances alive across navigation so reopening a chat
/// shows messages instantly instead of re-subscribing and flashing an empty
/// state. Providers are cached by chatId; the Firestore listener stays live
/// while cached. Call [clear] on sign-out to drop all subscriptions.
class ChatProviderCache {
  ChatProviderCache._();
  static final ChatProviderCache instance = ChatProviderCache._();

  final Map<String, ChatProvider> _providers = {};

  ChatProvider get(String currentUid, String contactUid) {
    final id = ChatService.chatIdFor(currentUid, contactUid);
    return _providers[id] ??=
        ChatProvider(currentUid: currentUid, contactUid: contactUid);
  }

  void clear() {
    for (final provider in _providers.values) {
      provider.dispose();
    }
    _providers.clear();
  }
}
