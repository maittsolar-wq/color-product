import 'package:flutter/foundation.dart';

import '../models/lesson_drawing_state.dart';
import '../models/lesson_progress.dart';

/// SINGLE SOURCE OF TRUTH for lesson progress state — status AND (as of
/// Pass 2) in-memory drawing state. Deliberately the SAME repository from
/// Pass 1, extended rather than duplicated, per the explicit instruction not
/// to create a second competing progress store.
///
/// Pass 2: drawing state is in-memory only, keyed by lessonId (real disk
/// persistence is still deferred). No fake/seeded progress is created here.
abstract class ProgressRepository extends ChangeNotifier {
  LessonProgress? getProgress(String lessonId);

  /// Creates or updates a lesson's progress record. `status` defaults to
  /// keeping the current status (or `inProgress` if none exists yet).
  void saveProgress(String lessonId, {LessonProgressStatus? status});

  /// Removes a lesson's progress record AND its saved drawing state (used by
  /// Profile's Restart contract) — after this, reopening the lesson starts
  /// clean, exactly as if it had never been colored.
  void resetProgress(String lessonId);

  List<String> get completedLessonIds;
  List<String> get inProgressLessonIds;

  /// The lesson's saved in-memory coloring state, or null if it has never
  /// been colored (or was just reset). Never another lesson's state — this
  /// is the mechanism that makes per-lesson isolation actually hold.
  LessonDrawingState? getDrawingState(String lessonId);

  void saveDrawingState(String lessonId, LessonDrawingState state);
}

class InMemoryProgressRepository extends ProgressRepository {
  final Map<String, LessonProgress> _progress = {};
  final Map<String, LessonDrawingState> _drawingStates = {};

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
    final removedProgress = _progress.remove(lessonId) != null;
    final removedDrawing = _drawingStates.remove(lessonId) != null;
    if (removedProgress || removedDrawing) {
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

  @override
  LessonDrawingState? getDrawingState(String lessonId) => _drawingStates[lessonId];

  @override
  void saveDrawingState(String lessonId, LessonDrawingState state) {
    _drawingStates[lessonId] = state;
    // Drawing-state saves happen continuously (every stroke/fill/undo/redo)
    // — notifying on each one would trigger excessive rebuilds of anything
    // listening to the whole repository (Home/Library/Profile only care
    // about status, not raw pixel data). saveProgress() already notifies
    // for the state changes those screens actually need to react to.
  }
}
