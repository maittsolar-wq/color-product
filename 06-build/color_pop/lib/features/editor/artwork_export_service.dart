import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/lesson_model.dart';
import '../../models/stroke.dart';
import 'editor_painter.dart';
import 'lesson_artwork_cache.dart';

/// PASS 5 §12 — the ONE export source of truth. Both Share and Save call
/// this; it reuses the exact same `paintUserArtwork` compositor the live
/// Editor (EditorPainter) and the discovery-screen preview cache
/// (LessonPreviewCache) already use — never a viewport screenshot, never a
/// second composition path.
///
/// §13: renders the full white 800x800 canvas + Fill/Brush/Erase
/// chronology + line art, at the artwork's native resolution — no Editor
/// chrome (toolbar/palette/tool rail), no Completion UI, and critically no
/// Zoom/Pan viewport transform (that is purely view state on
/// EditorController.viewScale/viewOffset, which this function never even
/// looks at — the export is always a flat, untransformed render of the
/// full source artwork, matching what a moved/zoomed on-screen view would
/// show if reset back to a plain 1:1 read of the same underlying strokes).
Future<Uint8List> renderArtworkForExport({
  required LessonModel lesson,
  required List<BrushStroke> strokes,
}) async {
  final artwork = await LessonArtworkCache.load(lesson);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, kArtworkSize.toDouble(), kArtworkSize.toDouble()));
  paintUserArtwork(canvas, strokes: strokes, lineArtImage: artwork.lineArtImage);
  final picture = recorder.endRecording();
  final image = await picture.toImage(kArtworkSize, kArtworkSize);
  picture.dispose();

  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (byteData == null) {
    throw StateError('Failed to encode artwork PNG for lesson ${lesson.id}');
  }
  return byteData.buffer.asUint8List();
}
