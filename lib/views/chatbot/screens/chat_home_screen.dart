import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:lifeline/constants/app_colors.dart';
import 'package:lifeline/models/chat_message.dart';
import 'package:lifeline/services/gemini_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// AI medical assistant powered by Gemini. General health info only — always
/// shows a "not a substitute for professional medical advice" disclaimer.
///
/// The conversation is persisted per-user in SharedPreferences so it survives
/// closing and reopening the screen, and the Gemini session is re-seeded with
/// that history so context is preserved too.
class ChatHomeScreen extends StatefulWidget {
  const ChatHomeScreen({super.key});

  @override
  State<ChatHomeScreen> createState() => _ChatHomeScreenState();
}

class _ChatHomeScreenState extends State<ChatHomeScreen> {
  static const _greeting =
      "Hi! I'm your LifeLine medical assistant. Ask me about general health or "
      "first aid.\n\nFor emergencies, call **1122** or use the SOS button.";

  final GeminiService _gemini = GeminiService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _loaded = false;

  String get _storageKey =>
      'medical_chat_${FirebaseAuth.instance.currentUser?.uid ?? 'guest'}';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  // ─── Persistence ────────────────────────────────────────────────────────────
  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        _messages.addAll(list.map((m) => ChatMessage(
              id: m['id'] as String,
              text: m['text'] as String,
              isSent: m['isSent'] as bool,
              time: DateTime.fromMillisecondsSinceEpoch(m['time'] as int),
            )));
      } catch (_) {
        // Corrupt cache — start fresh.
      }
    }
    if (_messages.isEmpty) {
      _messages.add(_bot(_greeting));
    }
    _gemini.restoreHistory(_messages);
    if (!mounted) return;
    setState(() => _loaded = true);
    _scrollToBottom();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_messages
        .map((m) => {
              'id': m.id,
              'text': m.text,
              'isSent': m.isSent,
              'time': m.time.millisecondsSinceEpoch,
            })
        .toList());
    await prefs.setString(_storageKey, raw);
  }

  // ─── Message helpers ────────────────────────────────────────────────────────
  ChatMessage _bot(String text) => ChatMessage(
        id: 'b${DateTime.now().microsecondsSinceEpoch}',
        text: text,
        isSent: false,
        time: DateTime.now(),
      );

  ChatMessage _user(String text) => ChatMessage(
        id: 'u${DateTime.now().microsecondsSinceEpoch}',
        text: text,
        isSent: true,
        time: DateTime.now(),
      );

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isTyping) return;

    setState(() {
      _messages.add(_user(trimmed));
      _isTyping = true;
    });
    _inputController.clear();
    _scrollToBottom();
    await _persist();

    final reply = await _gemini.send(trimmed);
    if (!mounted) return;

    setState(() {
      _isTyping = false;
      _messages.add(_bot(reply));
    });
    _scrollToBottom();
    await _persist();
  }

  Future<void> _clearChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear conversation?'),
        content: const Text(
            'This deletes your chat history with the assistant. This cannot be '
            'undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL',
                style: TextStyle(color: AppColors.textGrey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('CLEAR',
                style: TextStyle(color: AppColors.textTertiary)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..add(_bot(_greeting));
      _isTyping = false;
    });
    _gemini.restoreHistory(_messages);
  }

  // ─── UI ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.medical_services_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Medical Assistant',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Colors.white)),
                Text('AI health companion',
                    style: TextStyle(fontSize: 11.5, color: Colors.white70)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Clear chat',
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
            onPressed: _clearChat,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildDisclaimer(),
          Expanded(
            child: !_loaded
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding:
                        const EdgeInsets.fromLTRB(14, 18, 14, 12),
                    itemCount: _messages.length +
                        (_isTyping ? 1 : 0) +
                        (_showSuggestions ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i < _messages.length) {
                        return _Bubble(message: _messages[i]);
                      }
                      if (_isTyping && i == _messages.length) {
                        return const _TypingBubble();
                      }
                      return _Suggestions(onTap: _handleSend);
                    },
                  ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  bool get _showSuggestions =>
      _loaded && !_isTyping && _messages.length <= 1;

  Widget _buildDisclaimer() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF4E5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 16, color: Color(0xFFB26A00)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Not a substitute for professional medical advice. In an '
              'emergency call 1122.',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF8A5A00)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: AppColors.textLight.withOpacity(0.3)),
                  ),
                  child: TextField(
                    controller: _inputController,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _handleSend,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 14.5),
                    decoration: const InputDecoration(
                      hintText: 'Ask about your health…',
                      hintStyle:
                          TextStyle(color: AppColors.textLight, fontSize: 14.5),
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _handleSend(_inputController.text),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.accent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primary.withOpacity(0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3))
                    ],
                  ),
                  child: const Center(
                      child: Icon(Icons.send_rounded,
                          color: AppColors.textTertiary, size: 20)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Message bubble ───────────────────────────────────────────────────────────
class _Bubble extends StatelessWidget {
  final ChatMessage message;
  const _Bubble({required this.message});

  Future<void> _openLink(String? href) async {
    if (href == null) return;
    final uri = Uri.tryParse(href);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.isSent;

    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(left: 50, bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(6),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            message.text,
            style: const TextStyle(
                color: AppColors.textTertiary, fontSize: 14.5, height: 1.4),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 40, bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.medical_services_rounded,
                color: AppColors.primary, size: 16),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: MarkdownBody(
                data: message.text,
                onTapLink: (text, href, title) => _openLink(href),
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14.5,
                      height: 1.45),
                  strong: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary),
                  listBullet: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 14.5),
                  a: const TextStyle(
                      color: AppColors.primary,
                      decoration: TextDecoration.underline),
                  h1: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary),
                  h2: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary),
                  h3: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Typing bubble ────────────────────────────────────────────────────────────
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.medical_services_rounded,
                color: AppColors.primary, size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, __) {
                    final phase = (_ctrl.value + i * 0.2) % 1.0;
                    final scale =
                        1.0 - 0.4 * (phase < 0.5 ? phase * 2 : (1 - phase) * 2);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.5),
                      child: Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: AppColors.primary
                                .withOpacity(0.3 + phase * 0.5),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Suggestion chips ─────────────────────────────────────────────────────────
class _Suggestions extends StatelessWidget {
  final ValueChanged<String> onTap;
  const _Suggestions({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 38, top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Try asking',
              style: TextStyle(
                  color: AppColors.textGrey,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _ChatHomeScreenStateSuggestions.items
                .map((s) => GestureDetector(
                      onTap: () => onTap(s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.primary.withOpacity(0.25)),
                        ),
                        child: Text(s,
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

/// Suggestion prompts, kept next to the screen that owns them.
class _ChatHomeScreenStateSuggestions {
  static const items = [
    'How do I treat a minor burn?',
    'Steps to perform CPR',
    'What are the signs of a stroke?',
    'How to stop heavy bleeding?',
  ];
}
