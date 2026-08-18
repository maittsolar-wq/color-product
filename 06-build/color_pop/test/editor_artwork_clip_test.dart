// PASS 6.3 — user paint must never visually render outside the source
// 800x800 artwork rect, and that clip boundary must move/scale WITH the
// artwork under Zoom/Pan (never a fixed screen-position clip). This test
// deliberately paints a wide Brush stroke whose recorded path point sits
// exactly at the artwork's right edge (x=800) with maximum brush width, so
// its rounded stroke cap mathematically extends ~32 artwork units past the
// edge -- exactly the "Brush radius extends beyond source rect" scenario
// the fix targets. It samples a fixed on-screen point just past that edge
// BEFORE zoom, pinch-zooms centered exactly on the edge point (so the edge
// itself stays under that same screen position -- already proven by
// zoom_pan_test.dart's own focal-preservation check), then re-samples the
// SAME screen point, and finally pans the artwork and re-samples at the
// edge's new screen position -- in all three cases nothing must be painted
// there, proving the clip is transform-agnostic, not a one-time visual
// coincidence at 1x.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:color_pop/core/app_data.dart';
import 'package:color_pop/core/constants.dart';
import 'package:color_pop/features/editor/artwork_coordinates.dart';
import 'package:color_pop/features/editor/editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePathProviderPlatform extends PathProviderPlatform with MockPlatformInterfaceMixin {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    final dir = await Directory.systemTemp.createTemp('color_pop_artwork_clip_test_docs_');
    return dir.path;
  }
}

const _brushColor = Color(0xFF168B2D); // green -- matches the reported-bug screenshot's color

void main() {
  setUpAll(() async {
    PathProviderPlatform.instance = _FakePathProviderPlatform();
    await AppData.lessonRepository.load();
    await AppData.progressRepository.init();
  });

  testWidgets('user paint never renders outside the 800x800 artwork rect, at 1x, zoomed, and after Pan', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final rootKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: rootKey,
        child: MaterialApp(home: EditorScreen(lessonId: 'animal_babydeer', onOpenEditor: (_) {}, onBackToHome: () {})),
      ),
    );

    await tester.runAsync(() async {
      for (var i = 0; i < 150; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
        if (find.byKey(const Key('artboard-gesture-area')).evaluate().isNotEmpty) break;
      }
    });
    await tester.pump();

    // Unlock -- free-draw across the white background near the edge, not
    // constrained to a closed line-art region (§5 of the fix: Unlock must
    // still be able to paint anywhere inside the sheet, right up to it).
    await tester.tap(find.byKey(const Key('lock-toggle')));
    await tester.pump();

    // Max brush width -- the widest possible cap overshoot for an
    // unambiguous test margin.
    await tester.drag(find.byType(Slider), const Offset(1000, 0));
    await tester.pump();

    final artboardRect = tester.getRect(find.byKey(const Key('artboard-gesture-area')));
    Offset screenPointFor(Offset artworkPoint, {required Offset viewOffset, required double viewScale}) {
      final fit = baseFitScale(artboardRect.size);
      return artboardRect.topLeft + viewOffset + artworkPoint * (viewScale * fit);
    }

    final fit = baseFitScale(artboardRect.size);
    final rendered = kArtworkSize * fit;
    final initialOffset = Offset((artboardRect.width - rendered) / 2, (artboardRect.height - rendered) / 2);

    // The exact right edge of the source artwork, and a point comfortably
    // inside it to drag from.
    const edgeArtworkPoint = Offset(800, 400);
    const insideArtworkPoint = Offset(600, 400);
    final edgeScreenPoint = screenPointFor(edgeArtworkPoint, viewOffset: initialOffset, viewScale: 1.0);
    final insideScreenPoint = screenPointFor(insideArtworkPoint, viewOffset: initialOffset, viewScale: 1.0);

    Future<Color> sampleAt(Offset point) async {
      late Color result;
      await tester.runAsync(() async {
        final renderObject = rootKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await renderObject.toImage(pixelRatio: 1.0);
        final byteData = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        final bytes = byteData.buffer.asUint8List();
        final x = point.dx.round().clamp(0, image.width - 1);
        final y = point.dy.round().clamp(0, image.height - 1);
        final idx = (y * image.width + x) * 4;
        result = Color.fromARGB(255, bytes[idx], bytes[idx + 1], bytes[idx + 2]);
        image.dispose();
      });
      return result;
    }

    // Calibrate the ACTUAL on-screen radius of a max-width Brush dot in
    // THIS layout (rather than trusting a theoretical fit-scale
    // calculation) -- tap well inside the artwork, away from any edge, and
    // measure vertically (unaffected by the edge clip either way) how far
    // the dot's opaque paint actually reaches.
    await tester.tapAt(insideScreenPoint);
    await tester.pump();
    int measuredRadius = 0;
    for (var r = 2; r <= 40; r += 2) {
      final c = await sampleAt(insideScreenPoint + Offset(0, r.toDouble()));
      if (c.toARGB32() != _brushColor.toARGB32()) break;
      measuredRadius = r;
    }
    expect(measuredRadius, greaterThan(4), reason: 'sanity check: a max-width dot must have a real, measurable radius');

    // A point just past the edge, in the grey workspace, at HALF the
    // measured radius -- solidly within where an unclipped dot centered
    // exactly on the edge would paint, but with enough margin from the
    // anti-aliased boundary itself to sample cleanly either way.
    final overshoot = (measuredRadius / 2).clamp(3, 20).toDouble();
    final justOutside = edgeScreenPoint + Offset(overshoot, 0);
    final justInside = edgeScreenPoint - Offset(overshoot, 0);

    final cleanBefore = await sampleAt(justOutside);
    expect(cleanBefore.toARGB32(), isNot(_brushColor.toARGB32()));

    // ---- TEST A (1x): a max-width dot centered exactly ON the edge ----
    await tester.tapAt(edgeScreenPoint);
    await tester.pump();

    // Sanity: the dot actually painted (just inside the edge).
    final paintedInside = await sampleAt(justInside);
    expect(paintedInside.toARGB32(), _brushColor.toARGB32(),
        reason: 'sanity check: the dot must actually be visible just inside the artwork edge');

    // The actual fix under test: a max-width dot centered AT the edge
    // mathematically extends well past x=800 (per the calibration above)
    // -- without the clip, that overshoot would be visible here.
    final clean1x = await sampleAt(justOutside);
    expect(clean1x.toARGB32(), isNot(_brushColor.toARGB32()),
        reason: 'TEST A (1x): a wide Brush dot at the artwork edge must never paint into the grey workspace');
    debugPrint('[TEST] 1x: paint stops exactly at the artwork edge ok');

    // ---- TEST B (zoom): pinch centered EXACTLY on the edge point -- the ----
    // focal point stays under the same screen position through the zoom
    // (already proven by zoom_pan_test.dart), so `justOutside` (a fixed
    // screen offset past that SAME point) must still be outside the sheet
    // at any zoom level, and must still show no leaked paint.
    final g1 = await tester.startGesture(edgeScreenPoint - const Offset(20, 0), pointer: 201);
    final g2 = await tester.startGesture(edgeScreenPoint + const Offset(20, 0), pointer: 202);
    await tester.pump(const Duration(milliseconds: 16));
    for (final t in [0.25, 0.5, 0.75, 1.0]) {
      final half = 20 + t * (100 - 20);
      await g1.moveTo(edgeScreenPoint - Offset(half, 0));
      await g2.moveTo(edgeScreenPoint + Offset(half, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g1.up();
    await g2.up();
    await tester.pump();

    final cleanZoomed = await sampleAt(justOutside);
    expect(cleanZoomed.toARGB32(), isNot(_brushColor.toARGB32()),
        reason: 'TEST B (zoom): zooming must not expose paint that was correctly clipped at 1x -- the clip must scale WITH the artwork');
    debugPrint('[TEST] zoomed (~4x): edge clip still holds, no overflow exposed ok');

    // ---- TEST D (pan): move the artwork, then re-check the EDGE'S NEW ----
    // screen position -- the clip must follow it there, not stay behind at
    // the old centered position.
    const panDelta = Offset(-60, 40);
    final panGesture = await tester.startGesture(artboardRect.center);
    await tester.pump(const Duration(milliseconds: 260)); // hold past the pan-arbitration delay
    await panGesture.moveBy(panDelta);
    await tester.pump();
    await panGesture.up();
    await tester.pump();

    final cleanPanned = await sampleAt(justOutside + panDelta);
    expect(cleanPanned.toARGB32(), isNot(_brushColor.toARGB32()),
        reason: 'TEST D (pan): the clip boundary must move WITH the artwork to its new position, not remain at the old centered one');
    debugPrint('[TEST] panned: edge clip follows the artwork to its new position ok');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
