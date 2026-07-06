import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
    final engine = createAgoraRtcEngine();
    await engine.initialize(RtcEngineContext(appId: appId));
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

  Future<void> joinChannel(String channelName) async {
    final engine = await _ensureEngine();
    await engine.joinChannel(
      token: '',
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
