import 'dart:async';
import '../mesh/packet.dart';
import '../mesh/relay_worker.dart';
import 'lan_socket_transport.dart';

/// Connects peer discovery, the bounded local relay queue, and LAN transport.
/// A successful TCP write marks the next hop as accepted by the socket only;
/// authenticated app-level delivery/read receipts must update ticks separately.
class MeshTransportCoordinator {
  MeshTransportCoordinator({required this.transport, required this.relay, required this.localNodeId});
  final LanSocketTransport transport;
  final RelayWorker relay;
  final String localNodeId;
  void Function(MeshPacket packet, MeshPeer peer)? onLocalPacket;
  final Map<String, MeshPeer> _peers = {};
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    transport.onPeerHandshake = (peer) { _peers[peer.nodeId] = peer; flushForPeer(peer); };
    transport.onPacket = (packet, peer) async {
      if (packet.payloadType == 'delivery_receipt' || packet.payloadType == 'read_receipt') {
        await relay.markReceipt(packet.payload, read: packet.payloadType == 'read_receipt');
        return;
      }
      final accepted = await relay.acceptFromPeer(packet);
      if (accepted == null) return;
      if (accepted.recipientId == localNodeId) {
        onLocalPacket?.call(accepted, peer);
      } else {
        await flushForPeer(peer);
      }
    };
    await transport.start();
    _started = true;
  }

  Future<bool> queue(MeshPacket packet) async {
    final inserted = await relay.enqueue(packet);
    if (inserted) {
      final targetPeer = _peers[packet.recipientId];
      if (targetPeer != null) await _sendRecord(packet, targetPeer);
    }
    return inserted;
  }

  Future<void> flushForPeer(MeshPeer peer) async {
    for (final record in await relay.pending()) {
      final packet = record.packet;
      if (packet.recipientId != peer.nodeId && packet.path.contains(peer.nodeId)) continue;
      if (packet.ttl <= 0) continue;
      final ok = await transport.send(peer, packet);
      if (ok) await relay.markSentToNextHop(packet.packetId);
    }
  }

  Future<void> _sendRecord(MeshPacket packet, MeshPeer peer) async {
    if (await transport.send(peer, packet)) await relay.markSentToNextHop(packet.packetId);
  }

  Future<void> dispose() async {
    await transport.stop();
    _peers.clear();
    _started = false;
  }
}
