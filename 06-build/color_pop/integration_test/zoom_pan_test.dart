// PASS 3 targeted verification: pinch-zoom must not trigger a paint action
// from Brush/Fill/Erase (§5), and the artwork point under a pinch's focal
// point must remain under that SAME screen location through the zoom (§4,
// §7) — i.e. Fill/Brush/Erase must land exactly where the user is looking
// at any zoom level, not at some drifted/mis-scaled coordinate.
//
// Deliberately reuses the same style as erase_repaint_test.dart: a small,
// self-contained, targeted test rather than extending the larger
// coloring_engine_test.dart (which has a known, pre-existing, unrelated
// Lock/drag flake on this device).

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:color_pop/core/app_data.dart';
import 'package:color_pop/core/constants.dart';
import 'package:color_pop/features/editor/lesson_artwork_cache.dart';
import 'package:color_pop/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _lessonId = 'animal_babydeer';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'PASS 3: two-finger pinch never paints; the point under the pinch focal stays under it while zoomed',
    (tester) async {
    await tester.pumpWidget(const ColorPopApp());
    await _settle(tester);

    await _openLesson(tester, _lessonId);
    await _waitForArtworkReady(tester);

    final lesson = AppData.lessonRepository.findById(_lessonId)!;
    final artwork = await LessonArtworkCache.load(lesson);
    final interior = _findPaintablePoint(artwork.barrierMask, xMin: 250, xMax: 550, yMin: 250, yMax: 550);

    final rect = tester.getRect(find.byKey(const Key('artboard-gesture-area')));
    final baseScale = rect.width / kArtworkSize;
    // `interior`'s on-screen LOCAL position at scale=1 (before any zoom).
    final focalLocal = Offset(interior.dx * baseScale, interior.dy * baseScale);
    final focalGlobal = rect.topLeft + focalLocal;

    // ---- Two-finger pinch centered exactly on `interior`, tool = Brush ----
    // (the default active tool) the whole time -- the highest-risk case,
    // since it's what's selected without the user doing anything extra.
    final beforePinch = await _sampleLocalPixel(tester, focalLocal);

    final g1 = await tester.startGesture(focalGlobal - const Offset(20, 0), pointer: 101);
    final g2 = await tester.startGesture(focalGlobal + const Offset(20, 0), pointer: 102);
    await tester.pump(const Duration(milliseconds: 16));
    // Symmetric outward spread around the SAME focal point -- pure zoom,
    // no pan component -- from spread 40 to spread 200 (5x ratio, clamped
    // by the engine to maxScale 4.0).
    for (final t in [0.25, 0.5, 0.75, 1.0]) {
      final half = 20 + t * (100 - 20);
      await g1.moveTo(focalGlobal - Offset(half, 0));
      await g2.moveTo(focalGlobal + Offset(half, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g1.up();
    await g2.up();
    await _settle(tester);

    final afterPinch = await _sampleLocalPixel(tester, focalLocal);
    expect(
      _closeTo(afterPinch, beforePinch),
      true,
      reason: 'Two-finger pinch must NEVER produce a Brush/Fill/Erase paint action, even with Brush active',
    );
    debugPrint('[TEST] two-finger pinch produced no paint action ok');

    // ---- Coordinate correctness: Fill at the SAME screen location must ----
    // still land on `interior`'s artwork point, now zoomed ~4x.
    await _selectTool(tester, 'tool-fill');
    await _selectColor(tester, const Color(0xFFFF6D80)); // red/pink
    await tester.tapAt(focalGlobal);
    await _settle(tester);

    final filledAtFocal = await _sampleLocalPixel(tester, focalLocal);
    expect(
      _closeTo(filledAtFocal, const Color(0xFFFF6D80)),
      true,
      reason: 'Fill tapped at the pinch focal point must land on the SAME artwork point the pinch was centered on, even while zoomed (§7)',
    );
    debugPrint('[TEST] coordinate mapping correct under zoom (Fill) ok');

    // ---- Brush at the same zoomed focal point also lands correctly ----
    await _selectTool(tester, 'tool-brush');
    await _selectColor(tester, const Color(0xFF4A82FF)); // blue
    final g3 = await tester.startGesture(focalGlobal);
    await tester.pump(const Duration(milliseconds: 16));
    await g3.moveTo(focalGlobal + const Offset(6, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await g3.up();
    await _settle(tester);

    final brushedAtFocal = await _sampleLocalPixel(tester, focalLocal);
    expect(
      _closeTo(brushedAtFocal, const Color(0xFF4A82FF)),
      true,
      reason: 'Brush at the pinch focal point must land on the SAME artwork point while zoomed (§7)',
    );
    debugPrint('[TEST] coordinate mapping correct under zoom (Brush) ok');

    // ---- Undo/Redo still work correctly after Zoom/Pan (regression) ----
    await _tapUndo(tester); // undo the blue brush stroke
    final afterUndo = await _sampleLocalPixel(tester, focalLocal);
    expect(
      _closeTo(afterUndo, const Color(0xFF4A82FF)),
      false,
      reason: 'Undo after zoom must still correctly reverse the last action',
    );
    debugPrint('[TEST] undo after zoom ok');
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets(
    'PASS 3.1 §1: a realistic (non-simultaneous) gap between finger 1 and finger 2 must still produce zero paint',
    (tester) async {
    // The original bug specifically required finger 2 to arrive some real
    // milliseconds AFTER finger 1 -- back-to-back startGesture() calls with
    // no delay between them (as in the test above) land well inside any
    // reasonable arbitration window regardless of whether arbitration
    // exists at all, so that test alone would NOT have caught this bug.
    // This test inserts a delay in the middle of the human-pinch range
    // (well under the 70ms arbitration window, well above "simultaneous")
    // between the two touches, for both Fill (commits instantly on down —
    // the highest-risk tool) and Brush (default tool, live-stroke dot risk).
    await tester.pumpWidget(const ColorPopApp());
    await _settle(tester);
    await _openLesson(tester, _lessonId);
    await _waitForArtworkReady(tester);

    final lesson = AppData.lessonRepository.findById(_lessonId)!;
    final artwork = await LessonArtworkCache.load(lesson);
    final interior = _findPaintablePoint(artwork.barrierMask, xMin: 250, xMax: 550, yMin: 250, yMax: 550);
    final rect = tester.getRect(find.byKey(const Key('artboard-gesture-area')));
    final baseScale = rect.width / kArtworkSize;
    final focalLocal = Offset(interior.dx * baseScale, interior.dy * baseScale);
    final focalGlobal = rect.topLeft + focalLocal;

    // ---- Fill active (default) — the highest-risk case: Fill commits ----
    // synchronously on pointer-down, with no "live" preview to discard.
    await _selectTool(tester, 'tool-fill');
    await _selectColor(tester, const Color(0xFF168B2D)); // green
    final beforeFillRace = await _sampleLocalPixel(tester, focalLocal);

    final f1 = await tester.startGesture(focalGlobal, pointer: 201);
    await tester.pump(const Duration(milliseconds: 35)); // realistic human finger-to-finger gap
    final f2 = await tester.startGesture(focalGlobal + const Offset(140, 0), pointer: 202);
    await tester.pump(const Duration(milliseconds: 16));
    await f2.moveTo(focalGlobal + const Offset(200, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await f1.up();
    await f2.up();
    await _settle(tester);

    final afterFillRace = await _sampleLocalPixel(tester, focalLocal);
    expect(
      _closeTo(afterFillRace, beforeFillRace),
      true,
      reason: 'A 2nd finger arriving ~35ms after the 1st must cancel Fill outright, even though Fill normally commits instantly on pointer-down (§1)',
    );
    debugPrint('[TEST] realistic-gap race: Fill correctly cancelled ok');

    // ---- Brush active — must not leave even a single dot under finger 1 ----
    await _selectTool(tester, 'tool-brush');
    await _selectColor(tester, const Color(0xFFC34AD8)); // purple
    final beforeBrushRace = await _sampleLocalPixel(tester, focalLocal);

    final b1 = await tester.startGesture(focalGlobal, pointer: 301);
    await tester.pump(const Duration(milliseconds: 35));
    final b2 = await tester.startGesture(focalGlobal + const Offset(140, 0), pointer: 302);
    await tester.pump(const Duration(milliseconds: 16));
    await b2.moveTo(focalGlobal + const Offset(200, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await b1.up();
    await b2.up();
    await _settle(tester);

    final afterBrushRace = await _sampleLocalPixel(tester, focalLocal);
    expect(
      _closeTo(afterBrushRace, beforeBrushRace),
      true,
      reason: 'A 2nd finger arriving ~35ms after the 1st must leave zero trace of a Brush dot under finger 1 (§1)',
    );
    debugPrint('[TEST] realistic-gap race: Brush left no dot ok');

    // ---- Confirm a genuine single-finger tap still works afterward ----
    // (i.e. arbitration correctly resolves the OTHER way for a real tap).
    await tester.tapAt(focalGlobal);
    await _settle(tester);
    final afterRealTap = await _sampleLocalPixel(tester, focalLocal);
    expect(
      _closeTo(afterRealTap, const Color(0xFFC34AD8)),
      true,
      reason: 'A genuine single-finger tap after the cancelled gestures must still paint normally',
    );
    debugPrint('[TEST] genuine single-finger tap after cancelled gestures still works ok');
  }, timeout: const Timeout(Duration(minutes: 5)));
}

Future<void> _settle(WidgetTester tester, {Duration duration = const Duration(milliseconds: 600)}) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _openLesson(WidgetTester tester, String lessonId) async {
  final key = Key('lesson-card-$lessonId');
  if (!await _scrollUntilVisible(tester, key)) {
    await tester.tap(find.text('Library'));
    await _settle(tester);
    await _scrollUntilVisible(tester, key);
  }
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await _settle(tester);
  await tester.tap(finder);
  await _settle(tester);
}

Future<bool> _scrollUntilVisible(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  if (finder.evaluate().isNotEmpty) return true;
  final scrollTarget = find.byType(GridView).evaluate().isNotEmpty ? find.byType(GridView) : find.byType(Scrollable);
  if (scrollTarget.evaluate().isEmpty) return false;
  for (var i = 0; i < 15 && finder.evaluate().isEmpty; i++) {
    await tester.drag(scrollTarget.first, const Offset(0, -300));
    await _settle(tester);
  }
  return finder.evaluate().isNotEmpty;
}

Future<void> _waitForArtworkReady(WidgetTester tester) async {
  for (var i = 0; i < 100; i++) {
    if (find.byKey(const Key('artboard-gesture-area')).evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
  throw StateError('Artwork did not become ready in time');
}

Future<void> _selectTool(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await _settle(tester);
}

Future<void> _selectColor(WidgetTester tester, Color color) async {
  await tester.tap(find.byKey(Key('palette-color-${color.toARGB32().toRadixString(16)}')));
  await _settle(tester);
}

Future<void> _tapUndo(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.undo));
  await _settle(tester);
}

/// Samples the CURRENT rendered artboard at a WIDGET-LOCAL position
/// (post-zoom/pan-aware — unlike a plain artwork-space sample, which would
/// be wrong once the view is zoomed) — mirrors production's eyedropper
/// capture approach exactly.
Future<Color> _sampleLocalPixel(WidgetTester tester, Offset localPosition) async {
  final boundary = tester.renderObject(find.byKey(const Key('artboard-repaint-boundary'))) as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1.0);
  final displaySize = boundary.size;
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final width = image.width;
  final px = (localPosition.dx / displaySize.width * width).round().clamp(0, width - 1);
  final py = (localPosition.dy / displaySize.height * image.height).round().clamp(0, image.height - 1);
  final bytes = byteData!.buffer.asUint8List();
  final idx = (py * width + px) * 4;
  image.dispose();
  return Color.fromARGB(bytes[idx + 3], bytes[idx], bytes[idx + 1], bytes[idx + 2]);
}

bool _closeTo(Color actual, Color expected, {int tolerance = 24}) {
  int diff(double a, double b) => ((a * 255).round() - (b * 255).round()).abs();
  return diff(actual.r, expected.r) <= tolerance &&
      diff(actual.g, expected.g) <= tolerance &&
      diff(actual.b, expected.b) <= tolerance &&
      actual.a > 0.5;
}

Offset _findPaintablePoint(
  Uint8List barrierMask, {
  required int xMin,
  required int xMax,
  required int yMin,
  required int yMax,
  int step = 2,
  int clearance = 3,
}) {
  bool hasClearance(int x, int y) {
    for (int dy = -clearance; dy <= clearance; dy += clearance) {
      for (int dx = -clearance; dx <= clearance; dx += clearance) {
        final nx = x + dx, ny = y + dy;
        if (nx < 0 || nx >= kArtworkSize || ny < 0 || ny >= kArtworkSize) return false;
        if (barrierMask[ny * kArtworkSize + nx] != 0) return false;
      }
    }
    return true;
  }

  for (int y = yMin; y < yMax; y += step) {
    for (int x = xMin; x < xMax; x += step) {
      if (hasClearance(x, y)) return Offset(x.toDouble(), y.toDouble());
    }
  }
  throw StateError('No sufficiently-clear paintable point found in [$xMin,$xMax)x[$yMin,$yMax)');
}
