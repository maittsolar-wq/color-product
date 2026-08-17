// PASS 4.2 — the white 800x800 artwork sheet must move/scale as ONE object
// with the line art and user paint under Pan/Zoom, never as an
// independently-fixed background painted by the outer Editor container.
//
// This drives the REAL widget tree end-to-end (EditorScreen -> the actual
// Listener gesture area -> EditorController -> EditorPainter), captured via
// a root RepaintBoundary, and samples actual rendered pixels before/after a
// real hold-then-drag gesture -- not just controller field assertions --
// because the PASS 4.2 bug was specifically a compositing/occlusion issue
// (an opaque widget-tree Container painting its own fixed white behind the
// already-correctly-transformed canvas content) that field-level assertions
// alone would never have caught.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:color_pop/core/app_data.dart';
import 'package:color_pop/features/editor/editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePathProviderPlatform extends PathProviderPlatform with MockPlatformInterfaceMixin {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    final dir = await Directory.systemTemp.createTemp('color_pop_surface_test_docs_');
    return dir.path;
  }
}

Future<ui.Image> _captureRoot(GlobalKey key) async {
  final renderObject = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return renderObject.toImage(pixelRatio: 1.0);
}

bool _closeTo(int a, int b, {int tolerance = 3}) => (a - b).abs() <= tolerance;

void main() {
  setUpAll(() async {
    PathProviderPlatform.instance = _FakePathProviderPlatform();
    await AppData.lessonRepository.load();
    await AppData.progressRepository.init();
  });

  testWidgets('the white artwork sheet, not just the line art, moves with one-finger Pan', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final rootKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: rootKey,
        child: const MaterialApp(home: EditorScreen(lessonId: 'food_happydonuts')),
      ),
    );

    // Let the lesson artwork finish decoding (rootBundle + dart:ui codec).
    await tester.runAsync(() async {
      for (var i = 0; i < 150; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
        if (find.byKey(const Key('artboard-gesture-area')).evaluate().isNotEmpty) break;
      }
    });
    await tester.pump();

    final artboardRect = tester.getRect(find.byKey(const Key('artboard-gesture-area')));
    // A probe point inside the LEFT edge -- at rest this must be the white
    // artwork sheet (which covers the whole artboard at scale 1 / offset
    // zero), never the workspace background. Placed 40px in (comfortably
    // past the frame's ~20px shadow blur radius) and well short of the
    // 150px rightward drag below, so after panning it sits ~110px clear of
    // BOTH the shadow and the sheet's new edge -- a clean grey reading
    // rather than a shadow-blended one.
    final probe = Offset(artboardRect.left + 40, artboardRect.center.dy);

    // toImage()/toByteData() are real engine round-trips (like the asset
    // decode above), not Timer-based -- they never resolve on the fake test
    // clock alone and must run inside runAsync, with pump() interleaved.
    Future<ui.Color> sampleAt(Offset point) async {
      late ui.Color result;
      await tester.runAsync(() async {
        final image = await _captureRoot(rootKey);
        final byteData = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        final bytes = byteData.buffer.asUint8List();
        final x = point.dx.round().clamp(0, image.width - 1);
        final y = point.dy.round().clamp(0, image.height - 1);
        final idx = (y * image.width + x) * 4;
        result = ui.Color.fromARGB(255, bytes[idx], bytes[idx + 1], bytes[idx + 2]);
        image.dispose();
      });
      return result;
    }

    final before = await sampleAt(probe);
    expect(before.toARGB32(), 0xFFFFFFFF, reason: 'at rest, the artboard edge is the white artwork sheet');

    // A real hold-then-drag-right gesture through the ACTUAL Listener --
    // exactly the shape of a physical one-finger Pan.
    final gesture = await tester.startGesture(artboardRect.center);
    await tester.pump(const Duration(milliseconds: 260)); // hold past the delay -> Pan
    await gesture.moveBy(const Offset(150, 0)); // drag right
    await tester.pump();
    await gesture.up();
    await tester.pump();

    final after = await sampleAt(probe);
    // The Scaffold's workspace background (0xFFF1F1F1) must now show
    // through where the sheet moved away from -- if this point were STILL
    // white, that would mean an independent, non-transformed white behind
    // the artwork is masking the pan (the PASS 4.2 bug).
    expect(after.toARGB32(), isNot(0xFFFFFFFF), reason: 'after panning right, this point must no longer be the (moved-away) white sheet');
    final afterR = (after.r * 255).round();
    final afterG = (after.g * 255).round();
    final afterB = (after.b * 255).round();
    // Expect the workspace grey (0xF1) blended with the frame's own
    // BoxShadow (0x14000000 -- ~8% black), which reaches slightly inside
    // the frame edge due to its blur radius: 0xF1*(1-20/255) ≈ 222 (0xDE).
    // A wide tolerance covers that blend without accepting an unrelated
    // color (e.g. pure white, or the purple/line-art content, which would
    // indicate an actual bug rather than expected shadow blending).
    expect(_closeTo(afterR, 0xDE, tolerance: 20) && _closeTo(afterG, 0xDE, tolerance: 20) && _closeTo(afterB, 0xDE, tolerance: 20), isTrue,
        reason: 'the revealed pixel should be the workspace grey (shadow-blended), confirming the container has no independent white fill '
            '-- got r=$afterR g=$afterG b=$afterB');
  });
}
