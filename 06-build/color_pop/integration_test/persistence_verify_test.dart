// PASS 4 persistence verification, phase 2 of 2: run this ONLY after
// persistence_setup_test.dart has completed AND the app process has been
// genuinely killed via:
//
//   adb -s R7AY30981PA shell am force-stop com.maitt.colorpop
//
// `flutter test integration_test/... -d <device>` always installs + launches
// a brand-new process, so this test binary itself never shares memory with
// the setup run -- everything checked below can only be true if it was
// actually read back from disk during this fresh AppBootstrap.

import 'dart:ui' as ui;

import 'package:color_pop/core/app_data.dart';
import 'package:color_pop/core/constants.dart';
import 'package:color_pop/features/editor/lesson_preview_cache.dart';
import 'package:color_pop/main.dart';
import 'package:color_pop/models/lesson_progress.dart';
import 'package:color_pop/models/stroke.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const Color kPink = Color(0xFFFF6D80);
const Color kPurple = Color(0xFFC34AD8);
const Color kBlue = Color(0xFF4A82FF);
const Color kTeal = Color(0xFF2C8E92);
const Color kGreen = Color(0xFF168B2D);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PASS 4 VERIFY: everything from setup survives a real process kill', (tester) async {
    await tester.pumpWidget(const ColorPopApp());
    // AppBootstrap's Future.wait (asset load + ProgressRepository.init(),
    // real file I/O) needs real wall-clock time on a genuinely fresh
    // process -- give it generous room before asserting anything.
    await _settle(tester, duration: const Duration(seconds: 2));
    debugPrint('[VERIFY] app booted after a real process kill');

    // The corrupted CuteTaco file must not have taken the app down.
    expect(find.text('Manga'), findsWidgets, reason: 'Home must render normally despite one corrupt lesson file');

    // ---- BabyDeer: status + exact chronological strokes restored ----------
    final babydeerProgress = AppData.progressRepository.getProgress('animal_babydeer');
    expect(babydeerProgress, isNotNull, reason: 'BabyDeer status must survive a real process kill');
    expect(babydeerProgress!.status, LessonProgressStatus.inProgress);

    final babydeerStrokes = await AppData.progressRepository.getDrawingState('animal_babydeer');
    expect(babydeerStrokes.length, 2, reason: 'BabyDeer must restore exactly Fill(pink) then Brush(purple)');
    expect(babydeerStrokes[0].tool, StrokeTool.fill);
    expect(babydeerStrokes[0].color.toARGB32(), kPink.toARGB32());
    expect(babydeerStrokes[1].tool, StrokeTool.brush);
    expect(babydeerStrokes[1].color.toARGB32(), kPurple.toARGB32());
    expect(babydeerStrokes[1].locked, true, reason: 'the locked Brush stroke must round-trip its locked flag');
    debugPrint('[VERIFY] BabyDeer progress + strokes ok');

    final babydeerPreview = await LessonPreviewCache.instance.loadPersisted('animal_babydeer');
    expect(babydeerPreview, isNotNull, reason: 'BabyDeer must have a persisted preview PNG on disk');
    debugPrint('[VERIFY] BabyDeer persisted preview ok');

    // Open the real Editor: confirms the region mask was correctly
    // regenerated from the persisted seed point (RegionEngine.floodFillFrom)
    // and that Undo still works against the restored chronological history.
    await _openLesson(tester, 'animal_babydeer');
    await _waitForArtworkReady(tester);
    final babydeerPoint = Offset(babydeerStrokes[0].points.first.x, babydeerStrokes[0].points.first.y);
    final purpleCheckPixel = await _samplePixel(tester, babydeerPoint);
    debugPrint('[VERIFY] babydeer pixel at $babydeerPoint after restore: '
        'a=${purpleCheckPixel.a} r=${purpleCheckPixel.r} g=${purpleCheckPixel.g} b=${purpleCheckPixel.b} '
        '(expected purple ${kPurple.r},${kPurple.g},${kPurple.b})');
    expect(_closeTo(purpleCheckPixel, kPurple), true,
        reason: 'restored artwork must show the purple Brush on top of the pink Fill');
    await _tapUndo(tester);
    final pinkCheckPixel = await _samplePixel(tester, babydeerPoint);
    debugPrint('[VERIFY] babydeer pixel at $babydeerPoint after Undo: '
        'a=${pinkCheckPixel.a} r=${pinkCheckPixel.r} g=${pinkCheckPixel.g} b=${pinkCheckPixel.b} '
        '(expected pink ${kPink.r},${kPink.g},${kPink.b})');
    expect(_closeTo(pinkCheckPixel, kPink), true,
        reason: 'Undo against the restored history must reveal the Fill underneath');
    await tester.tap(find.byType(BackButton));
    await _settle(tester);
    debugPrint('[VERIFY] BabyDeer visual restoration + Undo-after-restart ok');

    // ---- BerryCupcake / DimSumBowl: per-lesson isolation -------------------
    final berryStrokes = await AppData.progressRepository.getDrawingState('food_berrycupcake');
    expect(berryStrokes.length, 1);
    expect(berryStrokes[0].color.toARGB32(), kBlue.toARGB32());

    final dimsumStrokes = await AppData.progressRepository.getDrawingState('dumpling_dimsumbowl');
    expect(dimsumStrokes.length, 3, reason: 'DimSumBowl must restore Fill(pink), Erase, Brush(teal)');
    expect(dimsumStrokes[0].tool, StrokeTool.fill);
    expect(dimsumStrokes[1].tool, StrokeTool.erase);
    expect(dimsumStrokes[2].tool, StrokeTool.brush);
    expect(dimsumStrokes[2].color.toARGB32(), kTeal.toARGB32());
    debugPrint('[VERIFY] BerryCupcake + DimSumBowl independent progress ok');

    // DimSumBowl must show teal where it was erased-then-repainted, NOT a
    // regression to white and NOT the original pink Fill underneath.
    await _openLesson(tester, 'dumpling_dimsumbowl');
    await _waitForArtworkReady(tester);
    final dimsumPoint = Offset(dimsumStrokes[0].points.first.x, dimsumStrokes[0].points.first.y);
    final dimsumPixel = await _samplePixel(tester, dimsumPoint);
    expect(_closeTo(dimsumPixel, kTeal), true, reason: 'Erase-then-repaint must restore to teal, not revert to white or pink');
    expect(_closeTo(dimsumPixel, Colors.white), false);
    expect(_closeTo(dimsumPixel, kPink), false);
    await tester.tap(find.byType(BackButton));
    await _settle(tester);
    debugPrint('[VERIFY] DimSumBowl true-transparent-Erase persistence ok (no white regression)');

    // ---- BabyDino: real Restart must have produced a genuinely clean state
    final babydinoProgress = AppData.progressRepository.getProgress('animal_babydino');
    expect(babydinoProgress, isNull, reason: 'Restarted lesson must be not-started after a real reload, not resurrected');
    final babydinoStrokes = await AppData.progressRepository.getDrawingState('animal_babydino');
    expect(babydinoStrokes, isEmpty);
    final babydinoPreview = await LessonPreviewCache.instance.loadPersisted('animal_babydino');
    expect(babydinoPreview, isNull, reason: 'Restarted lesson must have no persisted preview after reload');
    debugPrint('[VERIFY] BabyDino Restart persisted correctly (clean after reload)');

    // ---- CuteTaco: corrupted file fell back to clean, did not crash -------
    final cutetacoProgress = AppData.progressRepository.getProgress('food_cutetaco');
    expect(cutetacoProgress, isNull, reason: 'A corrupt save file must fall back to not-started, never crash the app');
    final cutetacoStrokes = await AppData.progressRepository.getDrawingState('food_cutetaco');
    expect(cutetacoStrokes, isEmpty);
    debugPrint('[VERIFY] CuteTaco corruption handled gracefully, other lessons unaffected');

    // ---- MRU color history: order preserved, last-picked color first -----
    final history = AppData.progressRepository.colorHistory;
    expect(history.isNotEmpty, true, reason: 'Color history must persist across a real restart');
    expect(history.first.toARGB32(), kGreen.toARGB32(),
        reason: 'the last color picked before force-stop (green, on BabyDino) must be most-recent after reload');
    debugPrint('[VERIFY] MRU color history order ok: ${history.map((c) => c.toARGB32().toRadixString(16)).toList()}');

    debugPrint('[VERIFY] ALL PASS 4 PERSISTENCE CHECKS PASSED');
  }, timeout: const Timeout(Duration(minutes: 10)));
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
    // Scoped to the bottom NavigationBar specifically -- once already on
    // the Library screen, a bare find.text('Library') also matches that
    // screen's own header/title and becomes ambiguous.
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

  // Reset to the top first -- this helper is reused across several lessons
  // without always returning to Home in between, so the scroll position can
  // already be partway down from finding an earlier lesson.
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

Future<void> _tapUndo(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.undo));
  await _settle(tester);
}

Future<Color> _samplePixel(WidgetTester tester, Offset artworkPoint) async {
  final boundary = tester.renderObject(find.byKey(const Key('artboard-repaint-boundary'))) as RenderRepaintBoundary;
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
