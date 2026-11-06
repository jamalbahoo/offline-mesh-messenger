import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/material.dart';
import 'portal_server.dart';

class ShareScreen extends StatefulWidget {
  const ShareScreen({super.key});
  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  static const _channel = MethodChannel('offline_mesh/share');
  final _portal = ApkPortalServer();
  bool _starting = false;
  String? _url;
  String? _ssid;
  String? _passphrase;
  String? _error;
  int? _clients;

  Future<void> _start() async {
    setState(() { _starting = true; _error = null; });
    try {
      final hotspot = await _channel.invokeMapMethod<String, dynamic>('startHotspot');
      final apkPath = await _channel.invokeMethod<String>('getApkPath');
      if (apkPath == null || !await File(apkPath).exists()) throw StateError('The installed APK could not be located.');
      final address = await _findLocalAddress();
      final url = await _portal.start(apkPath: apkPath, hostAddress: address);
      if (!mounted) return;
      setState(() {
        _url = url;
        _ssid = hotspot?['ssid'] as String?;
        _passphrase = hotspot?['passphrase'] as String?;
        _clients = null; // Android does not expose a portable client count API.
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
      try { await _channel.invokeMethod<void>('stopHotspot'); } catch (_) {}
    } finally { if (mounted) setState(() => _starting = false); }
  }

  Future<String> _findLocalAddress() async {
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        final value = address.address;
        if (value.startsWith('192.168.') || value.startsWith('10.') || _isPrivate172(value)) return value;
      }
    }
    // Android AOSP LocalOnlyHotspot commonly uses this address. OEMs may differ.
    return '192.168.49.1';
  }

  bool _isPrivate172(String address) {
    final parts = address.split('.');
    if (parts.length != 4 || parts[0] != '172') return false;
    final second = int.tryParse(parts[1]);
    return second != null && second >= 16 && second <= 31;
  }

  Future<void> _stop() async {
    await _portal.stop();
    try { await _channel.invokeMethod<void>('stopHotspot'); } catch (_) {}
    if (mounted) setState(() { _url = null; _ssid = null; _passphrase = null; _clients = null; });
  }

  @override
  void dispose() {
    unawaited(_portal.stop());
    unawaited(_channel.invokeMethod<void>('stopHotspot').catchError((_) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Share app offline')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Create a temporary local-only Wi-Fi hotspot and serve this installed APK to devices that join it.', style: TextStyle(fontSize: 16)),
      const SizedBox(height: 16),
      if (_ssid != null) ListTile(leading: const Icon(Icons.wifi), title: Text(_ssid!), subtitle: Text(_passphrase?.isNotEmpty == true ? 'Password: $_passphrase' : 'Open local hotspot')),
      ListTile(leading: const Icon(Icons.people_outline), title: Text(_clients == null ? 'Connected devices: unavailable' : '$_clients device(s) connected'), subtitle: const Text('Android does not expose a reliable hotspot client count to regular apps.')),
      if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
      if (_url != null) ...[
        Center(child: QrImageView(data: _url!, size: 220, backgroundColor: Colors.white)),
        SelectableText(_url!, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text('Connect the other device to the hotspot first, then scan this QR code. The portal serves only the installed APK.', textAlign: TextAlign.center),
      ],
      const SizedBox(height: 20),
      FilledButton.icon(onPressed: _starting ? null : (_url == null ? _start : _stop), icon: Icon(_url == null ? Icons.wifi_tethering : Icons.stop), label: _starting ? const Text('Starting…') : Text(_url == null ? 'Start sharing' : 'Stop sharing')),
      const SizedBox(height: 12),
      const Text('This uses Android LocalOnlyHotspot, not the general internet-sharing hotspot. Availability and portal IP vary by Android version/device. Only share APKs you trust.', style: TextStyle(fontSize: 12, color: Colors.black54)),
    ]),
  );
}
