import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lifeline/constants/app_colors.dart';
import 'package:lifeline/models/chat_message.dart';
import 'package:lifeline/views/main/live/live_tracking_screen.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── Header ───────────────────────────────────────────────────────────────────
class ChatHeader extends StatelessWidget {
  final String contactName;
  final String? contactImageUrl;

  const ChatHeader(
      {super.key, required this.contactName, this.contactImageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: AppColors.textTertiary, size: 22),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              _avatar(40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(contactName,
                          style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Row(children: [
                        Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                                color: AppColors.secondary,
                                shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        const Text('Online',
                            style: TextStyle(
                                color: AppColors.secondary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500)),
                      ]),
                    ]),
              ),
              IconButton(
                  icon: const Icon(Icons.phone_outlined,
                      color: AppColors.textTertiary, size: 22),
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints()),
              const SizedBox(width: 4),
              IconButton(
                  icon: const Icon(Icons.more_vert_rounded,
                      color: AppColors.textTertiary, size: 22),
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatar(double size) {
    final hasImage = contactImageUrl != null && contactImageUrl!.isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.secondary, width: 2.5)),
      child: ClipOval(
          child: hasImage
              ? Image.network(contactImageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _letterFallback(size))
              : _letterFallback(size)),
    );
  }

  Widget _letterFallback(double size) => Container(
        color: AppColors.primary.withOpacity(0.18),
        child: Center(
            child: Text(
          contactName.isNotEmpty ? contactName[0].toUpperCase() : '?',
          style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: size * 0.45,
              fontWeight: FontWeight.bold),
        )),
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
                    ? Image.network(contactImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _letterAvatar())
                    : _letterAvatar()),
          ),
          const SizedBox(height: 18),
          Text(contactName,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Start a conversation with ${contactName.split(' ').first}',
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
              Text('Type a message below',
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
    final isSent = message.isSent;
    final isFailed = message.status == MessageStatus.failed;
    final isSending = message.status == MessageStatus.sending;
    final timeStr = DateFormat('h:mm a').format(message.time);
    final bubbleColor = isFailed
        ? Colors.red.shade50
        : isSent
            ? AppColors.primary
            : AppColors.surface;

    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(
            left: isSent ? 56 : 0, right: isSent ? 0 : 56, bottom: 8),
        child: Column(
          crossAxisAlignment:
              isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!isSent) ...[
                    Container(
                        width: 3,
                        height: 28,
                        decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 6),
                  ],
                  GestureDetector(
                    onLongPress: isFailed ? onRetry : null,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 42),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(isSent ? 18 : 6),
                          bottomRight: Radius.circular(isSent ? 6 : 18),
                        ),
                        border: isFailed
                            ? Border.all(color: Colors.red.shade300)
                            : null,
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
                      child: Opacity(
                        opacity: isSending ? 0.55 : 1.0,
                        child: Text(message.text,
                            style: TextStyle(
                              color: isSent
                                  ? AppColors.textTertiary
                                  : AppColors.textPrimary,
                              fontSize: 14.5,
                              height: 1.45,
                            )),
                      ),
                    ),
                  ),
                  if (isSent)
                    CustomPaint(
                        size: const Size(10, 12),
                        painter:
                            _TailPainter(color: bubbleColor, isSent: true)),
                ]),
            if (!isSent)
              Padding(
                padding: const EdgeInsets.only(left: 9),
                child: CustomPaint(
                    size: const Size(10, 10),
                    painter:
                        _TailPainter(color: AppColors.surface, isSent: false)),
              ),
            const SizedBox(height: 4),
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (isFailed)
                GestureDetector(
                  onTap: onRetry,
                  child: Row(children: [
                    Icon(Icons.error_outline_rounded,
                        color: Colors.red.shade400, size: 13),
                    const SizedBox(width: 3),
                    Text('Failed · Tap to retry',
                        style: TextStyle(
                            color: Colors.red.shade400, fontSize: 10.5)),
                    const SizedBox(width: 6),
                  ]),
                ),
              Text(timeStr,
                  style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 10.5,
                      letterSpacing: 0.3)),
              if (isSent) ...[
                const SizedBox(width: 4),
                _statusIcon(),
              ],
            ]),
          ],
        ),
      ),
    );
  }

  Widget _statusIcon() {
    switch (message.status) {
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
        return const SizedBox.shrink();
    }
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
  const ChatInputBar({super.key, required this.onSend});
  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  late AnimationController _bounce;
  late Animation<double> _bounceAnim;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _bounceAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.85), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _bounce, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    _bounce.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _bounce.forward(from: 0);
    _controller.clear();
    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Divider(height: 1, color: AppColors.textLight.withOpacity(0.2)),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              IconButton(
                  icon: const Icon(Icons.attach_file_rounded,
                      color: AppColors.textGrey, size: 22),
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints()),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(24),
                    border:
                        Border.all(color: AppColors.textLight.withOpacity(0.3)),
                  ),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                            child: TextField(
                          controller: _controller,
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 14.5),
                          decoration: const InputDecoration(
                            hintText: 'Type a message…',
                            hintStyle: TextStyle(
                                color: AppColors.textLight, fontSize: 14.5),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 18, vertical: 12),
                          ),
                          onSubmitted: (_) => _send(),
                          textInputAction: TextInputAction.send,
                          maxLines: 5,
                          minLines: 1,
                        )),
                        Padding(
                          padding: const EdgeInsets.only(right: 4, bottom: 4),
                          child: IconButton(
                              icon: const Icon(Icons.emoji_emotions_outlined,
                                  color: AppColors.textLight, size: 22),
                              onPressed: () {},
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints()),
                        ),
                      ]),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedBuilder(
                animation: _bounceAnim,
                builder: (_, child) =>
                    Transform.scale(scale: _bounceAnim.value, child: child),
                child: GestureDetector(
                  onTap: _send,
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
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ─── Time Divider ─────────────────────────────────────────────────────────────
class TimeDivider extends StatelessWidget {
  final DateTime time;
  const TimeDivider({super.key, required this.time});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(children: [
        Expanded(
            child: Divider(
                color: AppColors.textLight.withOpacity(0.25), height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.textLight.withOpacity(0.2), width: 0.8),
            ),
            child: Text(DateFormat('h:mm a').format(time),
                style: const TextStyle(
                    color: AppColors.textLight,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.4)),
          ),
        ),
        Expanded(
            child: Divider(
                color: AppColors.textLight.withOpacity(0.25), height: 1)),
      ]),
    );
  }
}

// ─── Bubble Tail Painter ──────────────────────────────────────────────────────
class _TailPainter extends CustomPainter {
  final Color color;
  final bool isSent;
  const _TailPainter({required this.color, required this.isSent});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    if (isSent) {
      path.moveTo(0, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height * 0.6);
    } else {
      path.moveTo(size.width, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height * 0.6);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TailPainter old) =>
      old.color != color || old.isSent != isSent;
}
