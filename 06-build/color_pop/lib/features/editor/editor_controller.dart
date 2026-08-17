import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/app_data.dart';
import '../../core/constants.dart';
import '../../models/lesson_drawing_state.dart';
import '../../models/lesson_model.dart';
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

  // --- Pointer ARBITRATION (§1) ---------------------------------------------
  // A single pointer-down does NOT immediately become a paint action. It
  // becomes "pending" for a short window; if a 2nd pointer joins within
  // that window, the pending gesture is discarded outright (nothing was
  // ever committed — no dot, no live stroke, no Fill, no Eyedropper
  // sample). If the window elapses with still-exactly-one pointer down, OR
  // that one pointer lifts before the window elapses (a fast tap), the
  // gesture is retroactively confirmed as genuine single-pointer painting.
  static const Duration _paintArbitrationDelay = Duration(milliseconds: 70);
  int? _pendingPointerId;
  Offset? _pendingLocalPosition;
  Size? _pendingDisplaySize;
  final List<Offset> _pendingMovePositions = [];
  Timer? _pendingArbitrationTimer;
  bool _paintingConfirmed = false;

  /// Set by EditorScreen to bridge to the widget-layer pixel capture the
  /// Eyedropper needs (reading the actual RENDERED/composited artboard —
  /// see class doc on why that lives outside the controller).
  Future<Color?> Function(Offset localPosition)? sampleColorAt;
  bool _eyedropperSampling = false;
  Future<void>? _pendingEyedropperSample;
  int _eyedropperSampleToken = 0;
  Color? eyedropperPreviewColor;
  Offset? eyedropperPreviewLocalPosition;
  EditorTool? _toolBeforeEyedropper;

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
    _regionEngine = RegionEngine(size: kArtworkSize, barrierMask: artworkData.barrierMask);

    // Restore THIS lesson's saved in-memory drawing state, never another
    // lesson's — the per-lesson isolation contract (§16).
    final saved = AppData.progressRepository.getDrawingState(lessonId);
    strokes = saved != null ? List.of(saved.strokes) : [];

    artworkReady = true;
    notifyListeners();
  }

  // --- Tool / brush-size / lock / mode selection ----------------------------
  // Session-only — never pushed onto the undo/redo history.

  void selectTool(EditorTool tool) {
    if (activeTool == EditorTool.eyedropper && tool != EditorTool.eyedropper) {
      // Switching away from Eyedropper via the tool rail (not by
      // completing/cancelling a sample) still needs to drop any in-flight
      // preview state cleanly.
      eyedropperPreviewColor = null;
      eyedropperPreviewLocalPosition = null;
      _toolBeforeEyedropper = null;
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

  /// Remembers the current painting tool and enters sampling mode (§9) —
  /// does not permanently replace the Brush/Fill/Erase selection.
  void activateEyedropper() {
    if (activeTool == EditorTool.eyedropper) return;
    _toolBeforeEyedropper = activeTool;
    activeTool = EditorTool.eyedropper;
    notifyListeners();
  }

  /// PASS 3.1 Save/Done (§4). Completion is explicitly NOT part of this
  /// pass: this only (1) commits current in-memory progress, (2) which as
  /// part of that invalidates the cached preview so it regenerates fresh,
  /// and (3) ensures status is at least inProgress -- but ONLY if the
  /// artwork actually has user edits, never fabricating progress for an
  /// untouched lesson from a stray tap. Stays in the Editor; the visual
  /// "saved" acknowledgment is the widget layer's job (e.g. a SnackBar).
  void saveNow() {
    if (!artworkReady || strokes.isEmpty) return;
    _commitDrawingState();
  }

  // --- View transform helpers ----------------------------------------------

  Offset _clampOffset(Offset raw, double scale, Size displaySize) {
    final minDx = displaySize.width * (1 - scale);
    final minDy = displaySize.height * (1 - scale);
    // At scale == 1.0 this collapses to exactly (0,0) on both axes.
    return Offset(raw.dx.clamp(minDx, 0.0), raw.dy.clamp(minDy, 0.0));
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
  // Fill/Erase/Eyedropper. Exactly two drive Zoom/Pan. A second finger
  // arriving at ANY point — during arbitration or after painting was
  // already confirmed — aborts painting outright (§1).

  Future<void> handlePointerDown(int pointerId, Offset localPosition, Size displaySize) async {
    _activePointers[pointerId] = localPosition;

    if (_activePointers.length == 2) {
      _cancelPendingPaintGesture();
      _liveStroke = null;
      _eyedropperSampleToken++; // invalidate any in-flight sample from before this interrupt
      eyedropperPreviewColor = null;
      eyedropperPreviewLocalPosition = null;
      notifyListeners();
      _startTwoFingerGesture();
      return;
    }
    if (_activePointers.length > 2) return;

    if (!artworkReady || _regionEngine == null) return;

    // Exactly one active pointer -- arm the arbitration window. Nothing
    // irreversible happens yet: no live stroke, no Fill, no Eyedropper
    // sample. If a 2nd pointer joins before this fires, the branch above
    // discards it via _cancelPendingPaintGesture with zero visible trace.
    _pendingPointerId = pointerId;
    _pendingLocalPosition = localPosition;
    _pendingDisplaySize = displaySize;
    _pendingMovePositions.clear();
    _paintingConfirmed = false;
    _pendingArbitrationTimer?.cancel();
    _pendingArbitrationTimer = Timer(_paintArbitrationDelay, () {
      _pendingArbitrationTimer = null;
      unawaited(_confirmPendingPaintGesture());
    });
  }

  Future<void> handlePointerMove(int pointerId, Offset localPosition, Size displaySize) async {
    if (!_activePointers.containsKey(pointerId)) return;
    _activePointers[pointerId] = localPosition;

    if (_activePointers.length == 2) {
      _updateTwoFingerGesture(displaySize);
      return;
    }
    if (_activePointers.length != 1) return;

    if (!_paintingConfirmed) {
      // Still arbitrating -- buffer so a fast drag that starts before
      // confirmation doesn't lose its early points, but do not paint yet.
      if (pointerId == _pendingPointerId) {
        _pendingMovePositions.add(localPosition);
      }
      return;
    }

    final artworkPoint = artworkPointFromLocal(localPosition, displaySize, scale: viewScale, offset: viewOffset);
    await _handleToolPointerMove(artworkPoint, localPosition);
  }

  Future<void> handlePointerUp(int pointerId) async {
    final wasStillArbitrating = pointerId == _pendingPointerId && !_paintingConfirmed;

    _activePointers.remove(pointerId);
    if (_activePointers.length == 2) {
      _startTwoFingerGesture(); // re-baseline from whichever 2 fingers remain
    } else {
      _twoFingerStartFocal = null;
      _twoFingerStartDistance = null;
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
  }

  Future<void> _handleToolPointerDown(Offset artworkPoint, Offset localPosition) async {
    if (activeTool == EditorTool.eyedropper) {
      await _sampleEyedropper(localPosition);
      return;
    }
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
    if (activeTool == EditorTool.eyedropper) {
      await _sampleEyedropper(localPosition);
      return;
    }
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

      // Restore the tool first so the one notify below (whichever branch)
      // reflects the fully-settled state in a single frame.
      final color = eyedropperPreviewColor;
      activeTool = _toolBeforeEyedropper ?? EditorTool.brush;
      _toolBeforeEyedropper = null;
      eyedropperPreviewColor = null;
      eyedropperPreviewLocalPosition = null;
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
      _eyedropperSampleToken++; // invalidate any in-flight sample
      eyedropperPreviewColor = null;
      eyedropperPreviewLocalPosition = null;
    }
    notifyListeners();
  }

  Future<void> _sampleEyedropper(Offset localPosition) {
    final sampler = sampleColorAt;
    if (sampler == null || _eyedropperSampling) return Future.value();
    _eyedropperSampling = true;
    final token = ++_eyedropperSampleToken;
    final future = _runEyedropperSample(sampler, localPosition, token);
    _pendingEyedropperSample = future;
    return future;
  }

  Future<void> _runEyedropperSample(Future<Color?> Function(Offset) sampler, Offset localPosition, int token) async {
    try {
      final color = await sampler(localPosition);
      // A 2-finger interrupt (cancel) bumps the token while this was in
      // flight — discard a result that's no longer for the current
      // gesture rather than resurrecting a stale preview mid-zoom.
      if (color == null || token != _eyedropperSampleToken) return;
      eyedropperPreviewLocalPosition = localPosition;
      eyedropperPreviewColor = color;
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
    AppData.progressRepository.saveDrawingState(lessonId, LessonDrawingState(strokes: List.of(strokes)));
    AppData.progressRepository.saveProgress(lessonId);
    // Every committed lifecycle event (stroke/fill/erase commit, undo,
    // redo, exit, explicit Save) invalidates the cached discovery-screen
    // preview for this lesson — never regenerated on pointermove, only here.
    LessonPreviewCache.instance.invalidate(lessonId);
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
    // lineArtImage is owned by LessonArtworkCache (shared across reopens of
    // the same lesson) — must NOT be disposed here.
    super.dispose();
  }
}
