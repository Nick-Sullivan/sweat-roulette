import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Both faces are bundled under `assets/fonts/` rather than fetched at runtime
/// — VISION.md says the phone is the only source of truth, and that has to
/// include the UI.

/// Bebas Neue. Caps-only, one weight, tall and condensed — gym signage and
/// casino board in the same breath.
///
/// Two consequences worth knowing before using it anywhere new:
/// lowercase input renders as capitals whatever you type, and there is no bold,
/// so emphasis has to come from size, colour or tracking.
const _display = 'BebasNeue';

/// Chivo carries everything Bebas can't: body copy at length, mixed-case
/// titles, small labels. A grotesque with enough character not to read as
/// system default, and four weights to work with.
const _text = 'Chivo';

/// Display type is set noticeably larger than its Chivo counterpart would be —
/// Bebas is condensed, so at matched point sizes it occupies far less of the
/// line and reads as smaller than it is.
abstract final class SweatTypography {
  static const textTheme = TextTheme(
    // The rolled exercise name — the thing you look at from three feet away.
    displayLarge: TextStyle(
      fontFamily: _display,
      fontSize: 52,
      fontWeight: FontWeight.w400,
      letterSpacing: 1.0,
      height: 1.0,
    ),
    displayMedium: TextStyle(
      fontFamily: _display,
      fontSize: 40,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.8,
      height: 1.02,
    ),
    displaySmall: TextStyle(
      fontFamily: _display,
      fontSize: 32,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.6,
      height: 1.05,
    ),
    headlineMedium: TextStyle(
      fontFamily: _display,
      fontSize: 26,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.5,
      height: 1.1,
    ),

    // Titles are mixed-case UI furniture, so they stay in Chivo — Bebas would
    // shout every list row.
    titleLarge: TextStyle(
      fontFamily: _text,
      fontSize: 19,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.1,
      height: 1.25,
    ),
    titleMedium: TextStyle(
      fontFamily: _text,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.1,
      height: 1.3,
    ),

    bodyLarge: TextStyle(
      fontFamily: _text,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.45,
    ),
    bodyMedium: TextStyle(
      fontFamily: _text,
      fontSize: 15,
      fontWeight: FontWeight.w400,
      height: 1.45,
    ),
    bodySmall: TextStyle(
      fontFamily: _text,
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 1.4,
    ),

    // Button labels are Bebas: caps read faster at a glance, and condensed
    // letterforms keep a long label inside a big soft target.
    labelLarge: TextStyle(
      fontFamily: _display,
      fontSize: 21,
      fontWeight: FontWeight.w400,
      letterSpacing: 2.0,
      height: 1.0,
    ),
    // Smaller labels stay in Chivo — Bebas gets illegible below ~16px.
    labelMedium: TextStyle(
      fontFamily: _text,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 1.2,
    ),
    labelSmall: TextStyle(
      fontFamily: _text,
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 1.4,
    ),
  );
}

/// The styles that don't map onto a Material [TextTheme] slot.
///
/// Read through `context.sweatText`.
@immutable
class SweatTextStyles extends ThemeExtension<SweatTextStyles> {
  const SweatTextStyles({
    required this.wordmark,
    required this.sectionLabel,
    required this.metric,
    required this.metricSmall,
    required this.metricUnit,
    required this.metricUnitSmall,
  });

  /// "SWEAT ROULETTE" — Bebas, widely tracked.
  final TextStyle wordmark;

  /// Small uppercase label above a group of content.
  final TextStyle sectionLabel;

  /// Big numbers: weight, reps, sets. Tabular figures so the digits don't
  /// jitter as the value counts up.
  final TextStyle metric;

  final TextStyle metricSmall;

  /// The unit that trails a metric — `kg`, `reps`, `min`. Chivo, not Bebas:
  /// Bebas would render it `KG`, and a shouted unit competes with the number
  /// it is supposed to be qualifying. Small and dimmed so the digits stay the
  /// thing you read from across the gym.
  ///
  /// Sits in the same paragraph as the value, so the two share a baseline —
  /// see [MetricText].
  final TextStyle metricUnit;

  final TextStyle metricUnitSmall;

  static const _tabular = [FontFeature.tabularFigures()];

  static const dark = SweatTextStyles(
    wordmark: TextStyle(
      fontFamily: _display,
      fontSize: 26,
      fontWeight: FontWeight.w400,
      letterSpacing: 5.0,
      color: SweatPalette.inkHigh,
    ),
    sectionLabel: TextStyle(
      fontFamily: _text,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 2.0,
      color: SweatPalette.inkLow,
    ),
    metric: TextStyle(
      fontFamily: _display,
      fontSize: 46,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.5,
      height: 1.0,
      fontFeatures: _tabular,
      color: SweatPalette.inkHigh,
    ),
    metricSmall: TextStyle(
      fontFamily: _display,
      fontSize: 24,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.4,
      height: 1.05,
      fontFeatures: _tabular,
      color: SweatPalette.inkHigh,
    ),
    metricUnit: TextStyle(
      fontFamily: _text,
      fontSize: 17,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.2,
      color: SweatPalette.inkLow,
    ),
    metricUnitSmall: TextStyle(
      fontFamily: _text,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.2,
      color: SweatPalette.inkLow,
    ),
  );

  @override
  SweatTextStyles copyWith({
    TextStyle? wordmark,
    TextStyle? sectionLabel,
    TextStyle? metric,
    TextStyle? metricSmall,
    TextStyle? metricUnit,
    TextStyle? metricUnitSmall,
  }) {
    return SweatTextStyles(
      wordmark: wordmark ?? this.wordmark,
      sectionLabel: sectionLabel ?? this.sectionLabel,
      metric: metric ?? this.metric,
      metricSmall: metricSmall ?? this.metricSmall,
      metricUnit: metricUnit ?? this.metricUnit,
      metricUnitSmall: metricUnitSmall ?? this.metricUnitSmall,
    );
  }

  @override
  SweatTextStyles lerp(SweatTextStyles? other, double t) {
    if (other == null) return this;
    return SweatTextStyles(
      wordmark: TextStyle.lerp(wordmark, other.wordmark, t)!,
      sectionLabel: TextStyle.lerp(sectionLabel, other.sectionLabel, t)!,
      metric: TextStyle.lerp(metric, other.metric, t)!,
      metricSmall: TextStyle.lerp(metricSmall, other.metricSmall, t)!,
      metricUnit: TextStyle.lerp(metricUnit, other.metricUnit, t)!,
      metricUnitSmall: TextStyle.lerp(
        metricUnitSmall,
        other.metricUnitSmall,
        t,
      )!,
    );
  }
}

/// A number and its unit: Bebas digits, Chivo unit, one shared baseline.
///
/// Always use this rather than hand-rolling `'$value kg'` in a display style —
/// Bebas has no lowercase, so a unit typed into the value string comes out as
/// `87.5 KG`.
class MetricText extends StatelessWidget {
  const MetricText(this.value, {this.unit, this.small = false, this.color, super.key});

  final String value;
  final String? unit;

  /// Uses the [SweatTextStyles.metricSmall] pairing — for list rows and chips
  /// rather than the one number a screen is built around.
  final bool small;

  /// Overrides the value's colour; the unit stays dimmed relative to it.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final styles = Theme.of(context).extension<SweatTextStyles>()!;
    final valueStyle = small ? styles.metricSmall : styles.metric;
    final unitStyle = small ? styles.metricUnitSmall : styles.metricUnit;

    return Text.rich(
      TextSpan(
        text: value,
        style: color == null ? valueStyle : valueStyle.copyWith(color: color),
        children: [
          if (unit != null)
            // The space lives in the unit span so it takes Chivo's narrower
            // word space rather than Bebas's.
            TextSpan(text: ' ${unit!}', style: unitStyle),
        ],
      ),
    );
  }
}
