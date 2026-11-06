import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  Database? _database;
  Future<Database> open() async {
    if (_database != null) return _database!;
    final root = await getDatabasesPath();
    _database = await openDatabase(
      path.join(root, 'mesh_messenger.db'),
      version: 1,
      onCreate: (db, version) async {
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
      },
    );
    return _database!;
  }
}
