import 'package:cryptography/cryptography.dart';
import '../core/crypto_service.dart';
import '../core/uuid.dart';
import 'local_database.dart';

class StoredMessage {
  const StoredMessage({required this.id, required this.conversationId, required this.senderId, required this.text, required this.sentAt, required this.deliveryState});
  final String id;
  final String conversationId;
  final String senderId;
  final String text;
  final DateTime sentAt;
  final String deliveryState;
}

class MessageRepository {
  MessageRepository(this._database, this._crypto);
  final LocalDatabase _database;
  final CryptoService _crypto;

  Future<List<StoredMessage>> list(String conversationId) async {
    final db = await _database.open();
    final rows = await db.query('messages', where: 'conversation_id = ?', whereArgs: [conversationId], orderBy: 'sent_at ASC');
    final result = <StoredMessage>[];
    for (final row in rows) {
      final text = await _crypto.decrypt({'ciphertext': row['ciphertext']! as String, 'nonce': row['nonce']! as String, 'mac': row['mac']! as String});
      result.add(StoredMessage(id: row['id']! as String, conversationId: conversationId, senderId: row['sender_id']! as String, text: text, sentAt: DateTime.fromMillisecondsSinceEpoch(row['sent_at']! as int), deliveryState: row['delivery_state']! as String));
    }
    return result;
  }

  Future<void> addLocalMessage({required String conversationId, required String senderId, required String text}) async {
    final encrypted = await _crypto.encrypt(text);
    final db = await _database.open();
    await db.insert('messages', {
      'id': const Uuid().v4(),
      'conversation_id': conversationId,
      'sender_id': senderId,
      'ciphertext': encrypted['ciphertext'],
      'nonce': encrypted['nonce'],
      'mac': encrypted['mac'],
      'sent_at': DateTime.now().millisecondsSinceEpoch,
      'delivery_state': 'queued',
    });
  }
}
