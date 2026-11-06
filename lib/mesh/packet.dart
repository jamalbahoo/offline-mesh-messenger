import 'dart:convert';

/// Opaque end-to-end encrypted payload envelope. Relays must not interpret the
/// ciphertext. This class describes routing metadata, not a crypto protocol.
class MeshPacket {
  const MeshPacket({
    required this.senderId,
    required this.recipientId,
    required this.packetId,
    required this.hopCount,
    required this.path,
    required this.ttl,
    required this.payload,
    required this.payloadType,
    required this.timestamp,
  });

  final String senderId;
  final String recipientId;
  final String packetId;
  final int hopCount;
  final List<String> path;
  final int ttl;
  final String payload;
  final String payloadType;
  final DateTime timestamp;

  static const maxHops = 8;
  static const maxPayloadLength = 64 * 1024;

  Map<String, Object> toJson() => {
        'senderId': senderId,
        'recipientId': recipientId,
        'packetId': packetId,
        'hopCount': hopCount,
        'path': path,
        'ttl': ttl,
        'payload': payload,
        'payloadType': payloadType,
        'timestamp': timestamp.toUtc().toIso8601String(),
      };

  String encode() => jsonEncode(toJson());

  factory MeshPacket.fromJson(Map<String, dynamic> json) {
    String requiredText(String key, {int max = 256}) {
      final value = json[key];
      if (value is! String || value.isEmpty || value.length > max) {
        throw FormatException('Invalid $key');
      }
      return value;
    }

    final hops = json['hopCount'];
    final ttl = json['ttl'];
    final rawPath = json['path'];
    final rawTime = json['timestamp'];
    if (hops is! int || hops < 0 || hops > maxHops) throw const FormatException('Invalid hopCount');
    if (ttl is! int || ttl < 0 || ttl > maxHops) throw const FormatException('Invalid ttl');
    if (rawPath is! List || rawPath.length > maxHops + 1 || rawPath.any((item) => item is! String || item.length > 256)) {
      throw const FormatException('Invalid path');
    }
    if (rawTime is! String) throw const FormatException('Invalid timestamp');
    final payload = requiredText('payload', max: maxPayloadLength);
    return MeshPacket(
      senderId: requiredText('senderId'),
      recipientId: requiredText('recipientId'),
      packetId: requiredText('packetId', max: 128),
      hopCount: hops,
      path: List<String>.unmodifiable(rawPath.cast<String>()),
      ttl: ttl,
      payload: payload,
      payloadType: requiredText('payloadType', max: 64),
      timestamp: DateTime.parse(rawTime).toUtc(),
    );
  }

  factory MeshPacket.decode(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map<String, dynamic>) throw const FormatException('Packet must be a JSON object');
    return MeshPacket.fromJson(decoded);
  }

  /// Add this relay to the route and decrement the remaining forwarding budget.
  /// A repeated node is rejected to avoid routing loops.
  MeshPacket forwardedBy(String relayId) {
    if (ttl <= 0 || hopCount >= maxHops || path.contains(relayId)) {
      throw StateError('Packet cannot be forwarded (TTL, hop limit, or route loop).');
    }
    return MeshPacket(
      senderId: senderId,
      recipientId: recipientId,
      packetId: packetId,
      hopCount: hopCount + 1,
      path: List.unmodifiable([...path, relayId]),
      ttl: ttl - 1,
      payload: payload,
      payloadType: payloadType,
      timestamp: timestamp,
    );
  }
}
