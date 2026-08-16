import 'package:flutter/material.dart';

import '../../core/app_data.dart';
import '../../models/lesson_model.dart';
import '../../repositories/progress_repository.dart';
import '../../shared/lesson_thumb_card.dart';

/// SCR-HOME-001 — repeatable category sections (Manga/Animal/Nature) +
/// conditional Continue card, per the approved prototype/ui-spec. Reads
/// lessons ONLY through AppData.lessonRepository — no local lesson array.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onOpenLibrary,
    required this.onOpenEditor,
  });

  final void Function(String categoryId) onOpenLibrary;
  final void Function(String lessonId) onOpenEditor;

  static const _homeCategoryIds = ['manga', 'animal', 'nature'];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([AppData.lessonRepository, AppData.progressRepository]),
      builder: (context, _) {
        final repo = AppData.lessonRepository;
        final progressRepo = AppData.progressRepository;
        final continueLesson = _resolveContinueLesson(repo, progressRepo);

        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () {}, // Paywall is out of scope for Pass 1.
                  icon: const Icon(Icons.workspace_premium, size: 16, color: Color(0xFFE8850C)),
                  label: const Text('PRO', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFE8850C))),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFF0EEEB)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (continueLesson != null) ...[
                _ContinueCard(lesson: continueLesson, onTap: () => onOpenEditor(continueLesson.id)),
                const SizedBox(height: 24),
              ],
              for (final categoryId in _homeCategoryIds)
                _CategorySection(
                  categoryId: categoryId,
                  lessons: repo.byCategory(categoryId),
                  onSeeAll: () => onOpenLibrary(categoryId),
                  onOpenEditor: onOpenEditor,
                ),
            ],
          ),
        );
      },
    );
  }

  LessonModel? _resolveContinueLesson(dynamic repo, ProgressRepository progressRepo) {
    final inProgressIds = progressRepo.inProgressLessonIds;
    if (inProgressIds.isEmpty) return null;
    // Most recently updated wins (data-model.md Progress.updatedAt rule).
    String? bestId;
    DateTime? bestUpdatedAt;
    for (final id in inProgressIds) {
      final progress = progressRepo.getProgress(id);
      if (progress == null) continue;
      if (bestUpdatedAt == null || progress.updatedAt.isAfter(bestUpdatedAt)) {
        bestId = id;
        bestUpdatedAt = progress.updatedAt;
      }
    }
    if (bestId == null) return null;
    return repo.findById(bestId);
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.lesson, required this.onTap});

  final LessonModel lesson;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF3EFFC),
      borderRadius: BorderRadius.circular(21),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 170,
          child: Row(
            children: [
              Expanded(
                flex: 45,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 6, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        lesson.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C4DFF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome, size: 13, color: Colors.white),
                            SizedBox(width: 6),
                            Text('Continue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 55,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 16, 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(lesson.thumbnailAsset, fit: BoxFit.contain),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.categoryId,
    required this.lessons,
    required this.onSeeAll,
    required this.onOpenEditor,
  });

  final String categoryId;
  final List<LessonModel> lessons;
  final VoidCallback onSeeAll;
  final void Function(String lessonId) onOpenEditor;

  static const _titles = {'manga': 'Manga', 'animal': 'Animal', 'nature': 'Nature'};

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_titles[categoryId] ?? categoryId, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                TextButton(
                  onPressed: onSeeAll,
                  child: const Text('See all', style: TextStyle(color: Color(0xFF7C4DFF), fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 128,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: lessons.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final lesson = lessons[index];
                return LessonThumbCard(
                  key: Key('lesson-card-${lesson.id}'),
                  lesson: lesson,
                  width: 112,
                  showTitle: false,
                  onTap: () => onOpenEditor(lesson.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
