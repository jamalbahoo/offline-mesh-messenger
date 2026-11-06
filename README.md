# Offline Mesh Messenger

A Flutter/Android local-first messenger starter. This repository now includes a WhatsApp-inspired Material 3 UI, AES-GCM encrypted local demo message storage, and an Android foreground-service lifecycle shell. It is **not yet a complete P2P messenger**: mesh discovery, Wi-Fi/BLE data transports, relay persistence, cloud routing, calls, APK hosting, account recovery, and delivery receipts are not implemented. The UI explicitly identifies unavailable features rather than fabricating peer delivery.

## Implemented

- Chats, Status, Calls, and Settings navigation.
- Local demo chat messages encrypted with AES-256-GCM; the encryption key is stored using Android Keystore-backed `flutter_secure_storage`.
- Android foreground service started while the app activity launches, with an ongoing "Offline Mesh Network Active" notification and a notification channel.
- Android manifest declares relevant Wi-Fi, Bluetooth/nearby, network, location, notification, wake-lock, and foreground service permissions.
- Gradle project configuration for Flutter Android builds.

The service is only a lifecycle shell: it does not listen on sockets or claim that a mesh link is active. Android may stop background work, and users can force-stop the app; no normal app can guarantee service execution after force-stop. Starting services at boot and hotspot control are restricted by Android version and device policy, so they require dedicated compatibility work and user consent.

## Run on Android

1. Install Flutter stable, Android Studio/Android SDK (API 35 recommended), and JDK 17. Run `flutter doctor` and accept Android SDK licenses.
2. The Android Gradle project files are checked in. Flutter creates `android/local.properties` for the local SDK paths as part of normal setup; if needed run:

   ```sh
   flutter create --platforms=android --project-name offline_mesh_messenger .
   ```

   Choose to keep existing files, or restore the checked-in manifest, service, and Gradle configuration after generation.
3. Install dependencies and run:

   ```sh
   flutter pub get
   flutter run
   ```

4. Build a release APK after configuring signing credentials:

   ```sh
   flutter build apk --release
   ```

The app requests notification permission on Android 13+ when opened. Wi-Fi/Bluetooth and location permissions are declared but not requested until their corresponding user-facing transport features exist.

## Security and recovery notes

- Local message encryption is not end-to-end encryption and does not provide relay-safe encrypted envelopes.
- Secure storage is device-bound; uninstalling, clearing app data, losing the Android Keystore, or changing devices can make messages unrecoverable.
- Username/password account creation, portable recovery exports, encrypted media storage, and a production database migration strategy are not included. Do not use this prototype for sensitive or production communications.
- A future recovery feature must use an explicit encrypted export/import backup flow and a user-held recovery secret; simply re-entering credentials cannot restore data that was deleted with the app.

## Next implementation milestones

1. Add authenticated peer identity, key establishment, AEAD packet format, nonce/replay protection, hop/TTL limits, and encrypted persistent relay queue.
2. Implement Wi-Fi LAN/Wi-Fi Direct and BLE discovery/transport adapters with explicit runtime permission flows and interoperability tests on supported devices.
3. Add delivery/read acknowledgements, deduplicated store-and-forward routing, and bounded storage/expiry policies.
4. Add notifications/call UI, local WebRTC signaling/media, and a tested background service that owns active transports only when enabled by the user.
5. Implement a supported hotspot-sharing flow and a download server that serves only a verified user-selected APK.
6. Add encrypted backup/restore and privacy controls, then perform threat modeling, device testing, and release signing.

## Project layout

- `lib/main.dart` — Flutter UI and encrypted local chat prototype.
- `android/app/src/main/AndroidManifest.xml` — Android permissions, activity, and service declarations.
- `android/app/src/main/kotlin/.../MeshForegroundService.kt` — ongoing notification service shell.
- `android/app/src/main/kotlin/.../MainActivity.kt` — Flutter entry point and service startup.
