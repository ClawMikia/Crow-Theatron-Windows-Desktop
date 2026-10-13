# Crow Théatron — Windows Desktop / Web (Flutter port)

A Flutter port of the `Crow-Theatron-Android` app, built for **Windows Desktop**
(with a **Web** build as well). It went through two passes:
first a faithful port of the phone UI, then a full desktop restructure —
sidebar navigation, a folder-panel + wide grid library, and a video +
side-panel player — so it feels like a desktop app rather than a phone
layout dropped into a window. See "Desktop shell architecture" and "File
map" below.

I could not compile an actual `.exe`/`.wasm` in the sandbox this was built
in (no Windows build toolchain, no Flutter SDK installed there), so this is
the **complete source project** — you build it yourself with the Flutter
SDK on your PC, as agreed.

## 1. One-time setup

You need the [Flutter SDK](https://docs.flutter.dev/get-started/install/windows)
with Windows desktop support enabled, and Visual Studio 2022 with the
"Desktop development with C++" workload (required by Flutter for Windows
builds).

```powershell
flutter doctor           # confirm "Windows" and "Chrome" both show a checkmark
```

Unzip this project anywhere, `cd` into it, then **scaffold the native
runner folders** (these are large, version-specific boilerplate files that
`flutter create` generates from your exact installed Flutter version — it's
safer to generate them fresh than to ship them by hand):

```powershell
flutter create --platforms=windows,web .
```

This will *add* `windows/flutter/`, `windows/runner/*.cpp|h|rc` and the
remaining `web/flutter_bootstrap.js` etc. without touching the `lib/`,
`pubspec.yaml`, `web/index.html`, `web/manifest.json`, or
`windows/runner/resources/app_icon.ico` files already in this project
(those are already customized — if `flutter create` prompts to overwrite
`web/index.html`, say **No**, since ours has the app's favicon/title
already wired in).

Then get packages:

```powershell
flutter pub get
```

The app icon (used for the Windows `.exe`, the title-bar/taskbar icon, and
the web favicon) is already converted and sitting at:
- `windows/runner/resources/app_icon.ico` (multi-resolution, from `app_icon.png`)
- `web/icons/*.png`, `web/favicon.png`

`flutter create` writes a placeholder `app_icon.ico` into
`windows/runner/resources/` — **make sure the one from this project
(Crow Théatron's icon) is the one left in place** after you run the
command above (re-copy it from a backup if `flutter create` overwrote it).

### Web + SQLite

The web build uses `sqflite_common_ffi_web`, which needs a small one-time
asset setup step:

```powershell
dart run sqflite_common_ffi_web:setup
```

(Run this once; it copies the `sqlite3.wasm` worker into `web/`.)

### Media keys / earbud support (Windows)

The app uses `smtc_windows` for System Media Transport Controls (play/pause/next/prev
from hardware media keys, headphones, lock screen). This requires `rustup`
installed on the **build machine** (not the target machine):

```powershell
# Install rustup if not present
winget install Rustlang.Rustup
rustup default stable
```

Then rebuild:
```powershell
flutter clean
flutter pub get
flutter build windows
```

If you don't need media key support, you can remove `smtc_windows` from `pubspec.yaml`
and the related code in `lib/services/media_session/`.

## 2. Run it

```powershell
flutter run -d windows      # Windows desktop, hot reload
flutter run -d chrome       # Web, in Chrome
flutter run -d edge         # Web, in Edge
```

## 3. Build a release

```powershell
flutter build windows       # → build/windows/x64/runner/Release/crow_theatron.exe
flutter build web           # → build/web/  (deploy as a static site)
```

### Build variants

```powershell
flutter build windows --release       # Release (default)
flutter build windows --profile       # Profile build
flutter build windows --debug         # Debug build (larger, with asserts)
```

## Desktop shell architecture

The phone app navigates with a bottom tab bar and pushes a full-screen
`Activity` for every destination. The desktop version instead uses a
persistent shell:

- **`lib/widgets/app_shell.dart`** — the app's root frame: window title
  bar on top, `CrowSidebar` on the left, a switched content area in the
  middle (an `IndexedStack` so each tab keeps its scroll position/search
  state alive), and the mini-player docked full-width at the bottom.
- **`lib/widgets/crow_sidebar.dart`** — left nav rail (Home, Library,
  Favorites, Memory, Explore, Playlists up top; Enhancement and Settings
  pinned to the bottom), replacing the old bottom tab bar.
- **`lib/state/shell_nav.dart`** — a small `ChangeNotifier` (`ShellNavState`)
  that tracks which sidebar destination is selected. Any screen can call
  `context.read<ShellNavState>().goTo(SidebarDestination.library)` to
  switch tabs without pushing a route (used by Home's quick-action buttons).
- Screens embedded in the shell (Home, Library, Explore, Playlists,
  Enhancement, Settings) render straight into the content area with a
  lightweight `SectionHeader` (title + actions, no back button). Screens
  that are a genuine drill-down — a playlist's video list, the folder
  picker, or the full Player — are pushed as standalone routes on top of
  the shell instead, using `CrowScaffold`/`CrowToolbar` (title bar + a
  back-button toolbar + the mini-player).
- `LibraryScreen` takes a `standalone: bool` flag for this reason: `false`
  (default) when it's a sidebar destination, `true` when it's pushed for a
  playlist's contents.
- **Library** in "All" mode now shows a folder list panel on the left with
  a wide responsive grid (`crowVideoGridDelegate`, column count grows with
  window width) on the right, instead of collapsible in-list folder
  headers.
- **Player screen** lays out the video on the left (`Expanded`) with a
  fixed 400px scrollable control panel on the right, instead of the phone
  layout's video-on-top-then-cards-below single scrolling column.
  Fullscreen still collapses everything to just the video.

## Key features

| Feature | Description |
|---------|-------------|
| **Video Playback** | libmpv-based via `media_kit` — supports pitch, speed, video filters (eq, hue, unsharp), hardware decoding |
| **Local Library** | SQLite database mirroring Android schema — folders, videos, playlists, chapters, timeline skips |
| **Enhancement Presets** | Real-time video filters (brightness, contrast, saturation, hue, sharpen) driven by libmpv `vf` chain |
| **Equalizer** | Multi-band EQ presets with custom profile support |
| **Crop/Zoom Modes** | Fit, fill, stretch, 16:9, 4:3, 21:9, custom aspect ratios |
| **Chapter Markers** | Add/edit/skip chapters with timeline visualization |
| **Timeline Skips** | Mark and skip intros, outros, credits, custom segments |
| **Continue Watching** | Playback position memory per video, resume from last position |
| **Favorites** | Mark/unmark videos, dedicated Favorites shelf |
| **Playlists** | Create, edit, reorder, delete playlists; playlist video grid |
| **Folder Scanner** | Recursive folder scanning with media file detection (video extensions) |
| **Mini Player** | Always-visible bottom dock with play/pause, seek, title, next/prev |
| **Custom Title Bar** | Frameless window with drag area, minimize/maximize/close, app icon |
| **Keyboard Shortcuts** | Space (play/pause), arrows (seek), F/f (fullscreen), M (mute), +/- (volume), etc. |
| **Remote Control** | Crow-Chap phone remote via QR pairing (WebSocket + local HTTP) |
| **Media Session** | Windows SMTC + Web Media Session API for OS-level transport controls |
| **Responsive Layout** | Breakpoints for compact/medium/expanded window widths |
| **Dark/Light Theme** | System-following with manual override, custom Orbitron font |

## File map (Android → Flutter)

| Android | Flutter |
|---|---|
| `colors.xml`, `themes.xml` | `lib/theme/crow_colors.dart`, `lib/theme/crow_theme.dart` |
| `data/VideoEntity.kt` | `lib/models/video_entity.dart` |
| `data/EnhancementMode.kt` | `lib/models/enhancement_mode.dart` (+ real libmpv `vf` filter params) |
| `data/EqPreset.kt`, `CropMode.kt` | `lib/models/eq_preset.dart`, `crop_mode.dart` |
| `data/ChapterMarker.kt`, `TimelineSkip.kt` | `lib/models/chapter_marker.dart`, `timeline_skip.dart` |
| `data/CrowDbHelper.kt` | `lib/data/crow_database.dart` (same table/column names) |
| `data/AppPrefs.kt` | `lib/data/app_prefs.dart` |
| `data/FolderScanner.kt` | `lib/data/folder_scanner.dart` |
| `data/VideoRepository.kt` | `lib/data/video_repository.dart` |
| `util/FormatUtils.kt` | `lib/util/format_utils.dart` |
| `service/PlaybackService.kt` + `ui/MiniPlayerHelper.kt` | `lib/services/playback_service.dart` (media_kit) + `lib/widgets/mini_player.dart` (full-width bottom dock) |
| `ui/BottomNavHelper.kt`, `menu_bottom_nav.xml` | `lib/widgets/crow_sidebar.dart` + `lib/state/shell_nav.dart` (desktop sidebar, not a bottom bar) |
| `ui/LibraryAdapter.kt`, `item_video_card.xml`, `item_video_list_row.xml`, `item_library_header.xml` | `lib/widgets/video_tiles.dart` (+ responsive `crowVideoGridDelegate`) |
| `splash/SplashActivity.kt` | `lib/screens/splash_screen.dart` |
| (new — desktop shell frame) | `lib/widgets/app_shell.dart` |
| `main/MainActivity.kt` | `lib/screens/main_screen.dart` (dashboard: quick actions + Continue Watching / Favorites shelves) |
| `library/LibraryActivity.kt` | `lib/screens/library_screen.dart` (folder panel + wide grid) |
| `explore/ExploreActivity.kt` | `lib/screens/explore_screen.dart` |
| `folder/FolderSelectActivity.kt` | `lib/screens/folder_select_screen.dart` (standalone pushed route) |
| `settings/SettingsActivity.kt` | `lib/screens/settings_screen.dart` |
| `memory/PlaybackMemoryActivity.kt` | folded into `lib/screens/library_screen.dart` (`LibraryMode.continueWatching`, the shell's "Memory" tab) |
| `enhancement/VideoEnhancementActivity.kt` | `lib/screens/enhancement_screen.dart` (card grid) |
| `playlist/PlaylistListActivity.kt` | `lib/screens/playlist_list_screen.dart` (card grid; opens a standalone `LibraryScreen`) |
| `player/PlayerActivity.kt` + `activity_player.xml` | `lib/screens/player_screen.dart` (video + fixed side panel) |
| `dialog_add_chapter.xml`, `dialog_add_skip.xml` | `lib/widgets/player_dialogs.dart` |
| (window chrome — new for desktop) | `lib/widgets/crow_title_bar.dart` (icon + drag area + minimize/maximize/close) |
| (remote control — new) | `lib/services/remote/` (remote_server.dart, remote_server_io.dart, remote_server_stub.dart) |
| (media session — new) | `lib/services/media_session/` (Windows SMTC + Web Media Session) |

## Project structure

```
lib/
├── main.dart                          # App entry point, theme, providers
├── models/                            # Data models (video, playlist, eq, crop, chapters, skips, enhancement)
├── data/                              # Repository, database, folder scanner, prefs
├── services/
│   ├── playback_service.dart          # media_kit wrapper, playlist management
│   ├── thumbnail_service.dart         # Thumbnail generation (placeholder)
│   ├── remote/                        # Crow-Chap phone remote (WebSocket server)
│   └── media_session/                 # OS media session (Windows SMTC + Web)
├── widgets/                           # Reusable UI components
│   ├── app_shell.dart                 # Root shell: titlebar + sidebar + content + mini-player
│   ├── crow_sidebar.dart              # Left navigation rail
│   ├── crow_title_bar.dart            # Custom frameless window title bar
│   ├── crow_scaffold.dart             # Scaffold for pushed routes (toolbar + mini-player)
│   ├── crow_bottom_nav.dart           # Legacy bottom nav (kept for reference)
│   ├── video_tiles.dart               # Video grid/list tiles with responsive delegate
│   ├── mini_player.dart               # Bottom dock mini player
│   ├── player_dialogs.dart            # Chapter/skip editor dialogs
│   ├── section_header.dart            # Section title + actions
│   ├── library_actions.dart           # Library toolbar actions (sort, filter, view mode)
│   ├── keyboard_accessible.dart       # Focus/keyboard helpers
│   ├── confirm_dialog.dart            # Generic confirmation dialog
│   └── remote_settings_card.dart      # Remote pairing QR + status
├── screens/                           # Top-level screens
│   ├── splash_screen.dart
│   ├── main_screen.dart               # Home dashboard
│   ├── library_screen.dart            # Folder panel + grid (standalone or embedded)
│   ├── explore_screen.dart            # Browse/filter videos
│   ├── playlist_list_screen.dart      # Playlist management
│   ├── player_screen.dart             # Full player with side panel
│   ├── enhancement_screen.dart        # Video filter presets + sliders
│   ├── settings_screen.dart           # App settings, remote pairing
│   ├── folder_select_screen.dart      # Folder picker (SAF-style)
│   └── playback_memory_screen.dart    # Continue watching (legacy, merged)
├── state/
│   └── shell_nav.dart                 # Sidebar navigation state (ChangeNotifier)
├── theme/
│   ├── crow_colors.dart               # Color palette
│   └── crow_theme.dart                # ThemeData + extensions
├── util/
│   ├── format_utils.dart              # Duration, file size, date formatting
│   ├── seek_icons.dart                # Seek button icons
│   └── video_open.dart                # Video file association helpers
└── shortcuts/
    └── app_shortcuts.dart             # Keyboard shortcut definitions
```

## Dependencies

| Package | Purpose |
|---------|---------|
| `media_kit` | Core playback engine (libmpv) |
| `media_kit_video` | Video output widget |
| `media_kit_libs_video` | Bundled libmpv/FFmpeg binaries |
| `sqflite_common_ffi` | SQLite on desktop (via ffi) |
| `sqflite_common_ffi_web` | SQLite on Web (WASM) |
| `shared_preferences` | Key-value prefs (mirrors Android SharedPreferences) |
| `file_picker` | Folder/file picking (SAF replacement) |
| `window_manager` | Frameless window, custom title bar |
| `path_provider` | App data directory paths |
| `provider` | Lightweight state management (ChangeNotifier) |
| `smtc_windows` | Windows System Media Transport Controls |
| `qr_flutter` | QR code for remote pairing |
| `web` | Web platform APIs (Media Session) |
| `path` | Path manipulation |

## Known simplifications vs. the Android app

- **Thumbnails**: there's no cheap video-frame thumbnailer wired up for
  Windows/Web in this pass, so library tiles show a colored placeholder
  tile with a play glyph instead of a real extracted frame. Real
  thumbnails are doable (e.g. shelling out to a bundled `ffmpeg.exe` to
  grab a frame) — say the word and I'll wire it in.
- **Android-only concepts dropped**: Picture-in-Picture, screen
  orientation lock, and the Android media-session notification don't have
  a direct desktop/web equivalent and were omitted; the always-on
  mini-player bar covers the "keep playing while browsing" use case
  instead.
- **Subtitle rendering** uses libmpv's built-in subtitle track handling
  (via `media_kit`) rather than a custom renderer — track selection is
  wired in the data model but the Player screen's subtitle-styling UI
  (size/bold/background) isn't built out yet in this pass.
- Visual "Enhancement" presets and the brightness/contrast/saturation/hue/
  sharpen sliders are real — they drive libmpv's `vf=eq,hue,unsharp`
  filter chain live, not just a label.
- **Remote control server** is a basic WebSocket + HTTP implementation;
  production hardening (auth, TLS, mDNS discovery) would be needed for
  real-world deployment.

## Configuration

### App Preferences (`lib/data/app_prefs.dart`)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `themeMode` | int | 0 (system) | 0=system, 1=light, 2=dark |
| `lastSelectedFolder` | String? | null | Last opened folder path |
| `defaultEnhancementMode` | String | "normal" | Enhancement preset ID |
| `defaultEqPreset` | String | "flat" | EQ preset ID |
| `defaultCropMode` | String | "fit" | Crop/zoom mode ID |
| `playbackSpeed` | double | 1.0 | Global playback speed |
| `pitchCorrection` | bool | true | Enable pitch correction on speed change |
| `rememberPosition` | bool | true | Resume playback position |
| `miniPlayerEnabled` | bool | true | Show mini player dock |
| `remoteEnabled` | bool | false | Enable Crow-Chap remote |

### Database Schema (`lib/data/crow_database.dart`)

Tables mirror the Android `CrowDbHelper`:
- `videos` — video metadata, playback position, enhancement settings
- `folders` — watched folder paths
- `playlists` — playlist metadata
- `playlist_videos` — playlist ↔ video many-to-many with order
- `chapters` — chapter markers per video
- `timeline_skips` — skip segments per video

## Testing

```powershell
flutter test                    # Run unit/widget tests
flutter test --coverage         # With coverage report
```

Current test coverage is minimal (`test/widget_test.dart` only). Add tests for:
- `VideoRepository` CRUD operations
- `FolderScanner` file detection
- `PlaybackService` playlist management
- Enhancement/EQ/Crop mode application

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `flutter doctor` shows "Windows" not checked | Install Visual Studio 2022 with "Desktop development with C++" workload |
| `smtc_windows` build fails | Install `rustup`, run `rustup default stable`, then `flutter clean && flutter pub get` |
| Web SQLite errors | Run `dart run sqflite_common_ffi_web:setup` |
| Icon not showing in title bar | Ensure `windows/runner/resources/app_icon.ico` is the project's icon (not Flutter's placeholder) |
| Hot reload not working on Windows | Use `flutter run -d windows --hot` or check VS Code launch config |
| Remote pairing fails | Check firewall allows inbound on the server port (default 8080) |

## License

Proprietary / Internal use only. Derived from `Crow-Theatron-Android`.

---

**Version**: 2.0.0  
**Flutter SDK**: >=3.4.0 <4.0.0  
**Platforms**: Windows (x64), Web (Chrome/Edge/Firefox)