import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:lifeline/constants/app_design.dart';
import 'package:lifeline/services/call_service.dart';
import 'package:lifeline/services/chat_service.dart';
import 'package:lifeline/utils/logger.dart';

/// One-to-one voice call screen. Two entry points:
///  - [CallScreen.outgoing] — caller taps the phone icon in chat; this screen
///    creates the signaling doc, rings, and joins the Agora channel right away
///    so audio is live the instant the callee accepts.
///  - [CallScreen.incoming] — pushed by [CallService] when a fresh `ringing`
///    call doc addressed to this user appears; joins the channel only once the
///    user taps Accept.
///
/// Firestore's `calls/{callId}.status` is the source of truth both sides
/// react to (ringing -> accepted -> ended/declined/missed).
class CallScreen extends StatefulWidget {
  const CallScreen.outgoing({
    super.key,
    required this.calleeUid,
    required this.peerName,
    this.peerImageUrl,
  })  : isOutgoing = true,
        callId = null,
        channelName = null;

  const CallScreen.incoming({
    super.key,
    required String this.callId,
    required String this.channelName,
    required this.peerName,
    this.peerImageUrl,
  })  : isOutgoing = false,
        calleeUid = null;

  final bool isOutgoing;
  final String peerName;
  final String? peerImageUrl;
  final String? calleeUid; // outgoing only
  final String? callId; // known up-front for incoming; set once created for outgoing
  final String? channelName;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

enum _Phase { connecting, ringing, incoming, accepted, ended }

class _CallScreenState extends State<CallScreen>
    with SingleTickerProviderStateMixin {
  /// Drives the ripple rings and the avatar's breathing while ringing;
  /// stopped once the call connects or ends.
  late final AnimationController _pulse;

  String? _callId;
  String? _channelName;
  _Phase _phase = _Phase.connecting;
  String? _endReason;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _callSub;
  Timer? _ringTimeoutTimer;
  Timer? _durationTicker;
  Duration _elapsed = Duration.zero;
  bool _muted = false;
  bool _speaker = false;
  bool _resolved = false; // guards against popping twice
  bool _wasAccepted = false; // decides duration entry vs missed-call entry

  @override
  void initState() {
    super.initState();
    CallService.instance.callScreenActive = true;
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat();
    _phase = widget.isOutgoing ? _Phase.connecting : _Phase.incoming;
    _init();
  }

  Future<void> _init() async {
    // A fatal Agora join failure (bad/expired token) must end the call rather
    // than leave a fake "connected" timer running with no audio.
    CallService.instance.onEngineFailure = (reason) {
      if (mounted) _finish(reason);
    };

    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      if (mounted) _finish(AppLocalizations.of(context).micPermissionRequired);
      return;
    }

    if (widget.isOutgoing) {
      final me = FirebaseAuth.instance.currentUser;
      if (me == null || widget.calleeUid == null) {
        _finish(null);
        return;
      }
      try {
        final result = await CallService.instance.startCall(
          callerUid: me.uid,
          callerName: me.displayName ?? 'LifeLine user',
          calleeUid: widget.calleeUid!,
        );
        _callId = result.callId;
        _channelName = result.channelName;
      } catch (e) {
        logDebug('startCall failed: $e');
        if (mounted) _finish(null);
        return;
      }
      if (!mounted) return;
      setState(() => _phase = _Phase.ringing);
      _listenToCall();
      // Join immediately so the caller's audio is live the instant the callee
      // accepts, without waiting on a second round trip.
      unawaited(CallService.instance.joinChannel(_channelName!));
      _ringTimeoutTimer = Timer(const Duration(seconds: 30), () {
        if (_phase == _Phase.ringing) {
          CallService.instance.setStatus(_callId!, 'missed');
          _finish(AppLocalizations.of(context).callMissed);
        }
      });
    } else {
      _callId = widget.callId;
      _channelName = widget.channelName;
      _listenToCall();
      // Callee-side safety net: normally the caller's 30s timer marks the
      // call missed, but if the caller's app died mid-ring the doc stays
      // 'ringing' forever and this screen would hang. Slightly longer than
      // the caller's timeout so theirs wins when both are alive.
      _ringTimeoutTimer = Timer(const Duration(seconds: 45), () {
        if (_phase == _Phase.incoming) {
          final id = _callId;
          if (id != null) {
            unawaited(CallService.instance.setStatus(id, 'missed'));
          }
          _finish(AppLocalizations.of(context).callMissed);
        }
      });
    }
  }

  void _listenToCall() {
    final id = _callId;
    if (id == null) return;
    _callSub = CallService.instance.watchCall(id).listen((snap) {
      final status = snap.data()?['status'] as String?;
      if (status == null || !mounted) return;
      switch (status) {
        case 'accepted':
          if (_phase != _Phase.accepted) _onAccepted();
          break;
        case 'declined':
          _finish(AppLocalizations.of(context).callDeclined);
          break;
        case 'ended':
          _finish(AppLocalizations.of(context).callEnded);
          break;
        case 'missed':
          _finish(AppLocalizations.of(context).callMissed);
          break;
      }
    }, onError: (Object e) => logDebug('call doc listen failed: $e'));
  }

  void _onAccepted() {
    _ringTimeoutTimer?.cancel();
    _wasAccepted = true;
    _pulse.stop();
    setState(() => _phase = _Phase.accepted);
    _durationTicker?.cancel();
    _durationTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  Future<void> _accept() async {
    final id = _callId;
    if (id == null) return;
    await CallService.instance.joinChannel(_channelName ?? '');
    await CallService.instance.setStatus(id, 'accepted');
    _onAccepted();
  }

  Future<void> _decline() async {
    final id = _callId;
    if (id != null) await CallService.instance.setStatus(id, 'declined');
    _finish(null);
  }

  Future<void> _hangUp() async {
    final id = _callId;
    if (id != null) await CallService.instance.setStatus(id, 'ended');
    _finish(null);
  }

  /// Writes the call's outcome into the chat as a `type: 'call'` message —
  /// duration for answered calls, a missed-call entry otherwise. Only the
  /// caller's screen writes so both sides don't log the same call twice.
  Future<void> _logCallToChat() async {
    if (!widget.isOutgoing || _callId == null) return;
    final me = FirebaseAuth.instance.currentUser;
    final calleeUid = widget.calleeUid;
    if (me == null || calleeUid == null) return;
    try {
      await ChatService(me.uid).send(
        ChatService.chatIdFor(me.uid, calleeUid),
        calleeUid,
        _wasAccepted ? '📞 Voice call' : '📞 Missed voice call',
        type: 'call',
        durationMs: _wasAccepted ? _elapsed.inMilliseconds : null,
      );
    } catch (e) {
      logDebug('call log write failed: $e');
    }
  }

  void _finish(String? reason) {
    if (_resolved) return;
    _resolved = true;
    CallService.instance.onEngineFailure = null;
    _ringTimeoutTimer?.cancel();
    _durationTicker?.cancel();
    _callSub?.cancel();
    _pulse.stop();
    unawaited(_logCallToChat());
    unawaited(CallService.instance.releaseEngine());
    if (!mounted) return;
    if (reason == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _phase = _Phase.ended;
      _endReason = reason;
    });
    Timer(const Duration(seconds: 2), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    CallService.instance.callScreenActive = false;
    _pulse.dispose();
    _ringTimeoutTimer?.cancel();
    _durationTicker?.cancel();
    _callSub?.cancel();
    super.dispose();
  }

  String _durationText() {
    final m = _elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _statusText(AppLocalizations loc) {
    switch (_phase) {
      case _Phase.connecting:
        return loc.callConnecting;
      case _Phase.ringing:
        return loc.callRinging;
      case _Phase.incoming:
        return loc.incomingVoiceCall;
      case _Phase.accepted:
        return _durationText();
      case _Phase.ended:
        return _endReason ?? loc.callEnded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final accepted = _phase == _Phase.accepted;
    final ended = _phase == _Phase.ended;
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _hangUp();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF12141A),
        body: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF232834),
                    Color(0xFF161922),
                    Color(0xFF0F1116),
                  ],
                ),
              ),
            ),
            // Ambient glow behind the avatar — warm while ringing, green once
            // the call connects, gone when it ends.
            _glow(LL.orange, visible: !accepted && !ended),
            _glow(LL.green, visible: accepted),
            SafeArea(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                builder: (context, t, child) => Opacity(
                  opacity: t,
                  child: Transform.translate(
                      offset: Offset(0, 28 * (1 - t)), child: child),
                ),
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 400),
                      opacity: ended ? 0.55 : 1,
                      child: _avatarWithRings(accepted),
                    ),
                    const SizedBox(height: 30),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(widget.peerName,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: LL.display(28, color: Colors.white)),
                    ),
                    const SizedBox(height: 14),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                                  begin: const Offset(0, 0.35),
                                  end: Offset.zero)
                              .animate(anim),
                          child: child,
                        ),
                      ),
                      child: accepted
                          ? _durationPill()
                          : Text(_statusText(loc),
                              key: ValueKey(_statusText(loc)),
                              style: LL.body(15, color: Colors.white70)),
                    ),
                    const Spacer(flex: 3),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: ScaleTransition(
                            scale: Tween<double>(begin: 0.92, end: 1)
                                .animate(anim),
                            child: child),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(_phase == _Phase.incoming
                            ? 'incoming'
                            : ended
                                ? 'ended'
                                : 'incall'),
                        child: _controls(loc),
                      ),
                    ),
                    const SizedBox(height: 44),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Soft radial halo behind the avatar; cross-fades between phases.
  Widget _glow(Color color, {required bool visible}) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 600),
      opacity: visible ? 1 : 0,
      child: Align(
        alignment: const Alignment(0, -0.42),
        child: Container(
          width: 360,
          height: 360,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color.withOpacity(0.20), color.withOpacity(0.0)],
            ),
          ),
        ),
      ),
    );
  }

  /// Avatar inside a gradient ring, with expanding ripple rings and a subtle
  /// breathing scale while the call is still ringing.
  Widget _avatarWithRings(bool accepted) {
    final ringing = _phase == _Phase.connecting ||
        _phase == _Phase.ringing ||
        _phase == _Phase.incoming;
    return SizedBox(
      width: 250,
      height: 250,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final t = _pulse.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              if (ringing)
                CustomPaint(
                  size: const Size(250, 250),
                  painter: _RipplePainter(t, LL.orangeLight),
                ),
              Transform.scale(
                scale: ringing ? 1 + 0.02 * math.sin(t * 2 * math.pi) : 1.0,
                child: child,
              ),
            ],
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 450),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: accepted
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF35C97F), Color(0xFF148F53)],
                  )
                : LL.grad,
            boxShadow: [
              BoxShadow(
                color: (accepted ? LL.green : LL.orange).withOpacity(0.35),
                blurRadius: 40,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF14161C),
            ),
            child: _avatar(),
          ),
        ),
      ),
    );
  }

  /// Live call timer chip shown once the call is connected.
  Widget _durationPill() {
    return Container(
      key: const ValueKey('duration'),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: LL.green,
              boxShadow: [
                BoxShadow(color: LL.green.withOpacity(0.7), blurRadius: 8),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Text(
            _durationText(),
            style: LL
                .body(15, color: Colors.white, weight: FontWeight.w600)
                .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    );
  }

  Widget _avatar() {
    final initial =
        widget.peerName.isNotEmpty ? widget.peerName[0].toUpperCase() : '?';
    return Container(
      width: 132,
      height: 132,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LL.grad,
      ),
      alignment: Alignment.center,
      child: widget.peerImageUrl != null && widget.peerImageUrl!.isNotEmpty
          ? ClipOval(
              child: Image.network(
                widget.peerImageUrl!,
                width: 132,
                height: 132,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _initialText(initial),
              ),
            )
          : _initialText(initial),
    );
  }

  Widget _initialText(String initial) => Text(
        initial,
        style: LL.display(44, color: Colors.white),
      );

  Widget _controls(AppLocalizations loc) {
    if (_phase == _Phase.incoming) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _circleButton(
              icon: Icons.call_end_rounded,
              color: const Color(0xFFE5484D),
              label: loc.decline,
              onTap: _decline,
            ),
            _circleButton(
              icon: Icons.call_rounded,
              color: LL.green,
              label: loc.accept,
              onTap: _accept,
            ),
          ],
        ),
      );
    }

    if (_phase == _Phase.ended) return const SizedBox(height: 88);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _toggleButton(
          icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
          active: _muted,
          onTap: () {
            setState(() => _muted = !_muted);
            CallService.instance.setMuted(_muted);
          },
        ),
        _circleButton(
          icon: Icons.call_end_rounded,
          color: const Color(0xFFE5484D),
          label: null,
          onTap: _hangUp,
          size: 76,
        ),
        _toggleButton(
          icon: _speaker
              ? Icons.volume_up_rounded
              : Icons.hearing_rounded,
          active: _speaker,
          onTap: () {
            setState(() => _speaker = !_speaker);
            CallService.instance.setSpeakerphone(_speaker);
          },
        ),
      ],
    );
  }

  Widget _circleButton({
    required IconData icon,
    required Color color,
    required String? label,
    required VoidCallback onTap,
    double size = 68,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.45),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: color,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Icon(icon, color: Colors.white, size: size * 0.42),
            ),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 10),
          Text(label, style: LL.body(13, color: Colors.white70)),
        ],
      ],
    );
  }

  Widget _toggleButton({
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? Colors.white : Colors.white.withOpacity(0.10),
        border: Border.all(
            color: Colors.white.withOpacity(active ? 0 : 0.16)),
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(icon,
                  key: ValueKey(icon),
                  color: active ? const Color(0xFF14161C) : Colors.white,
                  size: 24),
            ),
          ),
        ),
      ),
    );
  }
}

/// Expanding, fading rings behind the avatar while a call is ringing.
class _RipplePainter extends CustomPainter {
  _RipplePainter(this.t, this.color);

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const ringCount = 3;
    final baseRadius = size.width * 0.30;
    final maxRadius = size.width * 0.5;
    for (var i = 0; i < ringCount; i++) {
      final p = (t + i / ringCount) % 1.0;
      final radius = baseRadius + (maxRadius - baseRadius) * p;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = color.withOpacity((1 - p) * 0.35);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_RipplePainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.color != color;
}
