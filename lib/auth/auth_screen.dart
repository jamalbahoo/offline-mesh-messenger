import 'package:flutter/material.dart';
import 'auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({required this.hasAccount, required this.auth, required this.onAuthenticated, super.key});
  final bool hasAccount;
  final AuthService auth;
  final ValueChanged<String> onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _createMode = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() { super.initState(); _createMode = !widget.hasAccount; }
  @override
  void dispose() { _username.dispose(); _password.dispose(); super.dispose(); }

  Future<void> _submit() async {
    setState(() { _busy = true; _error = null; });
    try {
      if (_createMode) {
        await widget.auth.createAccount(_username.text, _password.text);
      } else if (!await widget.auth.verify(_username.text, _password.text)) {
        throw StateError('Username or password is incorrect.');
      }
      widget.onAuthenticated(_username.text.trim());
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Bad state: ', '').replaceFirst('Invalid argument(s): ', ''));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(child: Center(child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.hub_rounded, size: 72, color: Color(0xFF087F6E)),
              const SizedBox(height: 12),
              Text(_createMode ? 'Create local profile' : 'Welcome back', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text('Phase 1 • Local device profile', textAlign: TextAlign.center),
              const SizedBox(height: 28),
              TextField(controller: _username, textInputAction: TextInputAction.next, autocorrect: false, decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: _password, obscureText: true, onSubmitted: (_) => _submit(), decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder(), helperText: 'Use at least 10 characters')),
              if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: const TextStyle(color: Colors.red))],
              const SizedBox(height: 18),
              FilledButton(onPressed: _busy ? null : _submit, child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator()) : Text(_createMode ? 'Create profile' : 'Sign in')),
              if (widget.hasAccount) TextButton(onPressed: _busy ? null : () => setState(() { _createMode = !_createMode; _error = null; }), child: Text(_createMode ? 'Back to sign in' : 'Recover account')),
              if (widget.hasAccount && !_createMode) const Text('Account recovery is limited to this installation. Reinstall recovery requires a previously exported encrypted backup.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          )),
        ))),
      );
}
