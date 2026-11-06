import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_messenger/mesh/packet.dart';

void main() {
  test('packet JSON round-trips and validates routing fields', () {
    final packet = MeshPacket(senderId: 'a', recipientId: 'c', packetId: 'packet-1', hopCount: 0, path: const ['a'], ttl: 8, payload: 'opaque-ciphertext', payloadType: 'text', timestamp: DateTime.utc(2025));
    final decoded = MeshPacket.decode(packet.encode());
    expect(decoded.packetId, packet.packetId);
    expect(decoded.path, packet.path);
    expect(decoded.timestamp, packet.timestamp);
  });

  test('forwarding increments hops, appends route, and consumes TTL', () {
    final packet = MeshPacket(senderId: 'a', recipientId: 'c', packetId: 'packet-1', hopCount: 0, path: const ['a'], ttl: 3, payload: 'ciphertext', payloadType: 'text', timestamp: DateTime.utc(2025));
    final forwarded = packet.forwardedBy('b');
    expect(forwarded.hopCount, 1);
    expect(forwarded.path, ['a', 'b']);
    expect(forwarded.ttl, 2);
    expect(() => forwarded.forwardedBy('b'), throwsStateError);
  });

  test('rejects invalid TTL and excessive path length', () {
    expect(() => MeshPacket.fromJson({'senderId':'a','recipientId':'b','packetId':'p','hopCount':0,'path':[],'ttl':99,'payload':'x','payloadType':'text','timestamp':DateTime.utc(2025).toIso8601String()}), throwsFormatException);
  });
}
