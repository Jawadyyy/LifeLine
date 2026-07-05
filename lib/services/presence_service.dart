import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

/// Writes the signed-in user's realtime presence to their `users/{uid}`
/// document so peers can show a truthful "Online" status instead of a
/// hard-coded one.
///
/// Presence is stored as two fields:
///   online: bool          — true while the app is foregrounded
///   lastActive: Timestamp — refreshed by a heartbeat while online
///
/// A reader should treat the peer as online only when `online == true` AND
/// `lastActive` is within [onlineWindow]. The heartbeat keeps `lastActive`
/// fresh; the recency guard prevents a crash or force-kill (which skips the
/// offline write) from pinning the presence dot green forever.
class PresenceService with WidgetsBindingObserver {
  PresenceService._();
  static final PresenceService instance = PresenceService._();

  /// A user counts as online only if their heartbeat landed within this window.
  /// Kept comfortably larger than [_heartbeatInterval] so a live user never
  /// flickers offline between beats.
  static const Duration onlineWindow = Duration(seconds: 60);
  static const Duration _heartbeatInterval = Duration(seconds: 30);

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  Timer? _heartbeat;
  bool _started = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Begins tracking presence for the signed-in user. Idempotent — safe to call
  /// on every auth-state emission.
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _goOnline();
  }

  /// Stops tracking and marks the user offline. Call before sign-out, while the
  /// uid is still available.
  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    _heartbeat?.cancel();
    _heartbeat = null;
    WidgetsBinding.instance.removeObserver(this);
    await _write(online: false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _goOnline();
    } else {
      // paused / inactive / detached / hidden — treat all as offline.
      _goOffline();
    }
  }

  void _goOnline() {
    _write(online: true);
    _heartbeat?.cancel();
    _heartbeat =
        Timer.periodic(_heartbeatInterval, (_) => _write(online: true));
  }

  void _goOffline() {
    _heartbeat?.cancel();
    _heartbeat = null;
    _write(online: false);
  }

  Future<void> _write({required bool online}) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db.collection('users').doc(uid).set({
        'online': online,
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Presence is best-effort; ignore transient write failures.
    }
  }
}
