import '../repositories/lesson_repository.dart';
import '../repositories/progress_repository.dart';

/// Simple, pragmatic service locator — one place that owns the repository
/// singletons so every screen reads the SAME instances (no duplicated
/// lesson arrays, no duplicated progress maps). Deliberately not a DI
/// package: two long-lived singletons don't need one, and this keeps the
/// dependency list unchanged from the stock Flutter template.
class AppData {
  AppData._();

  static final LessonRepository lessonRepository = LessonRepository();
  static final ProgressRepository progressRepository = InMemoryProgressRepository();
}
