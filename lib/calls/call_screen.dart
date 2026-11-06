import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'webrtc_call_engine.dart';

/// Full-screen calling UI shell. A secure signaling adapter is deliberately
/// required; the app must not send unauthenticated offers over LAN discovery.
class CallScreen extends StatefulWidget {
  const CallScreen({required this.peerId, required this.video, this.signaling, super.key});
  final String peerId;
  final bool video;
  final CallSignaling? signaling;
  @override
  State<CallScreen> createState() => _CallScreenState();
}
class _CallScreenState extends State<CallScreen> {
  WebRtcCallEngine? _engine;
  RTCVideoRenderer? _localRenderer;
  RTCVideoRenderer? _remoteRenderer;
  StreamSubscription<RTCPeerConnectionState>? _states;
  String _status = 'Call setup is not connected to authenticated peer signaling.';
  bool _starting = false;
  bool _muted = false;
  bool _cameraOff = false;

  Future<void> _start() async {
    final signaling = widget.signaling;
    if (signaling == null) {
      setState(() => _status = 'Unavailable: authenticated local signaling must be configured before placing a call.');
      return;
    }
    setState(() { _starting = true; _status = 'Requesting microphone and camera permission…'; });
    try {
      final local = RTCVideoRenderer();
      final remote = RTCVideoRenderer();
      await local.initialize();
      await remote.initialize();
      final engine = WebRtcCallEngine(localPeerId: 'local-user', remotePeerId: widget.peerId, signaling: signaling);
      await engine.start(video: widget.video);
      local.srcObject = engine.localStream;
      _engine = engine;
      _localRenderer = local;
      _remoteRenderer = remote;
      _states = engine.connectionStates.listen((state) { if (mounted) setState(() => _status = 'Connection: ${state.name}'); });
      if (mounted) setState(() => _status = 'Signaling offer sent; waiting for local peer…');
    } catch (error) {
      if (mounted) setState(() => _status = 'Call could not start: $error');
      await _finish();
    } finally { if (mounted) setState(() => _starting = false); }
  }

  Future<void> _finish() async {
    await _states?.cancel();
    _states = null;
    final engine = _engine;
    _engine = null;
    await engine?.dispose();
    await _localRenderer?.dispose();
    await _remoteRenderer?.dispose();
    _localRenderer = null;
    _remoteRenderer = null;
    if (mounted) setState(() => _status = 'Call ended');
  }

  @override
  void dispose() { unawaited(_finish()); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF10221E),
    appBar: AppBar(backgroundColor: Colors.transparent, title: Text(widget.video ? 'Video call' : 'Audio call')),
    body: SafeArea(child: Stack(children: [
      if (widget.video && _remoteRenderer != null)
        Positioned.fill(child: RTCVideoView(_remoteRenderer!, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover))
      else
        const Center(child: CircleAvatar(radius: 56, backgroundColor: Color(0xFF24483E), child: Icon(Icons.person, size: 64, color: Colors.white))),
      if (widget.video && _localRenderer != null) Positioned(right: 16, top: 16, width: 110, height: 160, child: ClipRRect(borderRadius: BorderRadius.circular(12), child: RTCVideoView(_localRenderer!, mirror: true))),
      Positioned(left: 20, right: 20, bottom: 28, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(widget.peerId, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(_status, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 24),
        Wrap(alignment: WrapAlignment.center, spacing: 18, children: [
          _control(Icons.mic, _muted, () { setState(() => _muted = !_muted); for (final track in _engine?.localStream?.getAudioTracks() ?? <MediaStreamTrack>[]) { track.enabled = !_muted; } }),
          if (widget.video) _control(Icons.videocam, _cameraOff, () { setState(() => _cameraOff = !_cameraOff); for (final track in _engine?.localStream?.getVideoTracks() ?? <MediaStreamTrack>[]) { track.enabled = !_cameraOff; } }),
          _control(Icons.call_end, true, _engine == null ? () => Navigator.pop(context) : _finish),
        ]),
        const SizedBox(height: 18),
        if (_engine == null) FilledButton(onPressed: _starting ? null : _start, child: Text(_starting ? 'Starting…' : 'Prepare call')),
      ])),
    ])),
  );

  Widget _control(IconData icon, bool active, VoidCallback onPressed) => CircleAvatar(backgroundColor: active ? Colors.redAccent : Colors.white24, child: IconButton(onPressed: onPressed, icon: Icon(icon, color: Colors.white)));
}

/// Incoming call presentation primitive. A real incoming-call route/notification
/// requires an authenticated signaling source and Android call-style notification.
class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({required this.callerName, required this.onAccept, required this.onDecline, super.key});
  final String callerName;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}
class _IncomingCallScreenState extends State<IncomingCallScreen> {
  Timer? _ring;
  @override
  void initState() { super.initState(); _ring = Timer.periodic(const Duration(seconds: 2), (_) => SystemSound.play(SystemSoundType.alert)); }
  @override
  void dispose() { _ring?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: const Color(0xFF10221E), body: SafeArea(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const CircleAvatar(radius: 56, child: Icon(Icons.person, size: 64)),
    const SizedBox(height: 20), Text(widget.callerName, style: const TextStyle(color: Colors.white, fontSize: 26)),
    const SizedBox(height: 8), const Text('Incoming local call', style: TextStyle(color: Colors.white70)),
    const SizedBox(height: 42), Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: widget.onDecline, icon: const Icon(Icons.call_end), label: const Text('Decline')),
      FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Colors.green), onPressed: widget.onAccept, icon: const Icon(Icons.call), label: const Text('Accept')),
    ]),
  ]))));
}
