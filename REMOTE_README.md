# Crow Théatron – phone remote (delta package)

Adds a remote-control server for the **Crow-Chap** Android app.
Copy the contents of this folder over your `Crow-Theatron-Windows-Desktop/` project
(overwrites `pubspec.yaml`, `lib/main.dart`, `lib/screens/settings_screen.dart`,
`lib/services/playback_service.dart`; adds `lib/services/remote/*`, `lib/widgets/remote_settings_card.dart`, `tools/bt_bridge.py`).
These four overwritten files are the originals from your zip with small additions only — if you have
since edited them, diff instead of overwriting.

```
flutter pub get      # adds qr_flutter
flutter run -d windows
```

Then **Settings → Remote control (phone)** → switch on. A PIN, this PC's IPs and a pairing QR appear.
Allow the app through Windows Firewall on Private networks (TCP 8765, UDP 8766).

What changed
- `remote_server_io.dart` – TCP 8765 JSON server + UDP 8766 discovery, PIN/token pairing, state push, all commands (uses your existing PlaybackService / VideoRepository calls). `remote_server_stub.dart` keeps the Web build compiling.
- `playback_service.dart` – new `applyAudioEq()` (EQ preset as labelled mpv audio filter `@crow_eq`, applied on every video open and by the remote).
- `settings_screen.dart` / `remote_settings_card.dart` – the settings card. `main.dart` – registers `RemoteServer`.
- `tools/bt_bridge.py` – optional Bluetooth relay (`pip install pybluez2`).

The server is off by default and only starts when you switch it on.
