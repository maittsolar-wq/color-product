import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/app_data.dart';
import '../../features/editor/lesson_artwork_render.dart';
import '../../features/editor/lesson_preview_cache.dart';
import '../../models/lesson_model.dart';
import '../../shared/lesson_thumb_card.dart';

/// Profile Artwork Detail Popup — Profile-only (Home/Library never show
/// this; they always open the Editor directly). Matches the approved
/// prototype structure: dimmed Profile behind, rounded white modal, X
/// close, artwork preview, Restart / Color.
///
/// PASS 3: uses LessonPreviewImage, so the preview here is the CURRENT
/// composited drawing state (or the static thumbnail if none exists yet) —
/// the same one Home/Library/Search show, never a separate copy. Restart
/// clears the lesson's progress record AND in-memory drawing state via
/// ProgressRepository.resetProgress, plus its cached preview, then reopens
/// a clean Editor for the same lesson only.
Future<void> showProfileArtworkPopup({
  required BuildContext context,
  required LessonModel lesson,
  required void Function(String lessonId) onOpenEditor,
}) {
  return showDialog(
    context: context,
    barrierColor: const Color(0x6B141216),
    builder: (context) => _ProfileArtworkPopup(lesson: lesson, onOpenEditor: onOpenEditor),
  );
}

class _ProfileArtworkPopup extends StatelessWidget {
  const _ProfileArtworkPopup({required this.lesson, required this.onOpenEditor});

  final LessonModel lesson;
  final void Function(String lessonId) onOpenEditor;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, size: 18),
                style: IconButton.styleFrom(backgroundColor: const Color(0xFFF5F5F6), shape: const CircleBorder()),
              ),
            ),
            const SizedBox(height: 8),
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  color: const Color(0xFFF4F4F5),
                  child: _HighResPreview(lesson: lesson),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              lesson.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // PASS 4 §15: real persistent reset — progress
                      // record + drawing state (in memory AND on disk, see
                      // ProgressRepository.resetProgress) plus the
                      // persisted preview PNG (deletePersisted, not just
                      // invalidate), so discovery screens revert to the
                      // static thumbnail immediately and it stays that way
                      // across a restart. Never another lesson's data.
                      AppData.progressRepository.resetProgress(lesson.id);
                      unawaited(LessonPreviewCache.instance.deletePersisted(lesson.id));
                      Navigator.of(context).pop();
                      onOpenEditor(lesson.id);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF7C4DFF),
                      side: const BorderSide(color: Color(0xFF7C4DFF), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Restart', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onOpenEditor(lesson.id);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7C4DFF),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Color', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// PASS 6.2 — the popup shows artwork noticeably larger than a grid
/// thumbnail, so it renders the current artwork at up to native resolution
/// on demand (see lesson_artwork_render.dart) instead of stretching the
/// shared thumbnail-sized preview. Shows that shared preview immediately
/// (same image Home/Library/Profile's grid already have in memory) so the
/// popup is never blank, then swaps to the high-res render once it's
/// ready. The high-res image is computed fresh per popup-open and disposed
/// when the popup closes -- never cached long-term, keeping this an
/// on-demand cost rather than a standing memory/CPU cost for every lesson.
class _HighResPreview extends StatefulWidget {
  const _HighResPreview({required this.lesson});

  final LessonModel lesson;

  @override
  State<_HighResPreview> createState() => _HighResPreviewState();
}

class _HighResPreviewState extends State<_HighResPreview> {
  ui.Image? _highRes;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final image = await renderHighResArtworkPreview(widget.lesson);
    if (_disposed) {
      image?.dispose();
      return;
    }
    if (mounted && image != null) {
      setState(() => _highRes = image);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _highRes?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _highRes;
    if (image == null) {
      return LessonPreviewImage(lesson: widget.lesson, fit: BoxFit.contain);
    }
    return RawImage(image: image, fit: BoxFit.contain);
  }
}
