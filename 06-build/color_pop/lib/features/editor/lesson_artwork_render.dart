import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../core/app_data.dart';
import '../../core/constants.dart';
import '../../models/lesson_model.dart';
import '../../models/persisted_stroke.dart';
import '../../models/stroke.dart';
import 'editor_painter.dart';
import 'lesson_artwork_cache.dart';
import 'region_engine.dart';

/// PASS 6.2 — on-demand, full-resolution artwork render for Profile's
/// popup (the one place an artwork is shown much larger than a thumbnail).
/// Deliberately separate from [LessonPreviewCache]: that cache renders a
/// SHARED, thumbnail-sized preview persisted on every commit for cheap
/// reuse across Home/Library/Profile's grid; this instead reconstructs the
/// lesson's persisted strokes (same flood-fill approach EditorController
/// uses when opening a lesson) and composites through the same
/// [paintUserArtwork] compositor at up to the artwork's native
/// [kArtworkSize] resolution, computed lazily only when a popup actually
/// opens for one lesson at a time -- never persisted to disk, never run
/// for a whole grid. Returns null if the lesson has no progress yet (the
/// caller falls back to the ordinary static/dynamic thumbnail).
Future<ui.Image?> renderHighResArtworkPreview(LessonModel lesson, {int size = kArtworkSize}) async {
  final progress = AppData.progressRepository.getProgress(lesson.id);
  if (progress == null) return null;

  final artworkData = await LessonArtworkCache.load(lesson);
  final regionEngine = RegionEngine(size: kArtworkSize, barrierMask: artworkData.barrierMask);
  final persisted = await AppData.progressRepository.getDrawingState(lesson.id);
  final strokes = await _hydrateStrokes(persisted, regionEngine);

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()));
  final scale = size / kArtworkSize;
  canvas.scale(scale, scale);
  paintUserArtwork(canvas, strokes: strokes, lineArtImage: artworkData.lineArtImage);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  picture.dispose();
  return image;
}

/// Mirrors EditorController._hydrateStrokes exactly (kept as an isolated
/// copy rather than a shared export so the live coloring-engine file stays
/// untouched by this read-only preview path).
Future<List<BrushStroke>> _hydrateStrokes(List<PersistedStroke> persisted, RegionEngine regionEngine) async {
  final result = <BrushStroke>[];
  for (final p in persisted) {
    ui.Image? maskImage;
    final needsMask = p.tool == StrokeTool.fill || (p.tool == StrokeTool.brush && p.locked);
    if (needsMask) {
      final seed = p.points.first;
      final mask = regionEngine.floodFillFrom(seed.x.round(), seed.y.round());
      if (mask == null) continue;
      maskImage = await _maskToImage(mask);
    }
    result.add(BrushStroke(
      tool: p.tool,
      color: p.color,
      width: p.width,
      points: p.points.map((pt) => StrokePoint(pt.x, pt.y)).toList(),
      regionMaskImage: maskImage,
    ));
  }
  return result;
}

Future<ui.Image> _maskToImage(Uint8List mask) {
  final rgba = Uint8List(kArtworkSize * kArtworkSize * 4);
  for (int i = 0; i < mask.length; i++) {
    if (mask[i] != 0) rgba[i * 4 + 3] = 255;
  }
  return decodeRgbaImage(rgba, kArtworkSize, kArtworkSize);
}
