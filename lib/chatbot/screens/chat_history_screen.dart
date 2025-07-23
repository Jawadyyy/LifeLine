import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lifeline/chatbot/hive/boxes.dart';
import 'package:lifeline/chatbot/hive/chat_history.dart';
import 'package:lifeline/chatbot/widgets/chat_history_widget.dart';
import 'package:lifeline/chatbot/widgets/empty_history_widget.dart';
import 'package:intl/intl.dart';

class ChatHistoryScreen extends StatefulWidget {
  const ChatHistoryScreen({super.key});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: _showAppBarShadow ? 4 : 0,
        centerTitle: true,
        title: const Text(
          'Chat History',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.blueGrey,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.blueGrey[600]),
            onPressed: () {
              // Implement search functionality
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<Box<ChatHistory>>(
        valueListenable: Boxes.getChatHistory().listenable(),
        builder: (context, box, _) {
          final chatHistory =
              box.values.toList().cast<ChatHistory>().reversed.toList();

          return chatHistory.isEmpty
              ? const EmptyHistoryWidget()
              : RefreshIndicator(
                  color: Colors.blue[800],
                  onRefresh: () async {
                    // Add refresh functionality if needed
                    await Future.delayed(const Duration(seconds: 1));
                    setState(() {});
                  },
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final chat = chatHistory[index];
                              final isToday = _isToday(chat.timestamp);
                              final isYesterday = _isYesterday(chat.timestamp);

                              // Show date header if needed
                              if (index == 0 ||
                                  !_isSameDay(chat.timestamp,
                                      chatHistory[index - 1].timestamp)) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          top: 16, bottom: 8),
                                      child: Text(
                                        isToday
                                            ? 'Today'
                                            : isYesterday
                                                ? 'Yesterday'
                                                : DateFormat('MMMM d, y')
                                                    .format(chat.timestamp),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                    _buildChatItem(chat),
                                  ],
                                );
                              }
                              return _buildChatItem(chat);
                            },
                            childCount: chatHistory.length,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
        },
      ),
    );
  }

  Widget _buildChatItem(ChatHistory chat) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Handle chat item tap
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ChatHistoryWidget(chat: chat),
        ),
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}
