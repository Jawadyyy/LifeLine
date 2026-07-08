import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lifeline/models/chat_message.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lifeline/components/chat_widgets.dart';
import 'package:lifeline/services/chat_service.dart';
import 'package:lifeline/views/main/contact/chat/call_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    // If the keyboard is open, a back press should only dismiss it and stay on
    // the chat; block the pop and unfocus instead of leaving the screen.
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return PopScope(
      canPop: !keyboardOpen,
      onPopInvoked: (didPop) {
        if (!didPop) FocusScope.of(context).unfocus();
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF6F4F1),
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          ChatHeader(
            contactName: widget.contactName,
            contactImageUrl: widget.contactImageUrl,
            peerUid: widget.contactUid,
            onCallTap: widget.contactUid == null || widget.contactUid!.isEmpty
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => CallScreen.outgoing(
                        calleeUid: widget.contactUid!,
                        peerName: widget.contactName,
                        peerImageUrl: widget.contactImageUrl,
                      ),
                    )),
          ),
          Expanded(
            child: currentUid == null
                ? _ChatNotice(
                    message: AppLocalizations.of(context).notSignedIn)
                : FutureBuilder<String?>(
                    future: _peerUidFuture,
                    // When the uid was passed in (the common case) it's known
                    // synchronously — seed it so the chat renders immediately
                    // instead of flashing a spinner for a frame while the
                    // future settles on a microtask.
                    initialData: widget.contactUid,
                    builder: (context, snapshot) {
                      final peerUid = snapshot.data;
                      if (peerUid == null || peerUid.isEmpty) {
                        // No uid yet: keep waiting if the lookup is still
                        // running, otherwise it's genuinely unregistered.
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        return _ChatNotice(
                          message:
                              AppLocalizations.of(context).notRegisteredUser,
                        );
                      }
                      return _ChatBody(
                        currentUid: currentUid,
                        peerUid: peerUid,
                        contactName: widget.contactName,
                        contactImageUrl: widget.contactImageUrl,
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
    );
  }
}

/// The live chat list + input bar once the peer uid is known.
class _ChatBody extends StatefulWidget {
  const _ChatBody({
    required this.currentUid,
    required this.peerUid,
    required this.contactName,
    required this.contactImageUrl,
  });

  final String currentUid;
  final String peerUid;
  final String contactName;
  final String? contactImageUrl;

  @override
  State<_ChatBody> createState() => _ChatBodyState();
}

class _ChatBodyState extends State<_ChatBody> {
  final _scrollController = ScrollController();

  /// Id of the newest message last rendered. Used to auto-scroll to the bottom
  /// only when a genuinely new message arrives — not when an older paginated
  /// chunk is loaded (which leaves the newest id unchanged).
  String? _lastNewestId;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// With the list built `reverse: true` the newest message sits at offset 0,
  /// so the chat opens on the latest messages with no post-layout jump. A new
  /// message only animates the view down if the user is already near the
  /// bottom — reading older history isn't yanked away.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      if (_scrollController.position.pixels > 150) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  /// Long-press menu: copy any text message; edit/delete only the current
  /// user's own messages. Edits are limited to plain text messages that have
  /// actually reached the server.
  Future<void> _showMessageActions(
      BuildContext context, ChatProvider provider, ChatMessage msg) async {
    final onServer = msg.status != MessageStatus.sending &&
        msg.status != MessageStatus.failed;
    final canCopy = msg.text.trim().isNotEmpty;
    final canEdit = msg.isSent && msg.type == 'text' && onServer;
    final canDelete = msg.isSent && onServer;
    if (!canCopy && !canEdit && !canDelete) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textGrey.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 6),
            if (canCopy)
              ListTile(
                leading: const Icon(Icons.copy_rounded,
                    color: AppColors.textGrey),
                title: const Text('Copy'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: msg.text));
                  Navigator.pop(sheetContext);
                },
              ),
            if (canEdit)
              ListTile(
                leading:
                    const Icon(Icons.edit_rounded, color: AppColors.textGrey),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showEditDialog(provider, msg);
                },
              ),
            if (canDelete)
              ListTile(
                leading: Icon(Icons.delete_outline_rounded,
                    color: AppColors.error),
                title: Text('Delete',
                    style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDelete(provider, msg);
                },
              ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditDialog(ChatProvider provider, ChatMessage msg) async {
    final controller = TextEditingController(text: msg.text);
    final newText = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit message',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('SAVE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newText == null || newText.isEmpty || newText == msg.text) return;
    await provider.editMessage(msg.id, newText);
  }

  Future<void> _confirmDelete(ChatProvider provider, ChatMessage msg) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete message?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: const Text(
            'This message will be removed for everyone in the chat.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child:
                const Text('DELETE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await provider.deleteMessage(msg.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reuse a cached provider so the Firestore stream persists across visits;
    // reopening the chat renders instantly instead of reloading. `.value` does
    // not dispose the instance, keeping it alive in the cache.
    return ChangeNotifierProvider<ChatProvider>.value(
      value: ChatProviderCache.instance.get(widget.currentUid, widget.peerUid),
      child: Column(
        children: [
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, provider, _) {
                final msgs = provider.messages;

                // First load not finished yet: spinner, not a false empty state.
                if (!provider.loaded) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (msgs.isEmpty) {
                  return ChatEmptyState(
                    contactName: widget.contactName,
                    contactImageUrl: widget.contactImageUrl,
                  );
                }

                final newestId = msgs.last.id;
                if (newestId != _lastNewestId) {
                  // Skip the auto-scroll on the very first render: a reversed
                  // list already opens pinned to the newest message.
                  final isFirstRender = _lastNewestId == null;
                  _lastNewestId = newestId;
                  if (!isFirstRender) _scrollToBottom();
                }

                final showTopLoader = provider.loadingMore;

                return NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    // In a reversed list older messages live at the far
                    // (max) end, so pull the next chunk as it's approached.
                    if (notification.metrics.pixels >=
                            notification.metrics.maxScrollExtent - 80 &&
                        provider.hasMore &&
                        !provider.loadingMore) {
                      provider.loadMore();
                    }
                    return false;
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    // Prebuild ~1.5 screens of bubbles beyond the viewport so a
                    // fast fling scrolls smoothly instead of flashing blanks.
                    cacheExtent: 1200,
                    padding: const EdgeInsets.symmetric(
                        vertical: 18, horizontal: 12),
                    itemCount: msgs.length + (showTopLoader ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Reversed: index 0 is the newest (bottom); the older-chunk
                      // loader sits past the oldest message, at the visual top.
                      if (showTopLoader && index == msgs.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }
                      final msgIndex = msgs.length - 1 - index;
                      final msg = msgs[msgIndex];
                      final showDivider = msgIndex == 0 ||
                          msgs[msgIndex]
                                  .time
                                  .difference(msgs[msgIndex - 1].time)
                                  .inMinutes >
                              5;
                      return Column(children: [
                        if (showDivider) TimeDivider(time: msg.time),
                        MessageBubble(
                          message: msg,
                          onLongPress: () =>
                              _showMessageActions(context, provider, msg),
                        ),
                      ]);
                    },
                  ),
                );
              },
            ),
          ),
          Consumer<ChatProvider>(
            builder: (context, provider, _) => ChatInputBar(
              onSend: provider.sendMessage,
              onSendImage: provider.sendImage,
              onSendVoice: provider.sendVoice,
              sending: provider.sendingMedia,
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
