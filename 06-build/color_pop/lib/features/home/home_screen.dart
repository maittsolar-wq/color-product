import 'package:flutter/material.dart';

import '../../core/app_data.dart';
import '../../models/lesson_model.dart';
import '../../repositories/progress_repository.dart';
import '../../shared/lesson_thumb_card.dart';
import '../paywall/paywall_screen.dart';

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
                  key: const Key('home-pro-button'),
                  // PASS 6 §6: Home PRO -> SCR-PAYWALL-001. A plain push;
                  // Paywall's own close button/system-back just pops back
                  // to this exact Home instance (§11 — never a duplicate
                  // Home route, never a reset of Home/tab state).
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaywallScreen())),
                  icon: const Icon(Icons.workspace_premium, size: 16, color: Colors.white),
                  label: const Text('PRO', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C4DFF),
                    side: BorderSide.none,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
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
                    child: LessonPreviewImage(lesson: lesson, fit: BoxFit.contain),
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
      // THUMBNAIL UI UPDATE: bumped from zero to land the measured
      // thumbnail-row -> next-category-title gap in the newly-requested
      // 22-28px range (previously tuned to ~14-19px against an older,
      // narrower 16-20px target). Value found via on-device pixel
      // measurement (border bottom -> next title's first ink pixel).
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _titles[categoryId] ?? categoryId,
                  // height:1.0 removes the font's own default extra
                  // leading above the cap-height ink -- without it, the
                  // title's line box (and therefore the Row it sits in)
                  // reserves several more invisible px above the visible
                  // letters than the explicit paddings above account for.
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, height: 1.0),
                ),
                // HOME ROW-HEIGHT FIX: a plain TextButton's default
                // ButtonStyle carries a Material tap-target minimum height
                // well past this row's ~19px text -- since the Row's
                // default crossAxisAlignment is center, that invisible
                // minimum height was inflating the WHOLE title row (and
                // centering the visible text within it), adding several
                // more px of unaccounted vertical space above the title
                // text on top of the row's own padding. Shrink-wrapping it
                // removes that.
                TextButton(
                  onPressed: onSeeAll,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('See all', style: TextStyle(color: Color(0xFF7C4DFF), fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          SizedBox(
            // UI-POLISH: Home-only thumbnail size, ~9% larger than the
            // previous 128 (within the requested 5-10% range). Library/
            // Search/Profile use LessonThumbCard without an explicit
            // width (their own GridView-driven sizing via
            // kLessonGridDelegate), so this stays scoped to Home alone —
            // only the layout dimensions differ; the card's shared
            // border/radius styling is untouched.
            //
            // HOME ROW-HEIGHT FIX: a horizontal ListView gives every item
            // a TIGHT cross-axis (height) constraint equal to this
            // SizedBox's own height -- unlike a Row/Column, the item
            // can't shrink-wrap smaller than that. A previous "+16px
            // slack" here (inherited from an older, titled card design)
            // was therefore forcing every card's own white background to
            // stretch 16px taller than its visible bordered thumbnail,
            // which read as a large blank gap before the next category
            // title. LessonThumbCard is title-less, so its natural height
            // is exactly its own width (square image + this widget's
            // symmetric 8px top/bottom padding) -- so this MUST equal
            // `width` below with zero slack, or that gap returns.
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: lessons.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final lesson = lessons[index];
                return LessonThumbCard(
                  key: Key('lesson-card-${lesson.id}'),
                  lesson: lesson,
                  width: 140,
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
