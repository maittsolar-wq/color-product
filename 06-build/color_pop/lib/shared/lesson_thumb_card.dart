import 'package:flutter/material.dart';

import '../models/lesson_model.dart';

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
                  child: Image.asset(
                    lesson.thumbnailAsset,
                    fit: BoxFit.cover,
                  ),
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
