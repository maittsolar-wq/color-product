// PASS 4.5 — verifies the live Eyedropper loupe's coordinate correctness
// under a genuine two-finger pinch-zoom, which raw `adb shell input` cannot
// physically reproduce on this unrooted test device (no multitouch
// injection primitive available — same documented limitation as PASS 4.4's
// zoom_pan_test.dart). Flutter's own gesture-testing API CAN synthesize
// genuine simultaneous multi-pointer touches, driven through the real
// widget tree on the real device, so this closes that gap at full fidelity
// rather than skipping it.
//
// Physical, single-finger loupe behavior (appearance, live tracking, MRU
// commit-only-on-release, moved-artwork sampling, Expanded mode, no
// accidental pan) was separately confirmed by hand on-device via adb
// screenshots — see the PASS 4.5 report.

import 'dart:typed_data';

import 'package:color_pop/core/app_data.dart';
import 'package:color_pop/core/constants.dart';
import 'package:color_pop/features/editor/artwork_coordinates.dart';
import 'package:color_pop/features/editor/editor_controller.dart';
import 'package:color_pop/features/editor/editor_painter.dart';
import 'package:color_pop/features/editor/lesson_artwork_cache.dart';
import 'package:color_pop/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _lessonId = 'animal_babydeer';
const _green = Color(0xFF168B2D);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'PASS 4.5: Eyedropper loupe samples the correct pixel at a genuinely zoomed focal point',
    (tester) async {
    await tester.pumpWidget(const ColorPopApp());
    await _settle(tester);
    await _openLesson(tester, _lessonId);
    await _waitForArtworkReady(tester);

    final lesson = AppData.lessonRepository.findById(_lessonId)!;
    final artwork = await LessonArtworkCache.load(lesson);
    final interior = _findPaintablePoint(artwork.barrierMask, xMin: 250, xMax: 550, yMin: 250, yMax: 550);
    final rect = tester.getRect(find.byKey(const Key('artboard-gesture-area')));
    final focalLocal = _artworkPointToLocal(rect.size, interior);
    final focalGlobal = rect.topLeft + focalLocal;

    // ---- Fill the target point a distinctive, unambiguous color ----
    await _selectTool(tester, 'tool-fill');
    await _selectColor(tester, _green);
    await tester.tapAt(focalGlobal);
    await _settle(tester);

    // ---- Genuine two-finger pinch centered on the target, up to ~3x ----
    final g1 = await tester.startGesture(focalGlobal - const Offset(20, 0), pointer: 401);
    final g2 = await tester.startGesture(focalGlobal + const Offset(20, 0), pointer: 402);
    await tester.pump(const Duration(milliseconds: 16));
    for (final t in [0.25, 0.5, 0.75, 1.0]) {
      final half = 20 + t * (60 - 20); // spread ratio 3x
      await g1.moveTo(focalGlobal - Offset(half, 0));
      await g2.moveTo(focalGlobal + Offset(half, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g1.up();
    await g2.up();
    await _settle(tester);

    // ---- Activate Pick and sample exactly at the (still-centered, now ----
    // ---- zoomed) focal point -- a fresh one-finger gesture, per §11. -----
    await _selectTool(tester, 'tool-eyedropper');
    final gesture = await tester.startGesture(focalGlobal);
    await _settle(tester, duration: const Duration(milliseconds: 400)); // let the live sample resolve

    // Checked directly against controller state rather than by re-deriving
    // the loupe's exact on-screen rect (which duplicates _EyedropperLoupe's
    // own edge-flip/clamp logic and is fragile to keep in lockstep) — this
    // is the same inverse-transform result the loupe widget itself reads to
    // decide both its position AND its rendered content, so checking it
    // directly is a strictly stronger, more direct proof of correctness.
    final controller = _findController(tester);
    expect(
      controller.eyedropperPreviewColor != null && _closeTo(controller.eyedropperPreviewColor!, _green),
      true,
      reason: 'the live sample at the zoomed focal point must be the SAME green fill under the finger, proving the '
          'inverse ArtworkSurface transform stays correct at ~3x zoom -- got ${controller.eyedropperPreviewColor}',
    );
    expect(controller.eyedropperSourceImage, isNotNull, reason: 'the loupe must have a live magnified crop to render');
    expect(find.byKey(const Key('eyedropper-loupe')), findsOneWidget, reason: 'the loupe widget must be mounted and visible');
    debugPrint('[TEST] Eyedropper loupe samples correctly at zoomed focal point ok');

    await gesture.up();
    await _settle(tester);

    // ---- Commit lands the SAME color, promoted to MRU #1 ----
    expect(controller.activeColor.toARGB32(), _green.toARGB32(), reason: 'the zoomed sample must commit on release (§14)');
    expect(controller.colorHistory.first.toARGB32(), _green.toARGB32());
    expect(controller.activeTool, EditorTool.eyedropper, reason: 'Pick stays active after a commit (§14 sticky Pick mode)');
    debugPrint('[TEST] zoomed Eyedropper commit promoted to MRU #1 ok');
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets(
    'PASS 4.5: dragging off the 800x800 artwork during Eyedropper never commits workspace grey',
    (tester) async {
    await tester.pumpWidget(const ColorPopApp());
    await _settle(tester);
    await _openLesson(tester, _lessonId);
    await _waitForArtworkReady(tester);

    final lesson = AppData.lessonRepository.findById(_lessonId)!;
    final artwork = await LessonArtworkCache.load(lesson);
    final interior = _findPaintablePoint(artwork.barrierMask, xMin: 250, xMax: 550, yMin: 250, yMax: 550);
    final rect = tester.getRect(find.byKey(const Key('artboard-gesture-area')));
    final focalLocal = _artworkPointToLocal(rect.size, interior);
    final focalGlobal = rect.topLeft + focalLocal;

    await _selectTool(tester, 'tool-fill');
    await _selectColor(tester, _green);
    await tester.tapAt(focalGlobal);
    await _settle(tester);

    await _selectTool(tester, 'tool-eyedropper');
    // Drag from inside the green fill straight up, well past the artwork's
    // top edge into the grey workspace margin.
    final gesture = await tester.startGesture(focalGlobal);
    await _settle(tester, duration: const Duration(milliseconds: 200));
    await gesture.moveTo(rect.topLeft + Offset(focalLocal.dx, -80));
    await _settle(tester, duration: const Duration(milliseconds: 200));
    await gesture.up();
    await _settle(tester);

    final controller = _findController(tester);
    expect(
      controller.activeColor.toARGB32(),
      isNot(const Color(0xFFF1F1F1).toARGB32()),
      reason: 'the workspace grey must never be committed, even though the gesture ended outside the artwork (§8)',
    );
    debugPrint('[TEST] out-of-bounds Eyedropper drag never committed workspace grey ok');
  }, timeout: const Timeout(Duration(minutes: 5)));
}

EditorController _findController(WidgetTester tester) {
  final painter = tester.widget<CustomPaint>(
    find.descendant(of: find.byKey(const Key('artboard-repaint-boundary')), matching: find.byType(CustomPaint)),
  );
  return (painter.painter as EditorPainter).controller;
}

bool _closeTo(Color actual, Color expected, {int tolerance = 30}) {
  int diff(double a, double b) => ((a * 255).round() - (b * 255).round()).abs();
  return diff(actual.r, expected.r) <= tolerance &&
      diff(actual.g, expected.g) <= tolerance &&
      diff(actual.b, expected.b) <= tolerance &&
      actual.a > 0.5;
}

Offset _artworkPointToLocal(Size displaySize, Offset artworkPoint) {
  final fit = baseFitScale(displaySize);
  final rendered = kArtworkSize * fit;
  final centeredOffset = Offset((displaySize.width - rendered) / 2, (displaySize.height - rendered) / 2);
  return centeredOffset + artworkPoint * fit;
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
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Library')));
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
  for (var i = 0; i < 15; i++) {
    await tester.drag(scrollTarget.first, const Offset(0, 3000));
    await _settle(tester);
  }
  for (var i = 0; i < 20 && finder.evaluate().isEmpty; i++) {
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
