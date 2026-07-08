enum MessageStatus { sending, sent, delivered, read, failed }

class ChatMessage {
  final String id;
  final String text;
  final bool isSent;
  final DateTime time;
  final MessageStatus status;

  /// Message kind: `'text'`, `'emergency'` (SOS location alert), `'safe'`
  /// (the "I'm safe now" follow-up), `'image'` (a photo), `'voice'` (an
  /// audio note), or `'call'` (a voice-call log entry). The chat UI renders
  /// each distinctly.
  final String type;

  /// When an emergency message also starts a live share, the id of the
  /// `live_locations` session so the recipient can open the live map in-app.
  final String? liveSessionId;

  /// For `type == 'image'`: the hosted URL of the picture.
  final String? imageUrl;

  /// For `type == 'voice'`: the hosted URL of the audio clip.
  final String? audioUrl;

  /// For `type == 'voice'`: clip length in milliseconds, for the duration label
  /// and progress bar without having to load the file first.
  /// For `type == 'call'`: how long the call lasted; null means the call was
  /// never answered (missed).
  final int? durationMs;

  /// True once the sender has edited the message; the bubble shows an
  /// "edited" tag next to the timestamp.
  final bool edited;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isSent,
    required this.time,
    this.status = MessageStatus.sent,
    this.type = 'text',
    this.liveSessionId,
    this.imageUrl,
    this.audioUrl,
    this.durationMs,
    this.edited = false,
  });

  bool get isEmergency => type == 'emergency';
  bool get isSafe => type == 'safe';
  bool get isImage => type == 'image';
  bool get isVoice => type == 'voice';
  bool get isCall => type == 'call';

  /// For `type == 'call'`: true when the call was never answered.
  bool get isMissedCall => isCall && durationMs == null;

  /// Voice clip length as a [Duration] (zero when unknown).
  Duration get duration => Duration(milliseconds: durationMs ?? 0);

  ChatMessage copyWith({MessageStatus? status}) => ChatMessage(
        id: id,
        text: text,
        isSent: isSent,
        time: time,
        status: status ?? this.status,
        type: type,
        liveSessionId: liveSessionId,
        imageUrl: imageUrl,
        audioUrl: audioUrl,
        durationMs: durationMs,
        edited: edited,
      );
}
