import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/lesson_model.dart';
import '../../models/stroke.dart';
import '../../repositories/local_storage.dart';
import 'editor_painter.dart';
import 'lesson_artwork_cache.dart';

/// Dynamic progress thumbnails — ONE source of truth (§22): a lesson's
/// preview is rendered from the exact same `strokes` list and the exact
/// same `paintUserArtwork` function EditorPainter itself uses. No separate/
/// duplicated coloring model, no possibility of a thumbnail drifting from
/// what the Editor would actually show.
///
/// PASS 4: previews are also persisted to disk as PNG files. Only the
/// Editor ever renders from live strokes (via [renderAndPersist], called
/// eagerly at each committed lifecycle point, when the strokes and line art
/// are already in memory). Home/Library/Search/Profile never replay
/// strokes — they only ever load the already-rendered PNG from disk (or
/// the in-memory cache of it), satisfying §20's "no full artwork replay at
/// startup."
///
/// This is a pure memoizing cache, not a Listenable — screens don't listen
/// to it directly. They already rebuild on ProgressRepository's own
/// notifyListeners(); on that rebuild, re-requesting a lesson's preview
/// here is cheap (returns the cached image instantly) unless invalidated/
/// deleted first (only on commit/undo/redo/exit/restart, never on
/// pointermove).
class LessonPreviewCache {
  LessonPreviewCache._();
  static final LessonPreviewCache instance = LessonPreviewCache._();

  static const int previewSize = 250;

  final Map<String, ui.Image> _cache = {};
  final Map<String, Future<ui.Image?>> _inFlight = {};

  String _path(String lessonId) => 'previews/${sanitizeFileName(lessonId)}.png';

  /// Synchronous best-effort read — null until a render or a disk load
  /// completes at least once (callers should keep showing the static
  /// thumbnail as a fallback until then; see LessonThumbCard).
  ui.Image? peek(String lessonId) => _cache[lessonId];

  /// Drops the in-memory cached preview for one lesson (never another —
  /// same per-lesson isolation contract the drawing state itself follows).
  /// Does NOT dispose the outgoing image: it may still be referenced by an
  /// on-screen RawImage that hasn't rebuilt yet this frame.
  void invalidate(String lessonId) {
    _cache.remove(lessonId);
    _inFlight.remove(lessonId);
  }

  /// Home/Library/Search/Profile thumbnail path: loads the already-
  /// persisted PNG from disk if one exists, memoizing it in-memory for the
  /// rest of this app session. Never replays strokes. Returns null if this
  /// lesson has no persisted preview yet (caller falls back to the static
  /// thumbnail asset).
  Future<ui.Image?> loadPersisted(String lessonId) {
    final cached = _cache[lessonId];
    if (cached != null) return Future.value(cached);
    final inFlight = _inFlight[lessonId];
    if (inFlight != null) return inFlight;

    final future = _loadFromDisk(lessonId).then((image) {
      if (image != null) _cache[lessonId] = image;
      _inFlight.remove(lessonId);
      return image;
    });
    _inFlight[lessonId] = future;
    return future;
  }

  Future<ui.Image?> _loadFromDisk(String lessonId) async {
    final bytes = await LocalStorage.instance.readBytes(_path(lessonId));
    if (bytes == null) return null;
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      debugPrint('[LessonPreviewCache] corrupt persisted preview for $lessonId: $e');
      return null;
    }
  }

  /// Editor-only path (§11-12): renders the CURRENT composited artwork from
  /// live strokes and persists it to disk as a PNG. Called eagerly from
  /// EditorController at every committed lifecycle point — never from a
  /// passive thumbnail widget, and never on pointermove.
  Future<void> renderAndPersist(LessonModel lesson, List<BrushStroke> strokes) async {
    final image = await _render(lesson, strokes);
    _cache[lesson.id] = image;
    _inFlight.remove(lesson.id);

    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;
    await LocalStorage.instance.writeBytes(_path(lesson.id), byteData.buffer.asUint8List());
  }

  /// Restart (§15): drops the in-memory preview AND deletes the persisted
  /// PNG, so a freshly reset lesson falls back to the static thumbnail
  /// everywhere, immediately and permanently (not just until next render).
  Future<void> deletePersisted(String lessonId) async {
    invalidate(lessonId);
    await LocalStorage.instance.deleteFile(_path(lessonId));
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
