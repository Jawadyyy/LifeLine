import 'package:flutter/material.dart';
import 'package:lifeline/constants/app_colors.dart';
import 'package:intl/intl.dart';

// ─── Message Model ────────────────────────────────────────────────────────────
class ChatMessage {
  final String text;
  final bool isSent;
  final DateTime time;

  ChatMessage({required this.text, required this.isSent, required this.time});
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class ChatScreen extends StatefulWidget {
  final String contactName;
  final String contactPhone;
  final String? contactImageUrl;
  final String contactId;

  const ChatScreen({
    super.key,
    required this.contactName,
    required this.contactPhone,
    required this.contactImageUrl,
    required this.contactId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final List<ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  late AnimationController _typingAnimController;
  late AnimationController _sendBounceController;
  late Animation<double> _sendBounceAnim;

  @override
  void initState() {
    super.initState();

    _typingAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _sendBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _sendBounceAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.85), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(
      parent: _sendBounceController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _typingAnimController.dispose();
    _sendBounceController.dispose();
    super.dispose();
  }

  // ─── Send ───────────────────────────────────────────────────────────────────
  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    _sendBounceController.forward(from: 0);

    setState(() {
      _messages
          .add(ChatMessage(text: text, isSent: true, time: DateTime.now()));
      _inputController.clear();
    });

    _scrollToBottom();
  }

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

  // ─── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _messages.isEmpty && !_isTyping
                ? _buildEmptyState()
                : _buildMessageList(),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
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
              _buildHeaderAvatar(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.contactName,
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: AppColors.secondary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'Online',
                          style: TextStyle(
                            color: AppColors.secondary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.phone_outlined,
                    color: AppColors.textTertiary, size: 22),
                onPressed: () {},
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.more_vert_rounded,
                    color: AppColors.textTertiary, size: 22),
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

  Widget _buildHeaderAvatar() {
    final hasImage =
        widget.contactImageUrl != null && widget.contactImageUrl!.isNotEmpty;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.secondary, width: 2.5),
      ),
      child: ClipOval(
        child: hasImage
            ? Image.network(
                widget.contactImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _letterAvatar(size: 40),
              )
            : _letterAvatar(size: 40),
      ),
    );
  }

  Widget _letterAvatar({required double size, double fontSize = 18}) {
    return Container(
      width: size,
      height: size,
      color: AppColors.primary.withOpacity(0.18),
      child: Center(
        child: Text(
          widget.contactName.isNotEmpty
              ? widget.contactName[0].toUpperCase()
              : '?',
          style: TextStyle(
            color: AppColors.textTertiary,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ─── Empty State ────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    final hasImage =
        widget.contactImageUrl != null && widget.contactImageUrl!.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Large avatar
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
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipOval(
                child: hasImage
                    ? Image.network(
                        widget.contactImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _emptyStateLetterAvatar(),
                      )
                    : _emptyStateLetterAvatar(),
              ),
            ),
            const SizedBox(height: 18),
            // Name
            Text(
              widget.contactName,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 6),
            // Prompt
            Text(
              'Start a conversation with ${widget.contactName.split(' ').first}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textLight,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            // Subtle hint pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.keyboard_alt_outlined,
                      color: AppColors.primary, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Type a message below',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyStateLetterAvatar() {
    return Container(
      color: AppColors.primary.withOpacity(0.12),
      child: Center(
        child: Text(
          widget.contactName.isNotEmpty
              ? widget.contactName[0].toUpperCase()
              : '?',
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 38,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ─── Message List ───────────────────────────────────────────────────────────
  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      itemCount: _messages.length + (_isTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length && _isTyping) {
          return _buildTypingIndicator();
        }

        final msg = _messages[index];
        final showTime = index == 0 ||
            _messages[index]
                    .time
                    .difference(_messages[index - 1].time)
                    .inMinutes >
                5;

        return Column(
          children: [
            if (showTime) _buildTimeDivider(msg.time),
            _buildMessageBubble(msg),
          ],
        );
      },
    );
  }

  Widget _buildTimeDivider(DateTime time) {
    final formatted = DateFormat('h:mm a').format(time);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Divider(
                color: AppColors.textLight.withOpacity(0.25),
                indent: 0,
                endIndent: 0,
                height: 1),
          ),
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
              child: Text(
                formatted,
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
          Expanded(
            child: Divider(
                color: AppColors.textLight.withOpacity(0.25),
                indent: 0,
                endIndent: 0,
                height: 1),
          ),
        ],
      ),
    );
  }

  // ─── Bubble + Tail ──────────────────────────────────────────────────────────
  Widget _buildMessageBubble(ChatMessage msg) {
    final isSent = msg.isSent;
    final timeStr = DateFormat('h:mm a').format(msg.time);

    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(
          left: isSent ? 56 : 0,
          right: isSent ? 0 : 56,
          bottom: 8,
        ),
        child: Column(
          crossAxisAlignment:
              isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Bubble row: for received, accent stripe + bubble + tail.
            // For sent: bubble + tail.
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Left accent stripe (received only)
                if (!isSent)
                  Container(
                    width: 3,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                if (!isSent) const SizedBox(width: 6),

                // Main bubble
                Container(
                  decoration: BoxDecoration(
                    color: isSent ? AppColors.primary : AppColors.surface,
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
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(minWidth: 42),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Text(
                    msg.text,
                    style: TextStyle(
                      color: isSent
                          ? AppColors.textTertiary
                          : AppColors.textPrimary,
                      fontSize: 14.5,
                      height: 1.45,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),

                // Tail pointer (sent only)
                if (isSent)
                  CustomPaint(
                    size: const Size(10, 12),
                    painter: _BubbleTailPainter(
                        color: AppColors.primary, isSent: true),
                  ),
              ],
            ),

            // Received tail sits below-left, outside the Row
            if (!isSent)
              Padding(
                padding: const EdgeInsets.only(left: 9),
                child: CustomPaint(
                  size: const Size(10, 10),
                  painter: _BubbleTailPainter(
                      color: AppColors.surface, isSent: false),
                ),
              ),

            // Timestamp row
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeStr,
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontSize: 10.5,
                    letterSpacing: 0.3,
                  ),
                ),
                if (isSent) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.done_all_rounded,
                      color: AppColors.secondary, size: 13),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Typing Indicator ───────────────────────────────────────────────────────
  Widget _buildTypingIndicator() {
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
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: const Radius.circular(6),
                  bottomRight: const Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) => _typingDot(i)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typingDot(int index) {
    return AnimatedBuilder(
      animation: _typingAnimController,
      builder: (context, child) {
        final double phase =
            (_typingAnimController.value + index * 0.14).clamp(0.0, 1.0);
        final double scale =
            1.0 - 0.4 * (phase < 0.5 ? phase * 2 : (1.0 - phase) * 2);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.5),
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.25 + phase * 0.55),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Input Bar ──────────────────────────────────────────────────────────────
  Widget _buildInputBar() {
    return Container(
      color: AppColors.surface,
      child: Column(
        children: [
          // top divider
          Divider(
            height: 1,
            color: AppColors.textLight.withOpacity(0.2),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file_rounded,
                        color: AppColors.textGrey, size: 22),
                    onPressed: () {},
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: AppColors.textLight.withOpacity(0.3),
                            width: 1),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _inputController,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14.5,
                                letterSpacing: 0.2,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Type a message…',
                                hintStyle: TextStyle(
                                  color: AppColors.textLight,
                                  fontSize: 14.5,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 12),
                              ),
                              onSubmitted: (_) => _sendMessage(),
                              textInputAction: TextInputAction.send,
                              maxLines: 5,
                              minLines: 1,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: IconButton(
                              icon: const Icon(Icons.abc,
                                  color: AppColors.textLight, size: 22),
                              onPressed: () {},
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Send button
                  AnimatedBuilder(
                    animation: _sendBounceAnim,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _sendBounceAnim.value,
                        child: child,
                      );
                    },
                    child: GestureDetector(
                      onTap: _sendMessage,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.accent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.send_rounded,
                              color: AppColors.textTertiary, size: 20),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bubble Tail Painter ────────────────────────────────────────────────────
class _BubbleTailPainter extends CustomPainter {
  final Color color;
  final bool isSent;

  _BubbleTailPainter({required this.color, required this.isSent});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();

    if (isSent) {
      // Tail points down-right from the bubble's bottom-right corner
      path.moveTo(0, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height * 0.6);
      path.close();
    } else {
      // Tail points down-left from the bubble's bottom-left corner
      path.moveTo(size.width, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height * 0.6);
      path.close();
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.isSent != isSent;
}
