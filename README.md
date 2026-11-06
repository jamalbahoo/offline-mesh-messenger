# Offline Mesh Messenger

A Flutter starter for a local-first Android messenger. The current commit provides a Material 3 chat-oriented UI and an encrypted, on-device message draft/history store. It is an app foundation, **not** a completed mesh messenger: there is no peer discovery, network transport, relay/routing, push notification, background service, hotspot portal, calling, or account recovery implementation yet. The UI labels these areas as unavailable rather than simulating delivery.

## What works now

- Chats, Status, Calls, and Settings navigation with a WhatsApp-inspired layout.
- Send and view local demo messages in the local chat.
- Message JSON is encrypted with AES-256-GCM. The random key is stored using `flutter_secure_storage` (Android Keystore-backed storage).
- Android manifest declares relevant network, Wi-Fi, Bluetooth/nearby, location, and foreground-service permissions for future transport work.

This storage is not a backup system. Uninstalling the app or clearing its secure storage can make the key and messages unrecoverable. Do not enter real credentials or sensitive data in this prototype.

## Run on Android

1. Install the Flutter stable SDK and Android Studio/Android SDK. Check setup with `flutter doctor`.
2. From the repository root, generate the standard Gradle wrapper/platform support (the wrapper JAR is intentionally not committed):

   ```sh
   flutter create --platforms=android --project-name offline_mesh_messenger .
   ```

   Keep the checked-in `lib/`, `pubspec.yaml`, Android manifest, and `MainActivity.kt` when prompted. If Flutter regenerates the manifest, restore `android/app/src/main/AndroidManifest.xml` from this repository.
3. Fetch packages and run on a connected Android device or emulator:

   ```sh
   flutter pub get
   flutter run
   ```

4. For a release build, configure your own signing credentials and run `flutter build apk --release`.

The manifest includes permissions for planned capabilities, but the prototype does not request runtime permissions or start a foreground service. Add permission prompts only alongside the corresponding feature and follow Android's current version-specific rules. Android cannot guarantee an ordinary app continues after a force-stop; hotspot control, background execution, full-screen call notifications, and nearby-device APIs also have OS/version and device restrictions.

## Planned architecture (not implemented)

- Define a transport interface and add Wi-Fi LAN/Wi-Fi Direct and BLE adapters with explicit user consent and runtime permission handling.
- Add authenticated, end-to-end encrypted envelopes, replay protection, bounded TTL/hop limits, deduplication, and an opt-in store-and-forward queue. A relay must never be trusted with plaintext or unlimited storage.
- Add delivery/read receipts only after authenticated peer acknowledgements; local persistence alone is not delivery.
- Implement notification channels and a properly typed foreground service only for a user-visible, ongoing feature, with Android lifecycle and force-stop limitations documented.
- Build hotspot sharing using supported Android APIs and a download endpoint that serves only a verified APK selected by the user. QR codes must not expose arbitrary local services.
- For account recovery, design an explicit encrypted export/import flow with a user-held recovery secret; Android Keystore keys do not survive reinstall as portable account keys.
- Evaluate WebRTC calling separately; local signaling, codecs, permissions, and device compatibility are still required even without external STUN/TURN.

## Repository structure

- `lib/main.dart` — Material 3 screens and encrypted local chat prototype.
- `android/app/src/main/AndroidManifest.xml` — Android app entry and planned capability permissions.
- `android/app/src/main/kotlin/com/example/offline_mesh_messenger/MainActivity.kt` — Flutter Android entry point.
