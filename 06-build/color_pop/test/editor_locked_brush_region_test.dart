// PASS 6.3.1 — a LOCKED Brush stroke must be clipped to the CLOSED REGION
// the stroke started in, not just constrained by the stroke's recorded
// point being inside that region. This test programmatically finds a real
// region-boundary pair from the actual source line art (never a guessed/
// hardcoded pixel coordinate): `inside`, a point comfortably inside some
// closed region, and `outside`, a nearby point (within a max-width Brush's
// own radius) that the SAME flood-filled region does NOT include -- i.e.
// genuinely a different region across a barrier line. A max-width Brush
// dot centered exactly at `inside` mathematically overlaps `outside` if
// nothing constrains it; LOCKED mode must still leave `outside` untouched,
// while UNLOCKED mode (free draw) must be able to reach it.
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
    final dir = await Directory.systemTemp.createTemp('color_pop_locked_brush_region_test_docs_');
    return dir.path;
  }
}

const _brushColor = Color(0xFF168B2D); // green
const _lessonId = 'animal_babydeer';

void main() {
  setUpAll(() async {
    PathProviderPlatform.instance = _FakePathProviderPlatform();
    await AppData.lessonRepository.load();
    await AppData.progressRepository.init();
  });

  testWidgets('LOCKED Brush clips to the starting region; UNLOCKED Brush can cross it', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Find a genuine region-boundary pair from the real source line art
    // BEFORE pumping any widget -- pure data, no rendering involved. The
    // artwork load itself is real asset I/O (rootBundle.load), which --
    // like path_provider/dart:io elsewhere in this suite -- never
    // completes inside flutter_test's FakeAsync pump zone unless wrapped
    // in tester.runAsync.
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

    // Max brush width -- the largest possible radius, so an unclipped dot
    // at `insideArtworkPoint` would definitely reach `outsideArtworkPoint`
    // (guaranteed by the search below capping their distance well under
    // the max radius).
    await tester.drag(find.byType(Slider), const Offset(1000, 0));
    await tester.pump();

    final artboardRect = tester.getRect(find.byKey(const Key('artboard-gesture-area')));
    Offset screenPointFor(Offset artworkPoint) {
      final fit = baseFitScale(artboardRect.size);
      final rendered = kArtworkSize * fit;
      final initialOffset = Offset((artboardRect.width - rendered) / 2, (artboardRect.height - rendered) / 2);
      return artboardRect.topLeft + initialOffset + artworkPoint * fit;
    }

    final insideScreenPoint = screenPointFor(insideArtworkPoint);
    final outsideScreenPoint = screenPointFor(outsideArtworkPoint);

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

    final outsideBefore = await sampleAt(outsideScreenPoint);

    // Warm-up gesture: the very first pointer gesture after the widget
    // settles needs one extra full async+pump cycle to flush (a
    // flutter_test FakeAsync-zone quirk around the first real async op in
    // a test, not app behavior -- confirmed separately on a physical
    // device). Its own paint result isn't asserted on; it just primes the
    // pipeline so the real, targeted taps below are reliable.
    final warmUpArtworkPoint = _findPaintablePoint(artwork.barrierMask, xMin: 250, xMax: 550, yMin: 250, yMax: 550);
    await tester.tapAt(screenPointFor(warmUpArtworkPoint));
    await tester.runAsync(() async {
      for (var i = 0; i < 30; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();

    // A LOCKED tap's pointer-down handler awaits a REAL async region-mask
    // image decode (ui.decodeImageFromPixels) before the dot is even
    // recorded -- like the artwork load above, that never resolves inside
    // a single synchronous pump; it needs real time inside runAsync.
    Future<void> tapAndAwaitAsyncWork(Offset point) async {
      await tester.tapAt(point);
      await tester.runAsync(() async {
        for (var i = 0; i < 30; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pump();
    }

    // ---- LOCKED (default state) — a single max-width dot centered ----
    // exactly at `insideArtworkPoint`.
    await tapAndAwaitAsyncWork(insideScreenPoint);

    final insideAfterLocked = await sampleAt(insideScreenPoint);
    expect(insideAfterLocked.toARGB32(), _brushColor.toARGB32(),
        reason: 'sanity check: the dot must actually paint at its own center');

    final outsideAfterLocked = await sampleAt(outsideScreenPoint);
    expect(outsideAfterLocked.toARGB32(), outsideBefore.toARGB32(),
        reason: 'LOCKED Brush must not bleed past the starting region\'s boundary, even though the dot\'s full radius geometrically reaches this point');
    debugPrint('[TEST] LOCKED: full-radius dot stays inside its starting region, boundary pixel untouched ok');

    // ---- UNLOCKED — the identical stroke must be free to cross it. ----
    await tester.tap(find.byKey(const Key('lock-toggle')));
    await tester.pump();
    await tapAndAwaitAsyncWork(insideScreenPoint);

    final outsideAfterUnlocked = await sampleAt(outsideScreenPoint);
    expect(outsideAfterUnlocked.toARGB32(), _brushColor.toARGB32(),
        reason: 'UNLOCKED Brush must remain free to cross into the neighboring region');
    debugPrint('[TEST] UNLOCKED: the same stroke freely crosses the boundary ok');
  });
}

/// Finds a pair of artwork-space points using the SAME [RegionEngine] the
/// app itself uses: `inside`, a non-barrier point a few pixels from a
/// barrier line, and `outside`, the non-barrier point immediately on the
/// OTHER side of that SAME barrier -- close enough for a large Brush
/// radius to geometrically reach -- that `inside`'s own flood-filled
/// region does NOT contain (a genuine different region/background, not
/// just the far side of a dead-end line stroke).
///
/// Flood-fills exactly ONCE (from any interior point) and then walks the
/// resulting region mask itself to find a true edge pixel -- for each
/// pixel INSIDE the region, checking outward in the four cardinal
/// directions for the first non-barrier pixel beyond the barrier band.
/// Using the region mask's own geometry (rather than a guessed offset
/// distance) means this correctly handles a barrier line at any local
/// orientation/thickness without needing more than one flood fill.
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
      if (region[idx] == 0) continue; // must be inside the found region

      for (final (dx, dy) in dirs) {
        for (int step = 1; step <= 6; step++) {
          final nx = x + dx * step;
          final ny = y + dy * step;
          if (nx < 0 || nx >= size || ny < 0 || ny >= size) break;
          final nIdx = ny * size + nx;
          if (barrierMask[nIdx] != 0) continue; // still inside the barrier band
          if (region[nIdx] == 0) {
            // Back `inside` off by a few more pixels AWAY from the
            // boundary (opposite the outside direction) so it's safely
            // clear of any screen<->artwork rounding error landing it
            // exactly on the barrier line itself.
            final safeX = x - dx * 3;
            final safeY = y - dy * 3;
            if (safeX < 0 || safeX >= size || safeY < 0 || safeY >= size) break;
            if (barrierMask[safeY * size + safeX] != 0 || region[safeY * size + safeX] == 0) break;
            return (inside: Offset(safeX.toDouble(), safeY.toDouble()), outside: Offset(nx.toDouble(), ny.toDouble()));
          }
          break; // reached a non-barrier pixel still in the same region
        }
      }
    }
  }
  return null;
}

/// A deep-interior, boundary-free point -- used purely to calibrate that a
/// LOCKED tap paints at all, independent of the found boundary pair.
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
  throw StateError('No paintable point found in the given box');
}
