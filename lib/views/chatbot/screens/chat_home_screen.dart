import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:lifeline/constants/app_colors.dart';
import 'package:lifeline/constants/app_design.dart';
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
  String get _greeting => AppLocalizations.of(context).assistantGreeting;

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
    if (!mounted) return;
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
    final loc = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(loc.clearConversationTitle),
        content: Text(loc.clearConversationBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.cancelAction,
                style: const TextStyle(color: AppColors.textGrey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(loc.clearAction,
                style: const TextStyle(color: AppColors.textTertiary)),
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
      backgroundColor: LL.canvas,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildDisclaimer(),
            Expanded(
              child: !_loaded
                  ? const Center(
                      child: CircularProgressIndicator(color: LL.orange))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
                      itemCount: _messages.length + (_isTyping ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i < _messages.length) {
                          return _Bubble(message: _messages[i]);
                        }
                        return const _TypingBubble();
                      },
                    ),
            ),
            if (_showSuggestions) _Suggestions(onTap: _handleSend),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  bool get _showSuggestions =>
      _loaded && !_isTyping && _messages.length <= 1;

  Widget _buildHeader() {
    final loc = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 18, 14),
      decoration: const BoxDecoration(
        color: LL.canvas,
        border: Border(bottom: BorderSide(color: LL.border)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: LL.ink, size: 20),
          ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LL.grad,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: LL.orange.withOpacity(0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.medical_services_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(loc.medicalAssistant,
                    style: LL.display(18, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                          color: LL.green, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(loc.assistantOnline,
                        style: LL.body(12, color: LL.muted)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: loc.clearChat,
            icon: const Icon(Icons.delete_outline_rounded,
                color: Color(0xFFADB1BB)),
            onPressed: _clearChat,
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      width: double.infinity,
      color: LL.canvas,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1E8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFAD9C6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline_rounded,
                size: 14, color: Color(0xFFE06A2E)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                AppLocalizations.of(context).disclaimerShort,
                style: LL.body(11.5,
                    weight: FontWeight.w600, color: const Color(0xFFC2541F)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      color: LL.canvas,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: LL.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE6E7EB)),
                  ),
                  child: TextField(
                    controller: _inputController,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _handleSend,
                    style: LL.body(14, color: LL.ink),
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context).askAboutHealth,
                      hintStyle: LL.body(14, color: LL.faint),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => _handleSend(_inputController.text),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LL.grad,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: LL.orange.withOpacity(0.32),
                          blurRadius: 18,
                          offset: const Offset(0, 8))
                    ],
                  ),
                  child: const Center(
                      child: Icon(Icons.send_rounded,
                          color: Colors.white, size: 22)),
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
          margin: const EdgeInsets.only(left: 50, bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LL.grad,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(6),
            ),
            boxShadow: [
              BoxShadow(
                color: LL.orange.withOpacity(0.28),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Text(
            message.text,
            style: LL.body(14, weight: FontWeight.w500, color: Colors.white,
                height: 1.45),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 40, bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const _AssistantAvatar(),
          const SizedBox(width: 9),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: LL.card,
                border: Border.all(color: LL.border),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF141828).withOpacity(0.05),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: MarkdownBody(
                data: message.text,
                onTapLink: (text, href, title) => _openLink(href),
                styleSheet: MarkdownStyleSheet(
                  p: LL.body(14, weight: FontWeight.w500, color: LL.ink2,
                      height: 1.5),
                  strong: LL.body(14, weight: FontWeight.w700, color: LL.ink2),
                  listBullet:
                      LL.body(14, weight: FontWeight.w500, color: LL.ink2),
                  a: LL.body(14,
                      weight: FontWeight.w600,
                      color: LL.orange)
                      .copyWith(decoration: TextDecoration.underline),
                  h1: LL.display(18, weight: FontWeight.w700),
                  h2: LL.display(16, weight: FontWeight.w700),
                  h3: LL.display(15, weight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small gradient app-mark used as the assistant avatar.
class _AssistantAvatar extends StatelessWidget {
  const _AssistantAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        gradient: LL.grad,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.medical_services_rounded,
          color: Colors.white, size: 16),
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
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          const _AssistantAvatar(),
          const SizedBox(width: 9),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: LL.card,
              border: Border.all(color: LL.border),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF141828).withOpacity(0.05),
                    blurRadius: 14,
                    offset: const Offset(0, 4)),
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
                            color: LL.orange.withOpacity(0.3 + phase * 0.5),
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
    final loc = AppLocalizations.of(context);
    final items = [
      loc.suggestionBurn,
      loc.suggestionCpr,
      loc.suggestionStroke,
      loc.suggestionBleeding,
    ];
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 9),
        itemBuilder: (context, i) {
          final s = items[i];
          return GestureDetector(
            onTap: () => onTap(s),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: LL.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: LL.border),
              ),
              child: Text(s,
                  style: LL.body(13,
                      weight: FontWeight.w600, color: const Color(0xFF5C616C))),
            ),
          );
        },
      ),
    );
  }
}
