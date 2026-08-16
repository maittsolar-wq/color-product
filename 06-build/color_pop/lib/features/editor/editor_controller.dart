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

sealed class _HistoryEntry {}

class _StrokeHistoryEntry extends _HistoryEntry {
  _StrokeHistoryEntry(this.stroke);
  final BrushStroke stroke;
}

class _FillHistoryEntry extends _HistoryEntry {
  _FillHistoryEntry({required this.before, required this.after});
  final Uint8List before;
  final Uint8List after;
}

/// Owns ALL Editor drawing state and tool logic for one open lesson. A
/// fresh EditorController is created each time SCR-EDITOR-001 opens (see
/// EditorScreen) — per-lesson isolation itself lives in ProgressRepository
/// (getDrawingState/saveDrawingState), which this controller reads from on
/// load and writes to on every committed change.
class EditorController extends ChangeNotifier {
  EditorController({required this.lessonId}) {
    _load();
  }

  final String lessonId;
  LessonModel? lesson;

  bool artworkReady = false;
  ui.Image? lineArtImage;
  RegionEngine? _regionEngine;

  Uint8List _fillBuffer = Uint8List(kArtworkSize * kArtworkSize * 4);
  ui.Image? fillImage;

  List<BrushStroke> strokes = [];
  LiveStroke? _liveStroke;
  LiveStroke? get liveStroke => _liveStroke;

  EditorTool activeTool = EditorTool.brush;
  Color activeColor = kEditorPresetColors.first;
  double brushSliderValue = 40; // 0-100
  bool locked = true;

  final List<_HistoryEntry> _undoStack = [];
  final List<_HistoryEntry> _redoStack = [];

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
    if (saved != null) {
      _fillBuffer = Uint8List.fromList(saved.fillBuffer);
      strokes = List.of(saved.strokes);
    } else {
      _fillBuffer = Uint8List(kArtworkSize * kArtworkSize * 4);
      strokes = [];
    }
    await _rebuildFillImage();

    artworkReady = true;
    notifyListeners();
  }

  Future<void> _rebuildFillImage() async {
    final newImage = await decodeRgbaImage(_fillBuffer, kArtworkSize, kArtworkSize);
    fillImage?.dispose();
    fillImage = newImage;
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
    strokes.add(stroke);
    _pushHistory(_StrokeHistoryEntry(stroke));
    _commitDrawingState();
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
  // Uses the exact same RegionEngine as Locked Brush. Renders into the fill
  // buffer (the bottom-most visual layer), never touching the immutable
  // line art or the brush/erase layer above it. Lock/Unlock never changes
  // Fill behavior.

  Future<void> _performFill(Offset artworkPoint) async {
    final mask = _regionEngine!.floodFillFrom(artworkPoint.dx.round(), artworkPoint.dy.round());
    if (mask == null) return; // tapped directly on a barrier line -- nothing to fill

    final before = Uint8List.fromList(_fillBuffer);
    final r = (activeColor.r * 255).round();
    final g = (activeColor.g * 255).round();
    final b = (activeColor.b * 255).round();
    for (int i = 0; i < mask.length; i++) {
      if (mask[i] != 0) {
        final base = i * 4;
        _fillBuffer[base] = r;
        _fillBuffer[base + 1] = g;
        _fillBuffer[base + 2] = b;
        _fillBuffer[base + 3] = 255;
      }
    }
    final after = Uint8List.fromList(_fillBuffer);

    _pushHistory(_FillHistoryEntry(before: before, after: after));
    await _rebuildFillImage();
    _commitDrawingState();
    notifyListeners();
  }

  // --- Undo / Redo -------------------------------------------------------

  Future<void> undo() async {
    if (_undoStack.isEmpty) return;
    final action = _undoStack.removeLast();
    await _applyInverse(action);
    _redoStack.add(action);
    if (_redoStack.length > kHistoryLimit) _redoStack.removeAt(0);
    _commitDrawingState();
    notifyListeners();
  }

  Future<void> redo() async {
    if (_redoStack.isEmpty) return;
    final action = _redoStack.removeLast();
    await _applyForward(action);
    _undoStack.add(action);
    if (_undoStack.length > kHistoryLimit) _undoStack.removeAt(0);
    _commitDrawingState();
    notifyListeners();
  }

  void _pushHistory(_HistoryEntry action) {
    _undoStack.add(action);
    if (_undoStack.length > kHistoryLimit) _undoStack.removeAt(0);
    _redoStack.clear(); // a new artwork action always clears redo
  }

  Future<void> _applyInverse(_HistoryEntry action) async {
    switch (action) {
      case _FillHistoryEntry():
        _fillBuffer = Uint8List.fromList(action.before);
        await _rebuildFillImage();
      case _StrokeHistoryEntry():
        strokes.remove(action.stroke);
    }
  }

  Future<void> _applyForward(_HistoryEntry action) async {
    switch (action) {
      case _FillHistoryEntry():
        _fillBuffer = Uint8List.fromList(action.after);
        await _rebuildFillImage();
      case _StrokeHistoryEntry():
        strokes.add(action.stroke);
    }
  }

  // --- Per-lesson progress isolation --------------------------------------

  void _commitDrawingState() {
    AppData.progressRepository.saveDrawingState(
      lessonId,
      LessonDrawingState(fillBuffer: Uint8List.fromList(_fillBuffer), strokes: List.of(strokes)),
    );
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
    fillImage?.dispose();
    // lineArtImage is owned by LessonArtworkCache (shared across reopens of
    // the same lesson) — must NOT be disposed here.
    super.dispose();
  }
}
