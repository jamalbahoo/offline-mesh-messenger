import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() => runApp(const MeshMessengerApp());

class MeshMessengerApp extends StatelessWidget {
  const MeshMessengerApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Mesh Messenger',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF087F6E),
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: const Color(0xFFF7F8F8),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF087F6E),
            foregroundColor: Colors.white,
          ),
        ),
        home: const HomePage(),
      );
}

class LocalMessage {
  const LocalMessage({
    required this.id,
    required this.text,
    required this.sentAt,
    required this.isMine,
  });

  final String id;
  final String text;
  final DateTime sentAt;
  final bool isMine;

  Map<String, Object> toJson() => {
        'id': id,
        'text': text,
        'sentAt': sentAt.toIso8601String(),
        'isMine': isMine,
      };

  factory LocalMessage.fromJson(Map<String, dynamic> json) => LocalMessage(
        id: json['id'] as String,
        text: json['text'] as String,
        sentAt: DateTime.parse(json['sentAt'] as String),
        isMine: json['isMine'] as bool,
      );
}

/// Stores this prototype's message history as AES-GCM ciphertext in Android
/// Keystore-backed secure storage. This is a local-device store, not backup or
/// multi-device account recovery.
class EncryptedMessageStore {
  static const _keyName = 'mesh_aes_key_v1';
  static const _dataName = 'mesh_messages_v1';
  static const _secureStorage = FlutterSecureStorage();
  static const _cipher = AesGcm.with256bits();
  final List<LocalMessage> messages = [];
  late SecretKey _key;

  Future<void> open() async {
    final storedKey = await _secureStorage.read(key: _keyName);
    if (storedKey == null) {
      final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
      _key = SecretKey(bytes);
      await _secureStorage.write(key: _keyName, value: base64Encode(bytes));
      return;
    }
    _key = SecretKey(base64Decode(storedKey));
    final packed = await _secureStorage.read(key: _dataName);
    if (packed == null) return;
    final box = jsonDecode(packed) as Map<String, dynamic>;
    final secretBox = SecretBox(
      base64Decode(box['ciphertext'] as String),
      nonce: base64Decode(box['nonce'] as String),
      mac: Mac(base64Decode(box['mac'] as String)),
    );
    final cleartext = await _cipher.decrypt(secretBox, secretKey: _key);
    final rows = jsonDecode(utf8.decode(cleartext)) as List<dynamic>;
    messages
      ..clear()
      ..addAll(rows.map((row) =>
          LocalMessage.fromJson(row as Map<String, dynamic>)));
  }

  Future<void> add(String text) async {
    messages.add(LocalMessage(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      text: text,
      sentAt: DateTime.now(),
      isMine: true,
    ));
    final encrypted = await _cipher.encrypt(
      utf8.encode(jsonEncode(messages.map((message) => message.toJson()).toList())),
      secretKey: _key,
    );
    await _secureStorage.write(
      key: _dataName,
      value: jsonEncode({
        'nonce': base64Encode(encrypted.nonce),
        'ciphertext': base64Encode(encrypted.cipherText),
        'mac': base64Encode(encrypted.mac.bytes),
      }),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _store = EncryptedMessageStore();
  int _tab = 0;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _openStore();
  }

  Future<void> _openStore() async {
    try {
      await _store.open();
    } catch (error) {
      debugPrint('Could not open encrypted local store: $error');
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _chatsPage(),
      const _InfoPage(
        icon: Icons.circle_outlined,
        title: 'Status',
        description: 'Local status updates will appear here when status sync is implemented.',
      ),
      const _InfoPage(
        icon: Icons.call_outlined,
        title: 'Calls',
        description: 'Offline audio and video calling is not connected in this starter.',
      ),
      _settingsPage(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mesh Messenger', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(onPressed: () => _showInfo('Search', 'Search will be available when conversations are added.'), icon: const Icon(Icons.search)),
          IconButton(onPressed: () => _showInfo('More options', 'More options'), icon: const Icon(Icons.more_vert)),
        ],
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : pages[_tab],
      floatingActionButton: _tab == 0
          ? FloatingActionButton(
              onPressed: () => _showInfo('New conversation', 'Nearby discovery is not implemented yet.'),
              backgroundColor: const Color(0xFF087F6E),
              foregroundColor: Colors.white,
              child: const Icon(Icons.chat),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Chats'),
          NavigationDestination(icon: Icon(Icons.circle_outlined), label: 'Status'),
          NavigationDestination(icon: Icon(Icons.call_outlined), label: 'Calls'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _chatsPage() {
    final latest = _store.messages.isEmpty ? null : _store.messages.last;
    return ListView(
      children: [
        Container(
          color: const Color(0xFFE5F3EF),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: const Row(children: [
            Icon(Icons.info_outline, size: 18),
            SizedBox(width: 8),
            Expanded(child: Text('Local prototype • no network transport connected')),
          ]),
        ),
        ListTile(
          leading: const CircleAvatar(backgroundColor: Color(0xFF087F6E), child: Icon(Icons.devices, color: Colors.white)),
          title: const Text('My local chat', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(latest?.text ?? 'Messages are encrypted and saved on this device'),
          trailing: Text(latest == null ? '' : _timeLabel(latest.sentAt), style: const TextStyle(fontSize: 12)),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ChatPage(store: _store, onChanged: () => setState(() {})),
          )),
        ),
        const Divider(height: 1, indent: 82),
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text('To chat with another device, a transport and peer discovery layer must be added.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
        ),
      ],
    );
  }

  Widget _settingsPage() => ListView(
        children: [
          const ListTile(title: Text('Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
          const ListTile(leading: Icon(Icons.person_outline), title: Text('Profile'), subtitle: Text('Local prototype account')),
          const ListTile(leading: Icon(Icons.lock_outline), title: Text('Privacy'), subtitle: Text('Encryption at rest for local messages')),
          const ListTile(leading: Icon(Icons.block_outlined), title: Text('Blocked contacts'), subtitle: Text('No contacts to show')),
          const ListTile(leading: Icon(Icons.share_outlined), title: Text('Share app offline'), subtitle: Text('Requires hotspot controls and a local download server')),
          const ListTile(leading: Icon(Icons.hub_outlined), title: Text('Mesh network'), subtitle: Text('Transport and relay engine not yet implemented')),
          const AboutListTile(icon: Icon(Icons.info_outline), applicationName: 'Mesh Messenger', applicationVersion: '0.1.0'),
        ],
      );

  void _showInfo(String title, String message) => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
}

class ChatPage extends StatefulWidget {
  const ChatPage({required this.store, required this.onChanged, super.key});
  final EncryptedMessageStore store;
  final VoidCallback onChanged;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _input.clear();
    try {
      await widget.store.add(text);
      widget.onChanged();
      if (mounted) setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      });
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save message: $error')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('My local chat')),
        body: Column(children: [
          const Padding(
            padding: EdgeInsets.all(10),
            child: Text('Demo messages stay on this device; delivery ticks are not available without networking.',
                style: TextStyle(fontSize: 12, color: Colors.black54), textAlign: TextAlign.center),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              itemCount: widget.store.messages.length,
              itemBuilder: (context, index) {
                final message = widget.store.messages[index];
                return Align(
                  alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 300),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: message.isMine ? const Color(0xFFD8F5E9) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Align(alignment: Alignment.centerLeft, child: Text(message.text)),
                      const SizedBox(height: 3),
                      Text(_timeLabel(message.sentAt), style: const TextStyle(fontSize: 10, color: Colors.black54)),
                    ]),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(children: [
                Expanded(child: TextField(
                  controller: _input,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Message',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  ),
                  onSubmitted: (_) => _send(),
                )),
                const SizedBox(width: 6),
                IconButton.filled(
                  onPressed: _sending ? null : _send,
                  icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
                ),
              ]),
            ),
          ),
        ]),
      );
}

class _InfoPage extends StatelessWidget {
  const _InfoPage({required this.icon, required this.title, required this.description});
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 56, color: const Color(0xFF087F6E)),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(description, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
          ]),
        ),
      );
}

String _timeLabel(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
