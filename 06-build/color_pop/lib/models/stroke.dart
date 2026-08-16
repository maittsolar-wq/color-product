import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Color;

enum StrokeTool { brush, erase }

/// A single point in a stroke, in artwork-space (0..800) coordinates.
class StrokePoint {
  const StrokePoint(this.x, this.y);
  final double x;
  final double y;
}

/// One committed Brush/Erase stroke — immutable once created (see
/// EditorController: strokes are only ever appended/removed from the
/// history list, never mutated in place).
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
  /// pixel ratio or on-screen display size.
  final double width;

  final List<StrokePoint> points;

  /// Non-null only for a LOCKED Brush stroke: an artwork-sized mask image,
  /// opaque where inside the region the stroke started in, transparent
  /// elsewhere. Used to clip this ONE stroke via BlendMode.dstIn. Lock only
  /// ever affects Brush — Erase strokes never carry a mask.
  final ui.Image? regionMaskImage;
}
