import 'package:flutter/foundation.dart';

/// Primary desktop-shell destinations, shown in the left sidebar.
/// Replaces the old bottom tab bar (`CrowNavTab` / `CrowBottomNav`).
enum SidebarDestination {
  home,
  library,
  favorites,
  memory,
  explore,
  playlists,
  enhancement,
  settings,
}

/// Which content the [AppShell] shows, and lets any embedded screen
/// switch destinations (e.g. the Home dashboard's "Library" button)
/// without pushing a new route on top of the shell.
class ShellNavState extends ChangeNotifier {
  SidebarDestination _current = SidebarDestination.home;
  SidebarDestination get current => _current;

  void goTo(SidebarDestination destination) {
    if (_current == destination) return;
    _current = destination;
    notifyListeners();
  }
}
