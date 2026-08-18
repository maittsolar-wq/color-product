import 'dart:async';

import 'package:flutter/material.dart';

import '../models/lesson_progress.dart';
import '../models/persisted_stroke.dart';
import 'local_storage.dart';
import 'progress_codec.dart';

/// SINGLE SOURCE OF TRUTH for lesson progress state — status, chronological
/// drawing actions, and app-level MRU color history. Deliberately the SAME
/// repository from Pass 1/2, extended rather than duplicated, per the
/// explicit instruction not to create a second competing progress store.
///
/// PASS 4: backed by real local files (see LocalStorage) rather than
/// memory-only maps. The split below is deliberate for startup performance
/// (§20): [init] loads only the lightweight status/timestamp metadata for
/// every lesson that has ever been touched — cheap JSON parsing, no image
/// decode, no RegionEngine, no artwork replay — so Home/Library/Profile can
/// reflect persisted state immediately. The full chronological action list
/// for a lesson (`getDrawingState`) is only ever read from disk lazily, the
/// first time the Editor actually opens that specific lesson.
abstract class ProgressRepository extends ChangeNotifier {
  /// Loads every persisted lesson's status/updatedAt from disk. Must
  /// complete before any screen that reads [getProgress] first builds (see
  /// AppBootstrap). Never throws — a corrupt or unreadable lesson file is
  /// skipped (that lesson simply reports as not-started) rather than
  /// failing the whole app's startup.
  Future<void> init();

  LessonProgress? getProgress(String lessonId);

  /// Creates or updates a lesson's progress record. `status` defaults to
  /// keeping the current status (or `inProgress` if none exists yet).
  void saveProgress(String lessonId, {LessonProgressStatus? status});

  /// PASS 5 §2/§8 — marks a lesson COMPLETED and AWAITS the disk write
  /// completing before returning (unlike saveProgress's fire-and-forget
  /// autosave) — the Editor's Done action calls this so it can guarantee
  /// the status is durable before navigating to Completion, surviving a
  /// force-stop immediately afterward.
  Future<void> completeLesson(String lessonId);

  /// Removes a lesson's progress record AND its saved drawing state, both
  /// in memory and on disk (used by Profile's Restart contract) — after
  /// this, reopening the lesson starts clean, exactly as if it had never
  /// been colored. Never touches another lesson's file.
  void resetProgress(String lessonId);

  List<String> get completedLessonIds;
  List<String> get inProgressLessonIds;

  /// The lesson's saved chronological paint actions, or an empty list if it
  /// has never been colored (or was just reset). Never another lesson's
  /// state — this is the mechanism that makes per-lesson isolation actually
  /// hold. Plain data only (no `ui.Image`): the Editor is responsible for
  /// regenerating Fill/locked-Brush region masks from each stroke's seed
  /// point via RegionEngine, exactly as it already does for live strokes.
  Future<List<PersistedStroke>> getDrawingState(String lessonId);

  Future<void> saveDrawingState(String lessonId, List<PersistedStroke> strokes);

  /// App-level (not per-lesson) MRU color history — persists across
  /// restarts, order preserved, capped by the Editor at kMaxColorHistory.
  List<Color> get colorHistory;
  void saveColorHistory(List<Color> colors);
}

class LocalProgressRepository extends ProgressRepository {
  final Map<String, LessonProgress> _progress = {};
  final Map<String, List<PersistedStroke>> _drawingCache = {};
  final List<Color> _colorHistory = [];

  @override
  Future<void> init() async {
    final lessonIds = await LocalStorage.instance.listFileNames('progress', 'json');
    for (final lessonId in lessonIds) {
      final json = await LocalStorage.instance.readJson('progress/$lessonId.json');
      if (json == null) continue; // unreadable/corrupt -- lesson stays not-started
      final decoded = decodeLessonRecord(json);
      if (decoded == null) continue; // corrupt/unsupported version -- same fallback
      _progress[decoded.progress.lessonId] = decoded.progress;
      // Strokes are intentionally NOT cached here -- see class doc (§20).
    }

    final historyJson = await LocalStorage.instance.readJson('color_history.json');
    if (historyJson != null) {
      final colors = decodeColorHistory(historyJson);
      if (colors != null) {
        _colorHistory
          ..clear()
          ..addAll(colors);
      }
    }

    notifyListeners();
  }

  @override
  LessonProgress? getProgress(String lessonId) => _progress[lessonId];

  @override
  void saveProgress(String lessonId, {LessonProgressStatus? status}) {
    final existing = _progress[lessonId];
    final updated = LessonProgress(
      lessonId: lessonId,
      status: status ?? existing?.status ?? LessonProgressStatus.inProgress,
      updatedAt: DateTime.now(),
    );
    _progress[lessonId] = updated;
    notifyListeners();
    unawaited(_persistRecord(lessonId, updated));
  }

  @override
  Future<void> completeLesson(String lessonId) async {
    final updated = LessonProgress(lessonId: lessonId, status: LessonProgressStatus.completed, updatedAt: DateTime.now());
    _progress[lessonId] = updated;
    notifyListeners();
    await _persistRecord(lessonId, updated); // AWAITED -- durable before the caller navigates
  }

  @override
  void resetProgress(String lessonId) {
    final removedProgress = _progress.remove(lessonId) != null;
    final removedDrawing = _drawingCache.remove(lessonId) != null;
    if (removedProgress || removedDrawing) {
      notifyListeners();
    }
    unawaited(LocalStorage.instance.deleteFile('progress/${sanitizeFileName(lessonId)}.json'));
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
  Future<List<PersistedStroke>> getDrawingState(String lessonId) async {
    final cached = _drawingCache[lessonId];
    if (cached != null) return cached;
    final json = await LocalStorage.instance.readJson('progress/${sanitizeFileName(lessonId)}.json');
    if (json == null) return const [];
    final decoded = decodeLessonRecord(json);
    if (decoded == null) return const []; // corrupt -- treat as a clean lesson, never crash
    _drawingCache[lessonId] = decoded.strokes;
    _progress[lessonId] = decoded.progress;
    return decoded.strokes;
  }

  @override
  Future<void> saveDrawingState(String lessonId, List<PersistedStroke> strokes) async {
    _drawingCache[lessonId] = strokes;
    final progress = _progress[lessonId] ??
        LessonProgress(lessonId: lessonId, status: LessonProgressStatus.inProgress, updatedAt: DateTime.now());
    await _writeRecord(lessonId, progress, strokes);
    // Drawing-state saves happen at every committed lifecycle event (stroke/
    // fill/erase commit, undo, redo) -- notifying on each one would trigger
    // excessive rebuilds of anything listening to the whole repository
    // (Home/Library/Profile only care about status, not raw stroke data).
    // saveProgress() already notifies for the state changes those screens
    // actually need to react to.
  }

  Future<void> _persistRecord(String lessonId, LessonProgress progress) async {
    final strokes = _drawingCache[lessonId] ?? await getDrawingState(lessonId);
    await _writeRecord(lessonId, progress, strokes);
  }

  Future<void> _writeRecord(String lessonId, LessonProgress progress, List<PersistedStroke> strokes) {
    final json = encodeLessonRecord(progress: progress, strokes: strokes);
    return LocalStorage.instance.writeJson('progress/${sanitizeFileName(lessonId)}.json', json);
  }

  @override
  List<Color> get colorHistory => List.unmodifiable(_colorHistory);

  @override
  void saveColorHistory(List<Color> colors) {
    _colorHistory
      ..clear()
      ..addAll(colors);
    unawaited(LocalStorage.instance.writeJson('color_history.json', encodeColorHistory(colors)));
  }
}
