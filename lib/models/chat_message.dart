enum MessageStatus { sending, sent, delivered, read, failed }

class ChatMessage {
  final String id;
  final String text;
  final bool isSent;
  final DateTime time;
  final MessageStatus status;

  /// Message kind: `'text'`, `'emergency'` (SOS location alert), or `'safe'`
  /// (the "I'm safe now" follow-up). The chat UI renders each distinctly.
  final String type;

  /// When an emergency message also starts a live share, the id of the
  /// `live_locations` session so the recipient can open the live map in-app.
  final String? liveSessionId;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isSent,
    required this.time,
    this.status = MessageStatus.sent,
    this.type = 'text',
    this.liveSessionId,
  });

  bool get isEmergency => type == 'emergency';
  bool get isSafe => type == 'safe';

  ChatMessage copyWith({MessageStatus? status}) => ChatMessage(
        id: id,
        text: text,
        isSent: isSent,
        time: time,
        status: status ?? this.status,
        type: type,
        liveSessionId: liveSessionId,
      );
}
