import 'package:flutter/material.dart';

import '../../core/app_data.dart';
import '../../models/lesson_model.dart';
import '../../shared/lesson_thumb_card.dart';
import '../search/search_screen.dart';

/// SCR-LIBRARY-001 — filter chips (All/Animal/Food/Manga/Nature/Dumpling) +
/// 2-column real lesson grid. `initialFilter` supports pre-applied entry
/// from Home "See all" (REQ-HOME-008) / Profile "Explore Library"
/// (REQ-PROFILE-002) — Bottom Nav entry always passes 'all'.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.initialFilter,
    required this.onOpenEditor,
    required this.onExploreLibraryAll,
  });

  final String initialFilter;
  final void Function(String lessonId) onOpenEditor;

  /// Forwarded to Search's "Explore library" CTA — forces the shell's
  /// Library filter to "All".
  final VoidCallback onExploreLibraryAll;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  static const _filters = ['all', 'animal', 'food', 'manga', 'nature', 'dumpling'];
  static const _filterLabels = {
    'all': 'All',
    'animal': 'Animal',
    'food': 'Food',
    'manga': 'Manga',
    'nature': 'Nature',
    'dumpling': 'Dumpling',
  };

  late String _activeFilter = widget.initialFilter;

  @override
  Widget build(BuildContext context) {
    // PASS 3.1 fix: was listening to lessonRepository ONLY, so Library
    // never rebuilt when coloring progress changed while it stayed mounted
    // underneath a pushed Editor route (Home/Profile already merged both
    // repositories correctly — this screen was the one actual bug).
    return AnimatedBuilder(
      animation: Listenable.merge([AppData.lessonRepository, AppData.progressRepository]),
      builder: (context, _) {
        final repo = AppData.lessonRepository;
        final lessons = _activeFilter == 'all' ? repo.lessons : repo.byCategory(_activeFilter);

        return SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Library', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                    IconButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SearchScreen(
                              onOpenEditor: widget.onOpenEditor,
                              onExploreLibrary: widget.onExploreLibraryAll,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.search),
                      style: IconButton.styleFrom(backgroundColor: const Color(0xFFF5F5F6), shape: const CircleBorder()),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 52,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  scrollDirection: Axis.horizontal,
                  itemCount: _filters.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final filterId = _filters[index];
                    final selected = filterId == _activeFilter;
                    return ChoiceChip(
                      label: Text(_filterLabels[filterId]!),
                      selected: selected,
                      onSelected: (_) => setState(() => _activeFilter = filterId),
                      selectedColor: const Color(0xFF7C4DFF),
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : const Color(0xFF3A3A3C),
                        fontWeight: FontWeight.w600,
                      ),
                      backgroundColor: const Color(0xFFF1F1F3),
                      shape: const StadiumBorder(),
                      side: BorderSide.none,
                    );
                  },
                ),
              ),
              Expanded(
                child: lessons.isEmpty
                    ? const Center(child: Text('No artwork in this category yet.'))
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                        gridDelegate: kLessonGridDelegate,
                        itemCount: lessons.length,
                        itemBuilder: (context, index) {
                          final LessonModel lesson = lessons[index];
                          return LessonThumbCard(
                            key: Key('lesson-card-${lesson.id}'),
                            lesson: lesson,
                            onTap: () => widget.onOpenEditor(lesson.id),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
