import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Application-provided signaling adapter. Implement this using an authenticated,
/// encrypted local peer channel before enabling calls across devices.
abstract interface class CallSignaling {
  Stream<Map<String, dynamic>> get events;
  Future<void> send(Map<String, dynamic> signal);
}

class WebRtcCallEngine {
  WebRtcCallEngine({required this.localPeerId, required this.remotePeerId, required this.signaling});
  final String localPeerId;
  final String remotePeerId;
  final CallSignaling signaling;
  RTCPeerConnection? _connection;
  MediaStream? localStream;
  MediaStream? remoteStream;
  StreamSubscription<Map<String, dynamic>>? _signalSubscription;
  final _state = StreamController<RTCPeerConnectionState>.broadcast();
  Stream<RTCPeerConnectionState> get connectionStates => _state.stream;

  /// Empty ICE server list intentionally avoids external STUN/TURN. Host ICE
  /// candidates work only when the peers can directly route over the same LAN.
  Future<void> start({required bool video}) async {
    if (_connection != null) throw StateError('Call already started');
    _signalSubscription = signaling.events.listen(_onSignal);
    final connection = await createPeerConnection({'iceServers': <Map<String, dynamic>>[]});
    _connection = connection;
    connection.onConnectionState = (state) { if (!_state.isClosed) _state.add(state); };
    connection.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      unawaited(signaling.send({'type': 'ice', 'from': localPeerId, 'to': remotePeerId, 'candidate': candidate.candidate, 'sdpMid': candidate.sdpMid, 'sdpMLineIndex': candidate.sdpMLineIndex}));
    };
    connection.onTrack = (event) { if (event.streams.isNotEmpty) remoteStream = event.streams.first; };
    localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': video});
    for (final track in localStream!.getTracks()) { await connection.addTrack(track, localStream!); }
    final offer = await connection.createOffer();
    await connection.setLocalDescription(offer);
    await signaling.send({'type': 'offer', 'from': localPeerId, 'to': remotePeerId, 'sdp': offer.sdp, 'sdpType': offer.type, 'video': video});
  }

  Future<void> _onSignal(Map<String, dynamic> signal) async {
    if (signal['to'] != localPeerId || signal['from'] != remotePeerId) return;
    final connection = _connection;
    if (connection == null) return;
    switch (signal['type']) {
      case 'answer':
        final sdp = signal['sdp'];
        if (sdp is String) await connection.setRemoteDescription(RTCSessionDescription(sdp, signal['sdpType'] as String? ?? 'answer'));
      case 'ice':
        final candidate = signal['candidate'];
        if (candidate is String) await connection.addCandidate(RTCIceCandidate(candidate, signal['sdpMid'] as String?, signal['sdpMLineIndex'] as int?));
      case 'hangup':
        await close();
    }
  }

  Future<void> close() async {
    await _signalSubscription?.cancel();
    _signalSubscription = null;
    final stream = localStream;
    localStream = null;
    if (stream != null) {
      for (final track in stream.getTracks()) { await track.stop(); }
      await stream.dispose();
    }
    await _connection?.close();
    _connection = null;
    remoteStream = null;
  }

  Future<void> dispose() async {
    await close();
    await _state.close();
  }
}
