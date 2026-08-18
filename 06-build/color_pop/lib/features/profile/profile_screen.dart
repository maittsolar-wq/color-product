import 'package:flutter/material.dart';

import '../../core/app_data.dart';
import '../../models/lesson_model.dart';
import '../../shared/explore_empty_state.dart';
import '../../shared/lesson_thumb_card.dart';
import '../settings/settings_screen.dart';
import 'profile_artwork_popup.dart';

enum _ProfileSegment { all, completed, inProgress }

/// SCR-PROFILE-001 — All / Completed / In Progress segments over
/// AppData.progressRepository. Pass 1 has no real progress yet (Coloring
/// Engine not implemented), so the empty state is the correct, honest
/// result — no fake/seeded artwork.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.onOpenLibraryAll,
    required this.onOpenEditor,
  });

  final VoidCallback onOpenLibraryAll;
  final void Function(String lessonId) onOpenEditor;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  _ProfileSegment _segment = _ProfileSegment.all;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([AppData.lessonRepository, AppData.progressRepository]),
      builder: (context, _) {
        final lessonRepo = AppData.lessonRepository;
        final progressRepo = AppData.progressRepository;
        final inProgressIds = progressRepo.inProgressLessonIds;
        final completedIds = progressRepo.completedLessonIds;
        final hasAnyProgress = inProgressIds.isNotEmpty || completedIds.isNotEmpty;

        final List<String> segmentIds = switch (_segment) {
          _ProfileSegment.all => [...inProgressIds, ...completedIds],
          _ProfileSegment.completed => completedIds,
          _ProfileSegment.inProgress => inProgressIds,
        };
        final lessons = segmentIds.map(lessonRepo.findById).whereType<LessonModel>().toList();

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Profile', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                      IconButton(
                        key: const Key('profile-settings-icon'),
                        // PASS 6 §3/REQ-PROFILE-006: SCR-SETTINGS-001 is a
                        // separate full screen (never merged into Profile).
                        // A plain push; Settings' own back button/system-
                        // back just pops back to this exact Profile
                        // instance, preserving its tab/segment state.
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                        ),
                        icon: const Icon(Icons.settings_outlined),
                        style: IconButton.styleFrom(backgroundColor: const Color(0xFFF5F5F6), shape: const CircleBorder()),
                      ),
                    ],
                  ),
                ),
                if (!hasAnyProgress)
                  Expanded(
                    child: Center(
                      child: ExploreEmptyState(
                        icon: Icons.palette_outlined,
                        title: 'Your gallery is empty',
                        message: "You haven't colored any artwork yet.\nLet's bring some color to your world!",
                        ctaLabel: 'Explore library',
                        onCta: widget.onOpenLibraryAll,
                      ),
                    ),
                  )
                else ...[
                  _buildSegmented(),
                  const SizedBox(height: 14),
                  Expanded(
                    child: lessons.isEmpty
                        ? const Center(child: Text('Nothing in this view yet.'))
                        : GridView.builder(
                            padding: const EdgeInsets.only(bottom: 20),
                            gridDelegate: kLessonGridDelegate,
                            itemCount: lessons.length,
                            itemBuilder: (context, index) {
                              final lesson = lessons[index];
                              return LessonThumbCard(
                                lesson: lesson,
                                // Profile-only: artwork tap opens the detail
                                // popup instead of the Editor directly — Home
                                // and Library never show this popup.
                                onTap: () => showProfileArtworkPopup(
                                  context: context,
                                  lesson: lesson,
                                  onOpenEditor: widget.onOpenEditor,
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSegmented() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFF1F1F3), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          _segmentButton('All', _ProfileSegment.all),
          _segmentButton('Completed', _ProfileSegment.completed),
          _segmentButton('In Progress', _ProfileSegment.inProgress),
        ],
      ),
    );
  }

  Widget _segmentButton(String label, _ProfileSegment segment) {
    final selected = _segment == segment;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _segment = segment),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500, fontSize: 13),
          ),
        ),
      ),
    );
  }
}
