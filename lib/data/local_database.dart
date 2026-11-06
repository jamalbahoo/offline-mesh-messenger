import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  Database? _database;

  Future<Database> open() async {
    if (_database != null) return _database!;
    final root = await getDatabasesPath();
    _database = await openDatabase(
      path.join(root, 'mesh_messenger.db'),
      version: 2,
      onCreate: (db, version) async {
        await _createMessages(db);
        await _createRelayQueue(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createRelayQueue(db);
      },
    );
    return _database!;
  }

  Future<void> _createMessages(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE messages (
      id TEXT PRIMARY KEY,
      conversation_id TEXT NOT NULL,
      sender_id TEXT NOT NULL,
      ciphertext TEXT NOT NULL,
      nonce TEXT NOT NULL,
      mac TEXT NOT NULL,
      sent_at INTEGER NOT NULL,
      delivery_state TEXT NOT NULL CHECK(delivery_state IN ('queued','relayed','delivered','read'))
    )''');
    await db.execute('CREATE INDEX messages_conversation_time ON messages(conversation_id, sent_at)');
  }

  Future<void> _createRelayQueue(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE relay_queue (
      packet_id TEXT PRIMARY KEY,
      packet_json TEXT NOT NULL,
      expires_at INTEGER NOT NULL,
      state TEXT NOT NULL CHECK(state IN ('queued','relayed','delivered','read','expired')),
      attempts INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )''');
    await db.execute('CREATE INDEX relay_queue_pending ON relay_queue(state, expires_at, created_at)');
  }
}
