import 'package:flutter/foundation.dart';

import '../models/lesson_progress.dart';

/// SINGLE SOURCE OF TRUTH for lesson progress state. Prepared now so later
/// passes (Coloring Engine, persistence, Completion) only need to change
/// this repository's *implementation* — the interface Home/Library/Profile/
/// Editor call against should not need to change.
///
/// Pass 1: in-memory only, starts empty. No fake/seeded progress is created
/// here — an empty Profile is the correct, honest state until the Coloring
/// Engine pass actually produces real progress.
abstract class ProgressRepository extends ChangeNotifier {
  LessonProgress? getProgress(String lessonId);

  /// Creates or updates a lesson's progress record. `status` defaults to
  /// keeping the current status (or `inProgress` if none exists yet) — the
  /// Coloring Engine pass will extend this with real drawing-state
  /// parameters (regionColors/brushStrokes) once it lands.
  void saveProgress(String lessonId, {LessonProgressStatus? status});

  /// Removes a lesson's progress entirely (used by Profile's Restart
  /// contract). The actual drawing-state reset belongs to the Coloring
  /// Engine pass — this only clears the progress *record*.
  void resetProgress(String lessonId);

  List<String> get completedLessonIds;
  List<String> get inProgressLessonIds;
}

class InMemoryProgressRepository extends ProgressRepository {
  final Map<String, LessonProgress> _progress = {};

  @override
  LessonProgress? getProgress(String lessonId) => _progress[lessonId];

  @override
  void saveProgress(String lessonId, {LessonProgressStatus? status}) {
    final existing = _progress[lessonId];
    _progress[lessonId] = LessonProgress(
      lessonId: lessonId,
      status: status ?? existing?.status ?? LessonProgressStatus.inProgress,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  @override
  void resetProgress(String lessonId) {
    if (_progress.remove(lessonId) != null) {
      notifyListeners();
    }
  }

  @override
  List<String> get completedLessonIds => _progress.values
      .where((p) => p.status == LessonProgressStatus.completed)
      .map((p) => p.lessonId)
      .toList();

  @override
  List<String> get inProgressLessonIds => _progress.values
      .where((p) => p.status == LessonProgressStatus.inProgress)
      .map((p) => p.lessonId)
      .toList();
}
