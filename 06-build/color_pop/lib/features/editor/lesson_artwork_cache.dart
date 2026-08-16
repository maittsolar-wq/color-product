import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;

import '../../core/constants.dart';
import '../../models/lesson_model.dart';
import 'region_engine.dart';

class LessonArtworkData {
  const LessonArtworkData({required this.barrierMask, required this.lineArtImage});
  final Uint8List barrierMask;
  final ui.Image lineArtImage;
}

/// Decodes + analyzes each lesson's 800x800 artwork PNG ONCE per app
/// session and caches the result, keyed by lessonId — the expensive
/// O(size^2) barrier-mask pass never reruns just because a lesson is
/// reopened (see PASS 2 §18 performance requirement).
class LessonArtworkCache {
  LessonArtworkCache._();

  static final Map<String, LessonArtworkData> _cache = {};
  static final Map<String, Future<LessonArtworkData>> _inFlight = {};

  static Future<LessonArtworkData> load(LessonModel lesson) {
    final cached = _cache[lesson.id];
    if (cached != null) return Future.value(cached);

    final inFlight = _inFlight[lesson.id];
    if (inFlight != null) return inFlight;

    final future = _decodeAndAnalyze(lesson).then((data) {
      _cache[lesson.id] = data;
      _inFlight.remove(lesson.id);
      return data;
    });
    _inFlight[lesson.id] = future;
    return future;
  }

  static Future<LessonArtworkData> _decodeAndAnalyze(LessonModel lesson) async {
    final bytes = await rootBundle.load(lesson.artworkAsset);
    final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    final image = frame.image;
    assert(
      image.width == kArtworkSize && image.height == kArtworkSize,
      'Expected ${kArtworkSize}x$kArtworkSize artwork, got ${image.width}x${image.height} for ${lesson.id}',
    );

    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final rgba = byteData!.buffer.asUint8List();

    final analysis = RegionEngine.analyze(rgba, kArtworkSize);
    final overlayImage = await decodeRgbaImage(analysis.lineArtOverlayRgba, kArtworkSize, kArtworkSize);

    return LessonArtworkData(barrierMask: analysis.barrierMask, lineArtImage: overlayImage);
  }
}

/// Shared RGBA8888 -> ui.Image decode helper (used for the line-art overlay,
/// the fill layer, and per-stroke region-mask images).
Future<ui.Image> decodeRgbaImage(Uint8List rgba, int width, int height) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(rgba, width, height, ui.PixelFormat.rgba8888, completer.complete);
  return completer.future;
}
