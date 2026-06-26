enum MessageStatus { sending, sent, delivered, read, failed }

class ChatMessage {
  final String id;
  final String text;
  final bool isSent;
  final DateTime time;
  final MessageStatus status;

  /// Message kind. `'text'` for normal messages, `'emergency'` for SOS
  /// location alerts that the chat UI renders distinctly.
  final String type;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isSent,
    required this.time,
    this.status = MessageStatus.sent,
    this.type = 'text',
  });

  bool get isEmergency => type == 'emergency';

  ChatMessage copyWith({MessageStatus? status}) => ChatMessage(
        id: id,
        text: text,
        isSent: isSent,
        time: time,
        status: status ?? this.status,
        type: type,
      );
}
