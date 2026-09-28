import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/playback_service.dart';
import '../state/shell_nav.dart';
import '../theme/crow_colors.dart';

/// ─────────────────────────────────────────────────────────────────────
/// Crow Théatron keyboard shortcut scheme (standard media-player
/// conventions — same family as YouTube / VLC / MPV / Windows Media
/// Player). This file is the ONE source of truth for every shortcut in
/// the app: previously there were three independent, overlapping
/// binding tables (in `keyboard_accessible.dart`, `mini_player.dart`
/// and `player_screen.dart`) that assigned the same key to different
/// actions (e.g. "F" was bound to both "fullscreen" and "go to
/// Favorites") and, in `mini_player.dart`, rebuilt a fresh `FocusNode`
/// with `autofocus: true` on every single rebuild — repeatedly
/// stealing keyboard focus away from whatever the user was doing.
/// Those have all been removed in favour of this module.
/// ─────────────────────────────────────────────────────────────────────

/// A single documented shortcut: the key combination, a human label for
/// the in-app cheat sheet, and the action it runs.
class AppShortcut {
  const AppShortcut(this.activator, this.label, this.action, {required this.category});
  final ShortcutActivator activator;
  final String label;
  final VoidCallback action;
  final String category;
}

/// True while a text-entry field (a search box, a dialog's TextField,
/// etc.) currently holds keyboard focus. Bare-letter / arrow-key
/// shortcuts must not fire in that state — the key event still reaches
/// the field for normal typing (Flutter delivers character input over a
/// separate channel from `Shortcuts`), but the field would *also* see
/// the app treat "F" as "toggle fullscreen" or Left/Right as "seek"
/// while the user is simply trying to type. Modifier-only combos
/// (Ctrl+…) are exempt from this guard at the call site where it makes
/// sense (e.g. Ctrl+1..8 navigation, Ctrl+Q to quit).
bool isTextInputActive() {
  final focus = FocusManager.instance.primaryFocus;
  final context = focus?.context;
  if (context == null) return false;
  if (context.widget is EditableText) return true;
  var found = false;
  context.visitAncestorElements((element) {
    if (element.widget is EditableText) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

/// Wraps [action] so it no-ops while a text field has focus.
VoidCallback _guarded(VoidCallback action) {
  return () {
    if (!isTextInputActive()) action();
  };
}

/// Renders [shortcuts] as both a `Shortcuts`/`Actions` binding (via
/// `CallbackShortcuts`) and keeps them available for the cheat sheet.
class AppShortcutsScope extends StatelessWidget {
  const AppShortcutsScope({super.key, required this.shortcuts, required this.child});

  final List<AppShortcut> shortcuts;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {for (final s in shortcuts) s.activator: s.action},
      child: child,
    );
  }
}

/// ── Transport shortcuts (play/pause, seek, volume, mute, next/prev) ──
///
/// Shared between the always-on mini-player (bound once, high in the
/// widget tree, in [AppShell]) and the full [PlayerScreen] (which lives
/// on its own `Navigator` route and so needs its own copy). Defining
/// the bindings in exactly one place guarantees both surfaces agree.
List<AppShortcut> buildTransportShortcuts(PlaybackService svc) {
  // Step sizes come from Settings → Display & Playback and are read at
  // the moment the key is pressed, so changing a setting takes effect
  // immediately.
  void seekBy(int direction, {int multiplier = 1}) =>
      svc.seekRelative(direction * svc.seekStepMs * multiplier);
  void volume(int direction) =>
      svc.adjustVolume((direction * svc.prefs.defaultVolumeStepPercent).toDouble());

  return [
    AppShortcut(const SingleActivator(LogicalKeyboardKey.space), 'Space', _guarded(svc.togglePlayPause), category: 'Playback'),
    AppShortcut(const SingleActivator(LogicalKeyboardKey.keyK), 'K', _guarded(svc.togglePlayPause), category: 'Playback'),
    AppShortcut(const SingleActivator(LogicalKeyboardKey.keyM), 'M', _guarded(svc.toggleMute), category: 'Playback'),
    AppShortcut(const SingleActivator(LogicalKeyboardKey.arrowLeft), '←', _guarded(() => seekBy(-1)), category: 'Playback'),
    AppShortcut(const SingleActivator(LogicalKeyboardKey.arrowRight), '→', _guarded(() => seekBy(1)), category: 'Playback'),
    AppShortcut(const SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true), 'Shift+←', _guarded(() => seekBy(-1, multiplier: 3)), category: 'Playback'),
    AppShortcut(const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true), 'Shift+→', _guarded(() => seekBy(1, multiplier: 3)), category: 'Playback'),
    AppShortcut(const SingleActivator(LogicalKeyboardKey.arrowUp), '↑', _guarded(() => volume(1)), category: 'Playback'),
    AppShortcut(const SingleActivator(LogicalKeyboardKey.arrowDown), '↓', _guarded(() => volume(-1)), category: 'Playback'),
    AppShortcut(const SingleActivator(LogicalKeyboardKey.arrowLeft, control: true), 'Ctrl+←', _guarded(svc.playPrevious), category: 'Playback'),
    AppShortcut(const SingleActivator(LogicalKeyboardKey.arrowRight, control: true), 'Ctrl+→', _guarded(svc.playNext), category: 'Playback'),

    // ── Hardware / earbud media keys — always active regardless of
    // text-field focus. These are the `LogicalKeyboardKey`s Flutter
    // maps HID consumer-control codes to; on platforms/situations
    // where the OS routes a media-key press to the app as a normal key
    // event (rather than exclusively through a media session — see
    // MediaSessionService for the primary path on Windows/Web) this is
    // the fallback that makes it work.
    AppShortcut(const SingleActivator(LogicalKeyboardKey.mediaPlay), 'Media Play', () { if (!svc.player.state.playing) svc.togglePlayPause(); }, category: 'Hardware media keys'),
    AppShortcut(const SingleActivator(LogicalKeyboardKey.mediaPause), 'Media Pause', () { if (svc.player.state.playing) svc.togglePlayPause(); }, category: 'Hardware media keys'),
    AppShortcut(const SingleActivator(LogicalKeyboardKey.mediaPlayPause), 'Media Play/Pause', svc.togglePlayPause, category: 'Hardware media keys'),
    AppShortcut(const SingleActivator(LogicalKeyboardKey.mediaTrackNext), 'Media Next', svc.playNext, category: 'Hardware media keys'),
    AppShortcut(const SingleActivator(LogicalKeyboardKey.mediaTrackPrevious), 'Media Previous', svc.playPrevious, category: 'Hardware media keys'),
    AppShortcut(const SingleActivator(LogicalKeyboardKey.mediaStop), 'Media Stop', svc.stop, category: 'Hardware media keys'),
    AppShortcut(const SingleActivator(LogicalKeyboardKey.audioVolumeUp), 'Volume Up key', () => volume(1), category: 'Hardware media keys'),
    AppShortcut(const SingleActivator(LogicalKeyboardKey.audioVolumeDown), 'Volume Down key', () => volume(-1), category: 'Hardware media keys'),
    AppShortcut(const SingleActivator(LogicalKeyboardKey.audioVolumeMute), 'Volume Mute key', svc.toggleMute, category: 'Hardware media keys'),
  ];
}

/// ── Navigation shortcuts (always active, even while typing) ──
List<AppShortcut> buildNavigationShortcuts({
  required ShellNavState nav,
  required List<SidebarDestination> order,
  required VoidCallback onQuit,
  required VoidCallback onShowHelp,
}) {
  final shortcuts = <AppShortcut>[];
  for (var i = 0; i < order.length && i < 9; i++) {
    final destination = order[i];
    shortcuts.add(AppShortcut(
      SingleActivator(_digitKeys[i], control: true),
      'Ctrl+${i + 1}',
      () => nav.goTo(destination),
      category: 'Navigation',
    ));
  }
  shortcuts.add(AppShortcut(const SingleActivator(LogicalKeyboardKey.comma, control: true), 'Ctrl+,', () => nav.goTo(SidebarDestination.settings), category: 'Navigation'));
  shortcuts.add(AppShortcut(const SingleActivator(LogicalKeyboardKey.keyQ, control: true), 'Ctrl+Q', onQuit, category: 'Navigation'));
  shortcuts.add(AppShortcut(const SingleActivator(LogicalKeyboardKey.f1), 'F1', onShowHelp, category: 'Navigation'));
  return shortcuts;
}

const _digitKeys = [
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
  LogicalKeyboardKey.digit4,
  LogicalKeyboardKey.digit5,
  LogicalKeyboardKey.digit6,
  LogicalKeyboardKey.digit7,
  LogicalKeyboardKey.digit8,
  LogicalKeyboardKey.digit9,
];

/// Callbacks the full [PlayerScreen] supplies for its player-only
/// shortcuts (fullscreen, chapters, trim/pitch/speed, etc). Kept as a
/// plain bag of closures so this module has no dependency on
/// `PlayerScreen`'s private state.
class PlayerShortcutCallbacks {
  const PlayerShortcutCallbacks({
    required this.toggleFullscreen,
    required this.exitOrBack,
    required this.restart,
    required this.addChapterAtCurrentPosition,
    required this.openAddSkipDialog,
    required this.manageSkips,
    required this.nextChapter,
    required this.previousChapter,
    required this.seekToPercent,
    required this.seekToStart,
    required this.seekToEnd,
    required this.pitchDown,
    required this.pitchUp,
    required this.resetPitch,
    required this.speedDown,
    required this.speedUp,
    required this.resetSpeed,
    required this.toggleAutoplay,
    required this.toggleLoop,
    required this.toggleShuffle,
    required this.toggleFavorite,
  });

  final VoidCallback toggleFullscreen;
  final VoidCallback exitOrBack;
  final VoidCallback restart;
  final VoidCallback addChapterAtCurrentPosition;
  final VoidCallback openAddSkipDialog;
  final VoidCallback manageSkips;
  final VoidCallback nextChapter;
  final VoidCallback previousChapter;
  final void Function(int percent) seekToPercent;
  final VoidCallback seekToStart;
  final VoidCallback seekToEnd;
  final VoidCallback pitchDown;
  final VoidCallback pitchUp;
  final VoidCallback resetPitch;
  final VoidCallback speedDown;
  final VoidCallback speedUp;
  final VoidCallback resetSpeed;
  final VoidCallback toggleAutoplay;
  final VoidCallback toggleLoop;
  final VoidCallback toggleShuffle;
  final VoidCallback toggleFavorite;
}

/// ── Player-only shortcuts (bound only inside the full PlayerScreen) ──
List<AppShortcut> buildPlayerOnlyShortcuts(PlayerShortcutCallbacks cb, {required VoidCallback onShowHelp}) {
  final shortcuts = <AppShortcut>[
    AppShortcut(const SingleActivator(LogicalKeyboardKey.keyF), 'F', _guarded(cb.toggleFullscreen), category: 'Player'),
    AppShortcut(const SingleActivator(LogicalKeyboardKey.escape), 'Esc', cb.exitOrBack, category: 'Player'),
    AppShortcut(const SingleActivator(LogicalKeyboardKey.keyR), 'R', _guarded(cb.restart), category: 'Player'),
    AppShortcut(const SingleActivator(LogicalKeyboardKey.keyC), 'C', _guarded(cb.addChapterAtCurrentPosition), category: 'Chapters & skips'),
    AppShortcut(const SingleActivator(LogicalKeyboardKey.keyQ), 'Q', _guarded(cb.openAddSkipDialog), category: 'Chapters & skips'),
    AppShortcut(const SingleActivator(LogicalKeyboardKey.keyK, control: true), 'Ctrl+K', cb.manageSkips, category: 'Chapters & skips'),
    AppShortcut(const SingleActivator(LogicalKeyboardKey.keyN), 'N', _guarded(cb.nextChapter), category: 'Chapters & skips'),
    AppShortcut(const SingleActivator(LogicalKeyboardKey.keyP), 'P', _guarded(cb.previousChapter), category: 'Chapters & skips'),
    AppShortcut(const SingleActivator(LogicalKeyboardKey.home), 'Home', _guarded(cb.seekToStart), category: 'Player'),
    AppShortcut(const SingleActivator(LogicalKeyboardKey.end), 'End', _guarded(cb.seekToEnd), category: 'Player'),
    AppShortcut(const SingleActivator(LogicalKeyboardKey.keyA), 'A', _guarded(cb.pitchDown), category: 'Pitch & speed'),
    AppShortcut(const SingleActivator(LogicalKeyboardKey.keyS), 'S', _guarded(cb.pitchUp), category: 'Pitch & speed'),
    AppShortcut(const SingleActivator(LogicalKeyboardKey.keyZ), 'Z', _guarded(cb.resetPitch), category: 'Pitch & speed'),
    AppShortcut(const SingleActivator(LogicalKeyboardKey.keyT), 'T', _guarded(cb.speedDown), category: 'Pitch & speed'),
    AppShortcut(const SingleActivator(LogicalKeyboardKey.keyY), 'Y', _guarded(cb.speedUp), category: 'Pitch & speed'),
    AppShortcut(const SingleActivator(LogicalKeyboardKey.keyU), 'U', _guarded(cb.resetSpeed), category: 'Pitch & speed'),
    AppShortcut(const SingleActivator(LogicalKeyboardKey.keyG), 'G', _guarded(cb.toggleAutoplay), category: 'Playback options'),
    AppShortcut(const SingleActivator(LogicalKeyboardKey.keyH), 'H', _guarded(cb.toggleLoop), category: 'Playback options'),
    AppShortcut(const SingleActivator(LogicalKeyboardKey.keyJ), 'J', _guarded(cb.toggleShuffle), category: 'Playback options'),
    AppShortcut(const SingleActivator(LogicalKeyboardKey.keyO), 'O', _guarded(cb.toggleFavorite), category: 'Playback options'),
    AppShortcut(const SingleActivator(LogicalKeyboardKey.f1), 'F1', onShowHelp, category: 'Player'),
  ];
  for (var d = 0; d <= 9; d++) {
    final percent = d * 10;
    shortcuts.add(AppShortcut(
      SingleActivator(_digitKeys0[d]),
      '$d',
      _guarded(() => cb.seekToPercent(percent)),
      category: 'Player',
    ));
  }
  return shortcuts;
}

const _digitKeys0 = [
  LogicalKeyboardKey.digit0,
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
  LogicalKeyboardKey.digit4,
  LogicalKeyboardKey.digit5,
  LogicalKeyboardKey.digit6,
  LogicalKeyboardKey.digit7,
  LogicalKeyboardKey.digit8,
  LogicalKeyboardKey.digit9,
];

/// Shows the keyboard-shortcut cheat sheet, grouped by category.
void showShortcutsHelp(BuildContext context, List<AppShortcut> shortcuts) {
  final byCategory = <String, List<AppShortcut>>{};
  for (final s in shortcuts) {
    byCategory.putIfAbsent(s.category, () => []).add(s);
  }
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: CrowColors.surfaceElevated,
      title: const Text('Keyboard shortcuts', style: TextStyle(color: CrowColors.onBg)),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in byCategory.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 6),
                  child: Text(entry.key.toUpperCase(),
                      style: const TextStyle(color: CrowColors.accentYellow, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
                for (final s in entry.value)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 130,
                          child: Text(s.label, style: const TextStyle(color: CrowColors.accentCyan, fontSize: 12, fontFamily: 'monospace')),
                        ),
                        Expanded(child: Text(_describe(s), style: const TextStyle(color: CrowColors.onMuted, fontSize: 12))),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
      ],
    ),
  );
}

String _describe(AppShortcut s) => s.label;

/// Convenience: reads [PlaybackService] and [ShellNavState] from
/// [context] via Provider and builds the two always-on shortcut lists
/// used by [AppShell].
List<AppShortcut> globalShortcutsFor(
  BuildContext context, {
  required VoidCallback onQuit,
  required VoidCallback onShowHelp,
}) {
  final svc = context.read<PlaybackService>();
  final nav = context.read<ShellNavState>();
  return [
    ...buildTransportShortcuts(svc),
    ...buildNavigationShortcuts(
      nav: nav,
      order: const [
        SidebarDestination.home,
        SidebarDestination.library,
        SidebarDestination.favorites,
        SidebarDestination.memory,
        SidebarDestination.explore,
        SidebarDestination.playlists,
        SidebarDestination.enhancement,
        SidebarDestination.settings,
      ],
      onQuit: onQuit,
      onShowHelp: onShowHelp,
    ),
  ];
}
