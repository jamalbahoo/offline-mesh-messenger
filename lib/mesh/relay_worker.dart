import 'package:sqflite/sqflite.dart';
import '../data/local_database.dart';
import 'packet.dart';

class RelayRecord {
  const RelayRecord({required this.packet, required this.state, required this.attempts, required this.expiresAt});
  final MeshPacket packet;
  final String state;
  final int attempts;
  final DateTime expiresAt;
}

/// Persistent, deduplicated and bounded-TTL queue. Payload must already be
/// encrypted for its intended recipient; this relay never decrypts it.
class RelayWorker {
  RelayWorker({required LocalDatabase database, required this.localNodeId}) : _database = database;
  final LocalDatabase _database;
  final String localNodeId;
  static const maxQueueRows = 1000;
  static const maxAge = Duration(days: 7);

  Future<bool> enqueue(MeshPacket packet) async {
    if (packet.ttl <= 0 || packet.hopCount > MeshPacket.maxHops) return false;
    final now = DateTime.now().toUtc();
    final db = await _database.open();
    return db.transaction((txn) async {
      final duplicate = await txn.query('relay_queue', columns: ['packet_id'], where: 'packet_id = ?', whereArgs: [packet.packetId], limit: 1);
      if (duplicate.isNotEmpty) return false;
      final count = Sqflite.firstIntValue(await txn.rawQuery("SELECT COUNT(*) FROM relay_queue WHERE state IN ('queued','relayed')")) ?? 0;
      if (count >= maxQueueRows) {
        final oldest = await txn.query('relay_queue', columns: ['packet_id'], where: "state IN ('queued','relayed')", orderBy: 'created_at ASC', limit: 1);
        if (oldest.isNotEmpty) await txn.delete('relay_queue', where: 'packet_id = ?', whereArgs: [oldest.first['packet_id']]);
      }
      await txn.insert('relay_queue', {'packet_id': packet.packetId, 'packet_json': packet.encode(), 'expires_at': now.add(maxAge).millisecondsSinceEpoch, 'state': 'queued', 'attempts': 0, 'created_at': now.millisecondsSinceEpoch, 'updated_at': now.millisecondsSinceEpoch});
      return true;
    });
  }

  Future<MeshPacket?> acceptFromPeer(MeshPacket received) async {
    final db = await _database.open();
    final existing = await db.query('relay_queue', columns: ['packet_id'], where: 'packet_id = ?', whereArgs: [received.packetId], limit: 1);
    if (existing.isNotEmpty) return null;
    if (received.recipientId == localNodeId) { await enqueue(received); return received; }
    if (received.ttl <= 0 || received.path.contains(localNodeId)) return null;
    final forwarded = received.forwardedBy(localNodeId);
    await enqueue(forwarded);
    return forwarded;
  }

  Future<List<RelayRecord>> pending({int limit = 100}) async {
    final db = await _database.open();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update('relay_queue', {'state': 'expired', 'updated_at': now}, where: "state IN ('queued','relayed') AND expires_at <= ?", whereArgs: [now]);
    final rows = await db.query('relay_queue', where: "state IN ('queued','relayed') AND expires_at > ?", whereArgs: [now], orderBy: 'created_at ASC', limit: limit.clamp(1, 200));
    return rows.map((row) => RelayRecord(packet: MeshPacket.decode(row['packet_json']! as String), state: row['state']! as String, attempts: row['attempts']! as int, expiresAt: DateTime.fromMillisecondsSinceEpoch(row['expires_at']! as int))).toList();
  }

  Future<void> markSentToNextHop(String packetId) async => _update(packetId, 'relayed', incrementAttempt: true);
  Future<void> markReceipt(String packetId, {required bool read}) async => _update(packetId, read ? 'read' : 'delivered');
  Future<String?> stateOf(String packetId) async {
    final rows = await (await _database.open()).query('relay_queue', columns: ['state'], where: 'packet_id = ?', whereArgs: [packetId], limit: 1);
    return rows.isEmpty ? null : rows.first['state'] as String;
  }
  Future<void> _update(String packetId, String state, {bool incrementAttempt = false}) async {
    await (await _database.open()).rawUpdate('UPDATE relay_queue SET state = ?, attempts = attempts + ?, updated_at = ? WHERE packet_id = ?', [state, incrementAttempt ? 1 : 0, DateTime.now().millisecondsSinceEpoch, packetId]);
  }
}
