import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:lifeline/models/chat_message.dart';

/// Thin wrapper around the Gemini API for the in-app medical assistant.
///
/// The API key is read from `.env` (`GEMINI_KEY`). The model is primed with a
/// medical-assistant system prompt that always defers to professional care.
class GeminiService {
  static const _systemPrompt = '''
You are LifeLine's medical assistant, a helpful AI for general health and
first-aid information inside an emergency-response app.

Rules:
- Give clear, concise, general health information and basic first-aid guidance.
- You are NOT a doctor. Never give a definitive diagnosis or prescribe specific
  medication doses.
- For anything urgent or serious (chest pain, difficulty breathing, severe
  bleeding, stroke signs, unconsciousness, etc.) tell the user to call
  emergency services immediately (1122 in Pakistan) or use the app's SOS.
- Always remind the user that this is not a substitute for professional medical
  advice when giving health guidance.
- Keep answers short and easy to read. Use plain language.
''';

  GenerativeModel? _model;
  ChatSession? _chat;
  String? _initError;

  /// Whether a usable API key was found and the model initialised.
  bool get isReady => _model != null;

  /// Human-readable reason the assistant is unavailable, if any.
  String? get initError => _initError;

  GeminiService() {
    final key = dotenv.env['GEMINI_KEY'];
    if (key == null || key.isEmpty) {
      _initError =
          'AI assistant is not configured. Add GEMINI_KEY to your .env file.';
      return;
    }
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: key,
      systemInstruction: Content.system(_systemPrompt),
    );
    _chat = _model!.startChat();
  }

  /// Rebuilds the chat session seeded with prior [messages] so the model keeps
  /// context across app restarts. User messages map to the `user` role, bot
  /// messages to the `model` role. Leading model turns (e.g. the static
  /// greeting) are dropped — Gemini history must start with a user turn.
  void restoreHistory(List<ChatMessage> messages) {
    final model = _model;
    if (model == null) return;

    final turns = [...messages];
    while (turns.isNotEmpty && !turns.first.isSent) {
      turns.removeAt(0);
    }

    final history = turns
        .map((m) => m.isSent
            ? Content.text(m.text)
            : Content.model([TextPart(m.text)]))
        .toList();

    _chat = model.startChat(history: history);
  }

  /// Sends [text] to the model and returns its reply.
  Future<String> send(String text) async {
    final chat = _chat;
    if (chat == null) {
      return _initError ?? 'AI assistant is unavailable right now.';
    }
    try {
      final response = await chat.sendMessage(Content.text(text));
      final reply = response.text?.trim();
      if (reply == null || reply.isEmpty) {
        return 'Sorry, I could not generate a response. Please try again.';
      }
      return reply;
    } catch (e) {
      return 'Something went wrong reaching the assistant. Please try again.';
    }
  }
}
