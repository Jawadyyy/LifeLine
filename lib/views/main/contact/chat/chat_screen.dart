import 'package:flutter/material.dart';
import 'package:lifeline/components/chat_widgets.dart';
import 'package:lifeline/services/chat_service.dart';
import 'package:provider/provider.dart';
import 'package:lifeline/constants/app_colors.dart';

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

class _ChatScreenState extends State<ChatScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatProvider(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        resizeToAvoidBottomInset: true,
        body: Column(
          children: [
            ChatHeader(
              contactName: widget.contactName,
              contactImageUrl: widget.contactImageUrl,
            ),
            Expanded(
              child: Consumer<ChatProvider>(
                builder: (context, provider, _) {
                  if (provider.messages.isNotEmpty || provider.isTyping) {
                    _scrollToBottom();
                  }

                  if (provider.messages.isEmpty && !provider.isTyping) {
                    return ChatEmptyState(
                      contactName: widget.contactName,
                      contactImageUrl: widget.contactImageUrl,
                    );
                  }

                  final msgs = provider.messages;
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        vertical: 18, horizontal: 12),
                    itemCount: msgs.length + (provider.isTyping ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == msgs.length) return const TypingIndicator();
                      final msg = msgs[i];
                      final showDivider = i == 0 ||
                          msgs[i].time.difference(msgs[i - 1].time).inMinutes >
                              5;
                      return Column(children: [
                        if (showDivider) TimeDivider(time: msg.time),
                        MessageBubble(
                          message: msg,
                          onRetry: () =>
                              context.read<ChatProvider>().retry(msg),
                        ),
                      ]);
                    },
                  );
                },
              ),
            ),
            Consumer<ChatProvider>(
              builder: (context, provider, _) => ChatInputBar(
                onSend: provider.sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
