import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/stroke.dart';
import 'artwork_coordinates.dart';
import 'editor_controller.dart';

final Rect kArtRect = Rect.fromLTWH(0, 0, kArtworkSize.toDouble(), kArtworkSize.toDouble());

/// PASS 6.3 — a real, hard-bounded 800x800 fully-opaque image, built once
/// and cached, used to force-clip the ENTIRE composited artwork to the
/// source rect via BlendMode.dstIn (see [paintUserArtwork]). `canvas.
/// clipRect`/`clipPath` measured unreliably on-device for content drawn
/// through this compositor's saveLayer/masked-stroke chain (Skia's own
/// docs describe saveLayer's bounds as a rasterization HINT only, and this
/// app's target renderer appears to genuinely not clip stroke content to
/// it) -- `drawImage` + `dstIn` against a real, hard-bounded raster has no
/// such ambiguity: pixels outside the image's own extent are categorically
/// outside the draw operation, not just clipped by hint.
ui.Image? _boundsMaskImage;

ui.Image _getBoundsMaskImage() {
  final cached = _boundsMaskImage;
  if (cached != null) return cached;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(kArtRect, Paint()..color = Colors.white);
  final picture = recorder.endRecording();
  final image = picture.toImageSync(kArtworkSize, kArtworkSize);
  picture.dispose();
  _boundsMaskImage = image;
  return image;
}

/// Composites (bottom to top): white artwork base, then ONE chronological
/// user-paint composition (every Fill/Brush/Erase action, replayed in the
/// exact order the user performed them, inside ONE shared saveLayer), then
/// the immutable line-art overlay on top. Assumes the canvas is ALREADY in
/// artwork-space (0..800) coordinates — callers apply their own transform
/// (viewport scale/pan for the live Editor; a flat fit-to-size scale for an
/// offscreen preview render) before calling this.
///
/// Shared by EditorPainter (the live Editor) AND LessonPreviewCache (the
/// discovery-screen dynamic thumbnails) — ONE compositor, not two, per the
/// PASS 3 "single source of truth" requirement: a thumbnail can never drift
/// from what the Editor itself would render for the same drawing state,
/// because they are, literally, the same function.
///
/// Because Fill/Brush/Erase are all just entries in the SAME ordered list
/// instead of Fill being a separate always-bottom raster, an Erase's
/// BlendMode.clear only ever removes whatever user paint was composited
/// before it in that order — never the white base drawn outside the layer,
/// never the line art drawn after restore() — and any action recorded
/// AFTER an Erase (Fill or Brush) is replayed after it and therefore paints
/// normally on top, unaffected by that earlier Erase.
///
/// PASS 6.3: the WHOLE composition (white base + user paint + line art) is
/// built inside ONE outer saveLayer, then force-masked to exactly the
/// source artwork rect via [_getBoundsMaskImage] + BlendMode.dstIn as the
/// very last step, before that layer is composited back by the final
/// restore(). Nothing this function draws -- regardless of a Brush/Erase
/// stroke's width pushing its geometry past x=800/y=800 (or below 0) --
/// can survive into the final result outside that rect. Because the mask
/// is applied here, inside the shared compositor, it automatically rides
/// along with whatever transform the caller already applied (viewport
/// scale/pan for the live Editor) -- the boundary moves and scales WITH
/// the artwork under Zoom/Pan, never pinned to a fixed screen position.
void paintUserArtwork(
  Canvas canvas, {
  required List<BrushStroke> strokes,
  required ui.Image? lineArtImage,
  LiveStroke? liveStroke,
}) {
  canvas.saveLayer(kArtRect, Paint());

  canvas.drawRect(kArtRect, Paint()..color = Colors.white);

  canvas.saveLayer(kArtRect, Paint());
  for (final stroke in strokes) {
    _paintAction(canvas, stroke.tool, stroke.color, stroke.width, stroke.points, stroke.regionMaskImage);
  }
  if (liveStroke != null) {
    _paintAction(canvas, liveStroke.tool, liveStroke.color, liveStroke.width, liveStroke.points, liveStroke.regionMaskImage);
  }
  canvas.restore();

  if (lineArtImage != null) {
    canvas.drawImage(lineArtImage, Offset.zero, Paint());
  }

  canvas.drawImage(_getBoundsMaskImage(), Offset.zero, Paint()..blendMode = BlendMode.dstIn);
  canvas.restore();
}

void _paintAction(
  Canvas canvas,
  StrokeTool tool,
  Color color,
  double width,
  List<StrokePoint> points,
  ui.Image? maskImage,
) {
  if (tool == StrokeTool.fill) {
    // A Fill action is a flat color over its whole precomputed region
    // mask — not a stroked path. Clipped via the same BlendMode.dstIn
    // technique masked Brush strokes use, isolated to just this action
    // via its own nested saveLayer.
    if (maskImage == null) return; // a fill action always carries its region mask
    canvas.saveLayer(kArtRect, Paint());
    canvas.drawRect(kArtRect, Paint()..color = color);
    canvas.drawImage(maskImage, Offset.zero, Paint()..blendMode = BlendMode.dstIn);
    canvas.restore();
    return;
  }

  if (points.isEmpty) return;
  final path = Path()..moveTo(points.first.x, points.first.y);
  if (points.length == 1) {
    // A tap with no drag — draw a dot so a single click is still visible.
    path.lineTo(points.first.x + 0.01, points.first.y);
  } else {
    for (final p in points.skip(1)) {
      path.lineTo(p.x, p.y);
    }
  }

  final isErase = tool == StrokeTool.erase;
  final strokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    // Erase is true transparent removal (BlendMode.clear wipes pixels back
    // to alpha 0 within the shared user-paint layer, revealing whatever
    // was drawn earlier in that same layer, or the white artboard base if
    // nothing was) — never a painted color, so it can never cover the
    // immutable line art with an opaque patch. Color is irrelevant for
    // BlendMode.clear; only the stroked shape matters.
    ..color = isErase ? Colors.black : color
    ..blendMode = isErase ? BlendMode.clear : BlendMode.srcOver;

  if (maskImage == null) {
    canvas.drawPath(path, strokePaint);
    return;
  }

  // Clip this ONE stroke to its precomputed region mask via dstIn — the
  // same destination-in compositing technique Locked Brush always uses,
  // isolated to just this stroke via its own nested saveLayer so it never
  // affects any other action already painted in the outer layer.
  canvas.saveLayer(kArtRect, Paint());
  canvas.drawPath(path, strokePaint);
  canvas.drawImage(maskImage, Offset.zero, Paint()..blendMode = BlendMode.dstIn);
  canvas.restore();
}

/// Paints the live Editor — adds the PASS 3/4.4 Zoom/Pan viewport transform
/// (and the live in-progress stroke, and the sheet's own drop shadow) on
/// top of the shared `paintUserArtwork` compositor. Zoom/Pan are purely a
/// canvas transform applied here; they never alter `controller.strokes` or
/// any stored coordinate. PASS 4.4: the viewport is the full widget size —
/// which may be a tall rectangle, not a square sized to the artwork — and
/// `baseFitScale` (the SAME function `artworkPointFromLocal` inverts) is
/// the one authoritative formula for how the 800x800 sheet maps into it.
class EditorPainter extends CustomPainter {
  EditorPainter(this.controller) : super(repaint: controller);

  final EditorController controller;

  @override
  void paint(Canvas canvas, Size size) {
    if (!controller.artworkReady) return;

    final baseScale = baseFitScale(size);
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Zoom/Pan viewport transform: screen = viewOffset + viewScale *
    // (baseScale * artworkPoint) — must mirror artworkPointFromLocal's
    // inverse exactly, or taps and paint would diverge under zoom.
    canvas.translate(controller.viewOffset.dx, controller.viewOffset.dy);
    canvas.scale(controller.viewScale);
    canvas.scale(baseScale, baseScale);

    // PASS 4.4 §5/§13: the sheet's own drop shadow is drawn HERE, inside
    // the same transformed canvas state as everything else, so it pans and
    // scales together with the white background/paint/line-art as part of
    // ONE artwork object ("one flat coloring page") — never as a separate,
    // fixed frame decoration behind it.
    final shadowPaint = Paint()
      ..color = const Color(0x33000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawRect(kArtRect.translate(0, 6), shadowPaint);

    paintUserArtwork(
      canvas,
      strokes: controller.strokes,
      lineArtImage: controller.lineArtImage,
      liveStroke: controller.liveStroke,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant EditorPainter oldDelegate) => false; // repaint is driven by `repaint: controller`
}
