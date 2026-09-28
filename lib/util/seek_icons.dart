import 'package:flutter/material.dart';

/// Rewind / fast-forward glyph matching the user's seek interval where
/// Material has a numbered icon (5 / 10 / 30 s); a generic one otherwise.
IconData seekIcon(int seconds, {required bool forward}) {
  switch (seconds) {
    case 5:
      return forward ? Icons.forward_5_rounded : Icons.replay_5_rounded;
    case 10:
      return forward ? Icons.forward_10_rounded : Icons.replay_10_rounded;
    case 30:
      return forward ? Icons.forward_30_rounded : Icons.replay_30_rounded;
    default:
      return forward ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded;
  }
}
