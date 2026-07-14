import 'package:lifeline/utils/logger.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lifeline/models/live_location_session.dart';
import 'package:lifeline/services/location_handler.dart';

/// Firestore-backed live location sharing (no paid services).
///
/// Pure Firestore ops ([createSession]/[updatePosition]/[stopSession]/[watch])
/// are unit-testable with a fake Firestore. [startBroadcast]/[stopBroadcast]
/// wire a battery-conscious geolocator stream + a foreground-service
/// notification on top of those ops.
class LiveLocationService {
  LiveLocationService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Shared instance used by the app for broadcasting (tests construct their
  /// own with a fake Firestore for the pure ops).
  static final LiveLocationService instance = LiveLocationService();

  /// Process-global id of the session currently being broadcast (or `null`).
  /// UI (e.g. the home "stop sharing" banner) listens to this.
  static final ValueNotifier<String?> activeSession = ValueNotifier(null);

  /// How often the device pushes a new position while broadcasting.
  static const broadcastInterval = Duration(seconds: 10);

  /// Default lifetime of a session before it auto-expires.
  static const defaultTtl = Duration(minutes: 30);

  StreamSubscription<Position>? _positionSub;
  Timer? _expiryTimer;
  String? _activeSessionId;

  /// The session id currently being broadcast, if any.
  String? get activeSessionId => _activeSessionId;
  bool get isBroadcasting => _activeSessionId != null;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('live_locations');

  // ─── Pure Firestore ops (unit-testable) ─────────────────────────────────────
  Future<String> createSession({
    required String ownerUid,
    required double lat,
    required double lng,
    Duration ttl = defaultTtl,
  }) async {
    final doc = _col.doc();
    await doc.set({
      'ownerUid': ownerUid,
      'lat': lat,
      'lng': lng,
      'updatedAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(DateTime.now().add(ttl)),
      'active': true,
    });
    return doc.id;
  }

  Future<void> updatePosition(String sessionId, double lat, double lng) {
    return _col.doc(sessionId).update({
      'lat': lat,
      'lng': lng,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> stopSession(String sessionId) {
    return _col.doc(sessionId).update({'active': false});
  }

  /// Streams a session doc; emits `null` if it does not exist.
  Stream<LiveLocationSession?> watch(String sessionId) {
    return _col.doc(sessionId).snapshots().map(
        (doc) => doc.exists ? LiveLocationSession.fromDoc(doc) : null);
  }

  // ─── Broadcasting (device → Firestore) ──────────────────────────────────────
  /// Starts a foreground location stream that writes the owner's position every
  /// [broadcastInterval] until [stopBroadcast], the [ttl] elapses, or an error.
  /// Returns the new session id, or `null` if location is unavailable.
  Future<String?> startBroadcast({
    required String ownerUid,
    Duration ttl = defaultTtl,
  }) async {
    if (isBroadcasting) return _activeSessionId;

    final start = await LocationHandler.getCurrentPosition();
    if (start == null) return null;

    final sessionId = await createSession(
      ownerUid: ownerUid,
      lat: start.latitude,
      lng: start.longitude,
      ttl: ttl,
    );
    _activeSessionId = sessionId;
    activeSession.value = sessionId;

    _positionSub = Geolocator.getPositionStream(
      locationSettings: _broadcastSettings(),
    ).listen(
      (pos) => updatePosition(sessionId, pos.latitude, pos.longitude)
          .catchError((Object e) => logDebug('live update failed: $e')),
      onError: (Object e) => logDebug('live stream error: $e'),
    );

    _expiryTimer = Timer(ttl, () => stopBroadcast());
    return sessionId;
  }

  /// Re-attaches to a session this user was still broadcasting when the app was
  /// killed (the in-memory [activeSession] resets on relaunch, but the Firestore
  /// session and the OS foreground service can outlive the process). Restores
  /// the "stop sharing" banner and resumes position updates so the user can see
  /// and stop the share from the app. No-op if there is no live session or one
  /// is already broadcasting. Expired/stale sessions are cleaned up.
  Future<void> restoreActiveSession(String ownerUid) async {
    if (isBroadcasting) return;
    try {
      final snap = await _col
          .where('ownerUid', isEqualTo: ownerUid)
          .where('active', isEqualTo: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return;

      final doc = snap.docs.first;
      final expiresAt = (doc.data()['expiresAt'] as Timestamp?)?.toDate();
      if (expiresAt == null || !expiresAt.isAfter(DateTime.now())) {
        await stopSession(doc.id); // stale — mark inactive, don't resurface it
        return;
      }

      final sessionId = doc.id;
      _activeSessionId = sessionId;
      activeSession.value = sessionId;

      // Resume the foreground broadcast on the existing session id.
      _positionSub = Geolocator.getPositionStream(
        locationSettings: _broadcastSettings(),
      ).listen(
        (pos) => updatePosition(sessionId, pos.latitude, pos.longitude)
            .catchError((Object e) => logDebug('live update failed: $e')),
        onError: (Object e) => logDebug('live stream error: $e'),
      );

      // Re-arm expiry for whatever time is left on the session.
      _expiryTimer = Timer(
          expiresAt.difference(DateTime.now()), () => stopBroadcast());
    } catch (e) {
      logDebug('restoreActiveSession failed: $e');
    }
  }

  /// Stops the active broadcast and marks the session inactive.
  Future<void> stopBroadcast() async {
    final id = _activeSessionId;
    await _positionSub?.cancel();
    _positionSub = null;
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _activeSessionId = null;
    activeSession.value = null;
    if (id != null) {
      try {
        await stopSession(id);
      } catch (e) {
        logDebug('stopSession failed: $e');
      }
    }
  }

  LocationSettings _broadcastSettings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        intervalDuration: broadcastInterval,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'LifeLine is sharing your location',
          notificationText: 'Your live location is being shared with contacts.',
          enableWakeLock: true,
          // Without an explicit icon geolocator falls back to the full-colour
          // launcher icon, which Android masks to a plain white square. Point
          // it at the monochrome status-bar icon instead.
          notificationIcon:
              AndroidResource(name: 'ic_notification', defType: 'drawable'),
        ),
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
  }
}
