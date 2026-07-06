import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lifeline/constants/app_colors.dart';
import 'package:lifeline/constants/app_design.dart';
import 'package:lifeline/services/chat_service.dart';
import 'package:lifeline/services/global_data_service.dart';
import 'package:lifeline/services/live_location_service.dart';
import 'package:lifeline/services/push_service.dart';
import 'package:lifeline/services/sos_followup.dart';
import 'package:lifeline/utils/urdu_transliterate.dart';
import 'package:lifeline/views/chatbot/screens/chat_home_screen.dart';
import 'package:lifeline/views/main/donation/donation_map_screen.dart';
import 'package:lifeline/views/main/home/controller/home_controller.dart';
import 'package:lifeline/views/main/medical_id/medical_id_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late HomeController controller;
  final GlobalDataService _globalDataService = GlobalDataService();

  @override
  void initState() {
    super.initState();
    controller = HomeController(this, setState);
    _globalDataService.addListener(_onGlobalDataChanged);
    // Loads once and caches; no-op if already loaded.
    _globalDataService.loadUserData();
  }

  void _onGlobalDataChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _globalDataService.removeListener(_onGlobalDataChanged);
    super.dispose();
  }

  String get _profileImage =>
      _globalDataService.currentUser?.profileImage ?? '';

  String get _firstName {
    final name = FirebaseAuth.instance.currentUser?.displayName?.trim();
    if (name == null || name.isEmpty) return '';
    return name.split(' ').first;
  }

  String get _initial {
    final n = _firstName;
    return n.isEmpty ? '?' : n[0].toUpperCase();
  }

  String _greetingFor(AppLocalizations loc) {
    final h = DateTime.now().hour;
    if (h < 12) return loc.goodMorning;
    if (h < 17) return loc.goodAfternoon;
    return loc.goodEvening;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LL.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _LiveShareBanner(),
            const _SafeFollowupBanner(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(),
                    _greetingBlock(),
                    const SizedBox(height: 22),
                    Center(
                      child: _SosDial(
                        onTap: controller.toggleEmergencyOptions,
                        onLongPress: controller.callEmergencyServices,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _quickActions(),
                    const SizedBox(height: 12),
                    _donateBanner(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ChatHomeScreen()),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        highlightElevation: 0,
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            gradient: LL.grad,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: LL.orange.withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  // ── Header: logo + wordmark + avatar ──────────────────────────────────────
  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Row(
        children: [
          Image.asset('assets/images/logos/logo1.png', height: 26, width: 26),
          const SizedBox(width: 9),
          Text('LifeLine',
              style: LL.display(20, weight: FontWeight.w800, letterSpacing: 0.2)),
          const Spacer(),
          _avatar(),
        ],
      ),
    );
  }

  Widget _avatar() {
    final url = _profileImage;
    final fallback = Text(_initial,
        style: LL.display(15, weight: FontWeight.w800, color: Colors.white));
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
          color: LL.orange, shape: BoxShape.circle),
      child: url.isEmpty
          ? fallback
          : Image.network(
              url,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
            ),
    );
  }

  Widget _greetingBlock() {
    final loc = AppLocalizations.of(context);
    final isUrdu = Localizations.localeOf(context).languageCode == 'ur';
    final name = isUrdu ? transliterateToUrdu(_firstName) : _firstName;
    final greeting = _greetingFor(loc);
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 22, 26, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name.isEmpty ? greeting : loc.greetingWithName(greeting, name),
              style: LL.body(13.5, weight: FontWeight.w600, color: LL.muted)),
          const SizedBox(height: 6),
          Text(loc.helpOneTapAway, style: LL.display(30)),
        ],
      ),
    );
  }

  // ── Quick actions: Call 1122 + Medical ID ─────────────────────────────────
  Widget _quickActions() {
    final loc = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: _QuickCard(
              icon: Icons.call_rounded,
              title: loc.call1122,
              subtitle: loc.ambulance,
              onTap: () => controller.callEmergencyServices(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickCard(
              icon: Icons.medical_information_outlined,
              title: loc.medicalId,
              subtitle: loc.viewCard,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MedicalIdScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _donateBanner() {
    final loc = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Material(
        color: LL.card,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context).push(PageRouteBuilder(
            pageBuilder: (_, __, ___) => const DonationMapScreen(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
          )),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: LL.border),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF141828).withOpacity(0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: LL.soft,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.water_drop_outlined,
                      color: LL.orange, size: 22),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(loc.donateBloodTitle,
                          style: LL.body(14.5, weight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(loc.findDonationCamps,
                          style: LL.body(12, color: LL.muted)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFFC2C6CE), size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Quick-action card ───────────────────────────────────────────────────────
class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LL.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: LL.border),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF141828).withOpacity(0.05),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: LL.soft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: LL.orange, size: 20),
              ),
              const SizedBox(height: 10),
              Text(title, style: LL.body(14.5, weight: FontWeight.w700)),
              const SizedBox(height: 1),
              Text(subtitle, style: LL.body(12, color: LL.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Animated SOS dial ───────────────────────────────────────────────────────
/// Big circular emergency control. Two concentric rings pulse outward (scale
/// 1 → 1.7, fading) on a staggered 2.8s loop, behind a static dashed ring and
/// the gradient core. Tap opens the emergency-type sheet; long-press dials 1122.
class _SosDial extends StatefulWidget {
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _SosDial({required this.onTap, required this.onLongPress});

  @override
  State<_SosDial> createState() => _SosDialState();
}

class _SosDialState extends State<_SosDial> with SingleTickerProviderStateMixin {
  static const double _core = 196;
  static const double _box = 236;

  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _box,
      height: _box,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing rings (staggered by half a cycle).
          _ring(0.0),
          _ring(0.5),
          // Static dashed ring.
          CustomPaint(
            size: const Size(_box, _box),
            painter: _DashedRingPainter(),
          ),
          // Gradient core.
          GestureDetector(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            child: Container(
              width: _core,
              height: _core,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LL.sosGrad,
                boxShadow: [
                  BoxShadow(
                    color: LL.orangeDark.withOpacity(0.4),
                    blurRadius: 48,
                    offset: const Offset(0, 24),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('SOS',
                      style: LL.display(46,
                          weight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 2)),
                  const SizedBox(height: 8),
                  Text(AppLocalizations.of(context).holdToCall,
                      style: LL.body(11,
                          weight: FontWeight.w700,
                          color: Colors.white.withOpacity(0.85),
                          letterSpacing: 2.4)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ring(double offset) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = (_ctrl.value + offset) % 1.0;
        final p = math.min(t / 0.7, 1.0); // expand over first 70%, then hold
        final scale = 1.0 + 0.7 * p;
        final opacity = 0.5 * (1 - p);
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: _core,
              height: _core,
              decoration:
                  const BoxDecoration(shape: BoxShape.circle, color: LL.orange),
            ),
          ),
        );
      },
    );
  }
}

class _DashedRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 2;
    final paint = Paint()
      ..color = LL.orange.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    const dashCount = 60;
    const gapRatio = 0.72; // dash 28% / gap 72% → fine ticks
    final sweep = (2 * math.pi / dashCount) * (1 - gapRatio);
    final step = 2 * math.pi / dashCount;
    final rect = Rect.fromCircle(center: center, radius: radius);
    for (int i = 0; i < dashCount; i++) {
      final start = i * step;
      canvas.drawArc(rect, start, sweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Persistent banner shown while a live location share is active, with a one-tap
/// stop. Listens to the process-global [LiveLocationService.activeSession].
class _LiveShareBanner extends StatelessWidget {
  const _LiveShareBanner();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: LiveLocationService.activeSession,
      builder: (context, sessionId, _) {
        if (sessionId == null) return const SizedBox.shrink();
        final loc = AppLocalizations.of(context);
        return Material(
          color: AppColors.primary,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: Row(
              children: [
                const Icon(Icons.share_location_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    loc.sharingLiveLocation,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: () => LiveLocationService.instance.stopBroadcast(),
                  child: Text(loc.stop,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Contextual "I'm safe now" banner shown after an SOS, sending a `type:'safe'`
/// follow-up to the same contacts. Driven by [SosFollowup.alertedContacts].
class _SafeFollowupBanner extends StatelessWidget {
  const _SafeFollowupBanner();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<String>>(
      valueListenable: SosFollowup.alertedContacts,
      builder: (context, contacts, _) {
        if (contacts.isEmpty) return const SizedBox.shrink();
        final loc = AppLocalizations.of(context);
        return Material(
          color: AppColors.success,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: Row(
              children: [
                const Icon(Icons.verified_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    loc.imSafeBanner,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final user = FirebaseAuth.instance.currentUser;
                    final uid = user?.uid;
                    if (uid == null) return;
                    // Snapshot recipients before sendSafe clears them, so we can
                    // fire best-effort pushes to the same contacts.
                    final recipients =
                        List<String>.from(SosFollowup.alertedContacts.value);
                    final count = await SosFollowup.sendSafe(currentUid: uid);
                    final push = PushService();
                    for (final r in recipients) {
                      push.notify(
                        recipientUid: r,
                        kind: 'safe',
                        chatId: ChatService.chatIdFor(uid, r),
                        payload: {
                          'senderUid': uid,
                          'senderName': user?.displayName ?? loc.yourContact,
                        },
                      );
                    }
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(count > 0
                            ? loc.safeSentCount(count)
                            : loc.nothingToSend),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: Text(loc.imSafe,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
