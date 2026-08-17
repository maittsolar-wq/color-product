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

  // PASS 4: persistence-facing (de)serialization. Kept on the model itself
  // since it's a trivial, stable mapping — no separate DTO needed.
  Map<String, dynamic> toJson() => {
    'lessonId': lessonId,
    'status': status.name,
    'updatedAt': updatedAt.toIso8601String(),
  };

  static LessonProgress? fromJson(Map<String, dynamic> json) {
    try {
      final lessonId = json['lessonId'] as String;
      final status = LessonProgressStatus.values.byName(json['status'] as String);
      final updatedAt = DateTime.parse(json['updatedAt'] as String);
      return LessonProgress(lessonId: lessonId, status: status, updatedAt: updatedAt);
    } catch (_) {
      return null;
    }
  }
}
