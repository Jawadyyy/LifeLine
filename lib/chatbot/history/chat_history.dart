import 'package:hive/hive.dart';

class ChatHistory {
  final Box _box = Hive.box('chat_sessions');

  List<String> getSessionIds() {
    return _box.keys.cast<String>().toList();
  }

  List<Map<String, dynamic>> getSession(String sessionId) {
    final raw = _box.get(sessionId, defaultValue: []);
    return (raw as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  void deleteSession(String sessionId) {
    if (_box.containsKey(sessionId)) {
      _box.delete(sessionId);
    }
  }

  void clearAllSessions() {
    _box.clear();
  }

  void saveSession(List<Map<String, String>> session) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    _box.put(id, session);
  }

  void addMessage(String role, String content) {
    final currentSessions = getSessionIds();
    final lastSessionId =
        currentSessions.isNotEmpty ? currentSessions.last : null;

    if (lastSessionId != null) {
      final currentSession = getSession(lastSessionId);
      currentSession.add({'role': role, 'content': content});
      _box.put(lastSessionId, currentSession);
    } else {
      final newSession = [
        {'role': role, 'content': content}
      ];
      saveSession(newSession);
    }
  }
}
