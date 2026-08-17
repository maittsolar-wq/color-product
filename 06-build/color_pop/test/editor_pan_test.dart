// PASS 4.1 — one-finger hold-to-pan controller-level tests.
//
// Physical-device testing (see PASS 4.1 report) confirms one-finger
// hold-to-pan at scale 1.0 with zero accidental paint, via `adb shell input
// draganddrop` (a real down-hold-drag-release touch sequence). It could NOT
// confirm the "pan while already pinch-zoomed" combination end-to-end,
// because that requires a genuine two-finger pinch gesture, and this
// specific test device's `adb shell` runs unrooted (`adbd cannot run as
// root in production builds`), so raw `/dev/input` multitouch injection is
// unavailable and `adb shell input` has no multi-pointer primitive.
//
// This test closes that gap at the controller level instead: it drives the
// EXACT same EditorController pointer-handling code the real Editor widget
// calls, with `viewScale` set directly to simulate an already-pinch-zoomed
// state (the same field the real two-finger pinch gesture writes to), and
// uses `tester.pump(duration)` to advance the SAME real `Timer`-based hold
// delay deterministically on Flutter's fake test clock — not a mock, not a
// simulation of the gesture logic, the real production code path.
import 'dart:io';

import 'package:color_pop/core/app_data.dart';
import 'package:color_pop/core/constants.dart';
import 'package:color_pop/features/editor/artwork_coordinates.dart';
import 'package:color_pop/features/editor/editor_controller.dart';
import 'package:color_pop/models/stroke.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePathProviderPlatform extends PathProviderPlatform with MockPlatformInterfaceMixin {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    final dir = await Directory.systemTemp.createTemp('color_pop_pan_test_docs_');
    return dir.path;
  }
}

const _displaySize = Size(400, 400);

Future<EditorController> _readyController(WidgetTester tester, String lessonId) async {
  final controller = EditorController(lessonId: lessonId);
  // Real (non-Timer) async work -- rootBundle.load, ui.instantiateImageCodec
  // -- never completes inside testWidgets' fake-async pump zone by itself;
  // interleaving tester.pump() inside runAsync (same pattern widget_test.dart
  // uses for ProgressRepository.init()'s file I/O) lets platform-channel and
  // real dart:io/dart:ui work actually resolve.
  await tester.runAsync(() async {
    for (var i = 0; i < 100 && !controller.artworkReady; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await tester.pump();
    }
  });
  return controller;
}

void main() {
  setUpAll(() async {
    PathProviderPlatform.instance = _FakePathProviderPlatform();
    await AppData.lessonRepository.load();
    await AppData.progressRepository.init();
  });

  testWidgets('hold past the delay with no movement pans, and commits ZERO paint', (tester) async {
    final controller = await _readyController(tester, 'food_happydonuts');
    addTearDown(controller.dispose);

    expect(controller.viewScale, 1.0, reason: 'starts unzoomed');
    expect(controller.strokes, isEmpty);

    const start = Offset(200, 200);
    await controller.handlePointerDown(1, start, _displaySize);
    // Nothing committed yet -- still arbitrating.
    expect(controller.strokes, isEmpty);
    expect(controller.liveStroke, isNull);

    // Advance the fake clock past the hold-to-pan delay (250ms) with NO
    // intervening move -- this must fire the real Timer and flip into Pan,
    // never a paint confirmation.
    await tester.pump(const Duration(milliseconds: 260));

    // Still zero paint -- entering Pan must not create a live stroke.
    expect(controller.strokes, isEmpty);
    expect(controller.liveStroke, isNull);

    // §4: pan must work at scale == 1.0 -- offset must NOT be forced to zero.
    await controller.handlePointerMove(1, const Offset(200, 80), _displaySize); // drag up 120
    expect(controller.viewOffset, isNot(Offset.zero));
    expect(controller.viewOffset.dy, lessThan(0), reason: 'content must follow the finger -- dragging up moves the artwork up (translate decreases)');
    expect(controller.strokes, isEmpty, reason: 'panning must never paint');
    expect(controller.liveStroke, isNull);

    await controller.handlePointerUp(1);
    expect(controller.strokes, isEmpty);
    expect(controller.canUndo, isFalse, reason: 'a pan gesture must never become an undoable action');
  });

  testWidgets('immediate movement beyond touch-slop confirms paint instantly, not pan', (tester) async {
    final controller = await _readyController(tester, 'food_croissantbreakfast');
    addTearDown(controller.dispose);
    controller.selectTool(EditorTool.brush);
    controller.locked = false; // avoid region-mask timing entirely for this check

    await controller.handlePointerDown(1, const Offset(50, 50), _displaySize);
    // Move well beyond kTouchSlop right away, BEFORE the hold delay would
    // fire -- must confirm as paint immediately (no waiting for 250ms).
    await controller.handlePointerMove(1, const Offset(90, 90), _displaySize);
    expect(controller.liveStroke, isNotNull, reason: 'a real drag must not wait out the hold delay');
    expect(controller.liveStroke!.tool, StrokeTool.brush);

    await controller.handlePointerUp(1);
    expect(controller.strokes.length, 1);
    expect(controller.canUndo, isTrue);
  });

  testWidgets('pan while already zoomed (viewScale simulating a prior pinch) still works and stays clamped', (tester) async {
    final controller = await _readyController(tester, 'animal_babydeer');
    addTearDown(controller.dispose);

    // Simulate "already pinch-zoomed to ~3x" -- the exact field the real
    // two-finger pinch gesture writes (_updateTwoFingerGesture -> viewScale).
    controller.viewScale = 3.0;
    controller.viewOffset = Offset.zero;

    const start = Offset(150, 150);
    await controller.handlePointerDown(2, start, _displaySize);
    await tester.pump(const Duration(milliseconds: 260)); // hold -> Pan
    expect(controller.strokes, isEmpty);

    await controller.handlePointerMove(2, const Offset(250, 250), _displaySize); // drag down-right
    expect(controller.viewScale, 3.0, reason: 'one-finger pan must never change zoom, only two-finger pinch does');
    expect(controller.viewOffset, isNot(Offset.zero));
    // PASS 4.4 §7 full-viewport-bounds clamp: offset must stay within the
    // slack bounds derived from the viewport size (not a square-artwork
    // assumption), same formula the existing two-finger pinch-pan uses.
    final rendered = kArtworkSize * controller.viewScale * baseFitScale(_displaySize);
    final slack = _displaySize.width * EditorController.kPanSlackFactor;
    final minDx = -rendered - slack;
    final maxDx = _displaySize.width + slack;
    expect(controller.viewOffset.dx, inInclusiveRange(minDx, maxDx));

    await controller.handlePointerUp(2);
    expect(controller.strokes, isEmpty);
    expect(controller.canUndo, isFalse);
  });

  testWidgets('a 2nd pointer joining during an active one-finger pan cancels it and hands off to two-finger transform', (tester) async {
    final controller = await _readyController(tester, 'food_cutetaco');
    addTearDown(controller.dispose);

    await controller.handlePointerDown(1, const Offset(150, 150), _displaySize);
    await tester.pump(const Duration(milliseconds: 260)); // -> Pan
    await controller.handlePointerMove(1, const Offset(150, 200), _displaySize);
    final panOffset = controller.viewOffset;
    expect(panOffset, isNot(Offset.zero));

    // 2nd finger joins mid-pan.
    await controller.handlePointerDown(2, const Offset(250, 150), _displaySize);
    // Re-baselined for pinch from wherever the pan left the artwork -- scale
    // starts unchanged until an actual pinch move happens.
    expect(controller.viewScale, 1.0);
    expect(controller.strokes, isEmpty);

    await controller.handlePointerUp(1);
    await controller.handlePointerUp(2);
    expect(controller.strokes, isEmpty, reason: 'no paint from any part of this interrupted sequence');
  });
}
