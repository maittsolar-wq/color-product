import 'package:flutter/material.dart';

import '../../core/app_data.dart';
import '../../models/lesson_model.dart';
import '../../shared/explore_empty_state.dart';
import '../../shared/lesson_thumb_card.dart';

/// SCR-SEARCH-001 — child of Library, no bottom nav. Pushed via Navigator,
/// so "Back preserves the previous Library filter" (REQ-LIB-011) is simply
/// the normal Navigator.pop() behavior — the Library screen instance
/// underneath was never rebuilt. "Explore library" is a DIFFERENT exit that
/// deliberately forces filter "All" (REQ-LIB-010), so it pops back to the
/// bottom-nav root and re-pushes Library fresh rather than just popping.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.onOpenEditor, required this.onExploreLibrary});

  final void Function(String lessonId) onOpenEditor;

  /// Forces the Library filter to "All" (REQ-LIB-010) — distinct from the
  /// header Back button, which just pops this route and leaves the Library
  /// screen underneath (and its prior filter) untouched.
  final VoidCallback onExploreLibrary;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // PASS 3.1 fix: Search had NO repository subscription at all, so a
    // lesson coloured via a result tapped here (pushing the Editor on top,
    // then popping back to this SAME still-mounted SearchScreen) never
    // showed its updated preview — this rebuilds Search whenever progress
    // changes, same fix as Library.
    return AnimatedBuilder(
      animation: AppData.progressRepository,
      builder: (context, _) => _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final repo = AppData.lessonRepository;
    final trimmed = _query.trim();
    final List<LessonModel> matches = trimmed.isEmpty ? const [] : repo.search(trimmed);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                  ),
                  const Expanded(
                    child: Text('Search', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                  ),
                  const SizedBox(width: 40), // balances the leading back button
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search drawing',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: trimmed.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _controller.clear();
                              setState(() => _query = '');
                            },
                          ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
            ),
            Expanded(child: _buildContent(context, trimmed, matches)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, String trimmed, List<LessonModel> matches) {
    if (trimmed.isEmpty) {
      // Default state: no grid, no empty state (REQ-LIB-008).
      return const SizedBox.shrink();
    }
    if (matches.isEmpty) {
      return Center(
        child: ExploreEmptyState(
          icon: Icons.search_off,
          title: 'No results found',
          message: "We couldn't find any artwork matching your search.",
          ctaLabel: 'Explore library',
          onCta: () {
            Navigator.of(context).pop();
            widget.onExploreLibrary();
          },
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      gridDelegate: kLessonGridDelegate,
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final lesson = matches[index];
        return LessonThumbCard(lesson: lesson, onTap: () => widget.onOpenEditor(lesson.id));
      },
    );
  }
}
