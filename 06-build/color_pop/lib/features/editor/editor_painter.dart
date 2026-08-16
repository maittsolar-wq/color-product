import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/stroke.dart';
import 'editor_controller.dart';

/// Composites (bottom to top): white artwork base, then the Fill layer and
/// the Brush/Erase strokes together inside ONE saveLayer (so Erase's
/// BlendMode.clear reaches user color from EITHER tool — Fill or Brush —
/// and reveals the white base beneath, never the line art), then the
/// immutable line-art overlay on top.
class EditorPainter extends CustomPainter {
  EditorPainter(this.controller) : super(repaint: controller);

  final EditorController controller;

  static final double _artSize = kArtworkSize.toDouble();
  static final Rect _artRect = Rect.fromLTWH(0, 0, _artSize, _artSize);

  @override
  void paint(Canvas canvas, Size size) {
    if (!controller.artworkReady) return;

    final scale = size.width / _artSize;
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.scale(scale, scale);

    canvas.drawRect(_artRect, Paint()..color = Colors.white);

    // Fill and Brush/Erase share this one saveLayer so that an Erase
    // stroke's BlendMode.clear can remove color regardless of whether it
    // was applied by Fill or Brush — clearing within this layer reveals the
    // white base drawn above, never the line art drawn after restore().
    canvas.saveLayer(_artRect, Paint());

    final fillImage = controller.fillImage;
    if (fillImage != null) {
      canvas.drawImage(fillImage, Offset.zero, Paint());
    }

    for (final stroke in controller.strokes) {
      _paintStroke(canvas, stroke.tool, stroke.color, stroke.width, stroke.points, stroke.regionMaskImage);
    }
    final live = controller.liveStroke;
    if (live != null) {
      _paintStroke(canvas, live.tool, live.color, live.width, live.points, live.regionMaskImage);
    }
    canvas.restore();

    final lineArt = controller.lineArtImage;
    if (lineArt != null) {
      canvas.drawImage(lineArt, Offset.zero, Paint());
    }

    canvas.restore();
  }

  void _paintStroke(
    Canvas canvas,
    StrokeTool tool,
    Color color,
    double width,
    List<StrokePoint> points,
    ui.Image? maskImage,
  ) {
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
      // to alpha 0 within the shared Fill+Brush layer, revealing the white
      // artboard base beneath) — never a painted color, so it can never
      // cover the immutable line art with an opaque patch. Color is
      // irrelevant for BlendMode.clear; only the stroked shape matters.
      ..color = isErase ? Colors.black : color
      ..blendMode = isErase ? BlendMode.clear : BlendMode.srcOver;

    if (maskImage == null) {
      canvas.drawPath(path, strokePaint);
      return;
    }

    // Clip this ONE stroke to its precomputed region mask via dstIn — the
    // same destination-in compositing technique Locked Brush always uses,
    // isolated to just this stroke via its own nested saveLayer so it never
    // affects any other stroke already painted in the outer layer.
    canvas.saveLayer(_artRect, Paint());
    canvas.drawPath(path, strokePaint);
    canvas.drawImage(maskImage, Offset.zero, Paint()..blendMode = BlendMode.dstIn);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant EditorPainter oldDelegate) => false; // repaint is driven by `repaint: controller`
}
