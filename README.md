# Offline Mesh Messenger — Phase 2 transport and relay foundation

Phase 2 adds an experimental local IPv4 LAN transport, packet serialization, a deduplicated/TTL-bounded SQLite relay queue, connectivity-mode hints, and packet model tests. It does **not** implement BLE Mesh, Wi-Fi Direct, end-to-end identity/key exchange, authenticated peer handshakes, cloud WebSocket delivery, or reliable app-level acknowledgements. Treat LAN beacons as unauthenticated and use only a trusted network during development.

## Run and test

```sh
flutter pub get
flutter test
flutter run
```

## Added modules

- `lib/mesh/packet.dart`: JSON packet model and validation; forwarding enforces path-loop, TTL, and hop bounds.
- `lib/mesh/relay_worker.dart`: SQLite deduplication by packet ID, bounded queue, expiry, retry attempts, and receipt state updates.
- `lib/data/local_database.dart`: schema v2 migration for the persistent relay queue.
- `lib/transport/lan_socket_transport.dart`: experimental IPv4 UDP broadcast discovery and newline-framed TCP packet channel on ports 40445/40444.
- `lib/transport/connectivity_switcher.dart`: connection type plus DNS reachability hint (`internet`, `localWifi`, `disconnected`). It does not configure a cloud server.
- `lib/transport/mesh_transport_coordinator.dart`: coordinator that queues, flushes on peer discovery, relays packets, and consumes receipt packets.

Transport APIs are not wired into the Flutter service button yet. The Android foreground service is still a native notification shell and does not host Dart sockets; Android background execution needs a dedicated Flutter engine/background plugin or native transport integration and physical-device validation. LAN discovery/listeners work only while the Dart transport is explicitly started and its isolate remains active.

## Packet and receipt contract

`payload` must be an opaque encrypted envelope prepared for the intended recipient. The existing Phase 1 AES key is device-local and is **not** a shared end-to-end key; do not send its ciphertext to other devices expecting them to decrypt it. A future protocol must authenticate peer identities and packets, establish recipient keys, prevent replay, and sign delivery/read receipts. `delivery_receipt` and `read_receipt` packet payloads contain the original packet ID; these are only state hooks and are not authenticated in this prototype.

States: `queued` = persisted locally (single tick); `relayed` = TCP write completed to a next hop (not proof of remote app delivery); `delivered` = app-level delivery receipt processed; `read` = read receipt processed. A blue tick is valid only after an authenticated read receipt is implemented.

## Limits and safety

- IPv4 LAN only; no BLE/Wi-Fi Direct or multi-interface route selection yet.
- UDP beacon reveals the local node ID and TCP port to devices on that LAN. Use an opaque random node ID, not a username or other personal data.
- TCP hello is a discovery handshake only, not authentication. Never treat it as proof of peer identity.
- Payload and path sizes are bounded; queue holds at most 1,000 pending entries with seven-day expiry.
- Connectivity classification uses DNS lookup and is advisory; it does not switch to a cloud path without a configured server.
- Android may suspend background work; force-stop prevents automatic execution.
