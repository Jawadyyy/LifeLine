import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lifeline/views/chatbot/history/chat_history.dart';
import 'package:lifeline/constants/app_colors.dart';
import 'chat_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<String> sessionIds = [];
  final ScrollController _scrollController = ScrollController();
  bool _showAppBarShadow = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadSessionIds();
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

  void _loadSessionIds() {
    setState(() {
      sessionIds = ChatHistory().getSessionIds();
    });
  }

  Future<void> _deleteSession(String sessionId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Chat",
            style: TextStyle(fontWeight: FontWeight.bold)),
        content:
            const Text("Are you sure you want to delete this chat session?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel",
                style: TextStyle(color: AppColors.textGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text("Delete", style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      ChatHistory().deleteSession(sessionId);
      _loadSessionIds();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Chat deleted"),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      );
    }
  }

  Future<void> _clearAllSessions() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Clear All History",
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
            "This will permanently remove all chat history. Continue?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel",
                style: TextStyle(color: AppColors.textGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Clear All",
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      ChatHistory().clearAllSessions();
      _loadSessionIds();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("All chats cleared"),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      );
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: AppColors.tertiary,
          ),
          const SizedBox(height: 16),
          const Text(
            "No Chat History",
            style: TextStyle(
              fontSize: 18,
              color: AppColors.textGrey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Your chat sessions will appear here",
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textGrey.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(String sessionId, int index) {
    final session = ChatHistory().getSession(sessionId);
    final preview = session.isNotEmpty
        ? session.first['content'] ?? '[No content]'
        : '[No content]';
    final timestamp = session.isNotEmpty && session.first['timestamp'] != null
        ? DateTime.fromMillisecondsSinceEpoch(
            int.parse(session.first['timestamp'].toString()))
        : DateTime.now();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppColors.textGrey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(restoredSession: session),
            ),
          );
        },
        onLongPress: () => _deleteSession(sessionId),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      "Chat Session ${index + 1}",
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    DateFormat('MMM d • h:mm a').format(timestamp),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textGrey.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.textGrey.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: AppColors.textGrey.withOpacity(0.9),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.textGrey.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete_outline,
                          size: 18, color: AppColors.error),
                    ),
                    onPressed: () => _deleteSession(sessionId),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: _showAppBarShadow ? 4 : 0,
        title: const Text(
          'Chat History',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textTertiary,
          ),
        ),
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: AppColors.textTertiary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (sessionIds.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_sweep, color: AppColors.textGrey),
              tooltip: "Clear All",
              onPressed: _clearAllSessions,
            ),
        ],
      ),
      body: sessionIds.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: () async {
                _loadSessionIds();
                await Future.delayed(const Duration(seconds: 1));
              },
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: sessionIds.length,
                itemBuilder: (context, index) {
                  return _buildSessionCard(sessionIds[index], index);
                },
              ),
            ),
    );
  }
}
