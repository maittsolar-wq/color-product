import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Color;

enum StrokeTool { brush, fill, erase }

/// A single point in a stroke, in artwork-space (0..800) coordinates.
class StrokePoint {
  const StrokePoint(this.x, this.y);
  final double x;
  final double y;
}

/// ONE committed user-paint action — Brush stroke, Erase stroke, OR Fill tap
/// — immutable once created and appended, in chronological order, to
/// EditorController.strokes (the single ordered user-paint composition; see
/// EditorPainter). Actions are only ever appended/removed at the list tail
/// by Undo/Redo, never mutated in place and never reordered, so replaying
/// them in list order every frame reproduces exactly what the user did and
/// in what order they did it — including a later action correctly painting
/// over an earlier Erase.
class BrushStroke {
  const BrushStroke({
    required this.tool,
    required this.color,
    required this.width,
    required this.points,
    this.regionMaskImage,
  });

  final StrokeTool tool;

  /// Irrelevant for `erase` (true transparent removal never paints a color).
  final Color color;

  /// Stroke width in artwork-space (800x800) units — independent of device
  /// pixel ratio or on-screen display size. Irrelevant for `fill` (a region
  /// fill has no stroke width).
  final double width;

  /// For `brush`/`erase`: the dragged path. For `fill`: a single point (the
  /// tap location) — kept only for consistency/debugging, not used to
  /// render the fill (the fill renders via `regionMaskImage`).
  final List<StrokePoint> points;

  /// For a LOCKED Brush stroke or a Fill action: an artwork-sized mask
  /// image, opaque where inside the region the action started in,
  /// transparent elsewhere. Used to clip via BlendMode.dstIn — REQUIRED
  /// (non-null) for `fill`, optional for `brush` (only when Lock is on),
  /// always null for `erase` (Lock never affects Erase).
  final ui.Image? regionMaskImage;
}
