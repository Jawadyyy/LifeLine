import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lifeline/views/chatbot/api_service/api.dart';
import 'package:lifeline/views/chatbot/history/chat_history.dart';
import 'package:lifeline/constants/app_colors.dart';

class ChatScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? restoredSession;
  const ChatScreen({super.key, this.restoredSession});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];

  bool _isLoading = false;
  File? _selectedImage;
  final ScrollController _scrollController = ScrollController();
  bool _showAppBarShadow = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (widget.restoredSession != null) {
      _messages.addAll(widget.restoredSession!);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
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
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _handleSend() async {
    final userText = _controller.text.trim();
    if (userText.isEmpty && _selectedImage == null) return;

    final userMessage = {
      "role": "user",
      "content": userText.isNotEmpty ? userText : "[Image uploaded]",
      "timestamp": DateTime.now().millisecondsSinceEpoch.toString(),
    };

    setState(() {
      _messages.add(userMessage);
      _controller.clear();
      _isLoading = true;
    });

    ChatHistory().addMessage(userMessage['role']!, userMessage['content']!);
    _scrollToBottom();

    try {
      final aiReply = await ApiService.sendMessage(
        userMessage['content']!,
        imageFile: _selectedImage,
      );

      final botMessage = {
        "role": "assistant",
        "content": aiReply,
        "timestamp": DateTime.now().millisecondsSinceEpoch.toString(),
      };

      setState(() {
        _messages.add(botMessage);
        _isLoading = false;
        _selectedImage = null;
      });

      ChatHistory().addMessage(botMessage['role']!, botMessage['content']!);
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  Widget _buildMessage(Map<String, dynamic> msg) {
    final isUser = msg['role'] == 'user';
    final timestamp = DateTime.fromMillisecondsSinceEpoch(
      int.tryParse(msg['timestamp'] ?? '') ?? 0,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser)
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.face, color: AppColors.textTertiary),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUser ? AppColors.primary : AppColors.tertiary,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(12),
                      topRight: const Radius.circular(12),
                      bottomLeft: isUser
                          ? const Radius.circular(12)
                          : const Radius.circular(4),
                      bottomRight: isUser
                          ? const Radius.circular(4)
                          : const Radius.circular(12),
                    ),
                  ),
                  child: Text(
                    msg['content'],
                    style: TextStyle(
                      color: isUser
                          ? AppColors.textTertiary
                          : AppColors.textPrimary,
                      fontSize: 15,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    DateFormat('h:mm a').format(timestamp),
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isUser)
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(left: 8),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: AppColors.textTertiary),
            ),
        ],
      ),
    );
  }

  Widget _buildInputField() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.image, color: AppColors.primary),
            onPressed: _isLoading ? null : _pickImage,
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Type your message...',
                        border: InputBorder.none,
                      ),
                      maxLines: 3,
                      minLines: 1,
                    ),
                  ),
                  if (_selectedImage != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _selectedImage!,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: -8,
                            right: -8,
                            child: IconButton(
                              icon: Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.surface,
                                ),
                                child: const Icon(Icons.close,
                                    size: 16, color: AppColors.error),
                              ),
                              onPressed: () =>
                                  setState(() => _selectedImage = null),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            mini: true,
            backgroundColor: AppColors.primary,
            onPressed: _isLoading ? null : _handleSend,
            child: Icon(
              _isLoading ? Icons.more_horiz : Icons.send,
              color: AppColors.textTertiary,
            ),
          ),
        ],
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
          'Gemini Chat',
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
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: AppColors.textTertiary),
              onPressed: () {},
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: AppColors.tertiary,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Start a conversation',
                          style: TextStyle(
                            fontSize: 18,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Send a message or upload an image',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessage(_messages[index]);
                    },
                  ),
          ),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Assistant is typing...',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          _buildInputField(),
        ],
      ),
    );
  }
}
