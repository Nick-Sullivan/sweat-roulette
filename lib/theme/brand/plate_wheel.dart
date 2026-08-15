import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_palette.dart';

/// The plate-wheel: a bumper weight plate that is also a roulette wheel.
///
/// Drawn in code rather than shipped as an asset so there is one source of
/// truth for the in-app logo, every Android icon slot, and — later — the wheel
/// that actually spins. All geometry is expressed as fractions of the radius,
/// so the same numbers hold at 48px and at 512px.
@immutable
class PlateWheelStyle {
  const PlateWheelStyle({
    required this.field,
    required this.wedge,
    required this.accent,
    this.wedges = 12,
    this.wedgeOuter = 0.80,
    this.wedgeInner = 0.54,
    this.hub = 0.28,
    this.hairline = 0.91,
    this.hairlineWidth = 0.05,
    this.cutOut = false,
  });

  /// The disc itself. Transparent for the adaptive-icon foreground, where the
  /// cognac comes from the background layer underneath.
  final Color field;

  /// The wedges cut into the field, and the hub bore.
  final Color wedge;

  /// The champagne hairline on the rim and around the hub — the sheen that the
  /// spin animation will later sweep.
  final Color accent;

  final int wedges;

  /// The segment band, as fractions of the radius.
  ///
  /// Keep it narrow and keep the count high: a wide band of few wedges reads as
  /// spokes on a wagon wheel. What makes it a *roulette* wheel is a ring of
  /// many short segments, and what makes it a *plate* is the solid cognac
  /// outside [wedgeOuter] and inside [wedgeInner]. That outer margin doubles as
  /// the adaptive icon's safe-zone padding.
  final double wedgeOuter;
  final double wedgeInner;

  final double hub;
  final double hairline;
  final double hairlineWidth;

  /// Punches the wedges and hub through to transparency instead of painting
  /// them. Used for the Android 13+ themed-icon layer, which is a silhouette
  /// the system tints itself.
  final bool cutOut;

  /// The full mark: cognac disc, graphite wedges, champagne hairline.
  static const mark = PlateWheelStyle(
    field: SweatPalette.cognac,
    wedge: SweatPalette.canvas,
    accent: SweatPalette.champagne,
  );

  /// The adaptive-icon foreground. No field — the launcher composites this over
  /// a flat cognac background layer, so painting one here would just hide it.
  static const iconForeground = PlateWheelStyle(
    field: Color(0x00000000),
    wedge: SweatPalette.canvas,
    accent: SweatPalette.champagne,
  );

  /// The themed-icon silhouette: solid disc, everything else punched out.
  static const monochrome = PlateWheelStyle(
    field: Color(0xFFFFFFFF),
    wedge: Color(0x00000000),
    accent: Color(0xFFFFFFFF),
    cutOut: true,
  );

  @override
  bool operator ==(Object other) =>
      other is PlateWheelStyle &&
      other.field == field &&
      other.wedge == wedge &&
      other.accent == accent &&
      other.wedges == wedges &&
      other.wedgeOuter == wedgeOuter &&
      other.wedgeInner == wedgeInner &&
      other.hub == hub &&
      other.hairline == hairline &&
      other.hairlineWidth == hairlineWidth &&
      other.cutOut == cutOut;

  @override
  int get hashCode => Object.hash(
    field,
    wedge,
    accent,
    wedges,
    wedgeOuter,
    wedgeInner,
    hub,
    hairline,
    hairlineWidth,
    cutOut,
  );

  PlateWheelStyle copyWith({int? wedges, Color? field}) {
    return PlateWheelStyle(
      field: field ?? this.field,
      wedge: wedge,
      accent: accent,
      wedges: wedges ?? this.wedges,
      wedgeOuter: wedgeOuter,
      wedgeInner: wedgeInner,
      hub: hub,
      hairline: hairline,
      hairlineWidth: hairlineWidth,
      cutOut: cutOut,
    );
  }
}

class PlateWheelPainter extends CustomPainter {
  const PlateWheelPainter({this.style = PlateWheelStyle.mark, this.rotation = 0});

  final PlateWheelStyle style;

  /// Radians. The mark is drawn with a wedge centred on top at zero, so the
  /// silhouette is symmetric about the vertical axis when it is at rest.
  final double rotation;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.shortestSide / 2;
    final centre = size.center(Offset.zero);
    final bounds = Rect.fromCircle(center: centre, radius: radius);

    // Cutting to transparency only works against a layer of its own; without
    // this the clear blend would punch through whatever is already on screen.
    if (style.cutOut) canvas.saveLayer(bounds, Paint());

    canvas.drawCircle(centre, radius, Paint()..color = style.field);

    _paintWedges(canvas, centre, radius);

    final accent = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * style.hairlineWidth
      ..color = style.accent
      ..isAntiAlias = true;
    canvas.drawCircle(centre, radius * style.hairline, accent);

    // The bore. A plate has a hole; a wheel has a hub. Same circle.
    canvas.drawCircle(centre, radius * style.hub, _fill(style.wedge));
    canvas.drawCircle(centre, radius * style.hub, accent);

    if (style.cutOut) canvas.restore();
  }

  void _paintWedges(Canvas canvas, Offset centre, double radius) {
    // An annulus sector is just a very thick arc — cheaper and more robust
    // than building the four-cornered path by hand.
    final band = (style.wedgeOuter - style.wedgeInner) * radius;
    final mid = (style.wedgeOuter + style.wedgeInner) / 2 * radius;
    final paint = _fill(style.wedge)
      ..style = PaintingStyle.stroke
      ..strokeWidth = band;

    final period = 2 * math.pi / style.wedges;
    final sweep = period / 2;
    // Centre the first wedge on twelve o'clock.
    final start = -math.pi / 2 - sweep / 2 + rotation;

    for (var i = 0; i < style.wedges; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: mid),
        start + i * period,
        sweep,
        false,
        paint,
      );
    }
  }

  Paint _fill(Color color) {
    final paint = Paint()..isAntiAlias = true;
    if (style.cutOut) {
      paint.blendMode = BlendMode.clear;
    } else {
      paint.color = color;
    }
    return paint;
  }

  @override
  bool shouldRepaint(PlateWheelPainter old) =>
      old.rotation != rotation || old.style != style;
}

/// The mark as a widget. [rotation] is here from the start so the spin
/// animation can drive it without the geometry changing.
class PlateWheel extends StatelessWidget {
  const PlateWheel({
    super.key,
    this.size = 40,
    this.rotation = 0,
    this.style = PlateWheelStyle.mark,
  });

  final double size;
  final double rotation;
  final PlateWheelStyle style;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: PlateWheelPainter(style: style, rotation: rotation),
    );
  }
}
