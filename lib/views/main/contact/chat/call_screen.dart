import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:lifeline/constants/app_design.dart';
import 'package:lifeline/services/call_service.dart';
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

class _CallScreenState extends State<CallScreen> {
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

  @override
  void initState() {
    super.initState();
    _phase = widget.isOutgoing ? _Phase.connecting : _Phase.incoming;
    _init();
  }

  Future<void> _init() async {
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

  void _finish(String? reason) {
    if (_resolved) return;
    _resolved = true;
    _ringTimeoutTimer?.cancel();
    _durationTicker?.cancel();
    _callSub?.cancel();
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
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _hangUp();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1B1E26),
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              _avatar(),
              const SizedBox(height: 24),
              Text(widget.peerName,
                  style: LL.display(26, color: Colors.white)),
              const SizedBox(height: 10),
              Text(_statusText(loc),
                  style: LL.body(15, color: Colors.white70)),
              const Spacer(flex: 3),
              _controls(loc),
              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatar() {
    final initial =
        widget.peerName.isNotEmpty ? widget.peerName[0].toUpperCase() : '?';
    return Container(
      width: 120,
      height: 120,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LL.grad,
      ),
      alignment: Alignment.center,
      child: widget.peerImageUrl != null && widget.peerImageUrl!.isNotEmpty
          ? ClipOval(
              child: Image.network(
                widget.peerImageUrl!,
                width: 120,
                height: 120,
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
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _circleButton(
            icon: Icons.call_end_rounded,
            color: Colors.redAccent,
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
      );
    }

    if (_phase == _Phase.ended) return const SizedBox(height: 72);

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
          color: Colors.redAccent,
          label: null,
          onTap: _hangUp,
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
  }) {
    return Column(
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 8),
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
    return Material(
      color: active ? Colors.white : Colors.white.withOpacity(0.15),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Icon(icon,
              color: active ? const Color(0xFF1B1E26) : Colors.white,
              size: 24),
        ),
      ),
    );
  }
}
