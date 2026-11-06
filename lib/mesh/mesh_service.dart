import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import '../data/local_database.dart';
import '../core/uuid.dart';
import '../mesh/relay_worker.dart';
import '../transport/connectivity_switcher.dart';
import '../transport/lan_socket_transport.dart';
import '../transport/mesh_transport_coordinator.dart';

/// Starts the Android user-visible service and the Phase 2 Dart LAN transport.
/// Dart sockets live in this process/isolate: the notification service alone
/// cannot preserve them if Android terminates the app process.
class MeshService {
  MeshService({LocalDatabase? database, String? localNodeId})
      : _database = database ?? LocalDatabase(),
        localNodeId = localNodeId ?? const Uuid().v4();

  static const _channel = MethodChannel('offline_mesh/service');
  final LocalDatabase _database;
  final String localNodeId;
  late final _transport = LanSocketTransport(nodeId: localNodeId);
  late final _relay = RelayWorker(database: _database, localNodeId: localNodeId);
  late final _coordinator = MeshTransportCoordinator(
    transport: _transport,
    relay: _relay,
    localNodeId: localNodeId,
  );
  final connectivity = ConnectivitySwitcher();
  bool _running = false;
  bool get isRunning => _running;
  List<MeshPeer> get peers => _transport.peers;
  void Function(Object error)? onError;

  Future<void> start() async {
    if (_running) return;
    await _channel.invokeMethod<void>('start');
    try {
      await connectivity.start();
      await _coordinator.start();
      _running = true;
    } catch (_) {
      await _channel.invokeMethod<void>('stop');
      rethrow;
    }
  }

  Future<bool> queuePacket(dynamic packet) => _coordinator.queue(packet);

  Future<void> stop() async {
    if (!_running) return;
    await _coordinator.dispose();
    await connectivity.dispose();
    await _channel.invokeMethod<void>('stop');
    _running = false;
  }
}
