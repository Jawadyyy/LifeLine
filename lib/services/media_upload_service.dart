import 'package:lifeline/utils/logger.dart';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Uploads all app media (chat images, voice notes, profile pictures) to
/// Supabase Storage and returns a public URL.
///
/// One public bucket (`media`) with per-feature prefixes:
///   chat/{chatId}/...    chat images + voice notes
///   profile/{uid}/...    profile pictures
///
/// Supabase replaced the old split hosting (images on ImgBB, audio on
/// Firebase Storage) — one free host for every file type, no billing plan
/// required. URLs already stored in Firestore keep working; only new uploads
/// land here.
class MediaUploadService {
  MediaUploadService({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final http.Client _http;

  static const _bucket = 'media';

  String get _baseUrl => (dotenv.env['SUPABASE_URL'] ?? '')
      .replaceAll(RegExp(r'/+$'), '');
  String get _anonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  /// Uploads [filePath] to `bucket/objectPath` and returns the public URL, or
  /// null on failure. Object paths get a millisecond timestamp prefix so
  /// repeat uploads never collide or overwrite.
  Future<String?> _upload(
    String filePath,
    String objectPath,
    String contentType,
  ) async {
    if (_baseUrl.isEmpty || _anonKey.isEmpty) {
      logDebug('MediaUploadService: SUPABASE_URL / SUPABASE_ANON_KEY missing '
          'from .env — uploads cannot work');
      return null;
    }
    try {
      final bytes = await File(filePath).readAsBytes();
      final uri = Uri.parse('$_baseUrl/storage/v1/object/$_bucket/$objectPath');
      final resp = await _http
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $_anonKey',
              'apikey': _anonKey,
              'Content-Type': contentType,
              // Overwrite guard is handled by unique paths; upsert false keeps
              // an accidental duplicate path from clobbering an older file.
              'x-upsert': 'false',
            },
            body: bytes,
          )
          .timeout(const Duration(seconds: 30));

      if (resp.statusCode == 200) {
        return '$_baseUrl/storage/v1/object/public/$_bucket/$objectPath';
      }
      logDebug(
          'MediaUploadService: upload failed ${resp.statusCode} ${resp.body}');
      return null;
    } catch (e) {
      logDebug('MediaUploadService: upload error $e');
      return null;
    }
  }

  String _stamp() => DateTime.now().millisecondsSinceEpoch.toString();

  /// Uploads a chat image and returns its hosted URL, or null on failure.
  Future<String?> uploadImage(String filePath, {String? chatId}) {
    final ext = filePath.split('.').last.toLowerCase();
    final safeExt = ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext)
        ? ext
        : 'jpg';
    final prefix = chatId != null ? 'chat/$chatId' : 'chat/misc';
    return _upload(
      filePath,
      '$prefix/${_stamp()}.$safeExt',
      'image/${safeExt == 'jpg' ? 'jpeg' : safeExt}',
    );
  }

  /// Uploads a recorded voice note and returns its hosted URL, or null on
  /// failure.
  Future<String?> uploadAudio(String filePath, {required String chatId}) {
    return _upload(filePath, 'chat/$chatId/${_stamp()}.m4a', 'audio/mp4');
  }

  /// Uploads a profile picture and returns its hosted URL, or null on failure.
  Future<String?> uploadProfileImage(String filePath, {required String uid}) {
    final ext = filePath.split('.').last.toLowerCase();
    final safeExt =
        ['jpg', 'jpeg', 'png', 'webp'].contains(ext) ? ext : 'jpg';
    return _upload(
      filePath,
      'profile/$uid/${_stamp()}.$safeExt',
      'image/${safeExt == 'jpg' ? 'jpeg' : safeExt}',
    );
  }
}
