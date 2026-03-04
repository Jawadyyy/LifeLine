enum MessageStatus { sending, sent, delivered, read, failed }

class ChatMessage {
  final String id;
  final String text;
  final bool isSent;
  final DateTime time;
  final MessageStatus status;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isSent,
    required this.time,
    this.status = MessageStatus.sent,
  });

  ChatMessage copyWith({MessageStatus? status}) => ChatMessage(
        id: id,
        text: text,
        isSent: isSent,
        time: time,
        status: status ?? this.status,
      );
}
