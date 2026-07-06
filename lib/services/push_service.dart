import 'package:lifeline/utils/logger.dart';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:lifeline/views/main/contact/chat/call_screen.dart';
import 'package:lifeline/views/main/contact/chat/chat_screen.dart';
import 'package:lifeline/views/main/donation/donation_map_screen.dart';

/// Where a tapped push should take the user.
enum PushDestinationType { chat, donation, call, unknown }

/// Parsed routing target from a notification `data` payload.
@immutable
class PushDestination {
  const PushDestination(
    this.type, {
    this.peerUid,
    this.peerName,
    this.chatId,
    this.sessionId,
    this.callId,
    this.channelName,
  });

  final PushDestinationType type;
  final String? peerUid;
  final String? peerName;
  final String? chatId;
  final String? sessionId;

  /// For [PushDestinationType.call]: the `calls/{callId}` doc id and Agora
  /// channel name to rejoin.
  final String? callId;
  final String? channelName;
}

/// FCM push for cross-user alerts (SOS, "I'm safe", donation accept).
///
/// Sending happens through the free serverless [relay](../../relay) — the app
/// only holds the public `PUSH_RELAY_URL` and authenticates each call with the
/// current user's Firebase ID token. The service-account credential never
/// touches the app.
///
/// Token storage, [notify] and [routeFor] are dependency-injected and unit
/// tested; the platform glue ([initForUser], [attachListeners]) wraps
/// `FirebaseMessaging` directly and runs only on device.
class PushService {
  PushService({
    FirebaseFirestore? firestore,
    http.Client? httpClient,
    String? relayBaseUrl,
    Future<String?> Function()? idTokenProvider,
    FirebaseMessaging? messaging,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _http = httpClient ?? http.Client(),
        _relayBaseUrl = relayBaseUrl,
        _idTokenProvider = idTokenProvider,
        _messaging = messaging;

  final FirebaseFirestore _db;
  final http.Client _http;
  final String? _relayBaseUrl;
  final Future<String?> Function()? _idTokenProvider;
  FirebaseMessaging? _messaging;

  FirebaseMessaging get _fm => _messaging ??= FirebaseMessaging.instance;

  /// Navigator + messenger keys so background/terminated taps and foreground
  /// banners work without a BuildContext. Wired to `MaterialApp` in main.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  /// The token currently registered for this device (kept so logout can remove
  /// exactly this device's token, leaving the user's other devices intact).
  /// Static so logout — which runs through a different [PushService] instance —
  /// can still find the device token registered at login.
  static String? _currentToken;

  // ---- Token storage (multi-device safe) -----------------------------------

  /// Adds [token] to `users/{uid}.fcmTokens` (arrayUnion; creates the field if
  /// absent). Idempotent across devices.
  Future<void> saveToken(String uid, String token) {
    return _db.collection('users').doc(uid).set(
      {'fcmTokens': FieldValue.arrayUnion([token])},
      SetOptions(merge: true),
    );
  }

  /// Removes [token] from `users/{uid}.fcmTokens` (arrayRemove). No-op if the
  /// doc/field is missing.
  Future<void> removeToken(String uid, String token) async {
    try {
      await _db.collection('users').doc(uid).set(
        {'fcmTokens': FieldValue.arrayRemove([token])},
        SetOptions(merge: true),
      );
    } catch (e) {
      logDebug('removeToken failed: $e');
    }
  }

  // ---- Relay call ----------------------------------------------------------

  Future<String?> _idToken() {
    if (_idTokenProvider != null) return _idTokenProvider();
    return FirebaseAuth.instance.currentUser?.getIdToken() ??
        Future.value(null);
  }

  /// Best-effort cross-user push. Returns the relay's `{sent, failed}` counts,
  /// or null if push could not be attempted (no URL/token) or the call failed.
  /// Callers MUST treat this as best-effort and never block the core action.
  Future<({int sent, int failed})?> notify({
    required String recipientUid,
    required String kind,
    String? chatId,
    Map<String, dynamic>? payload,
  }) async {
    try {
      final base = _relayBaseUrl ?? dotenv.env['PUSH_RELAY_URL'];
      if (base == null || base.isEmpty) return null;

      final token = await _idToken();
      if (token == null || token.isEmpty) return null;

      final uri = Uri.parse(
          '${base.replaceAll(RegExp(r'/+$'), '')}/api/send');
      final resp = await _http
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'recipientUid': recipientUid,
              'kind': kind,
              if (chatId != null) 'chatId': chatId,
              'payload': payload ?? const {},
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (resp.statusCode != 200) {
        logDebug('push relay ${resp.statusCode}: ${resp.body}');
        return null;
      }
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      return (
        sent: (json['sent'] as num?)?.toInt() ?? 0,
        failed: (json['failed'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      logDebug('push notify failed: $e');
      return null;
    }
  }

  // ---- Tap routing (pure) --------------------------------------------------

  /// Maps a notification `data` payload to a navigation target.
  static PushDestination routeFor(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    switch (type) {
      case 'emergency':
      case 'safe':
        return PushDestination(
          PushDestinationType.chat,
          peerUid: data['senderUid']?.toString(),
          peerName: data['senderName']?.toString(),
          chatId: data['chatId']?.toString(),
          sessionId: data['sessionId']?.toString(),
        );
      case 'donation_accept':
        return const PushDestination(PushDestinationType.donation);
      case 'incoming_call':
        return PushDestination(
          PushDestinationType.call,
          peerUid: data['callerUid']?.toString(),
          peerName: data['callerName']?.toString(),
          callId: data['callId']?.toString(),
          channelName: data['channelName']?.toString(),
        );
      default:
        return const PushDestination(PushDestinationType.unknown);
    }
  }

  // ---- Platform glue (device only) -----------------------------------------

  /// On login / app-start: request permission, register this device's token,
  /// and keep it fresh on rotation. Safe to call repeatedly.
  Future<void> initForUser(String uid) async {
    try {
      await _fm.requestPermission();
      final token = await _fm.getToken();
      if (token != null && token.isNotEmpty) {
        _currentToken = token;
        await saveToken(uid, token);
      }
      _fm.onTokenRefresh.listen((t) {
        _currentToken = t;
        saveToken(uid, t);
      });
    } catch (e) {
      logDebug('push initForUser failed: $e');
    }
  }

  /// On logout: drop only this device's token.
  Future<void> clearForUser(String uid) async {
    final token = _currentToken;
    if (token == null) return;
    await removeToken(uid, token);
    _currentToken = null;
  }

  /// Wires foreground banners and background/terminated tap routing. Call once
  /// after the user is authenticated.
  Future<void> attachListeners() async {
    FirebaseMessaging.onMessage.listen(_showForeground);
    FirebaseMessaging.onMessageOpenedApp.listen(handleTap);
    final initial = await _fm.getInitialMessage();
    if (initial != null) handleTap(initial);
  }

  void _showForeground(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;
    final messenger = messengerKey.currentState;
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('${n.title ?? ''}\n${n.body ?? ''}'.trim()),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'OPEN',
          onPressed: () => handleTap(message),
        ),
      ),
    );
  }

  /// Routes a tapped notification to the right screen using its `data` payload.
  void handleTap(RemoteMessage message) {
    final dest = routeFor(message.data);
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    switch (dest.type) {
      case PushDestinationType.chat:
        final peerUid = dest.peerUid;
        if (peerUid == null || peerUid.isEmpty) return;
        nav.push(MaterialPageRoute(
          builder: (_) => ChatScreen(
            contactName: dest.peerName ?? 'Contact',
            contactPhone: '',
            contactImageUrl: null,
            contactId: peerUid,
            contactUid: peerUid,
          ),
        ));
        break;
      case PushDestinationType.donation:
        nav.push(MaterialPageRoute(
          builder: (_) => const DonationMapScreen(),
        ));
        break;
      case PushDestinationType.call:
        final callId = dest.callId;
        final channelName = dest.channelName;
        if (callId == null || channelName == null) return;
        nav.push(MaterialPageRoute(
          builder: (_) => CallScreen.incoming(
            callId: callId,
            channelName: channelName,
            peerName: dest.peerName ?? 'Contact',
          ),
        ));
        break;
      case PushDestinationType.unknown:
        break;
    }
  }
}
