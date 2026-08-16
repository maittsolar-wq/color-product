import 'package:flutter/material.dart';

import '../../core/app_data.dart';
import '../../models/lesson_model.dart';

/// SCR-EDITOR-001 — SHELL ONLY for this pass. Loads the correct LessonModel
/// by id and displays the real 800x800 artwork asset (never the thumbnail)
/// inside an approved-layout-shaped topbar/canvas frame. No Brush/Fill/
/// Erase/Lock/Eyedropper/zoom/pan/undo/redo/persistence — those are the
/// Coloring Engine pass's job. This screen's only real purpose right now is
/// proving every card opens the correct real artwork.
class EditorScreen extends StatelessWidget {
  const EditorScreen({super.key, required this.lessonId});

  final String lessonId;

  @override
  Widget build(BuildContext context) {
    final LessonModel? lesson = AppData.lessonRepository.findById(lessonId);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F1F1),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF151515),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        title: Text(
          lesson?.title ?? 'Lesson not found',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: lesson == null
            ? const Center(child: Text('This lesson could not be found.'))
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: const [
                          BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, 8)),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      // The real 800x800 artwork asset — Editor is the only
                      // screen allowed to load lesson.artworkAsset. Every
                      // other screen (Home/Library/Search/Profile) must use
                      // lesson.thumbnailAsset instead.
                      child: Image.asset(lesson.artworkAsset, fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
