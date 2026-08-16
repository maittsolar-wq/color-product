enum LessonProgressStatus { notStarted, inProgress, completed }

// Pass 1: architecture/state shape only — no drawing data (regionColors,
// brushStrokes) or persistence yet. Those belong to the Coloring Engine pass.
class LessonProgress {
  const LessonProgress({
    required this.lessonId,
    required this.status,
    required this.updatedAt,
  });

  final String lessonId;
  final LessonProgressStatus status;
  final DateTime updatedAt;

  LessonProgress copyWith({LessonProgressStatus? status, DateTime? updatedAt}) {
    return LessonProgress(
      lessonId: lessonId,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
