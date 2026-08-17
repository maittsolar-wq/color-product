import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/lesson_model.dart';
import '../../models/stroke.dart';
import 'editor_painter.dart';
import 'lesson_artwork_cache.dart';

/// PASS 3 dynamic progress thumbnails — ONE source of truth (§22): a
/// lessonId's LessonDrawingState (the exact same `strokes` list the Editor
/// itself reads/writes) is composited through the exact same
/// `paintUserArtwork` function EditorPainter uses, at a small preview
/// resolution. No separate/duplicated coloring model, no possibility of a
/// thumbnail drifting from what the Editor would actually show.
///
/// This is a pure memoizing cache, not a Listenable — screens don't listen
/// to it directly. They already rebuild on ProgressRepository's own
/// notifyListeners() (every committed drawing action also calls
/// saveProgress(), which notifies); on that rebuild, re-requesting a
/// lesson's preview here is cheap (returns the cached image instantly)
/// unless EditorController explicitly invalidated it first (§23: only on
/// commit/undo/redo/exit, never on pointermove).
class LessonPreviewCache {
  LessonPreviewCache._();
  static final LessonPreviewCache instance = LessonPreviewCache._();

  static const int previewSize = 250;

  final Map<String, ui.Image> _cache = {};
  final Map<String, Future<ui.Image>> _inFlight = {};

  /// Synchronous best-effort read — null until the async render completes
  /// at least once (callers should keep showing the static thumbnail as a
  /// fallback until then; see LessonThumbCard).
  ui.Image? peek(String lessonId) => _cache[lessonId];

  /// Drops the cached preview for one lesson (never another — same
  /// per-lesson isolation contract the drawing state itself follows).
  /// Does NOT dispose the outgoing image: it may still be referenced by an
  /// on-screen RawImage that hasn't rebuilt yet this frame; this pass is
  /// explicitly in-memory/prototype-level (§29) and leaves aggressive
  /// image disposal to a later persistence-aware pass.
  void invalidate(String lessonId) {
    _cache.remove(lessonId);
    _inFlight.remove(lessonId);
  }

  /// Renders (or returns the cached render of) the CURRENT composited
  /// artwork state for [lesson] at `previewSize`x`previewSize`. Requires
  /// the lesson's line-art overlay — LessonArtworkCache already memoizes
  /// that per-lesson, so this never re-decodes the source PNG (§29).
  Future<ui.Image> get(LessonModel lesson, List<BrushStroke> strokes) {
    final cached = _cache[lesson.id];
    if (cached != null) return Future.value(cached);
    final inFlight = _inFlight[lesson.id];
    if (inFlight != null) return inFlight;

    final future = _render(lesson, strokes).then((image) {
      _cache[lesson.id] = image;
      _inFlight.remove(lesson.id);
      return image;
    });
    _inFlight[lesson.id] = future;
    return future;
  }

  Future<ui.Image> _render(LessonModel lesson, List<BrushStroke> strokes) async {
    final artwork = await LessonArtworkCache.load(lesson);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, previewSize.toDouble(), previewSize.toDouble()));
    final scale = previewSize / kArtworkSize;
    canvas.scale(scale, scale);
    paintUserArtwork(canvas, strokes: strokes, lineArtImage: artwork.lineArtImage);
    final picture = recorder.endRecording();
    final image = await picture.toImage(previewSize, previewSize);
    picture.dispose();
    return image;
  }
}
