# Offline Mesh Messenger — Phase 4 foundation

Phase 4 polishes the Material 3 Chats / Status / Calls / Settings UI, adds local privacy preferences and a block-list UI, and introduces a WebRTC media/call UI foundation configured with an empty ICE-server list for same-LAN host candidates. Camera and microphone permission declarations are included. Phase 1–3 local chat, LAN experiment, and APK-share screen remain.

## Run

```sh
flutter pub get
flutter test
flutter run
```

Release APK: `flutter build apk --release` (configure signing for distribution).

## Calling status and important limitation

`lib/calls/webrtc_call_engine.dart` provides a WebRTC peer/media engine and a `CallSignaling` integration interface. `lib/calls/call_screen.dart` provides audio/video call UI, local controls, and an incoming-call screen presentation primitive. No concrete authenticated signaling adapter is shipped, so the UI intentionally refuses to start a cross-device call until one is supplied. Offers, answers, and ICE candidates must use an authenticated, encrypted local channel with peer identity verification; the existing UDP beacon/TCP hello are unauthenticated and must not be used for call signaling. Empty `iceServers` avoids external STUN/TURN, but host ICE candidates only work when direct LAN routing/firewall policy allows it. Incoming calls are not wired to Android full-screen notifications or background call service.

## UI and privacy

- Chats, Status, Calls and Settings use a consistent Material 3 navigation and status language that does not claim delivery where none occurred.
- Status screen communicates that peer synchronization is not implemented.
- Settings stores local read-receipt preference and blocked peer IDs using `shared_preferences`; these preferences are not yet enforced by transport filtering.
- Share App Offline continues to open the Phase 3 hotspot/portal flow.

## Android/device validation

This update has not been built or tested on physical devices in this environment. Verify `flutter pub get`, `flutter analyze`, `flutter test`, and Android builds with the Flutter/Android SDK versions in use. Test WebRTC media permission prompts and LAN ICE candidate exchange on at least two devices. The Android foreground service does not host the Dart engine and cannot guarantee process survival; force-stop prevents restart. Do not describe this project as production-ready until signaling authentication, receipt validation, privacy enforcement, background call notifications, device testing, and security review are complete.
