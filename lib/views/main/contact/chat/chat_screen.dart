import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  /// Firebase uid of the contact. May be null/empty for legacy contacts that
  /// were saved before uids were stored — in that case it is resolved by phone.
  final String? contactUid;

  const ChatScreen({
    super.key,
    required this.contactName,
    required this.contactPhone,
    required this.contactImageUrl,
    required this.contactId,
    this.contactUid,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _scrollController = ScrollController();
  late final Future<String?> _peerUidFuture;

  @override
  void initState() {
    super.initState();
    _peerUidFuture = _resolvePeerUid();
    // Opening the chat marks the peer's incoming messages as seen.
    _peerUidFuture.then((peerUid) {
      final me = FirebaseAuth.instance.currentUser?.uid;
      if (peerUid == null || peerUid.isEmpty || me == null) return;
      ChatService(me).markSeen(ChatService.chatIdFor(me, peerUid));
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Resolves the chat peer's Firebase uid, preferring the value passed in and
  /// falling back to a phone lookup for contacts saved before uids were stored.
  Future<String?> _resolvePeerUid() async {
    final provided = widget.contactUid;
    if (provided != null && provided.isNotEmpty) return provided;

    final target = _normalizeTo10Digits(widget.contactPhone);
    if (target.length != 10) return null;

    final snapshot =
        await FirebaseFirestore.instance.collection('users').get();
    for (final doc in snapshot.docs) {
      final phone = doc.data()['phone'] as String?;
      if (phone != null && _normalizeTo10Digits(phone) == target) {
        return doc.id;
      }
    }
    return null;
  }

  String _normalizeTo10Digits(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
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
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          ChatHeader(
            contactName: widget.contactName,
            contactImageUrl: widget.contactImageUrl,
          ),
          Expanded(
            child: currentUid == null
                ? const _ChatNotice(message: 'You are not signed in.')
                : FutureBuilder<String?>(
                    future: _peerUidFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final peerUid = snapshot.data;
                      if (peerUid == null || peerUid.isEmpty) {
                        return const _ChatNotice(
                          message:
                              'This contact is not a registered LifeLine user yet.',
                        );
                      }
                      return _ChatBody(
                        currentUid: currentUid,
                        peerUid: peerUid,
                        contactName: widget.contactName,
                        contactImageUrl: widget.contactImageUrl,
                        scrollController: _scrollController,
                        onMessagesChanged: _scrollToBottom,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// The live chat list + input bar once the peer uid is known.
class _ChatBody extends StatelessWidget {
  const _ChatBody({
    required this.currentUid,
    required this.peerUid,
    required this.contactName,
    required this.contactImageUrl,
    required this.scrollController,
    required this.onMessagesChanged,
  });

  final String currentUid;
  final String peerUid;
  final String contactName;
  final String? contactImageUrl;
  final ScrollController scrollController;
  final VoidCallback onMessagesChanged;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatProvider(currentUid: currentUid, contactUid: peerUid),
      child: Column(
        children: [
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, provider, _) {
                final msgs = provider.messages;
                if (msgs.isNotEmpty) onMessagesChanged();

                if (msgs.isEmpty) {
                  return ChatEmptyState(
                    contactName: contactName,
                    contactImageUrl: contactImageUrl,
                  );
                }

                return ListView.builder(
                  controller: scrollController,
                  padding:
                      const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                  itemCount: msgs.length,
                  itemBuilder: (context, i) {
                    final msg = msgs[i];
                    final showDivider = i == 0 ||
                        msgs[i].time.difference(msgs[i - 1].time).inMinutes > 5;
                    return Column(children: [
                      if (showDivider) TimeDivider(time: msg.time),
                      MessageBubble(message: msg),
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
    );
  }
}

class _ChatNotice extends StatelessWidget {
  const _ChatNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textGrey,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
