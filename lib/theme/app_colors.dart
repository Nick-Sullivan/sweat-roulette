import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Colour roles Material's [ColorScheme] has no slot for.
///
/// Read it through `context.sweatColors` rather than digging it out of the
/// theme by hand. As the app grows this is where the movement-pool tints and
/// the RIR effort ramp will land — anything semantic that isn't primary /
/// surface / error.
@immutable
class SweatColors extends ThemeExtension<SweatColors> {
  const SweatColors({
    required this.canvas,
    required this.surfaceAlt,
    required this.outlineStrong,
    required this.champagne,
    required this.onChampagne,
  });

  /// The app background, distinct from [ColorScheme.surface] (cards sit
  /// *above* this).
  final Color canvas;

  /// One step above a card: chips, inputs, inactive tracks.
  final Color surfaceAlt;

  /// Borders that carry meaning and so must clear 3:1 against the canvas.
  /// [ColorScheme.outline] is the decorative hairline and does not.
  final Color outlineStrong;

  /// The reward colour. A landed roll, a completed set, a streak, the sheen
  /// that sweeps the wheel rim. Never a resting surface, never body text.
  final Color champagne;

  final Color onChampagne;

  static const dark = SweatColors(
    canvas: SweatPalette.canvas,
    surfaceAlt: SweatPalette.surfaceAlt,
    outlineStrong: SweatPalette.outlineStrong,
    champagne: SweatPalette.champagne,
    onChampagne: SweatPalette.inkOnBrand,
  );

  @override
  SweatColors copyWith({
    Color? canvas,
    Color? surfaceAlt,
    Color? outlineStrong,
    Color? champagne,
    Color? onChampagne,
  }) {
    return SweatColors(
      canvas: canvas ?? this.canvas,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      outlineStrong: outlineStrong ?? this.outlineStrong,
      champagne: champagne ?? this.champagne,
      onChampagne: onChampagne ?? this.onChampagne,
    );
  }

  @override
  SweatColors lerp(SweatColors? other, double t) {
    if (other == null) return this;
    return SweatColors(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      outlineStrong: Color.lerp(outlineStrong, other.outlineStrong, t)!,
      champagne: Color.lerp(champagne, other.champagne, t)!,
      onChampagne: Color.lerp(onChampagne, other.onChampagne, t)!,
    );
  }
}
