# Offline Mesh Messenger — Phase 1

Phase 1 adds a Flutter auth/chat skeleton, encrypted local messages in SQLite, and an opt-in Android foreground-service shell. It is not yet a P2P messenger: no peer discovery, network sockets, relay engine, delivery acknowledgements, call pipeline, hotspot portal, or cloud routing is present.

## Run

Requirements: Flutter stable, Android Studio/SDK, JDK 17, Android device or emulator.

```sh
flutter doctor
flutter pub get
flutter run
```

Build an APK:

```sh
flutter build apk --release
```

## Phase 1 included

- Material 3 Chats / Status / Calls / Settings navigation.
- Local username/password gate. Password verifier is derived with PBKDF2-HMAC-SHA256 and stored in Android secure storage; passwords are not stored.
- SQLite message table tracks conversation, sender, encrypted body, timestamp, and local delivery state.
- Each message body is encrypted using AES-256-GCM before insertion. The random AES key is saved in `flutter_secure_storage` using Android Keystore-backed storage.
- Foreground service can be enabled from Settings; Android notification and Bluetooth-connect permissions are requested when needed.
- Manifest declares Internet/network, Wi-Fi, location, Bluetooth, nearby Wi-Fi, foreground service, wake lock, notification, and boot permissions.

## Important constraints

- The displayed check mark means only that a message was saved locally (`queued`), not delivered to another device.
- Auth is device-local. Re-entering a username/password after reinstall cannot recover data that Android removed. A later phase must implement user-triggered encrypted export/import with a recovery key.
- The DB contains encrypted message bodies, but metadata (IDs, sender, timestamps, delivery state) remains visible. This is not end-to-end encryption or a reviewed security design.
- Foreground service is an opt-in lifecycle shell and does not listen for sockets. Android can stop it, and force-stop always prevents automatic restart. The boot permission is declared, but no boot receiver is included.
- Do not use this prototype for sensitive communications. Security review, Android device testing, database migrations, backup policy, and release signing remain necessary.

## Project layout

```text
lib/
  main.dart
  app.dart
  auth/
    auth_service.dart
    auth_screen.dart
  chat/
    home_screen.dart
  core/
    crypto_service.dart
    uuid.dart
  data/
    local_database.dart
    message_repository.dart
android/app/src/main/
  AndroidManifest.xml
  kotlin/com/example/offline_mesh_messenger/
    MainActivity.kt
    MeshForegroundService.kt
```

Next: authenticated peer identity, key exchange, packet protocol, bounded encrypted relay queue, Wi-Fi/BLE transport adapters, and tested delivery/read receipts.
