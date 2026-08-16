import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweat_roulette/theme/brand/plate_wheel.dart';

/// The mark is generated code, so the things that could quietly break it are
/// checked here rather than by squinting at a 48px PNG.
///
/// A plain `test`, not `testWidgets`: `Picture.toImage` needs the real event
/// loop, and the fake-async clock inside `testWidgets` deadlocks it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the mark survives 48px — the smallest launcher bucket', () async {
    final pixels = await _rasterise(PlateWheelStyle.mark, 48);

    // Cognac field, graphite wedges, champagne hairline: if the band collapses
    // at this size, the palette collapses with it.
    final colours = pixels.map((p) => p & 0xFFFFFF).toSet();
    expect(colours.length, greaterThan(3), reason: 'the mark rendered flat');
  });

  test('the mark is symmetric about the vertical axis', () async {
    // A wedge is centred on twelve o'clock at rest, so the silhouette mirrors.
    // This catches an off-by-half-a-period in the wedge start angle, which is
    // otherwise invisible until the thing is spinning.
    const size = 96;
    final pixels = await _rasterise(PlateWheelStyle.mark, size);

    var mismatches = 0;
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size ~/ 2; x++) {
        final delta = _worstChannelDelta(
          pixels[y * size + x],
          pixels[y * size + (size - 1 - x)],
        );
        if (delta > 8) mismatches++;
      }
    }

    // Antialiasing along the tessellated arc edges leaves a handful of pixels
    // off by ~16/255, so this can't demand exactness. A half-period error in
    // the start angle mismatches thousands, not a handful.
    const compared = size * size ~/ 2;
    expect(
      mismatches,
      lessThan(compared ~/ 200),
      reason: '$mismatches of $compared mirrored pixels differ',
    );
  });

  test('the themed-icon layer really is punched through', () async {
    // Transparent and white are indistinguishable in any image viewer, so the
    // only way to know the clear blend worked is to read the alpha channel.
    const size = 108;
    final pixels = await _rasterise(PlateWheelStyle.monochrome, size);

    final alphas = pixels.map((p) => (p >> 24) & 0xFF);
    expect(
      alphas.any((a) => a == 0),
      isTrue,
      reason: 'nothing was cut out — the silhouette is a solid disc',
    );
    expect(alphas.any((a) => a == 255), isTrue, reason: 'nothing was drawn');

    // The bore sits dead centre and must be one of the holes.
    expect((pixels[(size ~/ 2) * size + size ~/ 2] >> 24) & 0xFF, 0);
  });
}

/// Returns the image as packed ARGB pixels.
Future<List<int>> _rasterise(PlateWheelStyle style, int size) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Offset.zero & Size.square(size.toDouble()));
  PlateWheelPainter(style: style).paint(canvas, Size.square(size.toDouble()));

  final image = await recorder.endRecording().toImage(size, size);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawUnmodified);
  image.dispose();

  final bytes = data!.buffer.asUint8List();
  return [
    for (var i = 0; i < bytes.length; i += 4)
      (bytes[i + 3] << 24) |
          (bytes[i] << 16) |
          (bytes[i + 1] << 8) |
          bytes[i + 2],
  ];
}

/// Antialiasing makes mirrored pixels near-but-not-exactly equal.
int _worstChannelDelta(int a, int b) {
  var worst = 0;
  for (var shift = 0; shift <= 24; shift += 8) {
    final delta = (((a >> shift) & 0xFF) - ((b >> shift) & 0xFF)).abs();
    if (delta > worst) worst = delta;
  }
  return worst;
}
