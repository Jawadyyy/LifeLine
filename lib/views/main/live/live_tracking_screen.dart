import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:lifeline/constants/app_colors.dart';
import 'package:lifeline/models/live_location_session.dart';
import 'package:lifeline/services/live_location_service.dart';

/// Recipient view: follows a [LiveLocationSession] marker as it updates.
class LiveTrackingScreen extends StatefulWidget {
  final String sessionId;
  final String? personName;

  const LiveTrackingScreen({
    super.key,
    required this.sessionId,
    this.personName,
  });

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final LiveLocationService _service = LiveLocationService();
  final MapController _mapController = MapController();
  bool _autoFollow = true;
  LatLng? _last;

  @override
  Widget build(BuildContext context) {
    final name = widget.personName ?? 'Contact';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text('$name · Live location',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<LiveLocationSession?>(
        stream: _service.watch(widget.sessionId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final session = snapshot.data;
          if (session == null) {
            return const _Notice(
                icon: Icons.location_off_rounded,
                message: 'This live session no longer exists.');
          }

          final point = LatLng(session.lat, session.lng);
          if (_autoFollow && _last != point) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _mapController.move(point, 16);
            });
          }
          _last = point;

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: point,
                  initialZoom: 16,
                  onPointerDown: (_, __) => setState(() => _autoFollow = false),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.lifeline.app',
                  ),
                  MarkerLayer(markers: [
                    Marker(
                      point: point,
                      width: 54,
                      height: 54,
                      child: _LiveMarker(active: session.isLive),
                    ),
                  ]),
                ],
              ),
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: _StatusBanner(session: session),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () {
          setState(() => _autoFollow = true);
          if (_last != null) _mapController.move(_last!, 16);
        },
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final LiveLocationSession session;
  const _StatusBanner({required this.session});

  @override
  Widget build(BuildContext context) {
    final live = session.isLive;
    final updated = session.updatedAt;
    final updatedText = updated == null
        ? 'Waiting for first update…'
        : 'Last updated ${DateFormat('h:mm:ss a').format(updated)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: live ? AppColors.success : AppColors.textGrey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(live ? 'Sharing live' : 'Sharing ended',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontSize: 14)),
                Text(updatedText,
                    style: const TextStyle(
                        color: AppColors.textGrey, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveMarker extends StatelessWidget {
  final bool active;
  const _LiveMarker({required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.textGrey;
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 3),
      ),
      child: Icon(Icons.person_pin_circle, color: color, size: 28),
    );
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String message;
  const _Notice({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: AppColors.textGrey),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textGrey)),
          ),
        ],
      ),
    );
  }
}
