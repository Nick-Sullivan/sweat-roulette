import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweat_roulette/theme/app_palette.dart';
import 'package:sweat_roulette/theme/brand/plate_wheel.dart';

/// Rasterises the plate-wheel into every icon slot Android and Play want.
///
///     flutter test tool/generate_icons.dart
///
/// It lives outside `test/` on purpose: `flutter test` only walks `test/`, so
/// CI never runs it and never writes files into a checkout. Flutter is the
/// rasteriser here — no ImageMagick, no Inkscape, no binary design file.
///
/// Re-run it after any change to `PlateWheelStyle` or the palette; the PNGs are
/// build output that happens to be committed.
void main() {
  // A plain `test`, not `testWidgets`: `Picture.toImage` needs the real event
  // loop, and inside `testWidgets` the fake-async clock deadlocks it.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generate launcher, splash and store icons', () async {
    // mdpi is the 1x baseline; every other bucket is a multiple of it.
    const densities = <String, double>{
      'mdpi': 1,
      'hdpi': 1.5,
      'xhdpi': 2,
      'xxhdpi': 3,
      'xxxhdpi': 4,
    };

    for (final MapEntry(key: bucket, value: scale) in densities.entries) {
      final mipmap = 'android/app/src/main/res/mipmap-$bucket';
      final drawable = 'android/app/src/main/res/drawable-$bucket';

      // Legacy launcher icon: the finished disc on transparency, so launchers
      // that apply no mask still get a deliberate round icon.
      await _write(
        '$mipmap/ic_launcher.png',
        await _render(
          _px(48, scale),
          _px(48, scale),
          (canvas, size) => _wheel(canvas, size, PlateWheelStyle.mark, 0.98),
        ),
      );

      // Adaptive foreground on the 108dp canvas. The mark is drawn at 66dp so
      // it clears every mask shape the launcher might apply, and carries no
      // field of its own — the cognac comes from the background layer.
      await _write(
        '$mipmap/ic_launcher_foreground.png',
        await _render(
          _px(108, scale),
          _px(108, scale),
          (canvas, size) =>
              _wheel(canvas, size, PlateWheelStyle.iconForeground, 66 / 108),
        ),
      );

      // Themed icon (Android 13+): a silhouette the system tints itself.
      await _write(
        '$mipmap/ic_launcher_monochrome.png',
        await _render(
          _px(108, scale),
          _px(108, scale),
          (canvas, size) =>
              _wheel(canvas, size, PlateWheelStyle.monochrome, 66 / 108),
        ),
      );

      // Launch screen: mark only, centred on graphite by the layer-list.
      await _write(
        '$drawable/splash_logo.png',
        await _render(
          _px(96, scale),
          _px(96, scale),
          (canvas, size) => _wheel(canvas, size, PlateWheelStyle.mark, 1),
        ),
      );
    }

    // Play listing icon. Opaque graphite ground: Play composites the icon onto
    // its own surfaces and transparency there is a coin toss.
    await _write(
      'store/play_icon_512.png',
      await _render(512, 512, (canvas, size) {
        _ground(canvas, size);
        _wheel(canvas, size, PlateWheelStyle.mark, 0.76);
      }),
    );

    await _write('store/feature_graphic.png', await _featureGraphic());
  });
}

int _px(double dp, double scale) => (dp * scale).round();

/// Draws the mark centred, occupying [fraction] of the shorter side.
void _wheel(Canvas canvas, Size size, PlateWheelStyle style, double fraction) {
  final diameter = size.shortestSide * fraction;
  final origin = Offset(
    (size.width - diameter) / 2,
    (size.height - diameter) / 2,
  );

  canvas.save();
  canvas.translate(origin.dx, origin.dy);
  PlateWheelPainter(style: style).paint(canvas, Size.square(diameter));
  canvas.restore();
}

void _ground(Canvas canvas, Size size) {
  canvas.drawRect(
    Offset.zero & size,
    Paint()..color = SweatPalette.canvas,
  );
}

Future<Uint8List> _render(
  int width,
  int height,
  void Function(Canvas canvas, Size size) draw,
) async {
  final recorder = ui.PictureRecorder();
  final size = Size(width.toDouble(), height.toDouble());
  draw(Canvas(recorder, Offset.zero & size), size);

  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  picture.dispose();
  image.dispose();
  return data!.buffer.asUint8List();
}

/// 1024×500 for the Play listing: mark on the left, wordmark on the right.
Future<Uint8List> _featureGraphic() async {
  // Bundled fonts are not registered in the test environment, so Bebas has to
  // be loaded by hand or the wordmark silently falls back to the test font.
  final bebas = FontLoader('BebasNeue')
    ..addFont(
      File(
        'assets/fonts/BebasNeue-Regular.ttf',
      ).readAsBytes().then((bytes) => bytes.buffer.asByteData()),
    );
  await bebas.load();

  return _render(1024, 500, (canvas, size) {
    _ground(canvas, size);

    const markSize = 240.0;
    const gap = 64.0;
    const margin = 64.0;

    // Lay the wordmark out before deciding where anything goes, and shrink it
    // to fit rather than letting it run off the canvas — Play rejects a feature
    // graphic with clipped text, and at 1024px wide there is no room to spare.
    final available = size.width - margin * 2 - markSize - gap;
    var wordmark = _wordmark(92);
    if (wordmark.width > available) {
      wordmark = _wordmark(92 * available / wordmark.width);
    }

    // Centre the lockup as a unit.
    final left = (size.width - (markSize + gap + wordmark.width)) / 2;

    canvas.save();
    canvas.translate(left, (size.height - markSize) / 2);
    PlateWheelPainter().paint(canvas, const Size.square(markSize));
    canvas.restore();

    wordmark.paint(
      canvas,
      Offset(left + markSize + gap, (size.height - wordmark.height) / 2),
    );
  });
}

TextPainter _wordmark(double fontSize) {
  return TextPainter(
    text: TextSpan(
      text: 'SWEAT ROULETTE',
      style: TextStyle(
        fontFamily: 'BebasNeue',
        fontSize: fontSize,
        // Tracking scales with the size so the lockup keeps its proportions
        // when it shrinks to fit.
        letterSpacing: fontSize * 0.13,
        color: SweatPalette.inkHigh,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
}

Future<void> _write(String path, Uint8List bytes) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes);
  // ignore: avoid_print — this is a CLI tool; the listing is the point.
  print('wrote $path (${(bytes.length / 1024).toStringAsFixed(1)}KB)');
}
