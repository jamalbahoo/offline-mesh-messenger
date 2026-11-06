import 'package:flutter/material.dart';
import 'auth/auth_service.dart';
import 'auth/auth_screen.dart';
import 'chat/home_screen.dart';
import 'core/crypto_service.dart';
import 'data/local_database.dart';
import 'data/message_repository.dart';

class MeshMessengerApp extends StatefulWidget {
  const MeshMessengerApp({super.key});

  @override
  State<MeshMessengerApp> createState() => _MeshMessengerAppState();
}

class _MeshMessengerAppState extends State<MeshMessengerApp> {
  final _auth = AuthService();
  final _crypto = CryptoService();
  late final _database = LocalDatabase();
  bool _loading = true;
  bool _hasAccount = false;
  String? _username;
  late final _messages = MessageRepository(_database, _crypto);

  @override
  void initState() {
    super.initState();
    _checkAccount();
  }

  Future<void> _checkAccount() async {
    final hasAccount = await _auth.hasAccount();
    if (mounted) setState(() { _hasAccount = hasAccount; _loading = false; });
  }

  Future<void> _authenticated(String username) async {
    await _crypto.initialize();
    await _database.open();
    if (!mounted) return;
    setState(() { _username = username; _hasAccount = true; });
  }

  void _signOut() => setState(() => _username = null);

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Mesh Messenger',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF087F6E)),
          scaffoldBackgroundColor: const Color(0xFFF7F8F8),
          appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF087F6E), foregroundColor: Colors.white),
        ),
        home: _loading
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : _username == null
                ? AuthScreen(hasAccount: _hasAccount, auth: _auth, onAuthenticated: _authenticated)
                : HomeScreen(username: _username!, messages: _messages, onSignOut: _signOut),
      );
}
