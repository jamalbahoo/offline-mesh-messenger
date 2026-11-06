import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../calls/call_screen.dart';
import '../data/message_repository.dart';
import '../mesh/mesh_service.dart';
import '../share/share_screen.dart';

const _green = Color(0xFF087F6E);

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.username, required this.messages, required this.onSignOut, super.key});
  final String username;
  final MessageRepository messages;
  final VoidCallback onSignOut;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  late final MeshService _mesh = MeshService();
  bool _serviceOn = false;
  @override
  void dispose() { unawaited(_mesh.stop()); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mesh Messenger', style: TextStyle(fontWeight: FontWeight.w700)), actions: [IconButton(onPressed: widget.onSignOut, icon: const Icon(Icons.logout), tooltip: 'Sign out')]),
    body: IndexedStack(index: _tab, children: [
      _ChatsTab(username: widget.username, repository: widget.messages),
      const _StatusTab(),
      const _CallsTab(),
      _SettingsTab(username: widget.username, serviceOn: _serviceOn, onServiceChanged: _toggleService, onShare: _openShare),
    ]),
    bottomNavigationBar: NavigationBar(selectedIndex: _tab, onDestinationSelected: (index) => setState(() => _tab = index), destinations: const [
      NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Chats'),
      NavigationDestination(icon: Icon(Icons.circle_outlined), selectedIcon: Icon(Icons.circle), label: 'Status'),
      NavigationDestination(icon: Icon(Icons.call_outlined), selectedIcon: Icon(Icons.call), label: 'Calls'),
      NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
    ]),
  );

  Future<void> _toggleService(bool enable) async {
    try {
      if (enable) { await _mesh.start(); } else { await _mesh.stop(); }
      if (mounted) setState(() => _serviceOn = enable);
    } on PlatformException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message ?? 'Could not change service state.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Mesh service failed: $error')));
    }
  }
  Future<void> _openShare() async => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ShareScreen()));
}

class _ChatsTab extends StatefulWidget {
  const _ChatsTab({required this.username, required this.repository});
  final String username;
  final MessageRepository repository;
  @override
  State<_ChatsTab> createState() => _ChatsTabState();
}
class _ChatsTabState extends State<_ChatsTab> {
  static const _conversation = 'local-demo';
  List<StoredMessage> _items = [];
  bool _loading = true;
  @override
  void initState() { super.initState(); _refresh(); }
  Future<void> _refresh() async {
    try { _items = await widget.repository.list(_conversation); } catch (_) { }
    if (mounted) setState(() => _loading = false);
  }
  @override
  Widget build(BuildContext context) => ListView(children: [
    _meshBanner('Local-first prototype · peer identity and delivery receipts are not verified'),
    Padding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 8), child: Text('Messages', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
    if (_loading) const LinearProgressIndicator(),
    ListTile(
      leading: const CircleAvatar(radius: 26, backgroundColor: Color(0xFFD8F5E9), child: Icon(Icons.devices, color: _green)),
      title: const Text('Local conversation', style: TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(_items.isEmpty ? 'No messages yet · saved on this device' : _items.last.text, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: _items.isEmpty ? null : Text(_clock(_items.last.sentAt), style: const TextStyle(fontSize: 12)),
      onTap: () async { await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => _ChatScreen(repository: widget.repository, username: widget.username))); await _refresh(); },
    ),
    if (!_loading && _items.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('Your local messages are encrypted before being saved. No remote delivery is available yet.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54))),
  ]);
}

class _ChatScreen extends StatefulWidget {
  const _ChatScreen({required this.repository, required this.username});
  final MessageRepository repository;
  final String username;
  @override
  State<_ChatScreen> createState() => _ChatScreenState();
}
class _ChatScreenState extends State<_ChatScreen> {
  static const _conversation = 'local-demo';
  final _input = TextEditingController();
  List<StoredMessage> _items = [];
  bool _busy = false;
  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _input.dispose(); super.dispose(); }
  Future<void> _load() async { _items = await widget.repository.list(_conversation); if (mounted) setState(() {}); }
  Future<void> _send() async {
    final text = _input.text.trim(); if (text.isEmpty || _busy) return;
    setState(() => _busy = true);
    try { await widget.repository.addLocalMessage(conversationId: _conversation, senderId: widget.username, text: text); _input.clear(); await _load(); }
    catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save message: $error'))); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Local conversation')),
    body: Column(children: [
      _meshBanner('Single ✓ means saved locally only; it is not delivered.'),
      Expanded(child: ListView.builder(padding: const EdgeInsets.all(12), itemCount: _items.length, itemBuilder: (_, index) {
        final item = _items[index];
        return Align(alignment: Alignment.centerRight, child: Container(margin: const EdgeInsets.symmetric(vertical: 4), padding: const EdgeInsets.all(12), constraints: const BoxConstraints(maxWidth: 300), decoration: BoxDecoration(color: const Color(0xFFD8F5E9), borderRadius: BorderRadius.circular(14)), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Align(alignment: Alignment.centerLeft, child: Text(item.text)), const SizedBox(height: 4), Text('${_clock(item.sentAt)}  ✓', style: const TextStyle(fontSize: 10, color: Colors.black54))])));
      })),
      SafeArea(top: false, child: Padding(padding: const EdgeInsets.all(8), child: Row(children: [Expanded(child: TextField(controller: _input, minLines: 1, maxLines: 4, decoration: InputDecoration(hintText: 'Message', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10)), onSubmitted: (_) => _send())), const SizedBox(width: 8), IconButton.filled(onPressed: _busy ? null : _send, icon: const Icon(Icons.send))]))),
    ]),
  );
}

class _StatusTab extends StatelessWidget {
  const _StatusTab();
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    Text('Status', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
    const SizedBox(height: 16),
    const Card(child: ListTile(leading: CircleAvatar(child: Icon(Icons.person)), title: Text('My status'), subtitle: Text('Local status sync is not connected yet'), trailing: Icon(Icons.add_circle_outline))),
    const SizedBox(height: 16),
    const Text('RECENT UPDATES', style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 1)),
    const SizedBox(height: 8),
    const Card(child: ListTile(leading: CircleAvatar(backgroundColor: Color(0xFFE5F3EF), child: Icon(Icons.hub_outlined, color: _green)), title: Text('Mesh status'), subtitle: Text('Peer status updates will appear after authenticated sync is available.'))),
  ]);
}

class _CallsTab extends StatelessWidget {
  const _CallsTab();
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    Text('Calls', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
    const SizedBox(height: 12),
    const Card(child: ListTile(leading: CircleAvatar(child: Icon(Icons.link_off)), title: Text('Offline calling setup'), subtitle: Text('WebRTC engine foundation is present; secure local signaling is not connected.'))),
    const SizedBox(height: 16),
    FilledButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const CallScreen(peerId: 'nearby-peer', video: false))), icon: const Icon(Icons.call), label: const Text('Start audio call setup')),
    const SizedBox(height: 8),
    OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const CallScreen(peerId: 'nearby-peer', video: true))), icon: const Icon(Icons.videocam), label: const Text('Start video call setup')),
  ]);
}

class _SettingsTab extends StatefulWidget {
  const _SettingsTab({required this.username, required this.serviceOn, required this.onServiceChanged, required this.onShare});
  final String username;
  final bool serviceOn;
  final ValueChanged<bool> onServiceChanged;
  final VoidCallback onShare;
  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}
class _SettingsTabState extends State<_SettingsTab> {
  static const _blockedKey = 'mesh_blocked_peers_v1';
  List<String> _blocked = [];
  bool _readReceipts = true;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() { _blocked = prefs.getStringList(_blockedKey) ?? []; _readReceipts = prefs.getBool('mesh_read_receipts_v1') ?? true; });
  }
  Future<void> _addBlocked() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(context: context, builder: (context) => AlertDialog(title: const Text('Block peer'), content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Peer ID')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Block'))]));
    controller.dispose();
    if (value == null || value.isEmpty || _blocked.contains(value)) return;
    final prefs = await SharedPreferences.getInstance();
    setState(() => _blocked = [..._blocked, value]);
    await prefs.setStringList(_blockedKey, _blocked);
  }
  Future<void> _removeBlocked(String peer) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _blocked.remove(peer));
    await prefs.setStringList(_blockedKey, _blocked);
  }
  Future<void> _setReceipts(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _readReceipts = value);
    await prefs.setBool('mesh_read_receipts_v1', value);
  }
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.only(bottom: 24), children: [
    Padding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 8), child: Text('Settings', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold))),
    ListTile(leading: const CircleAvatar(child: Icon(Icons.person)), title: const Text('Local profile'), subtitle: Text(widget.username)),
    const Divider(),
    const ListTile(title: Text('NETWORK', style: TextStyle(fontWeight: FontWeight.bold))),
    SwitchListTile(secondary: const Icon(Icons.hub_outlined), title: const Text('LAN mesh listeners'), subtitle: Text(widget.serviceOn ? 'Experimental TCP/UDP listeners are running' : 'Start experimental LAN discovery while app is active'), value: widget.serviceOn, onChanged: widget.onServiceChanged),
    ListTile(leading: const Icon(Icons.share_outlined), title: const Text('Share App Offline'), subtitle: const Text('Hotspot, local APK portal and QR code'), onTap: widget.onShare),
    const Divider(),
    const ListTile(title: Text('PRIVACY', style: TextStyle(fontWeight: FontWeight.bold))),
    SwitchListTile(secondary: const Icon(Icons.done_all), title: const Text('Read receipts'), subtitle: const Text('Preference only; authenticated receipts are not implemented'), value: _readReceipts, onChanged: _setReceipts),
    ListTile(leading: const Icon(Icons.block_outlined), title: const Text('Blocked peers'), subtitle: Text(_blocked.isEmpty ? 'No blocked peer IDs' : '${_blocked.length} blocked'), trailing: const Icon(Icons.add), onTap: _addBlocked),
    ..._blocked.map((peer) => ListTile(dense: true, leading: const Icon(Icons.person_off_outlined), title: Text(peer), trailing: IconButton(onPressed: () => _removeBlocked(peer), icon: const Icon(Icons.close), tooltip: 'Unblock'))),
    const Padding(padding: EdgeInsets.all(16), child: Text('Phase 4 WebRTC is a calling foundation only. It has no authenticated signaling or incoming-call notification yet. Android does not guarantee background survival or restart after force-stop.', style: TextStyle(color: Colors.black54))),
  ]);
}

Widget _meshBanner(String message) => Container(color: const Color(0xFFE5F3EF), padding: const EdgeInsets.all(12), child: Row(children: [const Icon(Icons.info_outline, size: 18), const SizedBox(width: 8), Expanded(child: Text(message, style: const TextStyle(fontSize: 12)))]));
String _clock(DateTime time) => '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
