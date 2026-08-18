import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';

import '../../core/app_data.dart';
import '../../core/constants.dart';
import '../../models/lesson_model.dart';
import '../../models/persisted_stroke.dart';
import '../../models/stroke.dart';
import 'artwork_coordinates.dart';
import 'lesson_artwork_cache.dart';
import 'lesson_preview_cache.dart';
import 'region_engine.dart';

enum EditorTool { brush, fill, erase, eyedropper }

const double kBrushMinWidth = 8;
const double kBrushMaxWidth = 64;
const int kHistoryLimit = 15;

const double kMinZoomScale = 1.0;
const double kMaxZoomScale = 4.0;

const int kMaxColorHistory = 10;

const List<Color> kEditorPresetColors = [
  Color(0xFF168B2D), // green
  Color(0xFFFF6D80), // pink
  Color(0xFF4A82FF), // blue
  Color(0xFFC34AD8), // purple
  Color(0xFF0D0D0D), // black
  Color(0xFFF4F4F4), // white
  Color(0xFF2C8E92), // teal
  Color(0xFFF4E6BE), // cream
];

// PASS 4.5 — the live magnifying loupe. Diameter/magnification chosen to
// sit inside the spec's "60-90px diameter / 4x-8x magnification" ranges;
// tuned on the physical device (see PASS 4.5 report).
const double kLoupeDiameter = 76;
const double kLoupeMagnification = 6.0;

/// The result of one eyedropper capture: a small crop of the ACTUAL
/// rendered/composited artboard already centered on the sample point (the
/// loupe's direct rendering source -- see EditorScreen._captureColorAt),
/// plus the exact pixel color at its center. Ownership of `image` passes to
/// whoever stores it on EditorController; it must be disposed exactly once.
typedef EyedropperCapture = ({ui.Image image, Color color});

class LiveStroke {
  LiveStroke({
    required this.tool,
    required this.color,
    required this.width,
    required this.points,
    this.regionMaskImage,
  });

  final StrokeTool tool;
  final Color color;
  final double width;
  final List<StrokePoint> points;
  final ui.Image? regionMaskImage;
}

/// Owns ALL Editor drawing state and tool logic for one open lesson. A
/// fresh EditorController is created each time SCR-EDITOR-001 opens (see
/// EditorScreen) — per-lesson isolation itself lives in ProgressRepository
/// (getDrawingState/saveDrawingState), which this controller reads from on
/// load and writes to on every committed change.
///
/// PASS 2.1: Fill, Brush and Erase all live in ONE chronologically ordered
/// action list (`strokes`) — see EditorPainter, which replays them in that
/// exact order inside a single shared layer every frame.
///
/// PASS 3: Zoom/Pan view-transform state (viewport-only), Eyedropper.
///
/// PASS 3.1: robust pointer ARBITRATION (§1) — a single active pointer no
/// longer commits ANY paint action (not even a live-stroke dot) until a
/// short window has passed with no 2nd pointer joining, so a two-finger
/// pinch/pan can never leave a mark under the first finger. Also: MRU color
/// history replaces the old fixed presets + separate custom slot (§7), an
/// Expanded/Focus mode flag (§5), and an explicit Save/Done commit (§4).
///
/// PASS 4.1: the single-pointer arbitration window above is now ALSO a
/// hold-to-pan recognizer. A pointer that stays within [kTouchSlop] of its
/// down point for [_holdToPanDelay] is promoted to one-finger Pan instead of
/// being confirmed as a paint action — see _beginHoldToPan. A pointer that
/// moves beyond that tolerance first is confirmed as paint immediately
/// (never waits out the full delay), so Brush/Erase stay instant.
class EditorController extends ChangeNotifier {
  EditorController({required this.lessonId}) {
    _load();
  }

  final String lessonId;
  LessonModel? lesson;

  bool artworkReady = false;
  ui.Image? lineArtImage;
  RegionEngine? _regionEngine;

  /// The single chronological user-paint action list: Fill, Brush and Erase
  /// entries in the exact order the user performed them.
  List<BrushStroke> strokes = [];
  LiveStroke? _liveStroke;
  LiveStroke? get liveStroke => _liveStroke;

  EditorTool activeTool = EditorTool.brush;
  Color activeColor = kEditorPresetColors.first;
  double brushSliderValue = 40; // 0-100
  bool locked = true;
  bool expandedMode = false;

  // --- MRU color history (§7) ----------------------------------------------
  // Replaces the old fixed preset row + separate custom slot entirely: ONE
  // list, most-recently-used at index 0, max kMaxColorHistory, no duplicate
  // colors (exact ARGB equality). activeColor is always colorHistory.first
  // immediately after any promotion, so "which swatch is selected" needs no
  // separate boolean flag — a swatch is selected iff its color == activeColor.
  List<Color> colorHistory = List.of(kEditorPresetColors);

  void _promoteColor(Color color) {
    colorHistory.removeWhere((c) => c.toARGB32() == color.toARGB32());
    colorHistory.insert(0, color);
    if (colorHistory.length > kMaxColorHistory) {
      colorHistory.removeRange(kMaxColorHistory, colorHistory.length);
    }
    activeColor = color;
    // PASS 4 §16: MRU history is app-level (not per-lesson), so it survives
    // across restarts and across opening different lessons. A deliberate
    // swatch tap/confirm is a committed action, not pointermove-frequency,
    // so persisting on every promotion is safe.
    AppData.progressRepository.saveColorHistory(colorHistory);
  }

  /// A committed color choice — preset/history swatch tap, Playful Save, or
  /// Eyedropper release all funnel through here (directly or via
  /// commitCustomColor). NOT called while merely dragging inside the HSV
  /// picker (that's local draft state until Save).
  void selectColor(Color color) {
    _promoteColor(color);
    notifyListeners();
  }

  /// Playful Save and Eyedropper release both call this ONE method — same
  /// promotion path as selectColor, kept as a separate name because those
  /// two call sites are conceptually "committing a possibly-new color"
  /// rather than "picking an existing swatch."
  void commitCustomColor(Color color) {
    _promoteColor(color);
    notifyListeners();
  }

  // --- View transform (Zoom/Pan) -------------------------------------------
  // Viewport-only (§8): never scales stored Brush paths, never rewrites
  // Fill masks, never alters lesson progress or source artwork. Lives on
  // the controller (not widget-local State) so it's naturally preserved
  // across the Normal<->Expanded mode toggle, which reuses this same
  // controller instance rather than recreating the Editor.
  double viewScale = kMinZoomScale;
  Offset viewOffset = Offset.zero;

  // PASS 4.4 §7/§9: the viewport is now the FULL grey workspace rect (which
  // LayoutBuilder only reports once actual layout happens), not a fixed
  // square known in advance -- so the centered starting position has to be
  // computed lazily, once, the first time the real viewport size is known.
  // Deliberately does NOT re-center on every later size change (e.g. the
  // Normal<->Expanded toggle reusing this same controller against a
  // differently-sized viewport) -- per §16, the same scale/translation
  // state is preserved across that toggle rather than re-derived.
  bool _viewportInitialized = false;

  /// Called from the artboard's LayoutBuilder on every build; a no-op after
  /// the first real viewport size is seen. Centers the unzoomed 800x800
  /// sheet inside the viewport by default -- mutates plain fields only (no
  /// notifyListeners), since this always runs synchronously during layout,
  /// before the same frame's paint.
  void ensureViewportInitialized(Size viewportSize) {
    if (_viewportInitialized) return;
    final fit = baseFitScale(viewportSize);
    final rendered = kArtworkSize * fit;
    viewOffset = Offset((viewportSize.width - rendered) / 2, (viewportSize.height - rendered) / 2);
    _viewportInitialized = true;
  }

  // Raw multi-pointer tracking for the artboard. Deliberately NOT
  // GestureDetector's scale recognizer — that competes in the same gesture
  // arena as single-pointer tool input, and can't guarantee "two pointers
  // never produce a paint action." Tracking pointers ourselves (via
  // Listener, which never enters an arena) gives that guarantee directly.
  final Map<int, Offset> _activePointers = {};
  Offset? _twoFingerStartFocal;
  double? _twoFingerStartDistance;
  double? _twoFingerStartScale;
  Offset? _twoFingerStartOffset;

  // --- Pointer ARBITRATION (§1) + PASS 4.1 hold-to-pan -----------------------
  // A single pointer-down does NOT immediately become a paint action. It
  // becomes "pending" for a short window. Three ways out:
  //   1. A 2nd pointer joins -> discarded outright (nothing was ever
  //      committed — no dot, no live stroke, no Fill, no Eyedropper sample).
  //   2. It moves beyond `kTouchSlop`, or is released, before the hold delay
  //      elapses -> confirmed immediately as genuine single-pointer painting
  //      (a real drag never waits out the delay; a fast tap resolves on up).
  //   3. The hold delay elapses with the pointer still down and still within
  //      `kTouchSlop` of its start -> promoted to one-finger PAN instead
  //      (§1B) — the pending paint state is discarded with zero committed
  //      paint, and the rest of this gesture only ever pans, never paints.
  static const Duration _holdToPanDelay = Duration(milliseconds: 250);
  int? _pendingPointerId;
  Offset? _pendingLocalPosition;
  Size? _pendingDisplaySize;
  final List<Offset> _pendingMovePositions = [];
  Timer? _pendingArbitrationTimer;
  bool _paintingConfirmed = false;

  // One-finger Pan state (§1B, §4, §5) — armed by _beginHoldToPan once the
  // hold delay elapses; the artwork translates by the raw screen-space
  // delta from the pan's start point, independent of viewScale (viewOffset
  // is applied BEFORE scale in EditorPainter's transform chain).
  bool _singlePointerPanning = false;
  Offset? _panStartLocalPosition;
  Offset? _panStartViewOffset;

  /// Set by EditorScreen to bridge to the widget-layer pixel capture the
  /// Eyedropper needs (reading the actual RENDERED/composited artboard —
  /// see class doc on why that lives outside the controller).
  Future<EyedropperCapture?> Function(Offset localPosition)? sampleColorAt;
  bool _eyedropperSampling = false;
  Future<void>? _pendingEyedropperSample;
  int _eyedropperSampleToken = 0;
  Color? eyedropperPreviewColor;
  Offset? eyedropperPreviewLocalPosition;

  // PASS 4.5 — the small live crop backing the loupe (see EyedropperCapture
  // doc). Owned here; disposed whenever replaced, cleared, or the
  // controller itself is disposed -- never left to leak GPU memory.
  ui.Image? _eyedropperSourceImage;
  ui.Image? get eyedropperSourceImage => _eyedropperSourceImage;

  final List<BrushStroke> _undoStack = [];
  final List<BrushStroke> _redoStack = [];

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  double get brushWidth => kBrushMinWidth + (brushSliderValue / 100) * (kBrushMaxWidth - kBrushMinWidth);

  Future<void> _load() async {
    final resolvedLesson = AppData.lessonRepository.findById(lessonId);
    lesson = resolvedLesson;
    if (resolvedLesson == null) {
      notifyListeners();
      return;
    }

    final artworkData = await LessonArtworkCache.load(resolvedLesson);
    lineArtImage = artworkData.lineArtImage;
    final regionEngine = RegionEngine(size: kArtworkSize, barrierMask: artworkData.barrierMask);
    _regionEngine = regionEngine;

    // Restore THIS lesson's saved chronological actions, never another
    // lesson's — the per-lesson isolation contract (§16). Fill/locked-Brush
    // masks are NOT stored as pixels; they're regenerated deterministically
    // from each stroke's seed point via the same RegionEngine call the live
    // engine already makes (see _hydrateStrokes).
    final persisted = await AppData.progressRepository.getDrawingState(lessonId);
    strokes = await _hydrateStrokes(persisted, regionEngine);

    // PASS 4 §17: restore Undo history too, not just the visual result --
    // otherwise Undo silently no-ops (disabled button) immediately after a
    // restart, even though the same action would have been undoable a
    // moment before the app was killed. Capped the same way a live session
    // caps it. Redo is deliberately NOT restored (there is nothing to
    // redo into -- only committed actions are persisted) -- it starts
    // empty on every fresh app launch, same as a lesson opened for the
    // first time.
    _undoStack
      ..clear()
      ..addAll(strokes.length > kHistoryLimit ? strokes.sublist(strokes.length - kHistoryLimit) : strokes);
    _redoStack.clear();

    // App-level MRU color history (§16) — falls back to the default preset
    // row only if nothing has ever been persisted.
    final persistedHistory = AppData.progressRepository.colorHistory;
    if (persistedHistory.isNotEmpty) {
      colorHistory = List.of(persistedHistory);
      activeColor = colorHistory.first;
    }

    artworkReady = true;
    notifyListeners();
  }

  /// Reconstructs live [BrushStroke]s (with regenerated `ui.Image?` region
  /// masks) from disk-persisted plain-data [PersistedStroke]s. A stroke
  /// whose seed point no longer resolves to a valid region (should not
  /// happen in practice, since the same point was validated at commit time,
  /// but corruption/edge cases are possible) is skipped rather than drawn
  /// unclipped — mirroring how Fill itself refuses to commit with no mask.
  Future<List<BrushStroke>> _hydrateStrokes(List<PersistedStroke> persisted, RegionEngine regionEngine) async {
    final result = <BrushStroke>[];
    for (final p in persisted) {
      ui.Image? maskImage;
      final needsMask = p.tool == StrokeTool.fill || (p.tool == StrokeTool.brush && p.locked);
      if (needsMask) {
        final seed = p.points.first;
        final mask = regionEngine.floodFillFrom(seed.x.round(), seed.y.round());
        if (mask == null) continue; // cannot reconstruct this action safely -- skip it
        maskImage = await _maskToImage(mask);
      }
      result.add(BrushStroke(
        tool: p.tool,
        color: p.color,
        width: p.width,
        points: p.points.map((pt) => StrokePoint(pt.x, pt.y)).toList(),
        regionMaskImage: maskImage,
      ));
    }
    return result;
  }

  // --- Tool / brush-size / lock / mode selection ----------------------------
  // Session-only — never pushed onto the undo/redo history.

  void selectTool(EditorTool tool) {
    if (activeTool == EditorTool.eyedropper && tool != EditorTool.eyedropper) {
      // Switching away from Eyedropper via the tool rail (not by
      // completing/cancelling a sample) still needs to drop any in-flight
      // preview/loupe state cleanly.
      _clearEyedropperPreview();
    }
    activeTool = tool;
    notifyListeners();
  }

  /// Cycles Brush -> Fill -> Erase -> Brush — the only tool-switch surface
  /// available while Expanded (§5's Active Tool control); the full rail is
  /// intentionally hidden there.
  void cycleTool() {
    const order = [EditorTool.brush, EditorTool.fill, EditorTool.erase];
    final current = order.indexOf(activeTool);
    selectTool(order[(current < 0 ? 0 : current + 1) % order.length]);
  }

  void setBrushSliderValue(double value) {
    brushSliderValue = value;
    notifyListeners();
  }

  void toggleLock() {
    locked = !locked;
    notifyListeners();
  }

  void toggleExpandedMode() {
    expandedMode = !expandedMode;
    notifyListeners();
  }

  /// Enters live sampling mode (§9). PASS 4.5 §14: Eyedropper is now
  /// "sticky" — after a pick commits, the Editor stays in Pick mode (ready
  /// for another pick) rather than silently reverting to whatever tool was
  /// active before; the user leaves Pick explicitly via the tool rail.
  void activateEyedropper() {
    if (activeTool == EditorTool.eyedropper) return;
    activeTool = EditorTool.eyedropper;
    notifyListeners();
  }

  /// PASS 5 §2 — the Done action. Unlike the fire-and-forget autosave path
  /// (_commitDrawingState, used by every stroke/undo/redo/exit commit),
  /// every step here is durably AWAITED before returning, so the caller
  /// (EditorScreen's Done handler) can push Completion only once the
  /// drawing state, the discovery-screen preview, AND the COMPLETED status
  /// are all guaranteed to survive an immediate process kill (§8/§18 TEST
  /// G). COMPLETED means the user tapped Done — nothing here inspects
  /// coverage/percentage, and nothing here resets or alters the artwork.
  Future<void> completeLesson() async {
    if (!artworkReady) return;
    final resolvedLesson = lesson;
    if (resolvedLesson == null) return;

    final persisted = strokes.map(_toPersistedStroke).toList();
    await AppData.progressRepository.saveDrawingState(lessonId, persisted);
    await LessonPreviewCache.instance.renderAndPersist(resolvedLesson, List.of(strokes));
    await AppData.progressRepository.completeLesson(lessonId);
  }

  // --- View transform helpers ----------------------------------------------

  // PASS 4.4 §7: the viewport is now the FULL grey workspace, not a small
  // square sized to the artwork, so the ArtworkSurface must be able to
  // traverse that whole rectangle — top/bottom/left/right/diagonal — at
  // every scale, not just wiggle near a fixed center. minDx/maxDx (and Y)
  // range from "sheet's trailing edge at the viewport's leading edge" to
  // "sheet's leading edge at the viewport's trailing edge" (i.e. the sheet
  // can go anywhere from just-off-screen-left to just-off-screen-right),
  // plus a modest slack margin beyond that for a bit of overshoot give.
  // Still always recoverable: the gesture area covers the full viewport
  // regardless of where the sheet currently renders, so it can always be
  // grabbed and dragged back even while fully off-screen.
  static const double kPanSlackFactor = 0.2;

  Offset _clampOffset(Offset raw, double scale, Size viewportSize) {
    final rendered = kArtworkSize * scale * baseFitScale(viewportSize);
    final slackX = viewportSize.width * kPanSlackFactor;
    final slackY = viewportSize.height * kPanSlackFactor;
    final minDx = -rendered - slackX;
    final maxDx = viewportSize.width + slackX;
    final minDy = -rendered - slackY;
    final maxDy = viewportSize.height + slackY;
    return Offset(raw.dx.clamp(minDx, maxDx), raw.dy.clamp(minDy, maxDy));
  }

  void _startTwoFingerGesture() {
    final points = _activePointers.values.toList();
    if (points.length != 2) return;
    _twoFingerStartFocal = Offset((points[0].dx + points[1].dx) / 2, (points[0].dy + points[1].dy) / 2);
    _twoFingerStartDistance = (points[0] - points[1]).distance;
    _twoFingerStartScale = viewScale;
    _twoFingerStartOffset = viewOffset;
  }

  void _updateTwoFingerGesture(Size displaySize) {
    final d0 = _twoFingerStartDistance;
    final f0 = _twoFingerStartFocal;
    final s0 = _twoFingerStartScale;
    final o0 = _twoFingerStartOffset;
    if (_activePointers.length != 2 || d0 == null || d0 == 0 || f0 == null || s0 == null || o0 == null) return;

    final points = _activePointers.values.toList();
    final focal = Offset((points[0].dx + points[1].dx) / 2, (points[0].dy + points[1].dy) / 2);
    final distance = (points[0] - points[1]).distance;
    final newScale = (s0 * (distance / d0)).clamp(kMinZoomScale, kMaxZoomScale);

    // Anchor: the point (in "un-zoomed display" space) that was under the
    // gesture's starting focal point stays under the CURRENT focal point.
    final anchor = (f0 - o0) / s0;
    final newOffset = _clampOffset(focal - anchor * newScale, newScale, displaySize);

    viewScale = newScale;
    viewOffset = newOffset;
    notifyListeners();
  }

  // --- Pointer handling (screen-local coordinates; multi-pointer aware) ----
  // Exactly one active pointer, once ARBITRATED (see above), drives Brush/
  // Fill/Erase. Exactly two drive Zoom/Pan. A second finger arriving at ANY
  // point — during arbitration or after painting was already confirmed —
  // aborts painting outright (§1).
  //
  // PASS 4.5 §12: Eyedropper is the one exception to arbitration entirely —
  // a single finger while Pick is active samples immediately and on every
  // move, with NO hold-to-pan delay and NO touch-slop gate. A deliberate
  // slow drag (exactly how accurate color picking works) must never get
  // hijacked into Pan; priority for Pick mode is continuous, reliable
  // sampling. Two fingers still cancel it in favor of Zoom/Pan (§11).

  Future<void> handlePointerDown(int pointerId, Offset localPosition, Size displaySize) async {
    _activePointers[pointerId] = localPosition;

    if (_activePointers.length == 2) {
      // PASS 4.1 §14: a 2nd pointer arriving at ANY time — mid-arbitration
      // OR mid one-finger Pan — cancels that single-pointer state outright
      // and hands off to two-finger pinch/pan, re-baselined from wherever
      // the artwork currently is (including anywhere one-finger Pan just
      // moved it to). PASS 4.5: also cancels an in-progress Eyedropper
      // sample with zero MRU commit (§11) — the loupe hides immediately.
      _cancelPendingPaintGesture();
      _liveStroke = null;
      _eyedropperSampleToken++; // invalidate any in-flight sample from before this interrupt
      _clearEyedropperPreview();
      notifyListeners();
      _startTwoFingerGesture();
      return;
    }
    if (_activePointers.length > 2) return;

    if (!artworkReady || _regionEngine == null) return;

    if (activeTool == EditorTool.eyedropper) {
      // Bypass arbitration entirely — sample immediately (§1 "pointer down
      // -> immediately show a floating magnifier"). Still record
      // _pendingPointerId/_pendingDisplaySize so a 2nd finger joining mid-
      // drag is recognized and cancelled by the branch above.
      _pendingPointerId = pointerId;
      _pendingDisplaySize = displaySize;
      await _sampleEyedropper(localPosition, displaySize);
      return;
    }

    // Exactly one active pointer -- arm the arbitration/hold-to-pan window.
    // Nothing irreversible happens yet: no live stroke, no Fill. If a 2nd
    // pointer joins before this resolves, the branch above discards it via
    // _cancelPendingPaintGesture with zero visible trace.
    _pendingPointerId = pointerId;
    _pendingLocalPosition = localPosition;
    _pendingDisplaySize = displaySize;
    _pendingMovePositions.clear();
    _paintingConfirmed = false;
    _singlePointerPanning = false;
    _pendingArbitrationTimer?.cancel();
    _pendingArbitrationTimer = Timer(_holdToPanDelay, _beginHoldToPan);
  }

  /// PASS 4.1 §1B/§2/§3 — fires after [_holdToPanDelay] of the pointer
  /// staying down, still within [kTouchSlop] of its start (a real drag
  /// would already have confirmed as paint via handlePointerMove and
  /// cancelled this timer before it ever got here). Promotes the pending
  /// gesture to one-finger Pan: the provisional paint state is discarded
  /// wholesale — no live stroke was ever created, no Fill/Eyedropper ever
  /// sampled — so this gesture contributes ZERO paint no matter what
  /// happens next.
  void _beginHoldToPan() {
    _pendingArbitrationTimer = null;
    if (_paintingConfirmed || _singlePointerPanning) return; // already resolved another way
    final pointerId = _pendingPointerId;
    final startLocal = _pendingLocalPosition;
    if (pointerId == null || startLocal == null) return;
    if (_activePointers.length != 1 || !_activePointers.containsKey(pointerId)) return;

    _pendingMovePositions.clear();
    _singlePointerPanning = true;
    _panStartLocalPosition = startLocal;
    _panStartViewOffset = viewOffset;
    notifyListeners(); // lets the UI reflect "now panning" if it ever wants to (e.g. a cursor/hint)
  }

  void _updateSinglePointerPan(Offset localPosition, Size displaySize) {
    final startLocal = _panStartLocalPosition;
    final startOffset = _panStartViewOffset;
    if (startLocal == null || startOffset == null) return;
    // viewOffset is applied BEFORE viewScale in EditorPainter's transform
    // chain, so a raw screen-space delta translates the whole artwork by
    // exactly that many screen pixels regardless of current zoom (§6/§7).
    final delta = localPosition - startLocal;
    viewOffset = _clampOffset(startOffset + delta, viewScale, displaySize);
    notifyListeners();
  }

  Future<void> handlePointerMove(int pointerId, Offset localPosition, Size displaySize) async {
    if (!_activePointers.containsKey(pointerId)) return;
    _activePointers[pointerId] = localPosition;

    if (_activePointers.length == 2) {
      _updateTwoFingerGesture(displaySize);
      return;
    }
    if (_activePointers.length != 1) return;

    if (activeTool == EditorTool.eyedropper) {
      if (pointerId == _pendingPointerId) {
        await _sampleEyedropper(localPosition, displaySize);
      }
      return;
    }

    // PASS 4.1 §1B/§13 — once Pan Mode has been recognized for this
    // gesture, EVERY subsequent move is a pan and nothing else, until
    // pointerUp/cancel. Never switches back into painting mid-gesture.
    if (_singlePointerPanning) {
      if (pointerId == _pendingPointerId) {
        _updateSinglePointerPan(localPosition, displaySize);
      }
      return;
    }

    if (!_paintingConfirmed) {
      if (pointerId != _pendingPointerId) return;
      // Still arbitrating -- buffer so a fast drag that starts before
      // confirmation doesn't lose its early points, but do not paint yet.
      _pendingMovePositions.add(localPosition);

      // PASS 4.1 §1A — real painting motion (beyond touch-slop) confirms
      // immediately rather than waiting out the hold-to-pan delay, so
      // Brush/Erase drags never feel laggy. Only a pointer that stays near
      // its start point for the full delay becomes a Pan (via
      // _beginHoldToPan / the timer armed in handlePointerDown).
      final start = _pendingLocalPosition;
      if (start != null && (localPosition - start).distance > kTouchSlop) {
        _pendingArbitrationTimer?.cancel();
        _pendingArbitrationTimer = null;
        await _confirmPendingPaintGesture();
      }
      return;
    }

    final artworkPoint = artworkPointFromLocal(localPosition, displaySize, scale: viewScale, offset: viewOffset);
    await _handleToolPointerMove(artworkPoint, localPosition);
  }

  Future<void> handlePointerUp(int pointerId) async {
    final wasPendingPointer = pointerId == _pendingPointerId;

    if (activeTool == EditorTool.eyedropper && wasPendingPointer) {
      // PASS 4.5 §14: commit the final sample directly — Eyedropper never
      // goes through the paint arbitration/confirm pipeline, so there is
      // nothing to retroactively confirm, only the live-sampled state
      // already held in eyedropperPreviewColor to commit.
      _activePointers.remove(pointerId);
      if (_activePointers.length == 2) {
        _startTwoFingerGesture();
      } else {
        _twoFingerStartFocal = null;
        _twoFingerStartDistance = null;
      }
      _pendingPointerId = null;
      _pendingDisplaySize = null;
      await _finishToolGesture();
      return;
    }

    final wasPanning = wasPendingPointer && _singlePointerPanning;
    final wasStillArbitrating = wasPendingPointer && !_paintingConfirmed && !_singlePointerPanning;

    _activePointers.remove(pointerId);
    if (_activePointers.length == 2) {
      _startTwoFingerGesture(); // re-baseline from whichever 2 fingers remain
    } else {
      _twoFingerStartFocal = null;
      _twoFingerStartDistance = null;
    }

    if (wasPanning) {
      // Pan ends with the release -- nothing to commit (viewport-only,
      // never touches strokes/undo history) and nothing was ever pending
      // to confirm as paint (§3).
      _cancelPendingPaintGesture();
      return;
    }

    if (wasStillArbitrating) {
      _pendingArbitrationTimer?.cancel();
      _pendingArbitrationTimer = null;
      if (_activePointers.isEmpty) {
        // Released before the arbitration window elapsed, and no other
        // pointer is (or was) down for this gesture -- this can only ever
        // have been a genuine single-pointer tap. Confirm immediately
        // rather than waiting out the rest of the window.
        await _confirmPendingPaintGesture();
        await _finishToolGesture();
      } else {
        _cancelPendingPaintGesture();
      }
      return;
    }

    if (_activePointers.isEmpty) {
      await _finishToolGesture();
    }
  }

  Future<void> handlePointerCancel(int pointerId) async {
    final wasPendingPointer = pointerId == _pendingPointerId;

    _activePointers.remove(pointerId);
    if (_activePointers.length == 2) {
      _startTwoFingerGesture();
    } else {
      _twoFingerStartFocal = null;
      _twoFingerStartDistance = null;
    }
    if (wasPendingPointer) {
      _cancelPendingPaintGesture();
    }
    if (_activePointers.isEmpty) {
      _cancelToolGesture();
    }
  }

  /// Retroactively begins the actual paint action (Brush/Fill/Erase/
  /// Eyedropper) from the buffered first point, then replays any move
  /// points buffered during arbitration — called either when the
  /// arbitration timer fires, or immediately on a fast tap's pointer-up.
  Future<void> _confirmPendingPaintGesture() async {
    if (_paintingConfirmed) return; // already confirmed via the other path
    final pointerId = _pendingPointerId;
    final firstLocal = _pendingLocalPosition;
    final displaySize = _pendingDisplaySize;
    if (pointerId == null || firstLocal == null || displaySize == null) return;
    if (!_activePointers.containsKey(pointerId) && _activePointers.isNotEmpty) {
      // Pointer already gone AND some other pointer is active -- not a
      // valid single-pointer gesture; discard.
      _cancelPendingPaintGesture();
      return;
    }
    if (_activePointers.length > 1) {
      _cancelPendingPaintGesture();
      return;
    }

    _paintingConfirmed = true;
    final buffered = List<Offset>.of(_pendingMovePositions);
    _pendingMovePositions.clear();

    final artworkPoint = artworkPointFromLocal(firstLocal, displaySize, scale: viewScale, offset: viewOffset);
    await _handleToolPointerDown(artworkPoint, firstLocal);

    for (final pos in buffered) {
      if (_activePointers.length != 1) break;
      final ap = artworkPointFromLocal(pos, displaySize, scale: viewScale, offset: viewOffset);
      await _handleToolPointerMove(ap, pos);
    }
  }

  void _cancelPendingPaintGesture() {
    _pendingArbitrationTimer?.cancel();
    _pendingArbitrationTimer = null;
    _pendingPointerId = null;
    _pendingLocalPosition = null;
    _pendingDisplaySize = null;
    _pendingMovePositions.clear();
    _paintingConfirmed = false;
    _singlePointerPanning = false;
    _panStartLocalPosition = null;
    _panStartViewOffset = null;
  }

  // Eyedropper never reaches here — PASS 4.5 §12 routes it directly from
  // handlePointerDown/handlePointerMove, bypassing arbitration entirely, so
  // activeTool can never be eyedropper at this point.
  Future<void> _handleToolPointerDown(Offset artworkPoint, Offset localPosition) async {
    if (activeTool == EditorTool.fill) {
      await _performFill(artworkPoint);
      return;
    }
    if (activeTool != EditorTool.brush && activeTool != EditorTool.erase) return;

    // LOCKED Brush: detect the connected region at THIS stroke's start
    // point using the SAME engine as Fill, and bake a one-off mask into
    // just this stroke. Lock never affects Erase.
    ui.Image? maskImage;
    if (activeTool == EditorTool.brush && locked) {
      final mask = _regionEngine!.floodFillFrom(artworkPoint.dx.round(), artworkPoint.dy.round());
      if (mask == null) return; // start point is a barrier line -- nothing to constrain to
      maskImage = await _maskToImage(mask);
    }

    _liveStroke = LiveStroke(
      tool: activeTool == EditorTool.brush ? StrokeTool.brush : StrokeTool.erase,
      color: activeColor,
      width: brushWidth,
      points: [StrokePoint(artworkPoint.dx, artworkPoint.dy)],
      regionMaskImage: maskImage,
    );
    notifyListeners();
  }

  Future<void> _handleToolPointerMove(Offset artworkPoint, Offset localPosition) async {
    final live = _liveStroke;
    if (live == null) return;
    live.points.add(StrokePoint(artworkPoint.dx, artworkPoint.dy));
    notifyListeners();
  }

  Future<void> _finishToolGesture() async {
    if (activeTool == EditorTool.eyedropper) {
      // A fast tap can deliver PointerUpEvent before the async pixel
      // capture from PointerDownEvent has resolved -- wait for it, or this
      // would commit a stale null color.
      final pending = _pendingEyedropperSample;
      if (pending != null) await pending;

      // PASS 4.5 §14: commit the FINAL live-sampled color (never an
      // intermediate one — see _runEyedropperSample, which only ever holds
      // the latest sample), promote it to MRU, and hide the loupe. Stays in
      // Pick mode (§ activateEyedropper doc) rather than reverting tool.
      final color = eyedropperPreviewColor;
      _clearEyedropperPreview();
      if (color != null) {
        commitCustomColor(color);
      } else {
        notifyListeners();
      }
      return;
    }

    final live = _liveStroke;
    if (live == null) return;
    _liveStroke = null;

    final stroke = BrushStroke(
      tool: live.tool,
      color: live.color,
      width: live.width,
      points: live.points,
      regionMaskImage: live.regionMaskImage,
    );
    _commitAction(stroke);
    notifyListeners();
  }

  void _cancelToolGesture() {
    // Cancelled mid-stroke: drop it entirely rather than leaving a partial,
    // un-recorded stroke that Undo could never reach.
    _liveStroke = null;
    if (activeTool == EditorTool.eyedropper) {
      // Interrupted sample (e.g. a second finger joined) — stay in
      // Eyedropper mode rather than treating this as a completed pick.
      // PASS 4.5 §8: cancel hides the loupe and commits nothing to MRU.
      _eyedropperSampleToken++; // invalidate any in-flight sample
      _clearEyedropperPreview();
    }
    notifyListeners();
  }

  /// Drops zero, one, or two `ui.Image`s depending on timing: any image
  /// currently backing the loupe, and (via _runEyedropperSample's own
  /// stale-token check) any in-flight capture that resolves after this
  /// call — both are disposed exactly once, never leaked, never double-
  /// disposed.
  void _clearEyedropperPreview() {
    eyedropperPreviewColor = null;
    eyedropperPreviewLocalPosition = null;
    final image = _eyedropperSourceImage;
    _eyedropperSourceImage = null;
    image?.dispose();
  }

  /// PASS 4.5 §8/§9: never samples outside the 800x800 artwork (the grey
  /// workspace must never be read as a color) — computed via the SAME
  /// inverse ArtworkSurface transform every other tool uses, so this stays
  /// correct at any pan/zoom state, in Normal or Expanded mode alike.
  Future<void> _sampleEyedropper(Offset localPosition, Size displaySize) {
    final artworkPoint = artworkPointFromLocal(localPosition, displaySize, scale: viewScale, offset: viewOffset);
    final inBounds =
        artworkPoint.dx >= 0 && artworkPoint.dx <= kArtworkSize && artworkPoint.dy >= 0 && artworkPoint.dy <= kArtworkSize;
    if (!inBounds) return Future.value(); // retain the last valid sample rather than showing workspace grey

    final sampler = sampleColorAt;
    if (sampler == null || _eyedropperSampling) return Future.value();
    _eyedropperSampling = true;
    final token = ++_eyedropperSampleToken;
    final future = _runEyedropperSample(sampler, localPosition, token);
    _pendingEyedropperSample = future;
    return future;
  }

  Future<void> _runEyedropperSample(Future<EyedropperCapture?> Function(Offset) sampler, Offset localPosition, int token) async {
    try {
      final capture = await sampler(localPosition);
      // A 2-finger interrupt (cancel) bumps the token while this was in
      // flight — discard a result that's no longer for the current
      // gesture rather than resurrecting a stale preview mid-zoom. Still
      // dispose its image: it was never stored anywhere else.
      if (capture == null || token != _eyedropperSampleToken) {
        capture?.image.dispose();
        return;
      }
      final oldImage = _eyedropperSourceImage;
      _eyedropperSourceImage = capture.image;
      eyedropperPreviewLocalPosition = localPosition;
      eyedropperPreviewColor = capture.color;
      oldImage?.dispose();
      notifyListeners();
    } finally {
      _eyedropperSampling = false;
    }
  }

  Future<ui.Image> _maskToImage(Uint8List mask) {
    final rgba = Uint8List(kArtworkSize * kArtworkSize * 4);
    for (int i = 0; i < mask.length; i++) {
      if (mask[i] != 0) rgba[i * 4 + 3] = 255; // opaque alpha marks "inside the region"
    }
    return decodeRgbaImage(rgba, kArtworkSize, kArtworkSize);
  }

  // --- Fill ------------------------------------------------------------------
  // Uses the exact same RegionEngine as Locked Brush. A Fill tap becomes ONE
  // action in the same chronological `strokes` list as Brush/Erase. Lock/
  // Unlock never changes Fill behavior.

  Future<void> _performFill(Offset artworkPoint) async {
    final mask = _regionEngine!.floodFillFrom(artworkPoint.dx.round(), artworkPoint.dy.round());
    if (mask == null) return; // tapped directly on a barrier line -- nothing to fill

    final maskImage = await _maskToImage(mask);
    final stroke = BrushStroke(
      tool: StrokeTool.fill,
      color: activeColor,
      width: 0,
      points: [StrokePoint(artworkPoint.dx, artworkPoint.dy)],
      regionMaskImage: maskImage,
    );
    _commitAction(stroke);
    notifyListeners();
  }

  // --- Undo / Redo -------------------------------------------------------
  // One uniform action stack for Fill, Brush AND Erase: undo/redo simply
  // moves the most recent action between `strokes` and `_redoStack`/
  // `_undoStack`.

  void _commitAction(BrushStroke stroke) {
    strokes.add(stroke);
    _undoStack.add(stroke);
    if (_undoStack.length > kHistoryLimit) _undoStack.removeAt(0);
    _redoStack.clear(); // a new artwork action always clears redo
    _commitDrawingState();
  }

  Future<void> undo() async {
    if (_undoStack.isEmpty) return;
    final stroke = _undoStack.removeLast();
    strokes.removeLast();
    _redoStack.add(stroke);
    if (_redoStack.length > kHistoryLimit) _redoStack.removeAt(0);
    _commitDrawingState();
    notifyListeners();
  }

  Future<void> redo() async {
    if (_redoStack.isEmpty) return;
    final stroke = _redoStack.removeLast();
    strokes.add(stroke);
    _undoStack.add(stroke);
    if (_undoStack.length > kHistoryLimit) _undoStack.removeAt(0);
    _commitDrawingState();
    notifyListeners();
  }

  // --- Per-lesson progress isolation --------------------------------------

  void _commitDrawingState() {
    final persisted = strokes.map(_toPersistedStroke).toList();
    unawaited(AppData.progressRepository.saveDrawingState(lessonId, persisted));
    AppData.progressRepository.saveProgress(lessonId);
    // Every committed lifecycle event (stroke/fill/erase commit, undo,
    // redo, exit, explicit Save) re-renders and persists the discovery-
    // screen preview for this lesson — never on pointermove, only here.
    // Fire-and-forget: strokes/lineArtImage are already in memory, so this
    // never blocks the UI, and Home/Library never do this work themselves.
    final resolvedLesson = lesson;
    if (resolvedLesson != null) {
      unawaited(LessonPreviewCache.instance.renderAndPersist(resolvedLesson, List.of(strokes)));
    }
  }

  /// Strips the non-serializable `ui.Image?` mask down to a plain `locked`
  /// flag — the mask itself is regenerated on load (see _hydrateStrokes).
  PersistedStroke _toPersistedStroke(BrushStroke stroke) {
    return PersistedStroke(
      tool: stroke.tool,
      color: stroke.color,
      width: stroke.width,
      points: stroke.points.map((p) => PersistedPoint(p.x, p.y)).toList(),
      locked: stroke.regionMaskImage != null,
    );
  }

  /// Called on Editor Back — commits current in-memory progress before
  /// returning to the originating screen. No artwork reset.
  void commitOnExit() {
    if (!artworkReady) return;
    _commitDrawingState();
  }

  @override
  void dispose() {
    _pendingArbitrationTimer?.cancel();
    _eyedropperSourceImage?.dispose();
    // lineArtImage is owned by LessonArtworkCache (shared across reopens of
    // the same lesson) — must NOT be disposed here.
    super.dispose();
  }
}
