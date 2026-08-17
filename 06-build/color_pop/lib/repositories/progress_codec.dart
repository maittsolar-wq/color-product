import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;

import '../models/lesson_progress.dart';
import '../models/persisted_stroke.dart';

/// PASS 4 schema version for a single lesson's persisted record. Bump this
/// and add a migration branch in [decodeLessonRecord] if the shape ever
/// changes — unknown/older versions currently just fail closed (treated as
/// corrupt -> clean lesson) rather than crashing.
const int kLessonRecordSchemaVersion = 1;

/// A decoded lesson record: the lightweight status/timestamp metadata plus
/// the full chronological action list needed to reconstruct the artwork.
class DecodedLessonRecord {
  const DecodedLessonRecord({required this.progress, required this.strokes});
  final LessonProgress progress;
  final List<PersistedStroke> strokes;
}

Map<String, dynamic> encodeLessonRecord({
  required LessonProgress progress,
  required List<PersistedStroke> strokes,
}) {
  return {
    'version': kLessonRecordSchemaVersion,
    'progress': progress.toJson(),
    'strokes': strokes.map((s) => s.toJson()).toList(),
  };
}

/// Returns `null` if the record is unreadable/unsupported (caller falls
/// back to a clean lesson). Individual malformed strokes are skipped rather
/// than failing the whole lesson.
DecodedLessonRecord? decodeLessonRecord(Map<String, dynamic> json) {
  try {
    final version = json['version'] as int?;
    if (version != kLessonRecordSchemaVersion) {
      debugPrint('[ProgressCodec] unsupported schema version: $version');
      return null;
    }
    final progressJson = json['progress'] as Map<String, dynamic>;
    final progress = LessonProgress.fromJson(progressJson);
    if (progress == null) return null;

    final rawStrokes = json['strokes'] as List;
    final strokes = <PersistedStroke>[];
    for (final raw in rawStrokes) {
      final stroke = PersistedStroke.fromJson(raw as Map<String, dynamic>);
      if (stroke != null) strokes.add(stroke);
    }
    return DecodedLessonRecord(progress: progress, strokes: strokes);
  } catch (e) {
    debugPrint('[ProgressCodec] failed to decode lesson record: $e');
    return null;
  }
}

/// App-level MRU color history (`color_history.json`) — a flat ordered list
/// of ARGB ints, most-recent-first.
Map<String, dynamic> encodeColorHistory(List<Color> colors) {
  return {
    'version': kLessonRecordSchemaVersion,
    'colors': colors.map((c) => c.toARGB32()).toList(),
  };
}

List<Color>? decodeColorHistory(Map<String, dynamic> json) {
  try {
    final version = json['version'] as int?;
    if (version != kLessonRecordSchemaVersion) return null;
    final raw = json['colors'] as List;
    return raw.map((v) => Color(v as int)).toList();
  } catch (e) {
    debugPrint('[ProgressCodec] failed to decode color history: $e');
    return null;
  }
}
