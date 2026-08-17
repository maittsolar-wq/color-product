import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/app_data.dart';
import '../features/editor/lesson_preview_cache.dart';
import '../models/lesson_model.dart';

/// Dynamic progress preview (§21-22): no progress -> the original static
/// thumbnail asset; has progress -> the persisted composited artwork PNG
/// (PASS 4: loaded from disk, never re-rendered from strokes here — see
/// LessonPreviewCache class doc for why). Shared by LessonThumbCard, Home's
/// Continue card, and Profile's detail popup, so the "static vs dynamic"
/// decision and its loading-fallback behavior live in exactly one place.
class LessonPreviewImage extends StatelessWidget {
  const LessonPreviewImage({super.key, required this.lesson, this.fit = BoxFit.cover});

  final LessonModel lesson;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final progress = AppData.progressRepository.getProgress(lesson.id);
    if (progress == null) {
      return Image.asset(lesson.thumbnailAsset, fit: fit);
    }
    final peeked = LessonPreviewCache.instance.peek(lesson.id);
    if (peeked != null) {
      return RawImage(image: peeked, fit: fit);
    }
    return FutureBuilder<ui.Image?>(
      future: LessonPreviewCache.instance.loadPersisted(lesson.id),
      builder: (context, snapshot) {
        // Cheap once cached (only invalidated on committed lifecycle
        // events, not on every rebuild) — falls back to the static
        // thumbnail only for the brief first load from disk.
        final image = snapshot.data ?? LessonPreviewCache.instance.peek(lesson.id);
        if (image == null) {
          return Image.asset(lesson.thumbnailAsset, fit: fit);
        }
        return RawImage(image: image, fit: fit);
      },
    );
  }
}

/// Shared 250x250-thumbnail lesson card — Home, Library, Search, and Profile
/// all render through this ONE widget so thumbnail usage/sizing/tap
/// behavior never drifts between screens. Home cards omit the title caption
/// (matches the approved prototype); Library/Search/Profile show it.
class LessonThumbCard extends StatelessWidget {
  const LessonThumbCard({
    super.key,
    required this.lesson,
    required this.onTap,
    this.showTitle = true,
    this.width,
  });

  final LessonModel lesson;
  final VoidCallback onTap;
  final bool showTitle;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final card = Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LessonPreviewImage(lesson: lesson),
                ),
              ),
              if (showTitle) ...[
                const SizedBox(height: 6),
                Text(
                  lesson.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (width == null) return card;
    return SizedBox(width: width, child: card);
  }
}
