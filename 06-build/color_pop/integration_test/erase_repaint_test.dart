// PASS 2.1 targeted verification: Erase must remove user paint and reveal
// the ORIGINAL artwork (never a lower Fill layer, never opaque white paint
// data blocking future repaint), and a later Fill/Brush action must be able
// to repaint pixels an earlier Erase cleared.
//
// Deliberately separate from coloring_engine_test.dart and deliberately
// does not exercise Lock/drag-from-edge (a pre-existing, unrelated
// integration-test flake on this device, reproduced identically against
// the untouched baseline engine -- not a PASS 2.1 regression, and not
// something this pass is scoped to fix). Runs unlocked so only Fill/Brush/
// Erase chronology is under test.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:color_pop/core/app_data.dart';
import 'package:color_pop/core/constants.dart';
import 'package:color_pop/features/editor/artwork_coordinates.dart';
import 'package:color_pop/features/editor/lesson_artwork_cache.dart';
import 'package:color_pop/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Per PASS 2.1 "TEST ON REAL DEVICE" requirement: run against all three
// required lessons, not just one artwork shape.
const _lessonIds = ['animal_babydeer', 'food_berrycupcake', 'dumpling_dimsumbowl'];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'PASS 2.1: Erase reveals original artwork; later Fill/Brush repaints erased pixels; line art intact; undo/redo',
    (tester) async {
    await tester.pumpWidget(const ColorPopApp());
    await _settle(tester);
    debugPrint('[TEST] app booted');

    for (final lessonId in _lessonIds) {
      debugPrint('[TEST] ==== lesson $lessonId ====');
      await _openLesson(tester, lessonId);
      await _waitForArtworkReady(tester);
      debugPrint('[TEST] lesson ready');

      await _runEraseCases(tester, lessonId);

      await tester.tap(find.byType(BackButton));
      await _settle(tester);
    }
  }, timeout: const Timeout(Duration(minutes: 12)));
}

Future<void> _runEraseCases(WidgetTester tester, String lessonId) async {
    final lesson = AppData.lessonRepository.findById(lessonId)!;
    final artwork = await LessonArtworkCache.load(lesson);
    final interior = _findPaintablePoint(artwork.barrierMask, xMin: 250, xMax: 550, yMin: 250, yMax: 550);
    final barrierPoint = _findBarrierPoint(artwork.barrierMask, xMin: 250, xMax: 550, yMin: 250, yMax: 550);

    // Lock is not under test here -- unlock so Brush is never region
    // constrained (avoids a pre-existing, unrelated Lock/drag flake).
    await _toggleLock(tester);

    // ================= CASE A: Brush -> Erase -> Brush (different color) =====
    await _selectTool(tester, 'tool-brush');
    await _selectColor(tester, const Color(0xFFFF6D80)); // red/pink
    await _dragOnArtboard(tester, [interior, Offset(interior.dx + 20, interior.dy)]);
    expect(_closeTo(await _samplePixel(tester, interior), const Color(0xFFFF6D80)), true, reason: 'CASE A: Brush should paint red');

    await _selectTool(tester, 'tool-erase');
    await _dragOnArtboard(tester, [interior, Offset(interior.dx + 20, interior.dy)]);
    final erasedA = await _samplePixel(tester, interior);
    expect(_closeTo(erasedA, const Color(0xFFFF6D80)), false, reason: 'CASE A: Erase must remove the red brush paint');
    expect(_closeTo(erasedA, Colors.white), true, reason: 'CASE A: Erase must reveal the original artwork (white), not a blocking paint layer');

    await _selectTool(tester, 'tool-brush');
    await _selectColor(tester, const Color(0xFF4A82FF)); // blue
    await _dragOnArtboard(tester, [interior, Offset(interior.dx + 20, interior.dy)]);
    expect(
      _closeTo(await _samplePixel(tester, interior), const Color(0xFF4A82FF)),
      true,
      reason: 'CASE A: Blue Brush after Erase must render normally',
    );
    debugPrint('[TEST] CASE A brush-after-erase ok');

    for (var i = 0; i < 5; i++) {
      await _tapUndo(tester); // clean slate for CASE B
    }

    // ================= CASE B: Fill -> Erase -> Fill (different color) =======
    await _selectTool(tester, 'tool-fill');
    await _selectColor(tester, const Color(0xFFFF6D80)); // red
    await _tapOnArtboard(tester, interior);
    expect(_closeTo(await _samplePixel(tester, interior), const Color(0xFFFF6D80)), true, reason: 'CASE B: Fill should paint red');

    await _selectTool(tester, 'tool-erase');
    await _dragOnArtboard(tester, [interior, Offset(interior.dx + 20, interior.dy)]);
    final erasedB = await _samplePixel(tester, interior);
    expect(_closeTo(erasedB, const Color(0xFFFF6D80)), false, reason: 'CASE B: Erase must remove the filled red');
    expect(_closeTo(erasedB, Colors.white), true, reason: 'CASE B: Erase must reveal the original artwork (white), not a blocking paint layer');

    await _selectTool(tester, 'tool-fill');
    await _selectColor(tester, const Color(0xFF168B2D)); // green
    await _tapOnArtboard(tester, interior);
    expect(
      _closeTo(await _samplePixel(tester, interior), const Color(0xFF168B2D)),
      true,
      reason: 'CASE B (PASS 2.1 fix): Fill AFTER Erase must repaint the whole region',
    );
    expect(
      _closeTo(await _samplePixel(tester, Offset(interior.dx + 10, interior.dy)), const Color(0xFF168B2D)),
      true,
      reason: 'CASE B (PASS 2.1 fix): the previously-erased pixels specifically must become green too',
    );
    debugPrint('[TEST] CASE B fill-after-erase ok');

    // ================= CASE C: source line art survives Erase ================
    if (barrierPoint != null) {
      await _selectTool(tester, 'tool-brush');
      await _selectColor(tester, const Color(0xFF4A82FF));
      await _dragOnArtboard(tester, [barrierPoint, Offset(barrierPoint.dx + 6, barrierPoint.dy)]);
      await _selectTool(tester, 'tool-erase');
      await _dragOnArtboard(tester, [barrierPoint, Offset(barrierPoint.dx + 6, barrierPoint.dy)]);
      final linePixel = await _samplePixel(tester, barrierPoint);
      expect(_isBlackLine(linePixel), true, reason: 'CASE C: source black line art must remain intact after Erase crosses it');
      debugPrint('[TEST] CASE C line-art preserved ok');
    } else {
      debugPrint('[TEST] CASE C skipped -- no barrier pixel found in the calibration range');
    }

    // ================= CASE D: Undo/Redo of Erase =============================
    for (var i = 0; i < 6; i++) {
      await _tapUndo(tester); // back to a clean canvas
    }
    await _selectTool(tester, 'tool-brush');
    await _selectColor(tester, const Color(0xFFC34AD8)); // purple
    await _dragOnArtboard(tester, [interior, Offset(interior.dx + 20, interior.dy)]);
    await _selectTool(tester, 'tool-erase');
    await _dragOnArtboard(tester, [interior, Offset(interior.dx + 20, interior.dy)]);
    expect(_closeTo(await _samplePixel(tester, interior), Colors.white), true, reason: 'CASE D: precondition -- erased to white');

    await _tapUndo(tester); // undo the erase
    expect(
      _closeTo(await _samplePixel(tester, interior), const Color(0xFFC34AD8)),
      true,
      reason: 'CASE D: Undo Erase should restore the erased purple paint',
    );
    await _tapRedo(tester); // redo the erase
    expect(
      _closeTo(await _samplePixel(tester, interior), Colors.white),
      true,
      reason: 'CASE D: Redo Erase should reapply the erase',
    );
    debugPrint('[TEST] CASE D undo/redo ok');
}

Future<void> _settle(WidgetTester tester, {Duration duration = const Duration(milliseconds: 600)}) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Searches whatever screen is currently on top for the lesson's card,
/// scrolling to find it; only navigates to Library (where every lesson is
/// listed under the 'all' filter) if it's not reachable from the current
/// screen at all.
Future<void> _openLesson(WidgetTester tester, String lessonId) async {
  final key = Key('lesson-card-$lessonId');
  if (!await _scrollUntilVisible(tester, key)) {
    await tester.tap(find.text('Library'));
    await _settle(tester);
    await _scrollUntilVisible(tester, key);
  }
  final finder = find.byKey(key);
  // Being merely "found" isn't the same as being fully on-screen -- a card
  // that's still half-clipped at the scroll viewport's edge hit-tests to
  // whatever is on top of it instead. ensureVisible scrolls precisely so
  // the whole widget is inside its scrollable ancestor's viewport.
  await tester.ensureVisible(finder);
  await _settle(tester);
  await tester.tap(finder);
  await _settle(tester);
}

Future<bool> _scrollUntilVisible(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  if (finder.evaluate().isNotEmpty) return true;
  // Prefer the lesson GridView itself when present -- on Library,
  // `find.byType(Scrollable).first` would otherwise resolve to the
  // horizontal filter-chip row (it appears earlier in the widget tree),
  // wasting every vertical drag on the wrong scrollable.
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

// PASS 4.4: the gesture area is now the FULL grey workspace, not a square
// sized to the artwork -- the 800x800 sheet is centered inside it at
// `baseFitScale` (viewScale 1.0, no pan yet at the point these tests use
// this helper). Must mirror EditorController.ensureViewportInitialized's
// centering formula exactly, or a tap lands off the intended artwork point.
Offset _artworkPointToGlobal(Rect artboardRect, Offset artworkPoint) {
  final fit = baseFitScale(artboardRect.size);
  final rendered = kArtworkSize * fit;
  final centeredOffset = Offset((artboardRect.width - rendered) / 2, (artboardRect.height - rendered) / 2);
  return artboardRect.topLeft + centeredOffset + artworkPoint * fit;
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
  final boundary = tester.renderObject(find.byKey(const Key('artboard-repaint-boundary'))) as RenderRepaintBoundary;
  final displaySize = boundary.size;
  final fit = baseFitScale(displaySize);
  final rendered = kArtworkSize * fit;
  final centeredOffset = Offset((displaySize.width - rendered) / 2, (displaySize.height - rendered) / 2);
  final localPoint = centeredOffset + artworkPoint * fit;
  final image = await boundary.toImage(pixelRatio: 1.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final width = image.width;
  final px = localPoint.dx.round().clamp(0, width - 1);
  final py = localPoint.dy.round().clamp(0, image.height - 1);
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

bool _isBlackLine(Color c) => c.a > 0.5 && c.r < 0.3 && c.g < 0.3 && c.b < 0.3;

/// Finds a non-barrier point with a real margin of clearance around it (not
/// just the single pixel itself) -- a point immediately adjacent to a
/// barrier is a bad Fill calibration target, because the artwork-point <->
/// screen-point round trip through real device coordinates can round by a
/// pixel and tip a tap onto the barrier, where Fill silently no-ops (unlike
/// Brush, which paints regardless of exactly which pixel it lands on).
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

/// Finds a point solidly inside the line art (its whole 3x3 neighbourhood is
/// barrier, not just the single pixel) -- a 1px-wide sliver at a line's tip
/// is a bad sampling target, because the same artwork-point <-> screen-point
/// rounding that motivates `_findPaintablePoint`'s clearance requirement can
/// just as easily shift a *sample* off a too-thin line.
Offset? _findBarrierPoint(
  Uint8List barrierMask, {
  required int xMin,
  required int xMax,
  required int yMin,
  required int yMax,
}) {
  bool solidlyBarrier(int x, int y) {
    for (int dy = -1; dy <= 1; dy++) {
      for (int dx = -1; dx <= 1; dx++) {
        final nx = x + dx, ny = y + dy;
        if (nx < 0 || nx >= kArtworkSize || ny < 0 || ny >= kArtworkSize) return false;
        if (barrierMask[ny * kArtworkSize + nx] == 0) return false;
      }
    }
    return true;
  }

  for (int y = yMin; y < yMax; y++) {
    for (int x = xMin; x < xMax; x++) {
      if (solidlyBarrier(x, y)) return Offset(x.toDouble(), y.toDouble());
    }
  }
  return null;
}
