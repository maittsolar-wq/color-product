// Real on-device verification of the PASS 2 coloring engine — runs against
// the actual rendered widget tree (real Skia compositing, real
// PointerEvent dispatch), not just unit-level logic. Per the task's
// explicit instruction: "Do not claim visual/interaction success solely
// from unit tests."
//
// Calibration points (which artwork-space coordinate is "inside region X")
// are derived from the SAME LessonArtworkCache/RegionEngine the real app
// uses — via floodFillFrom ground truth — rather than guessed/hardcoded,
// so this test works against the real, irregular artwork shapes.

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

const _lessonAId = 'animal_babydeer';
const _lessonBId = 'food_berrycupcake';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Coloring engine: Brush, Lock, Unlock, Fill, background fill, Erase, Undo/Redo, lesson isolation',
    (tester) async {
    await tester.pumpWidget(const ColorPopApp());
    await _settle(tester);
    debugPrint('[TEST] app booted');

    await _openLesson(tester, _lessonAId, fromHome: true);
    debugPrint('[TEST] opened lesson A');
    await _waitForArtworkReady(tester);
    debugPrint('[TEST] lesson A artwork ready');

    final lessonA = AppData.lessonRepository.findById(_lessonAId)!;
    final artworkA = await LessonArtworkCache.load(lessonA);

    // ---- Calibration: find two genuinely DISJOINT regions -----------------
    final interior = _findPaintablePoint(artworkA.barrierMask, xMin: 250, xMax: 550, yMin: 250, yMax: 550);
    final maskFromInterior = _floodFillMask(artworkA.barrierMask, interior);
    final otherRegion = _findPointOutsideMask(artworkA.barrierMask, maskFromInterior);
    final backgroundCorner = _findPaintablePoint(artworkA.barrierMask, xMin: 0, xMax: 60, yMin: 0, yMax: 60, step: 1);

    // ================= BRUSH ================================================
    await _selectTool(tester, 'tool-brush');
    await _selectColor(tester, const Color(0xFF4A82FF)); // blue
    await _dragOnArtboard(tester, [interior, Offset(interior.dx + 20, interior.dy + 20)]);

    var pixel = await _samplePixel(tester, interior);
    expect(_closeTo(pixel, const Color(0xFF4A82FF)), true, reason: 'Brush stroke should paint the chosen color');

    // ================= LOCK (default ON) ====================================
    // A locked stroke dragged from `otherRegion` toward `interior` must stay
    // clipped to otherRegion's own connected area -- `interior` (a DIFFERENT
    // region entirely) must NOT receive paint from this stroke.
    await _selectColor(tester, const Color(0xFFC34AD8)); // purple, distinct from the blue already at `interior`
    await _dragOnArtboard(tester, [otherRegion, interior]);

    final otherRegionPixel = await _samplePixel(tester, otherRegion);
    expect(_closeTo(otherRegionPixel, const Color(0xFFC34AD8)), true, reason: 'Locked stroke should paint its own start region');
    final interiorAfterLockedCrossAttempt = await _samplePixel(tester, interior);
    expect(
      _closeTo(interiorAfterLockedCrossAttempt, const Color(0xFFC34AD8)),
      false,
      reason: 'Locked stroke must NOT leak into a different closed region',
    );
    // The earlier Brush stroke at `interior` must remain untouched.
    expect(_closeTo(interiorAfterLockedCrossAttempt, const Color(0xFF4A82FF)), true, reason: 'Earlier stroke must remain visible after a later, unrelated Locked stroke');
    debugPrint('[TEST] lock: first locked stroke ok');

    // A SECOND locked stroke in a NEW region (background corner) -- confirms
    // Lock re-detects a fresh region per stroke, not a session-wide lock.
    await _selectColor(tester, const Color(0xFF2C8E92)); // teal
    await _dragOnArtboard(tester, [backgroundCorner, Offset(backgroundCorner.dx + 10, backgroundCorner.dy + 10)]);
    final backgroundPixelAfterSecondLockedStroke = await _samplePixel(tester, backgroundCorner);
    expect(_closeTo(backgroundPixelAfterSecondLockedStroke, const Color(0xFF2C8E92)), true);
    // Both previous strokes remain.
    final interiorStillThere = await _samplePixel(tester, interior);
    expect(_closeTo(interiorStillThere, const Color(0xFF4A82FF)), true, reason: 'Earlier strokes remain after starting a new stroke in a new region');
    debugPrint('[TEST] lock: second locked stroke in new region ok, earlier strokes intact');

    // ================= UNLOCK ================================================
    await _toggleLock(tester); // now unlocked
    await _selectColor(tester, const Color(0xFFF4E6BE)); // cream
    await _dragOnArtboard(tester, [otherRegion, interior]);
    final interiorAfterUnlockedCross = await _samplePixel(tester, interior);
    expect(
      _closeTo(interiorAfterUnlockedCross, const Color(0xFFF4E6BE)),
      true,
      reason: 'Unlocked stroke must be able to cross into a different region',
    );
    await _toggleLock(tester); // restore locked for the rest of the test
    debugPrint('[TEST] unlock: cross-boundary stroke ok');

    // ================= FILL (internal region) ================================
    // Undo everything above back to a clean canvas for a clear Fill check.
    for (var i = 0; i < 6; i++) {
      await _tapUndo(tester);
    }
    await _selectTool(tester, 'tool-fill');
    await _selectColor(tester, const Color(0xFF168B2D)); // green
    await _tapOnArtboard(tester, interior);
    final filledInterior = await _samplePixel(tester, interior);
    expect(_closeTo(filledInterior, const Color(0xFF168B2D)), true, reason: 'Fill should paint the tapped region');
    final adjacentRegionUnchanged = await _samplePixel(tester, otherRegion);
    expect(_closeTo(adjacentRegionUnchanged, const Color(0xFF168B2D)), false, reason: 'Fill must not spill into an adjacent closed region');
    debugPrint('[TEST] fill: internal region ok');

    // ================= FULL OUTER BACKGROUND FILL =============================
    await _selectColor(tester, const Color(0xFFFF6D80)); // pink
    await _tapOnArtboard(tester, backgroundCorner);
    final trueCorner00 = await _samplePixel(tester, const Offset(0, 0));
    final trueCornerMax = await _samplePixel(tester, const Offset(kArtworkSize - 1, kArtworkSize - 1));
    expect(_closeTo(trueCorner00, const Color(0xFFFF6D80)), true, reason: 'Background fill must reach the true (0,0) artwork corner');
    expect(_closeTo(trueCornerMax, const Color(0xFFFF6D80)), true, reason: 'Background fill must reach the true bottom-right artwork corner');
    debugPrint('[TEST] fill: full background reaches true edges ok');

    // ================= ERASE (reveals ORIGINAL artwork, PASS 2.1 semantics) ===
    // Approved PASS 2.1 semantics: Erase removes user paint and reveals the
    // ORIGINAL uncoloured artwork underneath -- never a lower Fill layer,
    // never opaque white PAINT DATA that blocks future repaint. Brush a
    // distinct color OVER the just-filled background, then erase it -- the
    // pixel must revert to the untouched artwork (white background), not to
    // the earlier pink Fill.
    await _selectTool(tester, 'tool-brush');
    await _toggleLock(tester); // unlock so this brush stroke isn't region-constrained
    await _selectColor(tester, const Color(0xFF0D0D0D)); // black
    await _dragOnArtboard(tester, [backgroundCorner, Offset(backgroundCorner.dx + 8, backgroundCorner.dy + 8)]);
    final blackOverPink = await _samplePixel(tester, backgroundCorner);
    expect(_closeTo(blackOverPink, const Color(0xFF0D0D0D)), true);

    await _selectTool(tester, 'tool-erase');
    await _dragOnArtboard(tester, [backgroundCorner, Offset(backgroundCorner.dx + 8, backgroundCorner.dy + 8)]);
    final erasedPixel = await _samplePixel(tester, backgroundCorner);
    expect(_closeTo(erasedPixel, const Color(0xFF0D0D0D)), false, reason: 'Erase must remove the brushed color');
    expect(
      _closeTo(erasedPixel, const Color(0xFFFF6D80)),
      false,
      reason: 'Erase must NOT reveal a lower Fill layer -- it reveals the original artwork, not an earlier paint action',
    );
    expect(
      _closeTo(erasedPixel, Colors.white),
      true,
      reason: 'Erase must reveal the original uncoloured artwork (white background), not a blocking paint layer',
    );
    debugPrint('[TEST] erase: reveals original artwork, not a lower Fill layer ok');

    // ================= REPAINT AFTER ERASE (the PASS 2.1 bug fix) ============
    // The actual regression under test: a LATER Fill must be able to repaint
    // pixels an EARLIER Erase cleared. Under the old fixed-z-order engine
    // (Fill permanently bottom, Erase permanently on top) this failed -- the
    // erase stroke replayed on top every frame and re-cleared the new Fill.
    // Chronological ordering (one shared action list, replayed in order)
    // fixes it.
    await _selectTool(tester, 'tool-fill');
    await _selectColor(tester, const Color(0xFF168B2D)); // green
    await _tapOnArtboard(tester, backgroundCorner);
    final repaintedAfterErase = await _samplePixel(tester, backgroundCorner);
    expect(
      _closeTo(repaintedAfterErase, const Color(0xFF168B2D)),
      true,
      reason: 'A Fill AFTER an Erase must be able to repaint the erased pixels (PASS 2.1 fix)',
    );
    debugPrint('[TEST] repaint-after-erase: later Fill correctly repaints erased pixels ok');

    // ================= UNDO / REDO ==========================================
    await _tapUndo(tester); // undo the repaint-after-erase green fill
    final afterUndoRepaint = await _samplePixel(tester, backgroundCorner);
    expect(_closeTo(afterUndoRepaint, Colors.white), true, reason: 'Undo of the repaint Fill should restore the erased (white) state');
    await _tapRedo(tester);
    final afterRedoRepaint = await _samplePixel(tester, backgroundCorner);
    expect(_closeTo(afterRedoRepaint, const Color(0xFF168B2D)), true, reason: 'Redo should reapply the repaint Fill');
    await _tapUndo(tester); // undo the just-redone repaint fill -> back to erased/white

    await _tapUndo(tester); // undo the erase stroke
    final afterUndoErase = await _samplePixel(tester, backgroundCorner);
    expect(_closeTo(afterUndoErase, const Color(0xFF0D0D0D)), true, reason: 'Undo should restore the erased brush stroke');
    await _tapRedo(tester);
    final afterRedoErase = await _samplePixel(tester, backgroundCorner);
    expect(_closeTo(afterRedoErase, Colors.white), true, reason: 'Redo should reapply the erase, revealing the original artwork again');

    // Undo back through the erase, the brush stroke and the background Fill.
    await _tapUndo(tester); // undo redo-erase state -> back to black brush visible
    await _tapUndo(tester); // undo black brush -> back to pink fill
    await _tapUndo(tester); // undo pink fill
    final afterUndoFill = await _samplePixel(tester, backgroundCorner);
    expect(_closeTo(afterUndoFill, const Color(0xFFFF6D80)), false, reason: 'Undo of the background Fill should remove the pink');
    await _tapRedo(tester);
    final afterRedoFill = await _samplePixel(tester, backgroundCorner);
    expect(_closeTo(afterRedoFill, const Color(0xFFFF6D80)), true, reason: 'Redo of the background Fill should reapply the pink');
    debugPrint('[TEST] undo/redo ok');
    await _toggleLock(tester); // restore locked

    // ================= LESSON ISOLATION ======================================
    await _goBack(tester); // commits lesson A's in-memory progress, returns Home
    debugPrint('[TEST] back to Home');

    await _openLesson(tester, _lessonBId, fromHome: false); // reached via Library
    debugPrint('[TEST] opened lesson B via Library');
    await _waitForArtworkReady(tester);
    final lessonB = AppData.lessonRepository.findById(_lessonBId)!;
    final artworkB = await LessonArtworkCache.load(lessonB);
    final lessonBInterior = _findPaintablePoint(artworkB.barrierMask, xMin: 250, xMax: 550, yMin: 250, yMax: 550);
    final lessonBPixelBefore = await _samplePixel(tester, lessonBInterior);
    expect(lessonBPixelBefore.a, 0, reason: "Lesson B must open clean -- lesson A's coloring must not bleed over");
    debugPrint('[TEST] lesson B is clean');

    await _goBack(tester);
    await _openLesson(tester, _lessonAId, fromHome: true);
    await _waitForArtworkReady(tester);
    final lessonARestoredPixel = await _samplePixel(tester, backgroundCorner);
    expect(
      _closeTo(lessonARestoredPixel, const Color(0xFFFF6D80)),
      true,
      reason: 'Reopening lesson A in the same session must restore its in-memory coloring state',
    );
    debugPrint('[TEST] lesson A restored -- all checks passed');
  },
  timeout: const Timeout(Duration(minutes: 10)),
  );
}

// ---------------------------------------------------------------------------
// Bounded settle helper. IntegrationTestWidgetsFlutterBinding drives frames
// on the REAL device clock (unlike the fake/virtual clock plain `flutter
// test` widget tests use) -- `pumpAndSettle()` waits for "no more frames
// scheduled", which never happens while an indefinitely-animating widget
// (e.g. CircularProgressIndicator, shown briefly while lesson content/
// artwork loads) is on screen, hanging forever in real wall-clock time.
// Pumping for a fixed duration instead sidesteps that entirely.
// ---------------------------------------------------------------------------

Future<void> _settle(WidgetTester tester, {Duration duration = const Duration(milliseconds: 600)}) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

// ---------------------------------------------------------------------------
// Navigation helpers
// ---------------------------------------------------------------------------

Future<void> _openLesson(WidgetTester tester, String lessonId, {required bool fromHome}) async {
  if (!fromHome) {
    await tester.tap(find.text('Library'));
    await _settle(tester);
  }
  final finder = find.byKey(Key('lesson-card-$lessonId'));
  if (finder.evaluate().isEmpty) {
    // Not yet on-screen -- scroll the relevant Scrollable a bounded number
    // of times rather than risking an unbounded scrollUntilVisible loop.
    final scrollable = find.byType(Scrollable).first;
    for (var i = 0; i < 8 && finder.evaluate().isEmpty; i++) {
      await tester.drag(scrollable, const Offset(0, -300));
      await _settle(tester);
    }
  }
  await tester.tap(finder);
  await _settle(tester);
}

Future<void> _goBack(WidgetTester tester) async {
  await tester.tap(find.byType(BackButton));
  await _settle(tester);
}

Future<void> _waitForArtworkReady(WidgetTester tester) async {
  for (var i = 0; i < 100; i++) {
    if (find.byKey(const Key('artboard-gesture-area')).evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
  throw StateError('Artwork did not become ready in time');
}

// ---------------------------------------------------------------------------
// Tool/color/UI helpers
// ---------------------------------------------------------------------------

Future<void> _selectTool(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await _settle(tester);
}

Future<void> _selectColor(WidgetTester tester, Color color) async {
  await tester.tap(find.byKey(Key('palette-color-${color.toARGB32().toRadixString(16)}')));
  await _settle(tester);
}

Future<void> _toggleLock(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('lock-toggle')));
  await _settle(tester);
}

Future<void> _tapUndo(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.undo));
  await _settle(tester);
}

Future<void> _tapRedo(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.redo));
  await _settle(tester);
}

// ---------------------------------------------------------------------------
// Artboard gesture + pixel-sampling helpers (artwork-space 0..800 <-> real
// screen coordinates <-> captured RepaintBoundary pixels)
// ---------------------------------------------------------------------------

Offset _artworkPointToGlobal(Rect artboardRect, Offset artworkPoint) {
  return Offset(
    artboardRect.left + artworkPoint.dx / kArtworkSize * artboardRect.width,
    artboardRect.top + artworkPoint.dy / kArtworkSize * artboardRect.height,
  );
}

Future<void> _tapOnArtboard(WidgetTester tester, Offset artworkPoint) async {
  final rect = tester.getRect(find.byKey(const Key('artboard-gesture-area')));
  await tester.tapAt(_artworkPointToGlobal(rect, artworkPoint));
  await _settle(tester);
}

Future<void> _dragOnArtboard(WidgetTester tester, List<Offset> artworkPoints) async {
  final rect = tester.getRect(find.byKey(const Key('artboard-gesture-area')));
  final gesture = await tester.startGesture(_artworkPointToGlobal(rect, artworkPoints.first));
  for (final point in artworkPoints.skip(1)) {
    await gesture.moveTo(_artworkPointToGlobal(rect, point));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await _settle(tester);
}

Future<Color> _samplePixel(WidgetTester tester, Offset artworkPoint) async {
  final boundary =
      tester.renderObject(find.byKey(const Key('artboard-repaint-boundary'))) as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final width = image.width;
  final px = (artworkPoint.dx / kArtworkSize * width).round().clamp(0, width - 1);
  final py = (artworkPoint.dy / kArtworkSize * image.height).round().clamp(0, image.height - 1);
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

// ---------------------------------------------------------------------------
// Calibration helpers — derive real region points from the SAME
// LessonArtworkCache/RegionEngine data the app itself uses.
// ---------------------------------------------------------------------------

Offset _findPaintablePoint(
  Uint8List barrierMask, {
  required int xMin,
  required int xMax,
  required int yMin,
  required int yMax,
  int step = 2,
}) {
  for (int y = yMin; y < yMax; y += step) {
    for (int x = xMin; x < xMax; x += step) {
      if (barrierMask[y * kArtworkSize + x] == 0) return Offset(x.toDouble(), y.toDouble());
    }
  }
  throw StateError('No paintable point found in [$xMin,$xMax)x[$yMin,$yMax)');
}

Uint8List _floodFillMask(Uint8List barrierMask, Offset start) {
  final size = kArtworkSize;
  final visited = Uint8List(size * size);
  final sx = start.dx.round(), sy = start.dy.round();
  final stack = <int>[sy * size + sx];
  visited[sy * size + sx] = 1;
  while (stack.isNotEmpty) {
    final idx = stack.removeLast();
    final cx = idx % size, cy = idx ~/ size;
    for (final n in [
      [cx - 1, cy],
      [cx + 1, cy],
      [cx, cy - 1],
      [cx, cy + 1],
    ]) {
      final nx = n[0], ny = n[1];
      if (nx < 0 || nx >= size || ny < 0 || ny >= size) continue;
      final nIdx = ny * size + nx;
      if (visited[nIdx] != 0 || barrierMask[nIdx] != 0) continue;
      visited[nIdx] = 1;
      stack.add(nIdx);
    }
  }
  return visited;
}

Offset _findPointOutsideMask(Uint8List barrierMask, Uint8List mask) {
  final size = kArtworkSize;
  for (int y = 0; y < size; y += 3) {
    for (int x = 0; x < size; x += 3) {
      final idx = y * size + x;
      if (barrierMask[idx] == 0 && mask[idx] == 0) return Offset(x.toDouble(), y.toDouble());
    }
  }
  throw StateError('No point outside the given mask was found');
}
