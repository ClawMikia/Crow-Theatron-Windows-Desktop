# Keyboard, media-key & window update

This is a **delta package** — only new or changed files, arranged in
the same folder structure as your project (`lib/...`, `pubspec.yaml`).
Copy them over your existing `Crow-Theatron-Windows-Desktop/` folder,
then run:

```
flutter pub get
```

## 1. What changed, and why

The app already had *some* keyboard handling, but it was split across
three independent, overlapping binding tables that fought each other:

- `keyboard_accessible.dart`'s `KeyboardActions` bound **"F" to both
  "toggle fullscreen" and "go to Favorites"**, and bound **Ctrl+→/Ctrl+←
  to both "large seek" and "next/previous track"** (a duplicate map key
  — only the second entry ever actually fired).
- `mini_player.dart` had its own full YouTube/VLC-style key handler
  wired to a `Focus` widget with `autofocus: true` that was **recreated
  on every rebuild** — since the mini-player rebuilds on every playback
  tick, this meant keyboard focus was being yanked away from whatever
  you were doing (typing in search, tabbing through the sidebar, etc.)
  roughly once a second while something was playing.
- `player_screen.dart` layered a *third*, Ctrl+Alt+Letter-based scheme
  on top of a near-duplicate of the mini-player's handler, so most of
  the Ctrl+Alt combinations were actually unreachable — the plainer
  handler intercepted the keys first.

All three have been replaced with **one canonical table**,
`lib/shortcuts/app_shortcuts.dart`, built around standard media-player
conventions (the same family as YouTube/VLC/MPV/Windows Media Player).
`AppShell` and `PlayerScreen` each bind from that same table, so there
is exactly one place to look when you want to know — or change — what
a key does.

### Full shortcut list

**Playback (works everywhere in the app — mini-player or full player):**

| Key | Action |
|---|---|
| Space, K | Play / Pause |
| M | Mute |
| ← / → | Seek −10s / +10s |
| Shift+← / Shift+→ | Seek −30s / +30s |
| ↑ / ↓ | Volume up / down |
| Ctrl+← / Ctrl+→ | Previous / Next track |

**Hardware & earbud media keys** (Play, Pause, Play/Pause, Next, Previous,
Stop, Volume Up/Down/Mute) are bound to the same actions — see §2.

**Navigation (always active, even while typing in a search box):**

| Key | Action |
|---|---|
| Ctrl+1 … Ctrl+8 | Jump to Home / Library / Favorites / Memory / Explore / Playlists / Enhancement / Settings |
| Ctrl+, | Settings |
| Ctrl+Q | Quit |
| F1 | Show this shortcut list in-app |

**Inside the full Player screen only:**

| Key | Action | Key | Action |
|---|---|---|---|
| F | Toggle fullscreen | N / P | Next / previous chapter |
| Esc | Exit fullscreen / back | Home / End | Seek to start / end |
| R | Restart video | 0–9 | Seek to 0%–90% |
| C | Add chapter here | A / S / Z | Pitch down / up / reset |
| Q | Add timeline skip here | T / Y / U | Speed down / up / reset |
| Ctrl+K | Manage timeline skips | G / H / J | Toggle autoplay / loop / shuffle |
| | | O | Toggle favorite |

Bare single-letter/arrow shortcuts (not the Ctrl-combos) automatically
stand down whenever a text field has focus, so typing in the search
box or a dialog's text field is never hijacked.

### Focus / Tab accessibility

Every interactive element in the app is now reachable and operable by
keyboard alone (Tab / Shift+Tab to move focus, Enter or Space to
activate). Most of the app's own widgets already used the shared
`FocusableInkWell` / `FocusableIconButton` / `FocusableSlider` helpers
in `keyboard_accessible.dart`; the one real gap was the frameless
window's own minimize/maximize/close buttons in `crow_title_bar.dart`,
which used a bare `GestureDetector` with no focus handling at all —
that's now a `FocusableInkWell` like everywhere else. A handful of
other spots (`library_screen.dart`, `explore_screen.dart`,
`enhancement_screen.dart`, `playlist_list_screen.dart`,
`crow_scaffold.dart`) used plain `IconButton`/`InkWell` — those already
had default Tab/Enter support from Flutter itself, but have been
switched to the shared `Focusable*` widgets too, for a consistent
visible focus ring and semantics label across the whole app.

## 2. Media keys / earbud support

`lib/services/media_session/` is a small abstraction with three
implementations, picked automatically at compile time:

- **`media_session_windows.dart`** — Windows System Media Transport
  Controls, via the `smtc_windows` package. This is the real path for
  a Bluetooth earbud's or wired headset's Play/Pause/Next/Previous
  buttons, and for the dedicated media keys on a keyboard: Windows
  delivers those to whichever app is registered with SMTC, regardless
  of window focus, rather than as ordinary keystrokes.
- **`media_session_web.dart`** — the browser's Media Session API
  (`navigator.mediaSession`), the web equivalent, for the Web build.
- **`media_session_stub.dart`** — a harmless no-op fallback for any
  other target, or if the platform integration fails to initialize.

`PlaybackService` pushes title/album metadata and play/pause/position
updates to whichever implementation is active, and routes button
presses back into `togglePlayPause` / `playNext` / `playPrevious` /
etc. `LogicalKeyboardKey.mediaPlay` / `mediaPlayPause` / `mediaTrackNext`
/ … bindings in `app_shortcuts.dart` are a fallback for platforms or
situations where the OS instead delivers a media-key press as an
ordinary key event.

**Build requirement:** `smtc_windows` has a small Rust/`windows-rs`
native component, so **the Windows build machine needs `rustup`
installed** (see the package's own README/pub.dev page). If it isn't
present, `initialize()` in `media_session_windows.dart` catches the
failure and falls back to normal behavior — the app still runs, you
only lose the OS-level media-key routing (in-app buttons and keyboard
shortcuts keep working either way).

**One thing to double-check after `pub get`:** `smtc_windows` and the
Web Media Session bindings were written against their documented
public API (`SMTCWindows.initialize()` / `updateMetadata` /
`setPlaybackStatus` / `buttonPressStream`, and `package:web`'s
`navigator.mediaSession` / `MediaMetadata` / `setActionHandler`
respectively) but I couldn't run `flutter pub get` or a full build in
this environment to compile-check them against the exact versions
that resolve for you. If a method name has moved in whatever version
`pub get` picks, `media_session_windows.dart` or
`media_session_web.dart` are the one file each to adjust — everything
else (the abstract interface, `PlaybackService`, and every shortcut/UI
change) is unaffected.

## 3. Window: resizable + opens maximized

In `main.dart`:

- `windowManager.setResizable(true)` is now called explicitly (it was
  already the default, so this shouldn't change existing behavior, but
  makes "the window can be dragged bigger/smaller while not
  maximized" a deliberate, guaranteed setting rather than an
  assumption). `minimumSize` (900×560) still applies; there's no
  `maximumSize`, so there's no upper bound.
- The window now calls `windowManager.maximize()` before `show()`, so
  the very first frame the user sees is already maximized, instead of
  opening at 1360×820 and snapping to full screen a moment later.

## 4. Files in this package

```
lib/main.dart                                    (window: resizable + maximize on launch, media session init order)
lib/services/playback_service.dart               (wires MediaSessionService in/out)
lib/services/media_session/media_session_service.dart   (NEW)
lib/services/media_session/media_session_stub.dart      (NEW)
lib/services/media_session/media_session_windows.dart   (NEW)
lib/services/media_session/media_session_web.dart       (NEW)
lib/shortcuts/app_shortcuts.dart                 (NEW — the one shortcut table)
lib/widgets/app_shell.dart                       (binds global shortcuts)
lib/widgets/mini_player.dart                     (removed the focus-stealing bug)
lib/widgets/keyboard_accessible.dart             (removed the old conflicting KeyboardActions)
lib/widgets/crow_title_bar.dart                  (window buttons now keyboard-focusable)
lib/widgets/crow_scaffold.dart                   (back button → FocusableIconButton)
lib/screens/player_screen.dart                   (binds player-only shortcuts, removed old schemes)
lib/screens/library_screen.dart                  (IconButton → FocusableIconButton)
lib/screens/explore_screen.dart                  (IconButton → FocusableIconButton)
lib/screens/enhancement_screen.dart              (InkWell → FocusableInkWell)
lib/screens/playlist_list_screen.dart            (InkWell → FocusableInkWell)
pubspec.yaml                                     (adds smtc_windows, web; sdk floor bumped to 3.4.0)
```
