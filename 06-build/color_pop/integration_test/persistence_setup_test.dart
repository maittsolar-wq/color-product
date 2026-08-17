// PASS 4 persistence verification, phase 1 of 2: drives the real app into a
// known, non-trivial multi-lesson state and exits. This process is then
// killed for real via `adb shell am force-stop com.maitt.colorpop` (outside
// this test binary entirely -- Dart code cannot force-stop its own host
// process), and persistence_verify_test.dart -- a SEPARATE fresh app launch
// -- checks that everything below survived.
//
// Covers, in one pass: basic single-lesson persistence (BabyDeer), per-lesson
// isolation across independently-colored lessons (BerryCupcake, DimSumBowl),
// true-transparent-Erase persistence (DimSumBowl: Fill -> Erase -> Brush),
// a real Restart (BabyDino), MRU color history ordering, and a deliberately
// corrupted save file for one dedicated test lesson (CuteTaco) that must
// never touch any of the other, real lessons under test.

import 'dart:convert';
import 'dart:typed_data';

import 'package:color_pop/core/app_data.dart';
import 'package:color_pop/core/constants.dart';
import 'package:color_pop/features/editor/lesson_artwork_cache.dart';
import 'package:color_pop/features/editor/lesson_preview_cache.dart';
import 'package:color_pop/main.dart';
import 'package:color_pop/repositories/local_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const Color kPink = Color(0xFFFF6D80);
const Color kPurple = Color(0xFFC34AD8);
const Color kBlue = Color(0xFF4A82FF);
const Color kTeal = Color(0xFF2C8E92);
const Color kGreen = Color(0xFF168B2D);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PASS 4 SETUP: paint multiple lessons, Restart one, corrupt one, then exit', (tester) async {
    await tester.pumpWidget(const ColorPopApp());
    await _settle(tester);
    debugPrint('[SETUP] app booted');

    // ---- Scenario: BabyDeer -- Fill pink, then locked Brush purple ---------
    await _openLesson(tester, 'animal_babydeer');
    await _waitForArtworkReady(tester);
    final babydeerPoint = await _paintablePoint(tester, 'animal_babydeer');
    await _selectTool(tester, 'tool-fill');
    await _selectColor(tester, kPink);
    await _tapOnArtboard(tester, babydeerPoint);
    await _selectTool(tester, 'tool-brush');
    await _selectColor(tester, kPurple);
    await _dragOnArtboard(tester, [babydeerPoint, Offset(babydeerPoint.dx + 15, babydeerPoint.dy)]);
    await tester.tap(find.byType(BackButton));
    await _settle(tester);
    debugPrint('[SETUP] BabyDeer: Fill pink + locked Brush purple committed');

    // ---- Scenario: BerryCupcake -- Fill blue (independence partner #1) -----
    await _openLesson(tester, 'food_berrycupcake');
    await _waitForArtworkReady(tester);
    final berryPoint = await _paintablePoint(tester, 'food_berrycupcake');
    await _selectTool(tester, 'tool-fill');
    await _selectColor(tester, kBlue);
    await _tapOnArtboard(tester, berryPoint);
    await tester.tap(find.byType(BackButton));
    await _settle(tester);
    debugPrint('[SETUP] BerryCupcake: Fill blue committed');

    // ---- Scenario: DimSumBowl -- Fill pink, Erase, Brush teal over the ----
    // ---- erased area (independence partner #2 + Erase persistence) --------
    await _openLesson(tester, 'dumpling_dimsumbowl');
    await _waitForArtworkReady(tester);
    final dimsumPoint = await _paintablePoint(tester, 'dumpling_dimsumbowl');
    await _selectTool(tester, 'tool-fill');
    await _selectColor(tester, kPink);
    await _tapOnArtboard(tester, dimsumPoint);
    await _selectTool(tester, 'tool-erase');
    await _dragOnArtboard(tester, [dimsumPoint, Offset(dimsumPoint.dx + 15, dimsumPoint.dy)]);
    await _selectTool(tester, 'tool-brush');
    await _selectColor(tester, kTeal);
    await _dragOnArtboard(tester, [dimsumPoint, Offset(dimsumPoint.dx + 15, dimsumPoint.dy)]);
    await tester.tap(find.byType(BackButton));
    await _settle(tester);
    debugPrint('[SETUP] DimSumBowl: Fill pink -> Erase -> Brush teal committed');

    // ---- Scenario: BabyDino -- Fill green, then a real Restart -------------
    await _openLesson(tester, 'animal_babydino');
    await _waitForArtworkReady(tester);
    final dinoPoint = await _paintablePoint(tester, 'animal_babydino');
    await _selectTool(tester, 'tool-fill');
    await _selectColor(tester, kGreen);
    await _tapOnArtboard(tester, dinoPoint);
    await tester.tap(find.byType(BackButton));
    await _settle(tester);
    // Give the just-committed state a moment to actually reach disk before
    // immediately reverting it -- otherwise resetProgress could race the
    // write it's meant to undo.
    await _settle(tester, duration: const Duration(milliseconds: 500));
    // Exercises exactly what Profile's Restart button calls (see
    // profile_artwork_popup.dart) -- persistent reset, not just in-memory.
    AppData.progressRepository.resetProgress('animal_babydino');
    await LessonPreviewCache.instance.deletePersisted('animal_babydino');
    debugPrint('[SETUP] BabyDino: Fill green committed, then Restart (persistent reset)');

    // ---- Scenario: CuteTaco -- deliberately corrupted save file -----------
    // A dedicated, otherwise-untouched lesson so this can never be mistaken
    // for damage to a real colored lesson's data.
    await LocalStorage.instance.writeBytes(
      'progress/food_cutetaco.json',
      Uint8List.fromList(utf8.encode('{ this is not valid JSON')),
    );
    debugPrint('[SETUP] CuteTaco: corrupt progress file written');

    // ---- Let every fire-and-forget disk write actually finish before the -
    // ---- test process gets force-stopped from outside. --------------------
    await _settle(tester, duration: const Duration(seconds: 2));
    debugPrint('[SETUP] done -- ready for adb shell am force-stop');
  }, timeout: const Timeout(Duration(minutes: 10)));
}

Future<Offset> _paintablePoint(WidgetTester tester, String lessonId) async {
  final lesson = AppData.lessonRepository.findById(lessonId)!;
  final artwork = await LessonArtworkCache.load(lesson);
  return _findPaintablePoint(artwork.barrierMask, xMin: 250, xMax: 550, yMin: 250, yMax: 550);
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

  // This helper is reused across several lessons without always returning
  // to Home in between (Back returns to whichever screen a lesson was
  // opened from, e.g. Library), so the scroll position can already be
  // partway down from finding an EARLIER lesson. Reset to the top first --
  // otherwise a lesson positioned above the current scroll offset could
  // never be reached by the downward-only search below.
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

Future<void> _tapOnArtboard(WidgetTester tester, Offset artworkPoint) async {
  final rect = tester.getRect(find.byKey(const Key('artboard-gesture-area')));
  await tester.tapAt(_artworkPointToGlobal(rect, artworkPoint));
  await _settle(tester);
}

Future<void> _dragOnArtboard(WidgetTester tester, List<Offset> artworkPoints) async {
  final rect = tester.getRect(find.byKey(const Key('artboard-gesture-area')));
  final gesture = await tester.startGesture(_artworkPointToGlobal(rect, artworkPoints.first));
  // The Editor's pointer-arbitration window is 70ms (kBrushMinWidth et al,
  // see EditorController) -- a synthetic drag whose down-to-up span is
  // shorter than that collapses to a single-point dot (matching real touch
  // behavior for a genuinely fast tap-and-release), which would silently
  // under-test multi-point stroke persistence. Clear the window before the
  // first move, same as a real, deliberate drag would.
  await tester.pump(const Duration(milliseconds: 90));
  for (final point in artworkPoints.skip(1)) {
    await gesture.moveTo(_artworkPointToGlobal(rect, point));
    await tester.pump(const Duration(milliseconds: 32));
  }
  await gesture.up();
  await _settle(tester);
}

Offset _artworkPointToGlobal(Rect artboardRect, Offset artworkPoint) {
  return Offset(
    artboardRect.left + artworkPoint.dx / kArtworkSize * artboardRect.width,
    artboardRect.top + artworkPoint.dy / kArtworkSize * artboardRect.height,
  );
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
