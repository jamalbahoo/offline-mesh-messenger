# Offline Mesh Messenger — Phase 3

Phase 3 adds an opt-in experimental IPv4 LAN listener toggle and an offline APK sharing screen. The share flow requests Android `LocalOnlyHotspot`, starts a small allow-listed HTTP portal on port 8080, serves only the installed application APK, and displays a QR code for its URL.

## Run and test

```sh
flutter pub get
flutter test
flutter run
```

## Offline app sharing

1. Open Settings → **Share App Offline**.
2. Start sharing and accept the system's nearby Wi-Fi permission request if prompted.
3. Connect the receiving device to the SSID/password shown in the app.
4. Scan the displayed QR code in the receiving device's browser and download the APK.
5. Stop sharing when finished. Android may require the receiving user to explicitly allow APK installation from their browser/files app.

The portal accepts only `GET /` and `GET /app.apk`; it does not accept a filesystem path from a request. It serves the installed APK found through Android `PackageManager`. The HTTP portal is unauthenticated on the local network: enable it only on a network you control and stop it after sharing.

## Limits

- `WifiManager.LocalOnlyHotspot` creates a temporary local-only Wi-Fi network; it is not the regular internet-tethering hotspot. Availability/configuration varies by Android version and OEM. Android does not offer ordinary apps a reliable portable API for hotspot connected-client counts, so the UI reports that count as unavailable rather than inventing it.
- The portal address is selected from local IPv4 interfaces with an AOSP `192.168.49.1` fallback; verify the URL on each target device. The host server binds all IPv4 interfaces while sharing is active.
- The Settings mesh toggle starts the existing Dart TCP/UDP transport in the app isolate and starts the notification service. The notification service does not host a Flutter isolate, so Android process termination will end Dart sockets; force-stop prevents restart. This is not a guarantee of always-on networking.
- LAN beacons/hello frames remain unauthenticated. Do not treat a discovered peer or a TCP write as proof of delivery. No BLE/Wi-Fi Direct or true multi-hop security is added in this phase.

## Added files

- `lib/mesh/mesh_service.dart` — starts/stops the foreground notification shell, connectivity monitor, and LAN transport coordinator.
- `lib/share/portal_server.dart` — allow-listed local HTTP APK portal.
- `lib/share/share_screen.dart` — hotspot control, QR, and sharing instructions.
- `lib/chat/home_screen.dart` — Settings integration.
- `android/app/src/main/kotlin/com/example/offline_mesh_messenger/MainActivity.kt` — `LocalOnlyHotspot` and installed APK path method-channel endpoints.
