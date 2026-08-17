import 'stroke.dart';

/// A lesson's in-memory coloring state — the single ordered user-paint
/// action list (Fill/Brush/Erase, in chronological order). Held per-lessonId
/// by ProgressRepository (see saveDrawingState()/getDrawingState()) so
/// switching lessons never bleeds one lesson's drawing into another's.
class LessonDrawingState {
  const LessonDrawingState({required this.strokes});

  final List<BrushStroke> strokes;
}
