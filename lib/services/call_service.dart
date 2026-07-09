import 'dart:async';
import 'dart:convert';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:lifeline/services/chat_service.dart';
import 'package:lifeline/services/push_service.dart';
import 'package:lifeline/utils/logger.dart';
import 'package:lifeline/views/main/contact/chat/call_screen.dart';

/// One-to-one voice calling backed by Agora RTC for the audio/video stream and
/// Firestore for signaling (who's calling whom, ringing/accepted/declined/ended).
///
/// Data model:
///   calls/{callId}
///     callerUid, callerName, calleeUid: String
///     channelName: String              Agora channel, deterministic per pair
///     status: 'ringing' | 'accepted' | 'declined' | 'ended' | 'missed'
///     createdAt, endedAt: Timestamp
class CallService {
  CallService._();
  static final CallService instance = CallService._();

  final _db = FirebaseFirestore.instance;
  RtcEngine? _engine;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _incomingSub;
  String? _listeningUid;

  /// Set by the active [CallScreen] so a fatal Agora join failure (e.g. the
  /// project has an App Certificate enabled and we joined token-less) tears the
  /// call down with an error instead of showing a fake "connected" timer.
  void Function(String reason)? onEngineFailure;

  /// A ringing call older than this is stale (app was closed/killed while it
  /// rang) — don't resurrect it as a fresh incoming-call screen on launch.
  static const _staleAfter = Duration(seconds: 45);

  CollectionReference<Map<String, dynamic>> get _calls =>
      _db.collection('calls');

  String _channelFor(String a, String b) =>
      'call_${ChatService.chatIdFor(a, b)}';

  Future<RtcEngine> _ensureEngine() async {
    final existing = _engine;
    if (existing != null) return existing;
    final appId = dotenv.env['AGORA_APP_ID'] ?? '';
    if (appId.isEmpty) {
      logDebug('Agora: AGORA_APP_ID missing from .env — calls cannot work');
    }
    final engine = createAgoraRtcEngine();
    await engine.initialize(RtcEngineContext(appId: appId));
    // Joining with an empty token only works while the Agora project is in
    // App-ID-only auth (testing mode). If a certificate is enabled these
    // callbacks are the only place the resulting join failure surfaces.
    engine.registerEventHandler(RtcEngineEventHandler(
      onError: (err, msg) => logDebug('Agora error: $err $msg'),
      onJoinChannelSuccess: (conn, _) =>
          logDebug('Agora: joined ${conn.channelId} as uid ${conn.localUid}'),
      onUserJoined: (conn, uid, _) => logDebug('Agora: peer $uid joined'),
      onUserOffline: (conn, uid, reason) =>
          logDebug('Agora: peer $uid left ($reason)'),
      onConnectionStateChanged: (conn, state, reason) {
        logDebug('Agora: connection $state ($reason)');
        if (state == ConnectionStateType.connectionStateFailed) {
          final tokenIssue = reason ==
                  ConnectionChangedReasonType.connectionChangedInvalidToken ||
              reason ==
                  ConnectionChangedReasonType.connectionChangedTokenExpired;
          onEngineFailure?.call(tokenIssue
              ? 'Call setup failed (Agora token). '
                  'Disable the App Certificate or add a token server.'
              : 'Call connection failed.');
        }
      },
    ));
    await engine.enableAudio();
    await engine.setChannelProfile(ChannelProfileType.channelProfileCommunication);
    await engine.setDefaultAudioRouteToSpeakerphone(false);
    _engine = engine;
    return engine;
  }

  RtcEngine? get engine => _engine;

  /// Caller side: creates the signaling doc, best-effort pushes the callee,
  /// and returns the new call's id + channel name.
  Future<({String callId, String channelName})> startCall({
    required String callerUid,
    required String callerName,
    required String calleeUid,
  }) async {
    final channelName = _channelFor(callerUid, calleeUid);
    final callRef = _calls.doc();
    await callRef.set({
      'callerUid': callerUid,
      'callerName': callerName,
      'calleeUid': calleeUid,
      'channelName': channelName,
      'status': 'ringing',
      'createdAt': FieldValue.serverTimestamp(),
    });

    unawaited(PushService().notify(
      recipientUid: calleeUid,
      kind: 'incoming_call',
      payload: {
        'callId': callRef.id,
        'channelName': channelName,
        'callerUid': callerUid,
        'callerName': callerName,
      },
    ));

    return (callId: callRef.id, channelName: channelName);
  }

  Future<void> setStatus(String callId, String status) {
    return _calls.doc(callId).update({
      'status': status,
      if (status == 'ended' || status == 'declined' || status == 'missed')
        'endedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchCall(String callId) =>
      _calls.doc(callId).snapshots();

  /// Starts (once per login) a listener that pops an incoming-call screen for
  /// any fresh `ringing` call addressed to [myUid]. Idempotent — safe to call
  /// on every rebuild of the logged-in shell.
  void listenForIncomingCalls(String myUid) {
    if (_listeningUid == myUid) return;
    _incomingSub?.cancel();
    _listeningUid = myUid;
    _incomingSub = _calls
        .where('calleeUid', isEqualTo: myUid)
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .listen((snap) {
      for (final change in snap.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final data = change.doc.data();
        if (data == null) continue;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        if (createdAt == null ||
            DateTime.now().difference(createdAt) > _staleAfter) {
          continue;
        }
        _showIncomingCall(change.doc.id, data);
      }
    }, onError: (Object e) => logDebug('call listener error: $e'));
  }

  void _showIncomingCall(String callId, Map<String, dynamic> data) {
    final nav = PushService.navigatorKey.currentState;
    if (nav == null) return;
    nav.push(MaterialPageRoute(
      builder: (_) => CallScreen.incoming(
        callId: callId,
        channelName: data['channelName'] as String? ?? '',
        peerName: data['callerName'] as String? ?? 'Unknown',
      ),
    ));
  }

  /// Stops the incoming-call listener (call on sign-out).
  void stopListening() {
    _incomingSub?.cancel();
    _incomingSub = null;
    _listeningUid = null;
  }

  // ---- In-call engine controls ---------------------------------------------

  /// Fetches an RTC token from the relay's /api/agora-token endpoint. The
  /// Agora project has an App Certificate enabled, so joins are rejected
  /// without one. Returns '' when the relay isn't configured or the fetch
  /// fails — the join then proceeds token-less and the engine failure handler
  /// surfaces the real error to the call screen.
  Future<String> _fetchRtcToken(String channelName) async {
    final base =
        (dotenv.env['PUSH_RELAY_URL'] ?? '').replaceAll(RegExp(r'/+$'), '');
    if (base.isEmpty) {
      logDebug('Agora: PUSH_RELAY_URL not set — joining token-less');
      return '';
    }
    try {
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (idToken == null || idToken.isEmpty) return '';
      final resp = await http
          .post(
            Uri.parse('$base/api/agora-token'),
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'channelName': channelName}),
          )
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) {
        logDebug('Agora token fetch failed ${resp.statusCode}: ${resp.body}');
        return '';
      }
      return (jsonDecode(resp.body)['token'] as String?) ?? '';
    } catch (e) {
      logDebug('Agora token fetch error: $e');
      return '';
    }
  }

  Future<void> joinChannel(String channelName) async {
    final engine = await _ensureEngine();
    final token = await _fetchRtcToken(channelName);
    await engine.joinChannel(
      token: token,
      channelId: channelName,
      uid: 0,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );
  }

  Future<void> leaveChannel() async {
    await _engine?.leaveChannel();
  }

  Future<void> setMuted(bool muted) async {
    await _engine?.muteLocalAudioStream(muted);
  }

  Future<void> setSpeakerphone(bool on) async {
    await _engine?.setEnableSpeakerphone(on);
  }

  /// Releases the native engine. Safe to call between calls — a new one is
  /// created lazily by [joinChannel] on the next call.
  Future<void> releaseEngine() async {
    await _engine?.leaveChannel();
    await _engine?.release();
    _engine = null;
  }
}
