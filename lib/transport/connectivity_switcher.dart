import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

enum NetworkMode { internet, localWifi, disconnected }

/// Connection type plus a short DNS reachability check. This is a routing hint,
/// not a guarantee of internet access or a cloud transport implementation.
class ConnectivitySwitcher {
  ConnectivitySwitcher({Connectivity? connectivity}) : _connectivity = connectivity ?? Connectivity();
  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  final _controller = StreamController<NetworkMode>.broadcast();
  NetworkMode _mode = NetworkMode.disconnected;
  NetworkMode get mode => _mode;
  Stream<NetworkMode> get changes => _controller.stream;

  Future<NetworkMode> checkNow() async {
    final results = await _connectivity.checkConnectivity();
    if (results.contains(ConnectivityResult.none) || results.isEmpty) return _set(NetworkMode.disconnected);
    try {
      await InternetAddress.lookup('example.com').timeout(const Duration(seconds: 2));
      return _set(NetworkMode.internet);
    } on SocketException {
      return _set(results.contains(ConnectivityResult.wifi) || results.contains(ConnectivityResult.ethernet)
          ? NetworkMode.localWifi : NetworkMode.disconnected);
    } on TimeoutException {
      return _set(results.contains(ConnectivityResult.wifi) || results.contains(ConnectivityResult.ethernet)
          ? NetworkMode.localWifi : NetworkMode.disconnected);
    }
  }

  Future<void> start() async {
    await checkNow();
    _subscription ??= _connectivity.onConnectivityChanged.listen((_) { checkNow(); });
  }

  NetworkMode _set(NetworkMode next) {
    if (_mode != next) { _mode = next; if (!_controller.isClosed) _controller.add(next); }
    return next;
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _controller.close();
  }
}
