import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/app_data.dart';
import '../../core/constants.dart';
import '../../models/lesson_drawing_state.dart';
import '../../models/lesson_model.dart';
import '../../models/stroke.dart';
import 'lesson_artwork_cache.dart';
import 'region_engine.dart';

enum EditorTool { brush, fill, erase }

const double kBrushMinWidth = 8;
const double kBrushMaxWidth = 64;
const int kHistoryLimit = 15;

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
/// exact order inside a single shared layer every frame. There is no
/// separate always-bottom Fill raster any more: a Fill action is just
/// another entry in the same list, so an Erase correctly reveals whatever
/// (if anything) came before it, and a later Fill/Brush action correctly
/// paints over an earlier Erase, because it is drawn after it in the replay.
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

  // Mirrors `strokes` append order 1:1 — undo/redo only ever act on the
  // list tail, so these always agree with `strokes.last`/`strokes.length`.
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

  // --- Tool / color / brush-size / lock selection --------------------------
  // Session-only — never pushed onto the undo/redo history.

  void selectTool(EditorTool tool) {
    activeTool = tool;
    notifyListeners();
  }

  void selectColor(Color color) {
    activeColor = color;
    notifyListeners();
  }

  void setBrushSliderValue(double value) {
    brushSliderValue = value;
    notifyListeners();
  }

  void toggleLock() {
    locked = !locked;
    notifyListeners();
  }

  // --- Pointer handling (artwork-space coordinates) -------------------------

  Future<void> onPointerDown(Offset artworkPoint) async {
    if (!artworkReady || _regionEngine == null) return;

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

  void onPointerMove(Offset artworkPoint) {
    final live = _liveStroke;
    if (live == null) return;
    live.points.add(StrokePoint(artworkPoint.dx, artworkPoint.dy));
    notifyListeners();
  }

  void onPointerUp() {
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

  void onPointerCancel() {
    // Cancelled mid-stroke: drop it entirely rather than leaving a partial,
    // un-recorded stroke that Undo could never reach.
    _liveStroke = null;
    notifyListeners();
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
  // action in the same chronological `strokes` list as Brush/Erase — never a
  // separately-flattened always-bottom raster — so a Fill that happens AFTER
  // an Erase correctly repaints the erased pixels (it replays after the
  // Erase), and an Erase that happens after a Fill correctly reveals the
  // original artwork underneath (there is nothing else left to reveal).
  // Lock/Unlock never changes Fill behavior.

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
  // `_undoStack`, which is enough on its own to correctly reverse/reapply
  // an Erase (or anything else) because rendering always replays whatever
  // remains in `strokes`, in order, from scratch every frame.

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
  }

  /// Called on Editor Back — commits current in-memory progress before
  /// returning to the originating screen. No artwork reset.
  void commitOnExit() {
    if (!artworkReady) return;
    _commitDrawingState();
  }

  @override
  void dispose() {
    // lineArtImage is owned by LessonArtworkCache (shared across reopens of
    // the same lesson) — must NOT be disposed here.
    super.dispose();
  }
}
