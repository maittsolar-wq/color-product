// PASS 4.4 — the white 800x800 background, user paint, and line art must
// behave as ONE artwork object under Pan/Zoom: a point's position RELATIVE
// to the artwork must never change, i.e. there must be zero relative
// movement between the background and anything drawn on it.
//
// This places a distinctive Brush mark at a known artwork-space point,
// pans through the REAL gesture pipeline (EditorScreen -> Listener ->
// EditorController -> EditorPainter), and confirms the mark is found at
// exactly the transform-predicted new screen position afterward (not left
// behind at its old position, not drifted anywhere else) -- proving the
// mark and the background it sits on move together as one composited
// surface, not as two independently-transformed layers.
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
    final dir = await Directory.systemTemp.createTemp('color_pop_single_surface_test_docs_');
    return dir.path;
  }
}

void main() {
  setUpAll(() async {
    PathProviderPlatform.instance = _FakePathProviderPlatform();
    await AppData.lessonRepository.load();
    await AppData.progressRepository.init();
  });

  testWidgets('a Brush mark stays locked to the artwork -- moves exactly with Pan, never left behind', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final rootKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: rootKey,
        child: const MaterialApp(home: EditorScreen(lessonId: 'animal_babydeer')),
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

    // Unlock so a Brush dot lands regardless of what artwork-space region it
    // happens to fall in (region validity isn't what this test is about).
    await tester.tap(find.byKey(const Key('lock-toggle')));
    await tester.pump();

    final artboardRect = tester.getRect(find.byKey(const Key('artboard-gesture-area')));

    // PASS 4.4's own centering formula, called directly (not re-derived) --
    // predicts where artwork-space (400,400) renders BEFORE any user pan,
    // at the app's actual initial viewScale (1.0).
    Offset screenPointFor(Offset artworkPoint, {required Offset viewOffset, required double viewScale}) {
      final fit = baseFitScale(artboardRect.size);
      return artboardRect.topLeft + viewOffset + artworkPoint * (viewScale * fit);
    }

    final fit = baseFitScale(artboardRect.size);
    final rendered = kArtworkSize * fit;
    final initialOffset = Offset((artboardRect.width - rendered) / 2, (artboardRect.height - rendered) / 2);
    const markArtworkPoint = Offset(60, 60); // near a corner -- reliably background margin, not line art
    final markScreenPointBefore = screenPointFor(markArtworkPoint, viewOffset: initialOffset, viewScale: 1.0);

    // A quick tap -- a single-point Brush "dot" (default preset color, not
    // white/black) at that exact screen position.
    await tester.tapAt(markScreenPointBefore);
    await tester.pump();

    Future<ui.Color> sampleAt(Offset point) async {
      late ui.Color result;
      await tester.runAsync(() async {
        final renderObject = rootKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await renderObject.toImage(pixelRatio: 1.0);
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

    final markColorBefore = await sampleAt(markScreenPointBefore);
    expect(markColorBefore.toARGB32(), isNot(0xFFFFFFFF), reason: 'the Brush dot must be visible where it was placed');
    expect(markColorBefore.toARGB32(), isNot(0xFF000000), reason: 'must be the paint color, not accidentally the line art');

    // Real hold-then-drag Pan through the actual Listener.
    const dragDelta = Offset(80, -60);
    final gesture = await tester.startGesture(artboardRect.center);
    await tester.pump(const Duration(milliseconds: 260)); // hold -> Pan
    await gesture.moveBy(dragDelta);
    await tester.pump();
    await gesture.up();
    await tester.pump();

    // The mark must now be at exactly old-position + dragDelta (pure
    // translation) -- not left behind, not drifted anywhere else.
    final markScreenPointAfter = markScreenPointBefore + dragDelta;
    final colorAtNewPosition = await sampleAt(markScreenPointAfter);
    expect(colorAtNewPosition.toARGB32(), markColorBefore.toARGB32(),
        reason: 'the mark must have moved WITH the artwork by exactly the pan delta -- '
            'if it stayed still (or moved a different amount than the background), the background and the '
            'painted content are not one single transformed surface');

    // And its OLD screen position must no longer show the mark's color --
    // proving it genuinely moved (one object), rather than the mark being
    // redrawn in two places.
    final colorAtOldPosition = await sampleAt(markScreenPointBefore);
    expect(colorAtOldPosition.toARGB32(), isNot(markColorBefore.toARGB32()),
        reason: 'the mark must NOT remain visible at its old position after panning away from it');
  });
}
