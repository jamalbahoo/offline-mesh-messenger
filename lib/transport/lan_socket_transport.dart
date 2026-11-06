import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../mesh/packet.dart';

class MeshPeer {
  const MeshPeer({required this.nodeId, required this.host, required this.tcpPort, required this.lastSeen});
  final String nodeId;
  final InternetAddress host;
  final int tcpPort;
  final DateTime lastSeen;
}

/// Experimental IPv4 LAN transport. It is not a Bluetooth mesh implementation
/// and should only be enabled on a trusted local network. Packets are bounded
/// newline-delimited JSON; application payload encryption/authentication is
/// expected to be provided by a future end-to-end protocol.
class LanSocketTransport {
  LanSocketTransport({required this.nodeId, this.tcpPort = 40444, this.udpPort = 40445});
  final String nodeId;
  final int tcpPort;
  final int udpPort;
  final Map<String, MeshPeer> _peers = {};
  final Map<Socket, String> _buffers = {};
  ServerSocket? _server;
  RawDatagramSocket? _udp;
  Timer? _beaconTimer;
  bool _running = false;

  void Function(MeshPeer peer)? onPeerHandshake;
  void Function(MeshPacket packet, MeshPeer peer)? onPacket;
  void Function(Object error)? onError;

  List<MeshPeer> get peers => List.unmodifiable(_peers.values);

  Future<void> start() async {
    if (_running) return;
    _server = await ServerSocket.bind(InternetAddress.anyIPv4, tcpPort, shared: true);
    _server!.listen(_acceptSocket, onError: (Object error) => onError?.call(error));
    _udp = await RawDatagramSocket.bind(InternetAddress.anyIPv4, udpPort, reuseAddress: true);
    _udp!.broadcastEnabled = true;
    _udp!.listen(_onDatagram, onError: (Object error) => onError?.call(error));
    _running = true;
    _beaconTimer = Timer.periodic(const Duration(seconds: 15), (_) => announce());
    announce();
  }

  void announce() {
    final socket = _udp;
    if (!_running || socket == null) return;
    final beacon = utf8.encode(jsonEncode({'kind': 'mesh_beacon', 'nodeId': nodeId, 'tcpPort': tcpPort}));
    try { socket.send(beacon, InternetAddress('255.255.255.255'), udpPort); }
    catch (error) { onError?.call(error); }
  }

  void _onDatagram(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final datagram = _udp?.receive();
    if (datagram == null) return;
    try {
      final value = jsonDecode(utf8.decode(datagram.data));
      if (value is! Map || value['kind'] != 'mesh_beacon') return;
      final id = value['nodeId'];
      final port = value['tcpPort'];
      if (id is! String || id.isEmpty || id == nodeId || id.length > 256 || port is! int || port < 1 || port > 65535) return;
      final peer = MeshPeer(nodeId: id, host: datagram.address, tcpPort: port, lastSeen: DateTime.now());
      _peers[id] = peer;
      onPeerHandshake?.call(peer);
    } catch (error) { onError?.call(error); }
  }

  void _acceptSocket(Socket socket) {
    _buffers[socket] = '';
    socket.setOption(SocketOption.tcpNoDelay, true);
    socket.listen((bytes) {
      var buffer = (_buffers[socket] ?? '') + utf8.decode(bytes, allowMalformed: false);
      if (buffer.length > MeshPacket.maxPayloadLength + 8192) { socket.destroy(); _buffers.remove(socket); return; }
      var newline = buffer.indexOf('\n');
      while (newline >= 0) {
        final line = buffer.substring(0, newline).trim();
        buffer = buffer.substring(newline + 1);
        if (line.isNotEmpty) _handleLine(socket, line);
        newline = buffer.indexOf('\n');
      }
      _buffers[socket] = buffer;
    }, onDone: () { _buffers.remove(socket); socket.destroy(); }, onError: (Object error) { _buffers.remove(socket); socket.destroy(); onError?.call(error); });
  }

  String? _socketPeerId;
  void _handleLine(Socket socket, String line) {
    try {
      final value = jsonDecode(line);
      if (value is! Map<String, dynamic>) return;
      if (value['kind'] == 'hello') {
        final id = value['nodeId'];
        if (id is! String || id.isEmpty || id == nodeId || id.length > 256) return;
        final peer = MeshPeer(nodeId: id, host: socket.remoteAddress, tcpPort: value['tcpPort'] is int ? value['tcpPort'] as int : tcpPort, lastSeen: DateTime.now());
        _peers[id] = peer;
        _socketPeerId = id;
        onPeerHandshake?.call(peer);
        socket.writeln(jsonEncode({'kind': 'hello', 'nodeId': nodeId, 'tcpPort': tcpPort}));
        return;
      }
      final packet = MeshPacket.fromJson(value);
      final id = _socketPeerId;
      if (id == null) return; // Refuse packets until a basic peer hello is seen.
      final peer = _peers[id];
      if (peer != null) onPacket?.call(packet, peer);
    } catch (error) { onError?.call(error); }
  }

  Future<bool> send(MeshPeer peer, MeshPacket packet) async {
    if (!_running) return false;
    Socket? socket;
    try {
      socket = await Socket.connect(peer.host, peer.tcpPort, timeout: const Duration(seconds: 3));
      socket.setOption(SocketOption.tcpNoDelay, true);
      socket.writeln(jsonEncode({'kind': 'hello', 'nodeId': nodeId, 'tcpPort': tcpPort}));
      socket.writeln(packet.encode());
      await socket.flush().timeout(const Duration(seconds: 3));
      await socket.close();
      return true; // TCP acceptance only; recipient delivery needs an app ACK.
    } catch (error) {
      socket?.destroy();
      onError?.call(error);
      return false;
    }
  }

  Future<void> stop() async {
    _running = false;
    _beaconTimer?.cancel();
    _beaconTimer = null;
    await _server?.close();
    _server = null;
    _udp?.close();
    _udp = null;
    for (final socket in _buffers.keys.toList()) { socket.destroy(); }
    _buffers.clear();
    _peers.clear();
  }
}
