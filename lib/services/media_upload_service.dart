import 'dart:convert';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Uploads chat media to their hosts and returns a public URL.
///
/// Images reuse the same ImgBB path the profile picture upload uses (see
/// ProfileController.uploadImageToImgBB); audio goes to Firebase Storage under
/// `chat_media/{chatId}/` since ImgBB only accepts images.
class MediaUploadService {
  MediaUploadService({FirebaseStorage? storage}) : _storage = storage;

  // Resolved lazily so merely constructing this service (e.g. inside a
  // ChatProvider under unit test) never touches FirebaseStorage.instance,
  // which throws when Firebase isn't initialized.
  final FirebaseStorage? _storage;
  FirebaseStorage get _fs => _storage ?? FirebaseStorage.instance;

  /// Uploads an image file to ImgBB and returns its hosted URL, or null on
  /// failure. Mirrors the profile-picture upload path.
  Future<String?> uploadImage(String filePath) async {
    final apiKey = dotenv.env['IMGBB_KEY'] ?? '';
    final url = Uri.parse('https://api.imgbb.com/1/upload?key=$apiKey');
    try {
      final request = http.MultipartRequest('POST', url)
        ..files.add(await http.MultipartFile.fromPath('image', filePath));
      final response = await request.send();
      final res = await http.Response.fromStream(response);
      if (res.statusCode == 200) {
        return jsonDecode(res.body)['data']['url'] as String?;
      }
      debugPrint('MediaUploadService: image upload failed ${res.statusCode}');
      return null;
    } catch (e) {
      debugPrint('MediaUploadService: image upload error $e');
      return null;
    }
  }

  /// Uploads a recorded audio clip to Firebase Storage and returns its download
  /// URL, or null on failure.
  Future<String?> uploadAudio(String filePath, {required String chatId}) async {
    try {
      final name = '${DateTime.now().millisecondsSinceEpoch}.m4a';
      final ref = _fs.ref().child('chat_media/$chatId/$name');
      await ref.putFile(
        File(filePath),
        SettableMetadata(contentType: 'audio/mp4'),
      );
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('MediaUploadService: audio upload error $e');
      return null;
    }
  }
}
