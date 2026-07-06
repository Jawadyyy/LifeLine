import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lifeline/constants/app_colors.dart';
import 'package:lifeline/constants/app_design.dart';
import 'package:lifeline/models/chat_message.dart';
import 'package:lifeline/services/presence_service.dart';
import 'package:lifeline/views/main/live/live_tracking_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── Chat palette (warm, matches the Claude Design "Lifeline Chat" spec) ───────
const Color _chatCanvas = Color(0xFFF6F4F1); // warm cream screen bg
const Color _headerBg = Color(0xFFFDFCFB); // near-white header / input
const Color _incomingText = Color(0xFF2A2620); // dark warm text on white
const Color _metaGray = Color(0xFF97918B); // timestamps / secondary
const Color _chatDivider = Color(0xFFE7E2DD); // hairlines / date pill border
const Color _inputFill = Color(0xFFF1EEEA); // input pill fill
const Color _inputBorder = Color(0xFFE4DFD9); // input pill border

// ─── Header ───────────────────────────────────────────────────────────────────
class ChatHeader extends StatelessWidget {
  final String contactName;
  final String? contactImageUrl;

  /// Firebase uid of the peer, used to stream their live presence. When null
  /// (e.g. a legacy contact whose uid couldn't be resolved) no presence line or
  /// dot is shown rather than a misleading "Online".
  final String? peerUid;

  const ChatHeader({
    super.key,
    required this.contactName,
    this.contactImageUrl,
    this.peerUid,
  });

  /// Derives a truthful presence from a peer's user document: online only when
  /// the `online` flag is set AND the last heartbeat is within the presence
  /// window (guards against a crashed peer stuck "online").
  static bool _isOnline(Map<String, dynamic>? data) {
    if (data == null) return false;
    if (data['online'] != true) return false;
    final ts = data['lastActive'];
    if (ts is! Timestamp) return false;
    return DateTime.now().difference(ts.toDate()) < PresenceService.onlineWindow;
  }

  static String _statusText(Map<String, dynamic>? data) {
    if (_isOnline(data)) return 'Online';
    final ts = data?['lastActive'];
    if (ts is! Timestamp) return 'Offline';
    return _lastSeenText(ts.toDate());
  }

  static String _lastSeenText(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'last seen just now';
    if (diff.inMinutes < 60) return 'last seen ${diff.inMinutes}m ago';
    if (diff.inHours < 24) {
      return 'last seen ${DateFormat('h:mm a').format(t)}';
    }
    if (diff.inDays == 1) return 'last seen yesterday';
    return 'last seen ${DateFormat('MMM d').format(t)}';
  }

  @override
  Widget build(BuildContext context) {
    // Without a uid there's nothing to stream — render a presence-less header.
    if (peerUid == null || peerUid!.isEmpty) {
      return _build(context, online: false, statusText: '');
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(peerUid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        return _build(
          context,
          online: _isOnline(data),
          statusText: _statusText(data),
        );
      },
    );
  }

  Widget _build(BuildContext context,
      {required bool online, required String statusText}) {
    return Container(
      decoration: BoxDecoration(
        color: _headerBg,
        boxShadow: [
          BoxShadow(
              color: LL.orange.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 6)),
          BoxShadow(
              color: _chatDivider, blurRadius: 0, offset: const Offset(0, 1)),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 10, 12),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Color(0xFF554F49), size: 20),
                onPressed: () {
                  // Close the keyboard first if it's open; otherwise leave.
                  if (MediaQuery.of(context).viewInsets.bottom > 0) {
                    FocusScope.of(context).unfocus();
                  } else {
                    Navigator.pop(context);
                  }
                },
              ),
              _avatar(46, online: online),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(contactName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Color(0xFF2A2620),
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2)),
                      if (statusText.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(statusText,
                            style: TextStyle(
                                color: online ? LL.green : _metaGray,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500)),
                      ],
                    ]),
              ),
              IconButton(
                icon: const Icon(Icons.call_outlined, color: LL.orange, size: 22),
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text(AppLocalizations.of(context).callingComingSoon)),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert_rounded,
                    color: Color(0xFF6B655F), size: 22),
                onPressed: () {},
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatar(double size, {required bool online}) {
    final hasImage = contactImageUrl != null && contactImageUrl!.isNotEmpty;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: LL.grad,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: LL.orange.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4)),
              ],
            ),
            alignment: Alignment.center,
            clipBehavior: Clip.antiAlias,
            child: hasImage
                ? CachedNetworkImage(
                    imageUrl: contactImageUrl!,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    // Decode at ~3x logical size — crisp on retina, but a tiny
                    // fraction of the memory/decode cost of the full-res source.
                    memCacheWidth: (size * 3).round(),
                    memCacheHeight: (size * 3).round(),
                    placeholder: (_, __) => _initial(size),
                    errorWidget: (_, __, ___) => _initial(size))
                : _initial(size),
          ),
          // Presence dot — only rendered while the peer is truly online.
          if (online)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: LL.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: _headerBg, width: 2.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _initial(double size) => Text(
        contactName.isNotEmpty ? contactName[0].toUpperCase() : '?',
        style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.42,
            fontWeight: FontWeight.w700),
      );
}

// ─── Empty State ──────────────────────────────────────────────────────────────
class ChatEmptyState extends StatelessWidget {
  final String contactName;
  final String? contactImageUrl;

  const ChatEmptyState(
      {super.key, required this.contactName, this.contactImageUrl});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hasImage = contactImageUrl != null && contactImageUrl!.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 3),
              boxShadow: [
                BoxShadow(
                    color: AppColors.primary.withOpacity(0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 6))
              ],
            ),
            child: ClipOval(
                child: hasImage
                    ? CachedNetworkImage(
                        imageUrl: contactImageUrl!,
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                        memCacheWidth: 288,
                        memCacheHeight: 288,
                        placeholder: (_, __) => _letterAvatar(),
                        errorWidget: (_, __, ___) => _letterAvatar())
                    : _letterAvatar()),
          ),
          const SizedBox(height: 18),
          Text(contactName,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(l.chatStartConversation(contactName.split(' ').first),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textLight, fontSize: 13.5, height: 1.5)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.keyboard_alt_outlined,
                  color: AppColors.primary, size: 16),
              const SizedBox(width: 6),
              Text(l.typeMessageBelow,
                  style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _letterAvatar() => Container(
        color: AppColors.primary.withOpacity(0.12),
        child: Center(
            child: Text(
          contactName.isNotEmpty ? contactName[0].toUpperCase() : '?',
          style: const TextStyle(
              color: AppColors.primary,
              fontSize: 38,
              fontWeight: FontWeight.bold),
        )),
      );
}

// ─── Message Bubble ───────────────────────────────────────────────────────────
class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onRetry;

  const MessageBubble({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (message.isEmergency) {
      return _EmergencyBubble(message: message);
    }
    if (message.isSafe) {
      return _SafeBubble(message: message);
    }
    if (message.isImage) {
      return _ImageBubble(message: message);
    }
    if (message.isVoice) {
      return _VoiceBubble(message: message);
    }
    final isSent = message.isSent;
    final isFailed = message.status == MessageStatus.failed;
    final isSending = message.status == MessageStatus.sending;
    final emojiOnly = _isEmojiOnly(message.text);

    final bubble = GestureDetector(
      onLongPress: isFailed ? onRetry : null,
      child: Container(
        constraints: const BoxConstraints(minWidth: 40),
        padding: emojiOnly
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
            : const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        decoration: BoxDecoration(
          color: isFailed
              ? Colors.red.shade50
              : isSent
                  ? null
                  : Colors.white,
          gradient: (isSent && !isFailed) ? LL.grad : null,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isSent ? 20 : 7),
            bottomRight: Radius.circular(isSent ? 7 : 20),
          ),
          border: isFailed ? Border.all(color: Colors.red.shade300) : null,
          boxShadow: [
            BoxShadow(
              color: isSent
                  ? LL.orange.withOpacity(0.32)
                  : const Color(0xFF40281A).withOpacity(0.10),
              blurRadius: isSent ? 14 : 8,
              offset: Offset(0, isSent ? 4 : 2),
            )
          ],
        ),
        child: Opacity(
          opacity: isSending ? 0.6 : 1.0,
          child: Text(message.text,
              style: TextStyle(
                color: isFailed
                    ? Colors.red.shade900
                    : isSent
                        ? Colors.white
                        : _incomingText,
                fontSize: emojiOnly ? 26 : 15,
                fontWeight: FontWeight.w500,
                height: 1.35,
              )),
        ),
      ),
    );

    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(
            left: isSent ? 52 : 0, right: isSent ? 0 : 52, bottom: 3),
        child: Column(
          crossAxisAlignment:
              isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            bubble,
            const SizedBox(height: 3),
            Padding(
              padding: EdgeInsets.only(left: isSent ? 0 : 6, right: isSent ? 4 : 0),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (isFailed)
                  GestureDetector(
                    onTap: onRetry,
                    child: Row(children: [
                      Icon(Icons.error_outline_rounded,
                          color: Colors.red.shade400, size: 13),
                      const SizedBox(width: 3),
                      Text('Failed · Tap to retry',
                          style: TextStyle(
                              color: Colors.red.shade400, fontSize: 11)),
                      const SizedBox(width: 6),
                    ]),
                  ),
                Text(DateFormat('h:mm a').format(message.time),
                    style: const TextStyle(
                        color: _metaGray,
                        fontSize: 11,
                        fontWeight: FontWeight.w500)),
                if (isSent && !isFailed) ...[
                  const SizedBox(width: 4),
                  _bubbleStatusIcon(message.status),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }

  /// True when a message is only emoji (rendered larger, WhatsApp-style).
  static final RegExp _emojiRe = RegExp(
      r'^(?:[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2190}-\u{21FF}\u{2B00}-\u{2BFF}\u{FE0F}\u{200D}\u{20E3}\u{2000}-\u{206F}]|\s)+$',
      unicode: true);

  static bool _isEmojiOnly(String text) {
    final t = text.trim();
    if (t.isEmpty || t.runes.length > 8) return false;
    if (!_emojiRe.hasMatch(t)) return false;
    // Require at least one non-whitespace, non-ASCII rune so plain text/spaces
    // don't qualify.
    return t.runes.any((r) => r > 0x2100);
  }
}

// ─── Shared receipt/time row ──────────────────────────────────────────────────
Widget _bubbleStatusIcon(MessageStatus status) {
  switch (status) {
    case MessageStatus.sending:
      return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
              strokeWidth: 1.5, color: AppColors.textLight.withOpacity(0.5)));
    case MessageStatus.sent:
      return const Icon(Icons.done_rounded,
          color: AppColors.textLight, size: 13);
    case MessageStatus.delivered:
      return const Icon(Icons.done_all_rounded,
          color: AppColors.textLight, size: 13);
    case MessageStatus.read:
      return const Icon(Icons.done_all_rounded,
          color: AppColors.secondary, size: 13);
    case MessageStatus.failed:
      return Icon(Icons.error_outline_rounded,
          color: Colors.red.shade400, size: 13);
  }
}

Widget _timeStatusRow(ChatMessage message, {Color? timeColor}) {
  final timeStr = DateFormat('h:mm a').format(message.time);
  return Row(mainAxisSize: MainAxisSize.min, children: [
    Text(timeStr,
        style: TextStyle(
            color: timeColor ?? AppColors.textLight,
            fontSize: 10.5,
            letterSpacing: 0.3)),
    if (message.isSent) ...[
      const SizedBox(width: 4),
      _bubbleStatusIcon(message.status),
    ],
  ]);
}

// ─── Image Bubble ─────────────────────────────────────────────────────────────
/// Photo message: a rounded thumbnail that opens full-screen on tap.
class _ImageBubble extends StatelessWidget {
  final ChatMessage message;
  const _ImageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isSent = message.isSent;
    final url = message.imageUrl;
    final isSending = message.status == MessageStatus.sending;

    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(
            left: isSent ? 56 : 0, right: isSent ? 0 : 56, bottom: 8),
        child: Column(
          crossAxisAlignment:
              isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: (url == null || url.isEmpty)
                  ? null
                  : () => Navigator.of(context).push(PageRouteBuilder(
                        opaque: false,
                        barrierColor: Colors.black,
                        pageBuilder: (_, __, ___) =>
                            _FullScreenImage(url: url),
                      )),
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isSent ? 18 : 6),
                  bottomRight: Radius.circular(isSent ? 6 : 18),
                ),
                child: Stack(
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                          maxWidth: 240, maxHeight: 300, minWidth: 140),
                      child: (url == null || url.isEmpty)
                          ? _imagePlaceholder()
                          : CachedNetworkImage(
                              imageUrl: url,
                              fit: BoxFit.cover,
                              // Thumbnail caps at 240pt wide; decode at 2x for
                              // retina sharpness instead of the full camera-res
                              // bitmap. Full res is loaded only in the viewer.
                              memCacheWidth: 480,
                              placeholder: (_, __) => _imagePlaceholder(),
                              errorWidget: (_, __, ___) => _imageError(),
                            ),
                    ),
                    if (isSending)
                      const Positioned.fill(
                        child: ColoredBox(
                          color: Colors.black26,
                          child: Center(
                            child: SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    // Time + receipt chip over the bottom-right corner.
                    Positioned(
                      right: 8,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.45),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: _timeStatusRow(message, timeColor: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() => Container(
        width: 200,
        height: 200,
        color: AppColors.background,
        child: const Center(
            child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2))),
      );

  Widget _imageError() => Container(
        width: 200,
        height: 140,
        color: AppColors.background,
        child: const Center(
            child: Icon(Icons.broken_image_outlined,
                color: AppColors.textLight, size: 32)),
      );
}

/// Pinch-to-zoom full-screen viewer for an image message.
class _FullScreenImage extends StatelessWidget {
  final String url;
  const _FullScreenImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const CircularProgressIndicator(
                      color: Colors.white),
                  errorWidget: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 48),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Voice Bubble ─────────────────────────────────────────────────────────────
/// Audio-note message: play/pause with a scrub bar and duration label.
class _VoiceBubble extends StatefulWidget {
  final ChatMessage message;
  const _VoiceBubble({required this.message});

  @override
  State<_VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<_VoiceBubble> {
  final AudioPlayer _player = AudioPlayer();
  PlayerState _state = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _total = Duration.zero;

  late final StreamSubscription<Duration> _posSub;
  late final StreamSubscription<Duration> _durSub;
  late final StreamSubscription<void> _completeSub;
  late final StreamSubscription<PlayerState> _stateSub;

  @override
  void initState() {
    super.initState();
    _total = widget.message.duration;
    _posSub = _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _durSub = _player.onDurationChanged.listen((d) {
      if (mounted && d > Duration.zero) setState(() => _total = d);
    });
    _stateSub = _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _state = s);
    });
    _completeSub = _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _state = PlayerState.stopped;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _posSub.cancel();
    _durSub.cancel();
    _stateSub.cancel();
    _completeSub.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final url = widget.message.audioUrl;
    if (url == null || url.isEmpty) return;
    if (_state == PlayerState.playing) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(url));
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isSent = widget.message.isSent;
    final isSending = widget.message.status == MessageStatus.sending;
    final playing = _state == PlayerState.playing;
    final totalMs = _total.inMilliseconds;
    final progress =
        totalMs == 0 ? 0.0 : (_position.inMilliseconds / totalMs).clamp(0.0, 1.0);
    final fg = isSent ? AppColors.textTertiary : AppColors.primary;
    final bubbleColor = isSent ? AppColors.primary : AppColors.surface;
    final remaining =
        _position > Duration.zero ? _total - _position : _total;

    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(
            left: isSent ? 40 : 0, right: isSent ? 0 : 40, bottom: 8),
        child: Column(
          crossAxisAlignment:
              isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              width: 220,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isSent ? 18 : 6),
                  bottomRight: Radius.circular(isSent ? 6 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSent
                        ? AppColors.primary.withOpacity(0.25)
                        : Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: isSending ? null : _toggle,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: fg.withOpacity(isSent ? 0.22 : 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: isSending
                          ? Padding(
                              padding: const EdgeInsets.all(10),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: fg),
                            )
                          : Icon(
                              playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: fg,
                              size: 24),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 18,
                          child: LayoutBuilder(builder: (context, c) {
                            return Stack(
                              alignment: Alignment.centerLeft,
                              children: [
                                Container(
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: fg.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: progress == 0 ? 0.001 : progress,
                                  child: Container(
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: fg,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: (c.maxWidth - 10) * progress,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                        color: fg, shape: BoxShape.circle),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Icon(Icons.mic_rounded,
                                size: 13, color: fg.withOpacity(0.8)),
                            Text(
                              _fmt(playing || _position > Duration.zero
                                  ? _position
                                  : remaining),
                              style: TextStyle(
                                  color: fg.withOpacity(0.9),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            _timeStatusRow(widget.message),
          ],
        ),
      ),
    );
  }
}

// ─── Emergency Bubble ─────────────────────────────────────────────────────────
/// Distinct red, pinned-looking bubble for `type == 'emergency'` SOS messages,
/// with a tappable map link extracted from the message text.
class _EmergencyBubble extends StatelessWidget {
  final ChatMessage message;
  const _EmergencyBubble({required this.message});

  static final _urlRegExp = RegExp(r'https?://[^\s]+');

  Future<void> _openMap() async {
    final match = _urlRegExp.firstMatch(message.text);
    if (match == null) return;
    final uri = Uri.tryParse(match.group(0)!);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('h:mm a').format(message.time);
    final hasMap = _urlRegExp.hasMatch(message.text);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.red.shade300, width: 1.4),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(13)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.emergency_share_rounded,
                      color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'EMERGENCY ALERT',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
              child: Text(
                message.text,
                style: TextStyle(
                  color: Colors.red.shade900,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ),
            if (hasMap)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: TextButton.icon(
                  onPressed: _openMap,
                  icon: Icon(Icons.location_on, color: Colors.red.shade700),
                  label: Text(
                    'Open location in Maps',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            if (message.liveSessionId != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LiveTrackingScreen(
                          sessionId: message.liveSessionId!),
                    ),
                  ),
                  icon: Icon(Icons.share_location_rounded,
                      color: Colors.red.shade700),
                  label: Text(
                    'Follow live location',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Row(
                children: [
                  Text(
                    timeStr,
                    style:
                        TextStyle(color: Colors.red.shade400, fontSize: 10.5),
                  ),
                  if (message.isSent) ...[
                    const Spacer(),
                    _receiptLabel(message.status),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Delivery receipt shown to the SOS sender so they know help received it.
  Widget _receiptLabel(MessageStatus status) {
    late final String text;
    late final IconData icon;
    switch (status) {
      case MessageStatus.sending:
        text = 'Sending…';
        icon = Icons.schedule;
        break;
      case MessageStatus.delivered:
        text = 'Delivered';
        icon = Icons.done_all_rounded;
        break;
      case MessageStatus.read:
        text = 'Seen';
        icon = Icons.done_all_rounded;
        break;
      case MessageStatus.failed:
        text = 'Failed';
        icon = Icons.error_outline_rounded;
        break;
      case MessageStatus.sent:
        text = 'Sent';
        icon = Icons.done_rounded;
        break;
    }
    final color =
        status == MessageStatus.read ? Colors.green.shade700 : Colors.red.shade400;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(text,
            style: TextStyle(
                color: color, fontSize: 10.5, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ─── Safe Bubble ──────────────────────────────────────────────────────────────
/// Distinct green bubble for the `type == 'safe'` "I'm safe now" follow-up.
class _SafeBubble extends StatelessWidget {
  final ChatMessage message;
  const _SafeBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('h:mm a').format(message.time);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.green.shade300, width: 1.4),
        ),
        child: Row(
          children: [
            Icon(Icons.verified_rounded, color: Colors.green.shade600, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message.text,
                      style: TextStyle(
                          color: Colors.green.shade900,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.4)),
                  const SizedBox(height: 4),
                  Text(timeStr,
                      style: TextStyle(
                          color: Colors.green.shade400, fontSize: 10.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Typing Indicator ─────────────────────────────────────────────────────────
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});
  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                  width: 3,
                  height: 24,
                  decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(6),
                      bottomRight: Radius.circular(18)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                        3,
                        (i) => AnimatedBuilder(
                              animation: _ctrl,
                              builder: (_, __) {
                                final phase =
                                    (_ctrl.value + i * 0.14).clamp(0.0, 1.0);
                                final scale = 1.0 -
                                    0.4 *
                                        (phase < 0.5
                                            ? phase * 2
                                            : (1.0 - phase) * 2);
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 2.5),
                                  child: Transform.scale(
                                      scale: scale,
                                      child: Container(
                                        width: 7,
                                        height: 7,
                                        decoration: BoxDecoration(
                                            color: AppColors.primary
                                                .withOpacity(
                                                    0.25 + phase * 0.55),
                                            shape: BoxShape.circle),
                                      )),
                                );
                              },
                            ))),
              ),
            ]),
      ),
    );
  }
}

// ─── Input Bar ────────────────────────────────────────────────────────────────
class ChatInputBar extends StatefulWidget {
  final ValueChanged<String> onSend;

  /// Local file path of a picked image; the parent uploads and sends it.
  final ValueChanged<String> onSendImage;

  /// Local file path + length of a recorded voice note.
  final void Function(String path, int durationMs) onSendVoice;

  /// True while a media upload is in flight, so the trailing button shows a
  /// spinner instead of accepting more input.
  final bool sending;

  /// Emitted when the user starts/stops typing (debounced by the parent) so a
  /// typing indicator can be surfaced to the peer. Optional.
  final ValueChanged<bool>? onTypingChanged;

  const ChatInputBar({
    super.key,
    required this.onSend,
    required this.onSendImage,
    required this.onSendVoice,
    this.sending = false,
    this.onTypingChanged,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  late AnimationController _bounce;
  late Animation<double> _bounceAnim;

  bool _emojiOpen = false;
  bool _hasText = false;

  // ── Voice recording ──
  final AudioRecorder _recorder = AudioRecorder();
  bool _recording = false;
  DateTime? _recordStart;
  Duration _recordElapsed = Duration.zero;
  Timer? _recordTimer;
  double _dragDx = 0;

  static const double _cancelThreshold = -110;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _bounceAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.85), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _bounce, curve: Curves.easeInOut));

    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
    _focus.addListener(() {
      if (_focus.hasFocus && _emojiOpen) setState(() => _emojiOpen = false);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _bounce.dispose();
    _recordTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _bounce.forward(from: 0);
    _controller.clear();
    widget.onSend(text);
  }

  void _toggleEmoji() {
    if (_emojiOpen) {
      setState(() => _emojiOpen = false);
      _focus.requestFocus();
    } else {
      _focus.unfocus();
      setState(() => _emojiOpen = true);
    }
  }

  // ── Image picking ──
  Future<void> _pickImage() async {
    _focus.unfocus();
    if (_emojiOpen) setState(() => _emojiOpen = false);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.textLight.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.photo_camera_rounded,
                color: AppColors.primary),
            title: const Text('Camera'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading:
                const Icon(Icons.photo_library_rounded, color: AppColors.primary),
            title: const Text('Gallery'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (source == null) return;
    try {
      final file = await ImagePicker()
          .pickImage(source: source, imageQuality: 70, maxWidth: 1600);
      if (file != null) widget.onSendImage(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open image picker')));
      }
    }
  }

  // ── Voice recording ──
  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission denied')));
      }
      return;
    }
    _focus.unfocus();
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    _recordStart = DateTime.now();
    _dragDx = 0;
    setState(() {
      _recording = true;
      _recordElapsed = Duration.zero;
    });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _recordStart != null) {
        setState(() => _recordElapsed = DateTime.now().difference(_recordStart!));
      }
    });
  }

  Future<void> _stopRecording({required bool cancel}) async {
    _recordTimer?.cancel();
    final elapsed = _recordStart == null
        ? Duration.zero
        : DateTime.now().difference(_recordStart!);
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {
      path = null;
    }
    if (mounted) {
      setState(() {
        _recording = false;
        _dragDx = 0;
      });
    }
    // Discard on cancel or a too-short tap (< 800 ms) to avoid empty clips.
    if (cancel || path == null || elapsed.inMilliseconds < 800) {
      if (path != null) {
        try {
          File(path).deleteSync();
        } catch (_) {}
      }
      return;
    }
    widget.onSendVoice(path, elapsed.inMilliseconds);
  }

  String _fmtElapsed(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    // While the in-app emoji panel is open a back press should close it and
    // stay on the chat. This nested PopScope is consulted alongside the one on
    // the chat screen; either blocking canPop stops the route from popping.
    return PopScope(
      canPop: !_emojiOpen,
      onPopInvoked: (didPop) {
        if (!didPop && _emojiOpen) setState(() => _emojiOpen = false);
      },
      child: Container(
      decoration: const BoxDecoration(
        color: _headerBg,
        border: Border(top: BorderSide(color: _chatDivider)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SafeArea(
          top: false,
          bottom: !_emojiOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: _recording ? _recordingRow() : _inputRow(),
          ),
        ),
        if (_emojiOpen)
          SizedBox(
            height: 300,
            child: EmojiPicker(
              textEditingController: _controller,
              config: Config(
                height: 300,
                // Open on the smileys grid; the "Recent" tab is empty on first
                // use and looks like the picker failed to load.
                categoryViewConfig: const CategoryViewConfig(
                  initCategory: Category.SMILEYS,
                  indicatorColor: LL.orange,
                  iconColorSelected: LL.orange,
                  backspaceColor: LL.orange,
                  backgroundColor: _headerBg,
                ),
                emojiViewConfig: const EmojiViewConfig(
                  columns: 8,
                  emojiSizeMax: 28,
                  backgroundColor: _chatCanvas,
                  recentsLimit: 28,
                ),
                bottomActionBarConfig: const BottomActionBarConfig(
                  enabled: false,
                ),
                searchViewConfig: const SearchViewConfig(
                  backgroundColor: _headerBg,
                  buttonIconColor: LL.orange,
                ),
              ),
            ),
          ),
      ]),
    ),
    );
  }

  Widget _inputRow() {
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Expanded(
        child: Container(
          decoration: BoxDecoration(
            color: _inputFill,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: _inputBorder),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            const SizedBox(width: 6),
            IconButton(
                icon: const Icon(Icons.attach_file_rounded,
                    color: Color(0xFF6B655F), size: 21),
                onPressed: widget.sending ? null : _pickImage,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36)),
            Expanded(
                child: TextField(
              controller: _controller,
              focusNode: _focus,
              style: const TextStyle(color: _incomingText, fontSize: 15),
              decoration: const InputDecoration(
                hintText: 'Type a message…',
                hintStyle: TextStyle(color: Color(0xFF8C857E), fontSize: 15),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              onSubmitted: (_) => _send(),
              textInputAction: TextInputAction.send,
              maxLines: 5,
              minLines: 1,
            )),
            IconButton(
                icon: Icon(
                    _emojiOpen
                        ? Icons.keyboard_rounded
                        : Icons.emoji_emotions_outlined,
                    color: const Color(0xFF6B655F),
                    size: 22),
                onPressed: _toggleEmoji,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40)),
            const SizedBox(width: 4),
          ]),
        ),
      ),
      const SizedBox(width: 10),
      _trailingButton(),
    ]);
  }

  Widget _trailingButton() {
    if (widget.sending) {
      return const SizedBox(
        width: 50,
        height: 50,
        child: Center(
          child: SizedBox(
              width: 22,
              height: 22,
              child:
                  CircularProgressIndicator(strokeWidth: 2, color: LL.orange)),
        ),
      );
    }

    final circle = AnimatedBuilder(
      animation: _bounceAnim,
      builder: (_, child) =>
          Transform.scale(scale: _bounceAnim.value, child: child),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          gradient: LL.grad,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: LL.orange.withOpacity(0.45),
                blurRadius: 16,
                offset: const Offset(0, 6))
          ],
        ),
        child: Center(
            child: Icon(_hasText ? Icons.send_rounded : Icons.mic_rounded,
                color: Colors.white, size: 22)),
      ),
    );

    if (_hasText) {
      return GestureDetector(onTap: _send, child: circle);
    }
    // Empty text ⇒ press-and-hold to record, slide left to cancel.
    return GestureDetector(
      onLongPressStart: (_) => _startRecording(),
      onLongPressMoveUpdate: (d) {
        setState(() => _dragDx = d.offsetFromOrigin.dx);
      },
      onLongPressEnd: (_) =>
          _stopRecording(cancel: _dragDx < _cancelThreshold),
      child: circle,
    );
  }

  Widget _recordingRow() {
    final cancelling = _dragDx < _cancelThreshold;
    return Row(children: [
      Icon(Icons.mic_rounded,
          color: cancelling ? AppColors.textLight : Colors.red, size: 24),
      const SizedBox(width: 10),
      Text(_fmtElapsed(_recordElapsed),
          style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600)),
      const SizedBox(width: 16),
      Expanded(
        child: Text(
          cancelling ? 'Release to cancel' : '‹ Slide to cancel',
          style: TextStyle(
              color: cancelling ? Colors.red : AppColors.textLight,
              fontSize: 13),
        ),
      ),
      Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: cancelling ? AppColors.textLight : Colors.red,
          shape: BoxShape.circle,
        ),
        child: const Center(
            child: Icon(Icons.mic_rounded, color: Colors.white, size: 22)),
      ),
    ]);
  }
}

// ─── Time Divider ─────────────────────────────────────────────────────────────
class TimeDivider extends StatelessWidget {
  final DateTime time;
  const TimeDivider({super.key, required this.time});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 16),
      child: Row(children: [
        const Expanded(child: Divider(color: _chatDivider, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF40281A).withOpacity(0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1)),
              ],
            ),
            child: Text(DateFormat('h:mm a').format(time),
                style: const TextStyle(
                    color: Color(0xFF7C766F),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600)),
          ),
        ),
        const Expanded(child: Divider(color: _chatDivider, height: 1)),
      ]),
    );
  }
}
