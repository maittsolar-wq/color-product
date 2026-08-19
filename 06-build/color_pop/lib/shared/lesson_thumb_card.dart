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

/// PASS 6.4 §7 — the shared, subtle rounded border every lesson thumbnail
/// (Home/Library/Profile/Completion-recommendations, all via
/// [LessonThumbCard]) uses to separate a white-background line-art artwork
/// from the app's own white/light page background. Pure UI decoration:
/// applied around the artwork widget, never rasterized into it, so dynamic
/// colored previews keep rendering exactly as before.
const Color kThumbnailBorderColor = Color(0xFFE4E4E7);
const double kThumbnailBorderRadius = 15;

/// THUMBNAIL UI UPDATE — the ONE shared 2-column grid delegate for every
/// lesson thumbnail grid (Library, Search, Profile, Completion
/// recommendations), so their spacing/density never drifts apart into four
/// separately-tuned copies. Every consumer is now thumbnail-only (no title
/// caption reserved -- see [LessonThumbCard]), so `childAspectRatio: 1` is
/// the exact, fully width-responsive value: the card's natural height
/// always equals its given width (symmetric 8px padding around a square
/// image, nothing else), so a square cell fits it with zero slack at any
/// screen width. Deliberately a ratio, not a hardcoded `mainAxisExtent`,
/// which would only be exactly square at one specific screen width.
const SliverGridDelegateWithFixedCrossAxisCount kLessonGridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
  mainAxisSpacing: 16,
  crossAxisSpacing: 14,
  childAspectRatio: 1,
);

/// Shared thumbnail-only lesson card — Home, Library, Search, and Profile
/// all render through this ONE widget so thumbnail usage/sizing/tap
/// behavior never drifts between screens. THUMBNAIL UI UPDATE: lesson
/// titles are never shown here (moved to Home's Continue card and Profile's
/// detail popup, which render the title themselves) — the visible label is
/// preserved for assistive tech via [Semantics] instead.
class LessonThumbCard extends StatelessWidget {
  const LessonThumbCard({
    super.key,
    required this.lesson,
    required this.onTap,
    this.width,
  });

  final LessonModel lesson;
  final VoidCallback onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final card = Semantics(
      label: lesson.title,
      button: true,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(kThumbnailBorderRadius),
                  border: Border.all(color: kThumbnailBorderColor, width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(kThumbnailBorderRadius - 1),
                  child: LessonPreviewImage(lesson: lesson),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (width == null) return card;
    return SizedBox(width: width, child: card);
  }
}
