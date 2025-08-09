import 'dart:io';

import 'package:google_generative_ai/google_generative_ai.dart';

class ApiService {
  static const _apiKey = 'AIzaSyBm4Hj3zvOaXXLPlu_fHjsPjRQV0J9HkQw';
  static final _model = GenerativeModel(
    model: 'gemini-2.5-flash',
    apiKey: _apiKey,
  );

  static Future<String> sendMessage(String message, {File? imageFile}) async {
    try {
      final content = <Content>[];

      if (imageFile != null) {
        final imageData = await imageFile.readAsBytes();
        content.add(
          Content.multi([
            TextPart(message),
            DataPart('image/jpeg', imageData),
          ]),
        );
      } else {
        content.add(Content.text(message));
      }

      final response = await _model.generateContent(content);
      return response.text ?? "No response.";
    } catch (e) {
      return "Error: $e";
    }
  }
}
