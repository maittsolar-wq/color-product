// HIGH-ZOOM BRUSH FIX — exercises the REAL Editor pipeline (screen pointer
// -> viewport transform -> artwork-space coordinate -> Locked-Brush region
// mask -> composited render), not just RegionEngine in isolation, to prove
// LOCKED Brush containment is invariant under Zoom/Pan. Reuses
// editor_locked_brush_region_test.dart's proven methodology (find a real
// region-boundary pair from the actual source line art, then paint a
// max-width dot centered on the `inside` point and assert the `outside`
// point — geometrically within the dot's own radius, so only clipping
// prevents it — stays untouched) but additionally drives a REAL two-finger
// pinch/pan gesture through EditorController's actual arbitration code
// before painting.
//
// The test tracks `knownScale`/`knownOffset` itself, mirroring exactly
// what EditorController.viewScale/viewOffset hold at every point (derived
// purely from the gestures THIS test drives, never read from the
// controller directly, which is private) — this is what makes every
// computed screen point correct across zoom, pan, AND the Normal<->
// Expanded toggle (which changes the viewport's rect/baseFitScale but
// deliberately does NOT re-center viewOffset — see
// EditorController.ensureViewportInitialized's "does NOT re-center on
// later size change" doc).
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
    final dir = await Directory.systemTemp.createTemp('color_pop_highzoom_brush_test_docs_');
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

  testWidgets('LOCKED Brush containment is invariant under 1x, 4x, and 4x+pan zoom', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final lesson = AppData.lessonRepository.findById(_lessonId)!;
    late LessonArtworkData artwork;
    await tester.runAsync(() async {
      artwork = await LessonArtworkCache.load(lesson);
    });
    final pair = _findBoundaryPair(artwork.barrierMask, kArtworkSize, xMin: 40, xMax: 760, yMin: 40, yMax: 760);
    expect(pair, isNotNull, reason: 'this lesson\'s line art must have at least one findable closed-region boundary within a Brush radius');
    final insideArtworkPoint = pair!.inside;
    final outsideArtworkPoint = pair.outside;

    final rootKey = GlobalKey();
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

    // Max brush width (section 11 — a small brush could hide the bug).
    await tester.drag(find.byType(Slider), const Offset(1000, 0));
    await tester.pump();

    Rect artboardRect() => tester.getRect(find.byKey(const Key('artboard-gesture-area')));

    // ---- Tracked view state (this test's own model of the controller's
    // private viewScale/viewOffset, updated only via the SAME formula
    // EditorController._updateTwoFingerGesture uses) ----
    double knownScale = 1.0;
    Offset knownOffset = Offset.zero; // set for real immediately below

    Offset localCenteredOffset(Size rectSize) {
      final fit = baseFitScale(rectSize);
      final rendered = kArtworkSize * fit;
      return Offset((rectSize.width - rendered) / 2, (rectSize.height - rendered) / 2);
    }

    knownOffset = localCenteredOffset(artboardRect().size);

    /// The current GLOBAL screen position of an artwork-space point, per
    /// the tracked view state and the LIVE current rect (so this stays
    /// correct across the Normal<->Expanded toggle even though that
    /// changes the rect's size without the controller re-deriving
    /// knownOffset — exactly mirroring EditorPainter's own forward
    /// transform: screen = viewOffset + viewScale*baseScale*artworkPoint).
    Offset currentScreenPos(Offset artworkPoint) {
      final rect = artboardRect();
      final fit = baseFitScale(rect.size);
      return rect.topLeft + knownOffset + artworkPoint * fit * knownScale;
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

    Future<void> tapAndAwaitAsyncWork(Offset point) async {
      await tester.tapAt(point);
      await settleAsyncWork();
    }

    // Warm-up: the very first pointer gesture after the widget settles
    // needs one extra async+pump cycle to flush reliably (a flutter_test
    // FakeAsync quirk, not app behavior — see the 6.3.1 test's identical
    // note). Tapped well away from the boundary pair so it can't interfere.
    final warmUpPoint = Offset((insideArtworkPoint.dx + 400) % kArtworkSize, (insideArtworkPoint.dy + 400) % kArtworkSize);
    await tapAndAwaitAsyncWork(currentScreenPos(warmUpPoint));
    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();

    /// Drives a REAL two-finger gesture, through EditorController's actual
    /// arbitration code, anchored on `insideArtworkPoint`'s TRUE current
    /// screen position (per the tracked state), ending with the focal at
    /// `newFocalGlobal` and the scale clamped to exactly `targetScale`
    /// (must be kMinZoomScale or kMaxZoomScale — 1.0 or 4.0). The
    /// finger-distance ratio deliberately overshoots far enough that the
    /// CLAMPED result lands on `targetScale` regardless of the view's
    /// actual current scale (always in [1.0, 4.0]): e.g. for 4.0, even the
    /// worst case (already at 1.0) only needs ratio>=4, and ratio=20
    /// clears that with margin from anywhere in range; symmetrically for a
    /// ratio of 0.05 collapsing back down to 1.0. Updates knownScale/
    /// knownOffset to match afterward.
    Future<void> pinchInsideAnchorTo(double targetScale, Offset newFocalGlobal) async {
      final rect = artboardRect();
      final f0 = currentScreenPos(insideArtworkPoint);
      final ratio = targetScale >= 4.0 ? 20.0 : 0.05;
      const halfStart = 40.0;
      final halfEnd = halfStart * ratio;

      final gestureA = await tester.startGesture(f0 - const Offset(halfStart, 0));
      final gestureB = await tester.startGesture(f0 + const Offset(halfStart, 0));
      await tester.pump();
      await gestureA.moveTo(newFocalGlobal - Offset(halfEnd, 0));
      await gestureB.moveTo(newFocalGlobal + Offset(halfEnd, 0));
      await tester.pump();
      await gestureA.up();
      await gestureB.up();
      await tester.pump();

      final fit = baseFitScale(rect.size);
      knownScale = targetScale;
      knownOffset = (newFocalGlobal - rect.topLeft) - insideArtworkPoint * fit * targetScale;
    }

    /// Resets the view to exactly scale 1.0 / centered (the SAME formula
    /// ensureViewportInitialized uses, re-derived for whatever the CURRENT
    /// rect is), then undoes the scenario's committed stroke. Run between
    /// every scenario below so each one starts from an identical,
    /// verified-clean slate regardless of what the previous scenario did
    /// to zoom/pan/lock.
    Future<void> resetForNextScenario() async {
      final rect = artboardRect();
      final centeredFocal = rect.topLeft + localCenteredOffset(rect.size) + insideArtworkPoint * baseFitScale(rect.size);
      await pinchInsideAnchorTo(1.0, centeredFocal);
      await tester.tap(find.byIcon(Icons.undo));
      await tester.pump();
    }

    /// Runs the shared "max-width LOCKED dot at `inside` must never touch
    /// `outside`" assertion against whatever view transform is currently
    /// tracked. Leaves the stroke committed — callers must
    /// resetForNextScenario() before the next scenario.
    Future<void> assertLockedContainment(String label) async {
      final insideScreen = currentScreenPos(insideArtworkPoint);
      final outsideScreen = currentScreenPos(outsideArtworkPoint);

      final outsideBefore = await sampleAt(outsideScreen);
      // A precondition, not the thing under test: if this ever fires, the
      // computed screen point drifted onto the barrier line itself (a test
      // precision problem), which would make the containment assertion
      // below meaningless rather than a genuine pass or fail.
      expect(
        outsideBefore.toARGB32(),
        0xFFFFFFFF,
        reason: '[$label] precondition: outsideScreen must sample clean white background before painting, not the barrier line',
      );

      await tapAndAwaitAsyncWork(insideScreen);

      final insideAfter = await sampleAt(insideScreen);
      expect(insideAfter.toARGB32(), _brushColor.toARGB32(), reason: '[$label] sanity check: the dot must actually paint at its own center');

      final outsideAfter = await sampleAt(outsideScreen);
      expect(
        outsideAfter.toARGB32(),
        outsideBefore.toARGB32(),
        reason: '[$label] LOCKED Brush must not bleed past the starting region\'s boundary at this zoom/pan state',
      );
      debugPrint('[TEST] $label: LOCKED containment holds ok');
    }

    // ---- TEST A: 1x (baseline) ----
    await assertLockedContainment('1x');
    await resetForNextScenario();

    // ---- TEST B: 4x zoom, no pan ----
    await pinchInsideAnchorTo(4.0, currentScreenPos(insideArtworkPoint));
    await assertLockedContainment('4x (no pan)');
    await resetForNextScenario();

    // ---- TEST C: 4x zoom + pan (checks for stale transform/origin math) ----
    await pinchInsideAnchorTo(4.0, currentScreenPos(insideArtworkPoint) + const Offset(24, -18));
    await assertLockedContainment('4x + pan');
    await resetForNextScenario();

    // ---- TEST D: UNLOCKED must still be free to cross, even at 4x ----
    await tester.tap(find.byKey(const Key('lock-toggle')));
    await tester.pump();
    await pinchInsideAnchorTo(4.0, currentScreenPos(insideArtworkPoint));
    final unlockedOutsideBefore = await sampleAt(currentScreenPos(outsideArtworkPoint));
    expect(unlockedOutsideBefore.toARGB32(), 0xFFFFFFFF, reason: 'precondition: outsideScreen must sample clean white background');
    await tapAndAwaitAsyncWork(currentScreenPos(insideArtworkPoint));
    final unlockedOutsideAfter = await sampleAt(currentScreenPos(outsideArtworkPoint));
    expect(
      unlockedOutsideAfter.toARGB32(),
      _brushColor.toARGB32(),
      reason: 'UNLOCKED Brush must remain free to cross into the neighboring region at 4x zoom',
    );
    debugPrint('[TEST] UNLOCKED at 4x: still freely crosses the boundary ok');
    await resetForNextScenario();
    await tester.tap(find.byKey(const Key('lock-toggle')));
    await tester.pump(); // back to Locked for the remaining scenario

    // ---- TEST E: Expanded mode, 4x zoom — must match Normal mode exactly ----
    await tester.tap(find.byKey(const Key('maximize-button')));
    await tester.pump();
    // Expanded mode changes the artboard's padding (24 -> 12), so its
    // rect/baseFitScale differ even though viewScale/viewOffset didn't
    // change on the toggle itself — re-center explicitly for the NEW rect
    // before zooming, exactly like resetForNextScenario does elsewhere
    // (there's no stroke to undo here, so inlined rather than reused).
    final expandedRect = artboardRect();
    final expandedCenteredFocal =
        expandedRect.topLeft + localCenteredOffset(expandedRect.size) + insideArtworkPoint * baseFitScale(expandedRect.size);
    await pinchInsideAnchorTo(1.0, expandedCenteredFocal);
    await pinchInsideAnchorTo(4.0, currentScreenPos(insideArtworkPoint));
    await assertLockedContainment('Expanded 4x');
    await tester.tap(find.byKey(const Key('minimize-button')));
    await tester.pump();
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
