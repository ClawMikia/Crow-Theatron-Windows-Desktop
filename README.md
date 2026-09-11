# Crow Théatron — Windows Desktop / Web (Flutter port)

A Flutter port of the `Crow-Theatron-Android` app, built for **Windows Desktop**
(with a **Web** build as well, per your request). It went through two passes:
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

## 2. Run it

```powershell
flutter run -d windows      # Windows desktop, hot reload
flutter run -d chrome       # Web, in Chrome
```

## 3. Build a release

```powershell
flutter build windows       # → build/windows/x64/runner/Release/crow_theatron.exe
flutter build web           # → build/web/  (deploy as a static site)
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
