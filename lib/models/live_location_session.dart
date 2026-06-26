import 'package:cloud_firestore/cloud_firestore.dart';

/// A continuously-updating location share, stored at `live_locations/{id}`.
///
/// The owner streams their GPS into this doc while [active]; recipients (who
/// receive the [id] via an emergency chat message) read it to follow the
/// marker live. Sessions auto-expire at [expiresAt] so they never leak.
class LiveLocationSession {
  final String id;
  final String ownerUid;
  final double lat;
  final double lng;
  final DateTime? updatedAt;
  final DateTime expiresAt;
  final bool active;

  const LiveLocationSession({
    required this.id,
    required this.ownerUid,
    required this.lat,
    required this.lng,
    required this.updatedAt,
    required this.expiresAt,
    required this.active,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Live = explicitly active AND not past its expiry.
  bool get isLive => active && !isExpired;

  factory LiveLocationSession.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final updated = data['updatedAt'];
    final expires = data['expiresAt'];
    return LiveLocationSession(
      id: doc.id,
      ownerUid: (data['ownerUid'] as String?) ?? '',
      lat: (data['lat'] as num?)?.toDouble() ?? 0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0,
      updatedAt: updated is Timestamp ? updated.toDate() : null,
      // Missing expiry is treated as already-expired (epoch) rather than live.
      expiresAt: expires is Timestamp
          ? expires.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
      active: (data['active'] as bool?) ?? false,
    );
  }
}
