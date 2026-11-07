import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phone sizes (logical pixels) every stabilization batch is checked at:
/// small, the Redmi 8 class, the Figma frame width and a large phone.
const phoneViewports = <String, Size>{
  '320x640': Size(320, 640),
  '360x740': Size(360, 740),
  '390x844': Size(390, 844),
  '430x932': Size(430, 932),
};

/// Sets the test window to [size] logical pixels at a phone pixel ratio
/// and restores it when the test ends.
void useViewport(WidgetTester tester, Size size, {double ratio = 2}) {
  tester.view
    ..physicalSize = size * ratio
    ..devicePixelRatio = ratio;
  addTearDown(tester.view.reset);
}

/// Simulates the software keyboard covering [height] logical pixels.
void showKeyboard(WidgetTester tester, double height, {double ratio = 2}) {
  tester.view.viewInsets = FakeViewPadding(bottom: height * ratio);
  addTearDown(tester.view.resetViewInsets);
}

bool _fontsLoaded = false;

/// Loads the app's real fonts (Inter, Plus Jakarta Sans) and the Material
/// icon font, so text widths in layout tests and screenshots match a
/// device instead of the square test font.
Future<void> loadAppFonts() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  Future<void> family(String name, List<String> assets) async {
    final loader = FontLoader(name);
    for (final a in assets) {
      loader.addFont(rootBundle.load(a));
    }
    await loader.load();
  }

  await family('Inter', [
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold'])
      'assets/fonts/inter/Inter-$w.ttf',
  ]);
  await family('PlusJakartaSans', [
    for (final w in ['Medium', 'SemiBold', 'Bold'])
      'assets/fonts/plus_jakarta_sans/PlusJakartaSans-$w.ttf',
  ]);
  final root = Platform.environment['FLUTTER_ROOT'];
  final icons = root == null
      ? null
      : File(
          '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        );
  if (icons != null && icons.existsSync()) {
    final bytes = icons.readAsBytesSync();
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
}

/// Writes a PNG of the whole window to `$SCREENSHOT_DIR/<name>.png` when
/// that variable is set (manual visual review against Figma); a no-op in
/// normal and CI runs.
Future<void> screenshot(WidgetTester tester, String name) async {
  final dir = Platform.environment['SCREENSHOT_DIR'];
  if (dir == null || dir.isEmpty) return;
  final view = tester.binding.renderViews.first;
  final layer = view.debugLayer! as OffsetLayer;
  // The root layer already carries the device pixel ratio transform.
  final size = tester.view.physicalSize;
  await tester.runAsync(() async {
    final image = await layer.toImage(Offset.zero & size);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
  });
}
