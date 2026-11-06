import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/message_repository.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.username, required this.messages, required this.onSignOut, super.key});
  final String username;
  final MessageRepository messages;
  final VoidCallback onSignOut;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _native = MethodChannel('offline_mesh/service');
  int _tab = 0;
  bool _serviceOn = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Mesh Messenger', style: TextStyle(fontWeight: FontWeight.w700)), actions: [IconButton(onPressed: widget.onSignOut, icon: const Icon(Icons.logout), tooltip: 'Sign out')]),
        body: IndexedStack(index: _tab, children: [
          _ChatsTab(username: widget.username, repository: widget.messages),
          const _Placeholder(icon: Icons.circle_outlined, title: 'Status', details: 'Local status sync will be added in a later phase.'),
          const _Placeholder(icon: Icons.call_outlined, title: 'Calls', details: 'Offline calling is not implemented in Phase 1.'),
          _SettingsTab(serviceOn: _serviceOn, onServiceChanged: _toggleService, username: widget.username),
        ]),
        bottomNavigationBar: NavigationBar(selectedIndex: _tab, onDestinationSelected: (index) => setState(() => _tab = index), destinations: const [
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Chats'),
          NavigationDestination(icon: Icon(Icons.circle_outlined), label: 'Status'),
          NavigationDestination(icon: Icon(Icons.call_outlined), label: 'Calls'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ]),
      );

  Future<void> _toggleService(bool enable) async {
    try {
      await _native.invokeMethod(enable ? 'start' : 'stop');
      if (mounted) setState(() => _serviceOn = enable);
    } on PlatformException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message ?? 'Could not change service state.')));
    } on MissingPluginException {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foreground service requires an Android build.')));
    }
  }
}

class _ChatsTab extends StatefulWidget {
  const _ChatsTab({required this.username, required this.repository});
  final String username;
  final MessageRepository repository;
  @override
  State<_ChatsTab> createState() => _ChatsTabState();
}
class _ChatsTabState extends State<_ChatsTab> {
  static const conversation = 'local-demo';
  List<StoredMessage> _items = [];
  bool _loading = true;
  @override
  void initState() { super.initState(); _refresh(); }
  Future<void> _refresh() async {
    try { _items = await widget.repository.list(conversation); }
    finally { if (mounted) setState(() => _loading = false); }
  }
  @override
  Widget build(BuildContext context) => ListView(children: [
    Container(color: const Color(0xFFE5F3EF), padding: const EdgeInsets.all(12), child: const Row(children: [Icon(Icons.info_outline, size: 18), SizedBox(width: 8), Expanded(child: Text('Phase 1 local demo • no peer transport connected'))])),
    ListTile(leading: const CircleAvatar(backgroundColor: Color(0xFF087F6E), child: Icon(Icons.devices, color: Colors.white)), title: const Text('Local conversation'), subtitle: Text(_items.isEmpty ? 'Your encrypted local messages' : _items.last.text), trailing: _items.isEmpty ? null : const Icon(Icons.done), onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => _ChatScreen(repository: widget.repository, username: widget.username))); await _refresh(); }),
    if (_loading) const LinearProgressIndicator(),
    if (_items.isEmpty && !_loading) const Padding(padding: EdgeInsets.all(24), child: Text('Start a local demo conversation. Messages are stored encrypted on this device.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54))),
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
  static const conversation = 'local-demo';
  final _input = TextEditingController();
  List<StoredMessage> _items = [];
  bool _busy = false;
  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _input.dispose(); super.dispose(); }
  Future<void> _load() async { _items = await widget.repository.list(conversation); if (mounted) setState(() {}); }
  Future<void> _send() async {
    final text = _input.text.trim(); if (text.isEmpty || _busy) return;
    setState(() => _busy = true);
    try { await widget.repository.addLocalMessage(conversationId: conversation, senderId: widget.username, text: text); _input.clear(); await _load(); }
    catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save message: $error'))); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Local conversation')), body: Column(children: [
    const Padding(padding: EdgeInsets.all(10), child: Text('Queued means saved locally only; it does not mean delivered to a peer.', style: TextStyle(fontSize: 12, color: Colors.black54), textAlign: TextAlign.center)),
    Expanded(child: ListView.builder(padding: const EdgeInsets.all(12), itemCount: _items.length, itemBuilder: (context, index) { final item = _items[index]; return Align(alignment: Alignment.centerRight, child: Container(margin: const EdgeInsets.symmetric(vertical: 4), padding: const EdgeInsets.all(12), constraints: const BoxConstraints(maxWidth: 300), decoration: BoxDecoration(color: const Color(0xFFD8F5E9), borderRadius: BorderRadius.circular(14)), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Align(alignment: Alignment.centerLeft, child: Text(item.text)), const SizedBox(height: 4), Text('${item.sentAt.hour.toString().padLeft(2, '0')}:${item.sentAt.minute.toString().padLeft(2, '0')}  ✓', style: const TextStyle(fontSize: 10, color: Colors.black54))]))); })),
    SafeArea(top: false, child: Padding(padding: const EdgeInsets.all(8), child: Row(children: [Expanded(child: TextField(controller: _input, minLines: 1, maxLines: 4, decoration: InputDecoration(hintText: 'Message', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10)), onSubmitted: (_) => _send())), const SizedBox(width: 8), IconButton.filled(onPressed: _busy ? null : _send, icon: const Icon(Icons.send))]))),
  ]));
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab({required this.serviceOn, required this.onServiceChanged, required this.username});
  final bool serviceOn;
  final ValueChanged<bool> onServiceChanged;
  final String username;
  @override
  Widget build(BuildContext context) => ListView(children: [
    ListTile(title: Text('Settings', style: Theme.of(context).textTheme.headlineSmall)),
    ListTile(leading: const Icon(Icons.person_outline), title: const Text('Local profile'), subtitle: Text(username)),
    SwitchListTile(secondary: const Icon(Icons.hub_outlined), title: const Text('Foreground service'), subtitle: Text(serviceOn ? 'Ongoing service notification enabled' : 'Enable the user-visible service shell'), value: serviceOn, onChanged: onServiceChanged),
    const ListTile(leading: Icon(Icons.lock_outline), title: Text('Local encryption'), subtitle: Text('AES-256-GCM message bodies; device-bound key')),
    const ListTile(leading: Icon(Icons.share_outlined), title: Text('Share app offline'), subtitle: Text('Not implemented in Phase 1')),
    const ListTile(leading: Icon(Icons.privacy_tip_outlined), title: Text('Privacy and blocked peers'), subtitle: Text('Controls will be added with peer discovery')),
    const Padding(padding: EdgeInsets.all(16), child: Text('This service shell does not listen for peers and cannot guarantee survival after force-stop.', style: TextStyle(color: Colors.black54))),
  ]);
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.icon, required this.title, required this.details});
  final IconData icon;
  final String title;
  final String details;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 56, color: const Color(0xFF087F6E)), const SizedBox(height: 12), Text(title, style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 8), Text(details, textAlign: TextAlign.center)])));
}
