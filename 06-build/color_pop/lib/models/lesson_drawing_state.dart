import 'dart:typed_data';

import 'stroke.dart';

/// A lesson's in-memory coloring state — the fill layer's raw RGBA pixels
/// plus the ordered stroke history. Held per-lessonId by ProgressRepository
/// (see saveDrawingState()/getDrawingState()) so switching lessons never
/// bleeds one lesson's drawing into another's.
class LessonDrawingState {
  const LessonDrawingState({required this.fillBuffer, required this.strokes});

  /// RGBA8888 bytes, kArtworkSize*kArtworkSize*4 long.
  final Uint8List fillBuffer;
  final List<BrushStroke> strokes;
}
