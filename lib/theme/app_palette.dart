import 'package:flutter/material.dart';

/// The Graphite & Cognac palette — the *only* place hex literals live.
///
/// Nothing outside `lib/theme/` should reference this class. Screens read
/// `Theme.of(context).colorScheme` or `context.sweatColors`, so a palette
/// change here lands everywhere at once.
///
/// Two rules keep the palette looking like leather-on-steel rather than mud:
///
/// 1. The grey ramp is deliberately *cool* (blue-leaning). Warming it collapses
///    the distance between the greys and the cognac and the whole thing muddies.
/// 2. [champagne] is a reward colour — a landed roll, a finished set, a streak.
///    It is never a resting surface and never ordinary body text.
abstract final class SweatPalette {
  // Canvas and layers. These separate by *value*, not by shadow, so elevation
  // overlays stay off everywhere.
  static const canvas = Color(0xFF121315); // app background
  static const surfaceLow = Color(0xFF17191C);
  static const surface = Color(0xFF1C1E21); // raised card
  static const surfaceHigh = Color(0xFF23262A);
  static const surfaceAlt = Color(0xFF2A2D31); // chip, input, inactive track
  static const sink = Color(0xFF0D0E10); // recessed wells, scrim base

  // Lines.
  static const outline = Color(0xFF3D4147); // decorative hairline
  static const outlineStrong = Color(0xFF7A828C); // interactive borders (3:1)

  // Brand.
  static const cognac = Color(0xFFA9673B); // the ROLL action, active states
  static const cognacDeep = Color(0xFF33221A); // container fill
  static const cognacLight = Color(0xFFE3B58C); // text on [cognacDeep]
  static const champagne = Color(0xFFD9B26A); // win / jackpot / sheen ONLY

  // Ink. Anything sitting on [cognac] or [champagne] uses [inkOnBrand]; both
  // brand colours are mid-value, so light text on them cannot clear 4.5:1.
  static const inkHigh = Color(0xFFEDEBE7); // bone white
  static const inkLow = Color(0xFF9A9EA5); // cool grey secondary
  static const inkOnBrand = Color(0xFF14100C);

  // Feedback. [errorInk] is the legible-on-dark tint used for text and icons;
  // [errorFill] is the deeper container behind it.
  static const errorInk = Color(0xFFE0776A);
  static const errorFill = Color(0xFF5C241C);
  static const errorInkOnFill = Color(0xFFFFD9D3);
}
