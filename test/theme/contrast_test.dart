import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweat_roulette/theme/app_colors.dart';
import 'package:sweat_roulette/theme/app_theme.dart';

/// Makes the colour rules enforceable rather than aspirational: every pairing
/// the design system actually uses is checked against WCAG 2.1 here, so
/// retuning a token can't quietly make something unreadable.
///
/// Thresholds are WCAG AA: 4.5:1 for body text, 3:1 for large text (≥18.66px
/// bold or ≥24px) and for UI components such as interactive borders.
///
/// Both brand colours sit mid-value on purpose, which caps how much contrast
/// anything on top of them can reach — [SweatPalette.cognac] can't clear 4.5:1
/// against *any* foreground. That's why nothing small ever sits on cognac:
/// button labels are 17px semibold and up.
void main() {
  const scheme = SweatTheme.colorScheme;
  const sweat = SweatColors.dark;

  group('body text — 4.5:1', () {
    final pairs = <String, (Color, Color)>{
      'onSurface on canvas': (scheme.onSurface, sweat.canvas),
      'onSurface on surface': (scheme.onSurface, scheme.surface),
      'onSurface on surfaceAlt': (scheme.onSurface, sweat.surfaceAlt),
      'onSurfaceVariant on canvas': (scheme.onSurfaceVariant, sweat.canvas),
      'onSurfaceVariant on surface': (scheme.onSurfaceVariant, scheme.surface),
      'onSurfaceVariant on surfaceAlt': (
        scheme.onSurfaceVariant,
        sweat.surfaceAlt,
      ),
      'error on canvas': (scheme.error, sweat.canvas),
      'error on surface': (scheme.error, scheme.surface),
      'onPrimaryContainer on primaryContainer': (
        scheme.onPrimaryContainer,
        scheme.primaryContainer,
      ),
      'onErrorContainer on errorContainer': (
        scheme.onErrorContainer,
        scheme.errorContainer,
      ),
      'champagne on canvas': (sweat.champagne, sweat.canvas),
      'champagne on surface': (sweat.champagne, scheme.surface),
    };

    pairs.forEach((name, pair) {
      test(
        name,
        () => expect(_ratio(pair.$1, pair.$2), greaterThanOrEqualTo(4.5)),
      );
    });
  });

  group('large text and UI — 3:1', () {
    final pairs = <String, (Color, Color)>{
      // Button labels (17px semibold and up) on the brand fills.
      'onPrimary on primary': (scheme.onPrimary, scheme.primary),
      'onSecondary on champagne': (scheme.onSecondary, sweat.champagne),
      // Outlined buttons: cognac border *and* cognac label on the canvas.
      'primary on canvas': (scheme.primary, sweat.canvas),
      'primary on surface': (scheme.primary, scheme.surface),
      // Interactive borders.
      'outlineStrong on canvas': (sweat.outlineStrong, sweat.canvas),
      'outlineStrong on surface': (sweat.outlineStrong, scheme.surface),
      // The search field's focused border, read against the fill it encloses
      // rather than the canvas outside it. Hint text needs no entry of its own:
      // it is `onSurfaceVariant on surfaceAlt`, already covered above at 4.5:1.
      'outlineStrong on surfaceAlt': (sweat.outlineStrong, sweat.surfaceAlt),
    };

    pairs.forEach((name, pair) {
      test(
        name,
        () => expect(_ratio(pair.$1, pair.$2), greaterThanOrEqualTo(3.0)),
      );
    });
  });

  test('layers are separable by value alone', () {
    // The whole system is flat — no shadows, no elevation overlays — so each
    // step of the ramp has to be visible on its own.
    final ramp = [sweat.canvas, scheme.surface, sweat.surfaceAlt];
    for (var i = 1; i < ramp.length; i++) {
      expect(
        _luminance(ramp[i]),
        greaterThan(_luminance(ramp[i - 1]) * 1.4),
        reason: 'layer $i is too close in value to layer ${i - 1}',
      );
    }
  });
}

double _ratio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

/// WCAG 2.1 relative luminance. Flutter's own [Color.computeLuminance] does
/// exactly this, but spelling it out keeps the test independent of the thing
/// it's checking.
double _luminance(Color c) =>
    0.2126 * _linear(c.r) + 0.7152 * _linear(c.g) + 0.0722 * _linear(c.b);

double _linear(double channel) => channel <= 0.03928
    ? channel / 12.92
    : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
