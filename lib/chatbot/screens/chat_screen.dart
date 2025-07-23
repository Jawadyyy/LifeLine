import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lifeline/chatbot/providers/chat_provider.dart';
import 'package:lifeline/chatbot/utility/animated_dialog.dart';
import 'package:lifeline/chatbot/widgets/bottom_chat_field.dart';
import 'package:lifeline/chatbot/widgets/chat_messages.dart';
import 'package:provider/provider.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showAppBarShadow = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    setState(() {
      _showAppBarShadow = _scrollController.offset > 0;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients &&
          _scrollController.position.maxScrollExtent > 0.0) {
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
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        if (chatProvider.inChatMessages.isNotEmpty) {
          _scrollToBottom();
        }

        chatProvider.addListener(() {
          if (chatProvider.inChatMessages.isNotEmpty) {
            _scrollToBottom();
          }
        });

        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: _showAppBarShadow ? 4 : 0,
            centerTitle: true,
            title: const Text(
              'Bot Assistant',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.blueGrey,
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (chatProvider.inChatMessages.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        CupertinoIcons.pencil,
                        size: 20,
                        color: Colors.blue[800],
                      ),
                    ),
                    onPressed: () async {
                      showMyAnimatedDialog(
                        context: context,
                        title: 'Start New Chat',
                        content:
                            'Are you sure you want to start a new chat? Your current conversation will be cleared.',
                        actionText: 'New Chat',
                        onActionPressed: (value) async {
                          if (value) {
                            await chatProvider.prepareChatRoom(
                                isNewChat: true, chatID: '');
                          }
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                      child: chatProvider.inChatMessages.isEmpty
                          ? _buildEmptyState()
                          : ChatMessages(
                              scrollController: _scrollController,
                              chatProvider: chatProvider,
                            ),
                    ),
                  ),
                ),
                // Bottom input field with padding
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                  child: BottomChatField(chatProvider: chatProvider),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/ai.png',
            width: 120,
            height: 120,
            color: Colors.blue[100],
          ),
          const SizedBox(height: 20),
          Text(
            'How can I help you today?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask me anything about medical emergencies',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }
}
