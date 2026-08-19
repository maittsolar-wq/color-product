// HIGH-ZOOM BRUSH COMMITTED-STROKE FIX — the previous high-zoom regression
// (editor_highzoom_brush_test.dart) only ever sampled the LIVE render
// immediately after painting, in the SAME EditorController instance. This
// file specifically targets the newly-confirmed fact that the leak
// survives leaving and reopening the lesson: it paints a DRAGGED (multi-
// point), large-radius, Locked Brush stroke along a contour at 1x and at
// 4x+pan, then DISPOSES the whole Editor widget tree and mounts a BRAND
// NEW EditorScreen for the SAME lesson id (forcing a real
// EditorController._load() -> ProgressRepository.getDrawingState ->
// _hydrateStrokes round trip, exactly the "leave and reopen" path), and
// only THEN samples the composited render for leaks.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:color_pop/core/app_data.dart';
import 'package:color_pop/core/constants.dart';
import 'package:color_pop/features/editor/artwork_coordinates.dart';
import 'package:color_pop/features/editor/editor_screen.dart';
import 'package:color_pop/features/editor/lesson_artwork_cache.dart';
import 'package:color_pop/features/editor/region_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePathProviderPlatform extends PathProviderPlatform with MockPlatformInterfaceMixin {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    final dir = await Directory.systemTemp.createTemp('color_pop_highzoom_reload_test_docs_');
    return dir.path;
  }
}

const _brushColor = Color(0xFF168B2D); // kEditorPresetColors.first
const _lessonId = 'animal_babydeer';

void main() {
  setUpAll(() async {
    PathProviderPlatform.instance = _FakePathProviderPlatform();
    await AppData.lessonRepository.load();
    await AppData.progressRepository.init();
  });

  testWidgets('LOCKED Brush drag at 1x and 4x+pan survives leaving and reopening the lesson with no leak', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final lesson = AppData.lessonRepository.findById(_lessonId)!;
    late LessonArtworkData artwork;
    await tester.runAsync(() async {
      artwork = await LessonArtworkCache.load(lesson);
    });

    // ONE boundary pair, reused by both scenarios: Scenario 1's reloaded
    // stroke is explicitly undone (Undo history survives reload per PASS
    // 4 §17) before Scenario 2 paints the SAME pair again, so the two
    // scenarios can never interfere with each other despite sharing a
    // region.
    final pair = _findBoundaryPair(artwork.barrierMask, kArtworkSize, xMin: 40, xMax: 760, yMin: 40, yMax: 760);
    expect(pair, isNotNull, reason: 'this lesson\'s line art must have at least one findable closed-region boundary within a Brush radius');

    Future<Rect> mountEditorAndAwaitReady(GlobalKey rootKey) async {
      await tester.pumpWidget(
        RepaintBoundary(
          key: rootKey,
          child: MaterialApp(home: EditorScreen(lessonId: _lessonId, onOpenEditor: (_) {}, onBackToHome: () {})),
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
      return tester.getRect(find.byKey(const Key('artboard-gesture-area')));
    }

    var rootKey = GlobalKey();
    var artboardRect = await mountEditorAndAwaitReady(rootKey);

    // Max brush width (a small brush could hide the bug).
    await tester.drag(find.byType(Slider), const Offset(1000, 0));
    await tester.pump();

    Offset localCenteredOffset(Size rectSize) {
      final fit = baseFitScale(rectSize);
      final rendered = kArtworkSize * fit;
      return Offset((rectSize.width - rendered) / 2, (rectSize.height - rendered) / 2);
    }

    double knownScale = 1.0;
    Offset knownOffset = localCenteredOffset(artboardRect.size);

    Offset currentScreenPos(Offset artworkPoint) {
      final fit = baseFitScale(artboardRect.size);
      return artboardRect.topLeft + knownOffset + artworkPoint * fit * knownScale;
    }

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

    Future<void> settleAsyncWork() async {
      await tester.runAsync(() async {
        for (var i = 0; i < 30; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pump();
    }

    /// A short DRAGGED stroke (not a single tap) starting at `pair.inside`
    /// and running tangent to the local boundary (perpendicular to the
    /// inside->outside direction) for a few steps, brushing close to the
    /// boundary throughout — mirroring the reported repro ("paint along
    /// the upper hair contour") far more closely than a single dot.
    Future<void> dragLockedStroke(({Offset inside, Offset outside}) pair) async {
      final boundaryVector = pair.outside - pair.inside;
      final tangent = Offset(-boundaryVector.dy, boundaryVector.dx);
      final tangentUnit = tangent / tangent.distance;
      final artworkSteps = List.generate(5, (i) => pair.inside + tangentUnit * (i * 6.0));

      final screenSteps = artworkSteps.map(currentScreenPos).toList();
      final gesture = await tester.startGesture(screenSteps.first);
      for (final p in screenSteps.skip(1)) {
        await gesture.moveTo(p);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await settleAsyncWork();
    }

    final boundaryPair = pair!;

    // Warm-up (flutter_test FakeAsync quirk on the first real gesture —
    // see the sibling high-zoom test's identical note).
    final warmUpPoint = Offset((boundaryPair.inside.dx + 400) % kArtworkSize, (boundaryPair.inside.dy + 400) % kArtworkSize);
    await tester.tapAt(currentScreenPos(warmUpPoint));
    await settleAsyncWork();
    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();

    // ---- SCENARIO 1: 1x, dragged Locked stroke, then leave and reopen ----
    final outsideBefore1 = await sampleAt(currentScreenPos(boundaryPair.outside));
    expect(outsideBefore1.toARGB32(), 0xFFFFFFFF, reason: 'precondition: outside must sample clean white before painting');

    await dragLockedStroke(boundaryPair);

    final insideAfterLive1 = await sampleAt(currentScreenPos(boundaryPair.inside));
    expect(insideAfterLive1.toARGB32(), _brushColor.toARGB32(), reason: '1x LIVE: sanity check, the drag must paint at its own start point');
    final outsideAfterLive1 = await sampleAt(currentScreenPos(boundaryPair.outside));
    expect(
      outsideAfterLive1.toARGB32(),
      outsideBefore1.toARGB32(),
      reason: '1x LIVE: LOCKED drag must not bleed past the region boundary before reload',
    );
    debugPrint('[TEST] 1x LIVE: LOCKED drag containment holds ok');

    // Leave the Editor (dispose) and reopen the SAME lesson (fresh
    // EditorController -> _load -> getDrawingState -> _hydrateStrokes).
    rootKey = GlobalKey();
    artboardRect = await mountEditorAndAwaitReady(rootKey);
    knownScale = 1.0;
    knownOffset = localCenteredOffset(artboardRect.size);

    final insideAfterReload1 = await sampleAt(currentScreenPos(boundaryPair.inside));
    expect(insideAfterReload1.toARGB32(), _brushColor.toARGB32(), reason: '1x RELOAD: the drag must still be visible after reopening');
    final outsideAfterReload1 = await sampleAt(currentScreenPos(boundaryPair.outside));
    expect(
      outsideAfterReload1.toARGB32(),
      0xFFFFFFFF,
      reason: '1x RELOAD: LOCKED drag must have NO leak after leaving and reopening the lesson',
    );
    debugPrint('[TEST] 1x RELOAD: LOCKED drag containment holds ok');

    // Undo history is restored on load (PASS 4 §17) -- clear Scenario 1's
    // reloaded stroke so Scenario 2 can reuse the SAME region cleanly.
    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();
    final insideAfterUndo = await sampleAt(currentScreenPos(boundaryPair.inside));
    expect(insideAfterUndo.toARGB32(), 0xFFFFFFFF, reason: 'precondition: undo must fully clear Scenario 1\'s reloaded stroke before Scenario 2');

    // ---- SCENARIO 2: 4x + pan, dragged Locked stroke, then leave and reopen ----
    await tester.drag(find.byType(Slider), const Offset(1000, 0)); // max width again (fresh controller)
    await tester.pump();

    final f0 = currentScreenPos(boundaryPair.inside);
    final targetFocal = f0 + const Offset(20, -15); // pan while zooming
    const halfStart = 40.0;
    const halfEnd = halfStart * 20.0; // extreme ratio -> clamps to exactly kMaxZoomScale (4.0)
    final gestureA = await tester.startGesture(f0 - const Offset(halfStart, 0));
    final gestureB = await tester.startGesture(f0 + const Offset(halfStart, 0));
    await tester.pump();
    await gestureA.moveTo(targetFocal - const Offset(halfEnd, 0));
    await gestureB.moveTo(targetFocal + const Offset(halfEnd, 0));
    await tester.pump();
    await gestureA.up();
    await gestureB.up();
    await tester.pump();

    final fit = baseFitScale(artboardRect.size);
    knownScale = 4.0;
    knownOffset = (targetFocal - artboardRect.topLeft) - boundaryPair.inside * fit * 4.0;

    final outsideBefore2 = await sampleAt(currentScreenPos(boundaryPair.outside));
    expect(outsideBefore2.toARGB32(), 0xFFFFFFFF, reason: 'precondition: outside must sample clean white before painting, at 4x+pan');

    await dragLockedStroke(boundaryPair);

    final insideAfterLive2 = await sampleAt(currentScreenPos(boundaryPair.inside));
    expect(insideAfterLive2.toARGB32(), _brushColor.toARGB32(), reason: '4x+pan LIVE: sanity check, the drag must paint at its own start point');
    final outsideAfterLive2 = await sampleAt(currentScreenPos(boundaryPair.outside));
    expect(
      outsideAfterLive2.toARGB32(),
      outsideBefore2.toARGB32(),
      reason: '4x+pan LIVE: LOCKED drag must not bleed past the region boundary before reload',
    );
    debugPrint('[TEST] 4x+pan LIVE: LOCKED drag containment holds ok');

    // Leave and reopen again.
    rootKey = GlobalKey();
    artboardRect = await mountEditorAndAwaitReady(rootKey);
    knownScale = 1.0;
    knownOffset = localCenteredOffset(artboardRect.size);

    final insideAfterReload2 = await sampleAt(currentScreenPos(boundaryPair.inside));
    expect(insideAfterReload2.toARGB32(), _brushColor.toARGB32(), reason: '4x+pan RELOAD: the drag must still be visible after reopening');
    final outsideAfterReload2 = await sampleAt(currentScreenPos(boundaryPair.outside));
    expect(
      outsideAfterReload2.toARGB32(),
      0xFFFFFFFF,
      reason: '4x+pan RELOAD: LOCKED drag must have NO leak after leaving and reopening the lesson',
    );
    debugPrint('[TEST] 4x+pan RELOAD: LOCKED drag containment holds ok');
  });
}

/// Copied from editor_locked_brush_region_test.dart (kept file-local, same
/// as that test's own convention) — finds a genuine region-boundary pair
/// using the SAME RegionEngine the app itself uses.
({Offset inside, Offset outside})? _findBoundaryPair(
  Uint8List barrierMask,
  int size, {
  required int xMin,
  required int xMax,
  required int yMin,
  required int yMax,
}) {
  final engine = RegionEngine(size: size, barrierMask: barrierMask);

  Offset? seed;
  for (int y = yMin; y < yMax && seed == null; y += 4) {
    for (int x = xMin; x < xMax; x += 4) {
      if (barrierMask[y * size + x] == 0) {
        seed = Offset(x.toDouble(), y.toDouble());
        break;
      }
    }
  }
  if (seed == null) return null;

  final region = engine.floodFillFrom(seed.dx.toInt(), seed.dy.toInt());
  if (region == null) return null;

  const dirs = [(1, 0), (-1, 0), (0, 1), (0, -1)];
  for (int y = yMin; y < yMax; y++) {
    for (int x = xMin; x < xMax; x++) {
      final idx = y * size + x;
      if (region[idx] == 0) continue;

      for (final (dx, dy) in dirs) {
        for (int step = 1; step <= 6; step++) {
          final nx = x + dx * step;
          final ny = y + dy * step;
          if (nx < 0 || nx >= size || ny < 0 || ny >= size) break;
          final nIdx = ny * size + nx;
          if (barrierMask[nIdx] != 0) continue;
          if (region[nIdx] == 0) {
            final safeX = x - dx * 3;
            final safeY = y - dy * 3;
            if (safeX < 0 || safeX >= size || safeY < 0 || safeY >= size) break;
            if (barrierMask[safeY * size + safeX] != 0 || region[safeY * size + safeX] == 0) break;
            return (inside: Offset(safeX.toDouble(), safeY.toDouble()), outside: Offset(nx.toDouble(), ny.toDouble()));
          }
          break;
        }
      }
    }
  }
  return null;
}
