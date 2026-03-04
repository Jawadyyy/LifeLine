import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:lifeline/models/chat_message.dart';
import 'package:uuid/uuid.dart';

// ─── Simulated replies (swap _simulateReply body for your real socket/API) ───
const _replies = [
  'Got it, thanks!',
  'Sure, let me check.',
  'On my way!',
  'Can you call me?',
  'That sounds great 👍',
  'Just a moment.',
  'Everything okay?',
  'Roger that.',
  'I\'ll be right there.',
];

// ─── Service ──────────────────────────────────────────────────────────────────
class ChatService {
  final _uuid = const Uuid();
  final _incoming = StreamController<ChatMessage>.broadcast();
  final _typing = StreamController<bool>.broadcast();

  Stream<ChatMessage> get incomingMessages => _incoming.stream;
  Stream<bool> get typingStream => _typing.stream;

  Future<ChatMessage> send(String text) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final msg = ChatMessage(
      id: _uuid.v4(),
      text: text,
      isSent: true,
      time: DateTime.now(),
      status: MessageStatus.sent,
    );
    _simulateReply();
    return msg;
  }

  void _simulateReply() async {
    await Future.delayed(Duration(milliseconds: 700 + Random().nextInt(600)));
    _typing.add(true);
    await Future.delayed(Duration(milliseconds: 1000 + Random().nextInt(800)));
    _typing.add(false);
    _incoming.add(ChatMessage(
      id: _uuid.v4(),
      text: _replies[Random().nextInt(_replies.length)],
      isSent: false,
      time: DateTime.now(),
      status: MessageStatus.delivered,
    ));
  }

  void dispose() {
    _incoming.close();
    _typing.close();
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────
class ChatProvider extends ChangeNotifier {
  final ChatService _service = ChatService();
  final _uuid = const Uuid();

  final List<ChatMessage> _messages = [];
  bool isTyping = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);

  ChatProvider() {
    _service.incomingMessages.listen((msg) {
      _messages.add(msg);
      notifyListeners();
    });
    _service.typingStream.listen((val) {
      isTyping = val;
      notifyListeners();
    });
  }

  Future<void> sendMessage(String text) async {
    final tempId = 'tmp_${_uuid.v4()}';
    final optimistic = ChatMessage(
      id: tempId,
      text: text,
      isSent: true,
      time: DateTime.now(),
      status: MessageStatus.sending,
    );
    _messages.add(optimistic);
    notifyListeners();

    try {
      final confirmed = await _service.send(text);
      final i = _messages.indexWhere((m) => m.id == tempId);
      if (i != -1) _messages[i] = confirmed;
    } catch (_) {
      final i = _messages.indexWhere((m) => m.id == tempId);
      if (i != -1)
        _messages[i] = optimistic.copyWith(status: MessageStatus.failed);
    }
    notifyListeners();
  }

  void retry(ChatMessage msg) {
    _messages.removeWhere((m) => m.id == msg.id);
    notifyListeners();
    sendMessage(msg.text);
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
