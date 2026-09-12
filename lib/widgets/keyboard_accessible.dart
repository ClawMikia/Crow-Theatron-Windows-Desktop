import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A wrapper that makes any widget keyboard accessible.
/// Handles focus, Enter/Space activation, and hover states.
class KeyboardAccessible extends StatefulWidget {
  const KeyboardAccessible({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onKeyEvent,
    this.focusNode,
    this.autofocus = false,
    this.descendantsAreFocusable = false,
    this.descendantsAreTraversable = false,
    this.semanticsLabel,
    this.tooltip,
    this.enabled = true,
    this.focusHighlightColor,
    this.hoverColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final FocusOnKeyEventCallback? onKeyEvent;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool descendantsAreFocusable;
  final bool descendantsAreTraversable;
  final String? semanticsLabel;
  final String? tooltip;
  final bool enabled;
  final Color? focusHighlightColor;
  final Color? hoverColor;

  @override
  State<KeyboardAccessible> createState() => _KeyboardAccessibleState();
}

class _KeyboardAccessibleState extends State<KeyboardAccessible> {
  late FocusNode _focusNode;
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() => _isFocused = _focusNode.hasFocus);
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!widget.enabled) return KeyEventResult.ignored;

    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.space ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        widget.onTap?.call();
        return KeyEventResult.handled;
      }
    }

    if (widget.onKeyEvent != null) {
      return widget.onKeyEvent!(node, event);
    }
    return KeyEventResult.ignored;
  }

  void _handleTap() {
    if (widget.enabled) {
      widget.onTap?.call();
      _focusNode.requestFocus();
    }
  }

  void _handleLongPress() {
    if (widget.enabled) {
      widget.onLongPress?.call();
    }
  }

  void _handleHover(bool hovered) {
    if (widget.enabled && mounted) {
      setState(() => _isHovered = hovered);
    }
  }

  @override
  Widget build(BuildContext context) {
    final focusHighlightColor =
        widget.focusHighlightColor ?? Theme.of(context).focusColor;
    final hoverColor = widget.hoverColor ?? Theme.of(context).hoverColor;

    Widget result = Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      descendantsAreFocusable: widget.descendantsAreFocusable,
      descendantsAreTraversable: widget.descendantsAreTraversable,
      onKeyEvent: _handleKeyEvent,
      child: MouseRegion(
        onEnter: (_) => _handleHover(true),
        onExit: (_) => _handleHover(false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            border: _isFocused
                ? Border.all(color: focusHighlightColor, width: 2)
                : null,
            borderRadius: BorderRadius.circular(8),
            color: _isHovered && !_isFocused ? hoverColor : null,
          ),
          child: Semantics(
            button: widget.onTap != null,
            link: widget.onTap != null && widget.tooltip == null,
            label: widget.semanticsLabel,
            tooltip: widget.tooltip,
            enabled: widget.enabled,
            child: GestureDetector(
              onTap: _handleTap,
              onLongPress: widget.onLongPress != null ? _handleLongPress : null,
              child: widget.child,
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      result = Tooltip(message: widget.tooltip!, child: result);
    }

    return result;
  }
}

/// A focusable InkWell alternative that properly handles keyboard activation.
class FocusableInkWell extends StatefulWidget {
  const FocusableInkWell({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onDoubleTap,
    this.focusNode,
    this.autofocus = false,
    this.borderRadius,
    this.splashColor,
    this.highlightColor,
    this.hoverColor,
    this.focusColor,
    this.semanticsLabel,
    this.tooltip,
    this.enabled = true,
    this.canRequestFocus = true,
    this.onKeyEvent,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;
  final FocusNode? focusNode;
  final bool autofocus;
  final BorderRadius? borderRadius;
  final Color? splashColor;
  final Color? highlightColor;
  final Color? hoverColor;
  final Color? focusColor;
  final String? semanticsLabel;
  final String? tooltip;
  final bool enabled;
  final bool canRequestFocus;
  final FocusOnKeyEventCallback? onKeyEvent;

  @override
  State<FocusableInkWell> createState() => _FocusableInkWellState();
}

class _FocusableInkWellState extends State<FocusableInkWell> {
  late FocusNode _focusNode;
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() => _isFocused = _focusNode.hasFocus);
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!widget.enabled) return KeyEventResult.ignored;

    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.space ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        widget.onTap?.call();
        return KeyEventResult.handled;
      }
      if (widget.onKeyEvent != null) {
        return widget.onKeyEvent!(node, event);
      }
    }
    return KeyEventResult.ignored;
  }

  void _handleTap() {
    if (widget.enabled) {
      widget.onTap?.call();
      if (widget.canRequestFocus) {
        _focusNode.requestFocus();
      }
    }
  }

  void _handleHover(bool hovered) {
    if (widget.enabled && mounted) {
      setState(() => _isHovered = hovered);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final focusColor = widget.focusColor ?? theme.focusColor;
    final hoverColor = widget.hoverColor ?? theme.hoverColor;
    final highlightColor = widget.highlightColor ?? theme.highlightColor;
    final splashColor = widget.splashColor ?? theme.splashColor;

    Widget result = Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: _handleKeyEvent,
      canRequestFocus: widget.canRequestFocus,
      child: MouseRegion(
        onEnter: (_) => _handleHover(true),
        onExit: (_) => _handleHover(false),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
          child: InkWell(
            onTap: widget.enabled ? _handleTap : null,
            onLongPress: widget.enabled && widget.onLongPress != null
                ? widget.onLongPress
                : null,
            onDoubleTap: widget.enabled && widget.onDoubleTap != null
                ? widget.onDoubleTap
                : null,
            borderRadius: widget.borderRadius,
            splashColor: splashColor,
            highlightColor: highlightColor,
            hoverColor: hoverColor,
            focusColor: focusColor,
            child: Semantics(
              button: widget.onTap != null,
              label: widget.semanticsLabel,
              tooltip: widget.tooltip,
              enabled: widget.enabled,
              child: widget.child,
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      result = Tooltip(message: widget.tooltip!, child: result);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        border: _isFocused ? Border.all(color: focusColor, width: 2) : null,
        borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
        color: _isHovered && !_isFocused ? hoverColor : null,
      ),
      child: result,
    );
  }
}

/// A focusable IconButton that properly handles keyboard activation.
class FocusableIconButton extends StatefulWidget {
  const FocusableIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.focusNode,
    this.autofocus = false,
    this.iconSize = 24.0,
    this.size,
    this.color,
    this.disabledColor,
    this.hoverColor,
    this.focusColor,
    this.splashColor,
    this.highlightColor,
    this.semanticsLabel,
    this.enabled = true,
    this.padding = const EdgeInsets.all(8.0),
    this.alignment = Alignment.center,
    this.onKeyEvent,
  });

  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final FocusNode? focusNode;
  final bool autofocus;
  final double iconSize;
  final double? size;
  final Color? color;
  final Color? disabledColor;
  final Color? hoverColor;
  final Color? focusColor;
  final Color? splashColor;
  final Color? highlightColor;
  final String? semanticsLabel;
  final bool enabled;
  final EdgeInsetsGeometry padding;
  final Alignment alignment;
  final FocusOnKeyEventCallback? onKeyEvent;

  @override
  State<FocusableIconButton> createState() => _FocusableIconButtonState();
}

class _FocusableIconButtonState extends State<FocusableIconButton> {
  late FocusNode _focusNode;
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() => _isFocused = _focusNode.hasFocus);
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!widget.enabled) return KeyEventResult.ignored;

    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.space ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        widget.onPressed?.call();
        return KeyEventResult.handled;
      }
      if (widget.onKeyEvent != null) {
        return widget.onKeyEvent!(node, event);
      }
    }
    return KeyEventResult.ignored;
  }

  void _handleHover(bool hovered) {
    if (widget.enabled && mounted) {
      setState(() => _isHovered = hovered);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final focusColor = widget.focusColor ?? theme.focusColor;
    final hoverColor = widget.hoverColor ?? theme.hoverColor;
    final splashColor = widget.splashColor ?? theme.splashColor;
    final highlightColor = widget.highlightColor ?? theme.highlightColor;
    final effectiveIconSize = widget.size ?? widget.iconSize;

    Widget result = Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: _handleKeyEvent,
      child: MouseRegion(
        onEnter: (_) => _handleHover(true),
        onExit: (_) => _handleHover(false),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.enabled ? widget.onPressed : null,
            borderRadius: BorderRadius.circular(8),
            splashColor: splashColor,
            highlightColor: highlightColor,
            hoverColor: hoverColor,
            focusColor: focusColor,
            child: Semantics(
              button: true,
              label: widget.semanticsLabel,
              tooltip: widget.tooltip,
              enabled: widget.enabled,
              child: Padding(
                padding: widget.padding,
                child: IconTheme.merge(
                  data: IconThemeData(
                    size: effectiveIconSize,
                    color: widget.enabled ? widget.color : widget.disabledColor,
                  ),
                  child: widget.icon,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      result = Tooltip(message: widget.tooltip!, child: result);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        border: _isFocused ? Border.all(color: focusColor, width: 2) : null,
        borderRadius: BorderRadius.circular(8),
        color: _isHovered && !_isFocused ? hoverColor : null,
      ),
      child: result,
    );
  }
}

/// A focusable slider that properly handles keyboard navigation.
class FocusableSlider extends StatefulWidget {
  const FocusableSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    this.label,
    this.focusNode,
    this.autofocus = false,
    this.semanticsLabel,
    this.semanticsValue,
    this.enabled = true,
    this.activeColor,
    this.inactiveColor,
    this.thumbColor,
    this.overlayColor,
    this.trackHeight,
    this.onKeyEvent,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final int? divisions;
  final String? label;
  final FocusNode? focusNode;
  final bool autofocus;
  final String? semanticsLabel;
  final String? semanticsValue;
  final bool enabled;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? thumbColor;
  final Color? overlayColor;
  final double? trackHeight;
  final FocusOnKeyEventCallback? onKeyEvent;

  @override
  State<FocusableSlider> createState() => _FocusableSliderState();
}

class _FocusableSliderState extends State<FocusableSlider> {
  late FocusNode _focusNode;
  bool _isFocused = false;
  double _localValue = 0.0;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _localValue = widget.value;
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant FocusableSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _localValue = widget.value;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() => _isFocused = _focusNode.hasFocus);
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!widget.enabled) return KeyEventResult.ignored;

    if (event is KeyDownEvent) {
      final step = widget.divisions != null
          ? (widget.max - widget.min) / widget.divisions!
          : (widget.max - widget.min) / 100;

      if (widget.onKeyEvent != null) {
        final result = widget.onKeyEvent!(node, event);
        if (result == KeyEventResult.handled) return result;
      }

      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowRight:
        case LogicalKeyboardKey.arrowUp:
          _localValue = (_localValue + step).clamp(widget.min, widget.max);
          widget.onChanged(_localValue);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowLeft:
        case LogicalKeyboardKey.arrowDown:
          _localValue = (_localValue - step).clamp(widget.min, widget.max);
          widget.onChanged(_localValue);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.home:
          _localValue = widget.min;
          widget.onChanged(_localValue);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.end:
          _localValue = widget.max;
          widget.onChanged(_localValue);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.pageUp:
          _localValue = (_localValue + step * 10).clamp(widget.min, widget.max);
          widget.onChanged(_localValue);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.pageDown:
          _localValue = (_localValue - step * 10).clamp(widget.min, widget.max);
          widget.onChanged(_localValue);
          return KeyEventResult.handled;
      }

      if (widget.onKeyEvent != null) {
        return widget.onKeyEvent!(node, event);
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: _handleKeyEvent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          border:
              _isFocused ? Border.all(color: theme.focusColor, width: 2) : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Semantics(
          slider: true,
          label: widget.semanticsLabel,
          value: widget.semanticsValue ?? widget.label,
          enabled: widget.enabled,
          child: Slider(
            value: _localValue,
            min: widget.min,
            max: widget.max,
            divisions: widget.divisions,
            label: widget.label,
            onChanged: widget.enabled
                ? (value) {
                    setState(() => _localValue = value);
                    widget.onChanged(value);
                  }
                : null,
            activeColor: widget.activeColor,
            inactiveColor: widget.inactiveColor,
            thumbColor: widget.thumbColor,
            // overlayColor expects WidgetStateProperty<Color?>?, not Color?
            // overlayColor: widget.overlayColor != null ? WidgetStateProperty.resolveWith((states) => widget.overlayColor) : null,
          ),
        ),
      ),
    );
  }
}

/// Intent classes for keyboard shortcuts.
class PlayPauseIntent extends Intent {
  const PlayPauseIntent();
}

class FullscreenIntent extends Intent {
  const FullscreenIntent();
}

class MuteIntent extends Intent {
  const MuteIntent();
}

class SeekForwardIntent extends Intent {
  const SeekForwardIntent();
}

class SeekBackwardIntent extends Intent {
  const SeekBackwardIntent();
}

class SeekForwardLargeIntent extends Intent {
  const SeekForwardLargeIntent();
}

class SeekBackwardLargeIntent extends Intent {
  const SeekBackwardLargeIntent();
}

class VolumeUpIntent extends Intent {
  const VolumeUpIntent();
}

class VolumeDownIntent extends Intent {
  const VolumeDownIntent();
}

class NextTrackIntent extends Intent {
  const NextTrackIntent();
}

class PreviousTrackIntent extends Intent {
  const PreviousTrackIntent();
}

class EscapeIntent extends Intent {
  const EscapeIntent();
}

class NavigateHomeIntent extends Intent {
  const NavigateHomeIntent();
}

class NavigateLibraryIntent extends Intent {
  const NavigateLibraryIntent();
}

class NavigateFavoritesIntent extends Intent {
  const NavigateFavoritesIntent();
}

class OpenSettingsIntent extends Intent {
  const OpenSettingsIntent();
}

class AddChapterIntent extends Intent {
  const AddChapterIntent();
}

class AddSkipIntent extends Intent {
  const AddSkipIntent();
}

/// Actions for keyboard shortcuts.
class KeyboardActions extends StatelessWidget {
  const KeyboardActions({
    super.key,
    required this.child,
    this.onPlayPause,
    this.onFullscreen,
    this.onMute,
    this.onSeekForward,
    this.onSeekBackward,
    this.onSeekForwardLarge,
    this.onSeekBackwardLarge,
    this.onVolumeUp,
    this.onVolumeDown,
    this.onNextTrack,
    this.onPreviousTrack,
    this.onEscape,
    this.onNavigateHome,
    this.onNavigateLibrary,
    this.onNavigateFavorites,
    this.onOpenSettings,
    this.onAddChapter,
    this.onAddSkip,
  });

  final Widget child;
  final VoidCallback? onPlayPause;
  final VoidCallback? onFullscreen;
  final VoidCallback? onMute;
  final VoidCallback? onSeekForward;
  final VoidCallback? onSeekBackward;
  final VoidCallback? onSeekForwardLarge;
  final VoidCallback? onSeekBackwardLarge;
  final VoidCallback? onVolumeUp;
  final VoidCallback? onVolumeDown;
  final VoidCallback? onNextTrack;
  final VoidCallback? onPreviousTrack;
  final VoidCallback? onEscape;
  final VoidCallback? onNavigateHome;
  final VoidCallback? onNavigateLibrary;
  final VoidCallback? onNavigateFavorites;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onAddChapter;
  final VoidCallback? onAddSkip;

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: {
        PlayPauseIntent: CallbackAction<PlayPauseIntent>(
            onInvoke: (_) => onPlayPause?.call()),
        FullscreenIntent: CallbackAction<FullscreenIntent>(
            onInvoke: (_) => onFullscreen?.call()),
        MuteIntent: CallbackAction<MuteIntent>(onInvoke: (_) => onMute?.call()),
        SeekForwardIntent: CallbackAction<SeekForwardIntent>(
            onInvoke: (_) => onSeekForward?.call()),
        SeekBackwardIntent: CallbackAction<SeekBackwardIntent>(
            onInvoke: (_) => onSeekBackward?.call()),
        SeekForwardLargeIntent: CallbackAction<SeekForwardLargeIntent>(
            onInvoke: (_) => onSeekForwardLarge?.call()),
        SeekBackwardLargeIntent: CallbackAction<SeekBackwardLargeIntent>(
            onInvoke: (_) => onSeekBackwardLarge?.call()),
        VolumeUpIntent:
            CallbackAction<VolumeUpIntent>(onInvoke: (_) => onVolumeUp?.call()),
        VolumeDownIntent: CallbackAction<VolumeDownIntent>(
            onInvoke: (_) => onVolumeDown?.call()),
        NextTrackIntent: CallbackAction<NextTrackIntent>(
            onInvoke: (_) => onNextTrack?.call()),
        PreviousTrackIntent: CallbackAction<PreviousTrackIntent>(
            onInvoke: (_) => onPreviousTrack?.call()),
        EscapeIntent:
            CallbackAction<EscapeIntent>(onInvoke: (_) => onEscape?.call()),
        NavigateHomeIntent: CallbackAction<NavigateHomeIntent>(
            onInvoke: (_) => onNavigateHome?.call()),
        NavigateLibraryIntent: CallbackAction<NavigateLibraryIntent>(
            onInvoke: (_) => onNavigateLibrary?.call()),
        NavigateFavoritesIntent: CallbackAction<NavigateFavoritesIntent>(
            onInvoke: (_) => onNavigateFavorites?.call()),
        OpenSettingsIntent: CallbackAction<OpenSettingsIntent>(
            onInvoke: (_) => onOpenSettings?.call()),
        AddChapterIntent: CallbackAction<AddChapterIntent>(
            onInvoke: (_) => onAddChapter?.call()),
        AddSkipIntent:
            CallbackAction<AddSkipIntent>(onInvoke: (_) => onAddSkip?.call()),
      },
      child: Shortcuts(
        shortcuts: {
          SingleActivator(LogicalKeyboardKey.space): const PlayPauseIntent(),
          SingleActivator(LogicalKeyboardKey.keyF): const FullscreenIntent(),
          SingleActivator(LogicalKeyboardKey.keyM): const MuteIntent(),
          SingleActivator(LogicalKeyboardKey.arrowRight):
              const SeekForwardIntent(),
          SingleActivator(LogicalKeyboardKey.arrowLeft):
              const SeekBackwardIntent(),
          SingleActivator(LogicalKeyboardKey.arrowRight, control: true):
              const SeekForwardLargeIntent(),
          SingleActivator(LogicalKeyboardKey.arrowLeft, control: true):
              const SeekBackwardLargeIntent(),
          SingleActivator(LogicalKeyboardKey.arrowUp): const VolumeUpIntent(),
          SingleActivator(LogicalKeyboardKey.arrowDown):
              const VolumeDownIntent(),
          SingleActivator(LogicalKeyboardKey.arrowRight, control: true):
              const NextTrackIntent(),
          SingleActivator(LogicalKeyboardKey.arrowLeft, control: true):
              const PreviousTrackIntent(),
          SingleActivator(LogicalKeyboardKey.escape): const EscapeIntent(),
          SingleActivator(LogicalKeyboardKey.keyH): const NavigateHomeIntent(),
          SingleActivator(LogicalKeyboardKey.keyL):
              const NavigateLibraryIntent(),
          SingleActivator(LogicalKeyboardKey.keyF):
              const NavigateFavoritesIntent(),
          SingleActivator(LogicalKeyboardKey.keyS, control: true):
              const OpenSettingsIntent(),
          SingleActivator(LogicalKeyboardKey.keyC): const AddChapterIntent(),
          SingleActivator(LogicalKeyboardKey.keyK): const AddSkipIntent(),
        },
        child: child,
      ),
    );
  }
}

/// Focus traversal group for proper tab navigation.
class FocusGroup extends StatelessWidget {
  const FocusGroup({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// Mixin for widgets that want to handle keyboard shortcuts.
mixin KeyboardShortcutHandler {
  KeyEventResult handleKeyEvent(FocusNode node, KeyEvent event) {
    return KeyEventResult.ignored;
  }
}
