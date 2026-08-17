import 'package:flutter/material.dart' show Color;

import 'stroke.dart';

/// PASS 4 — the on-disk shape of a single chronological paint action.
///
/// This is deliberately a *separate* type from [BrushStroke]: `BrushStroke`
/// carries a live `ui.Image? regionMaskImage`, which cannot be serialized
/// and is never persisted. Fill / locked-Brush masks are regenerated on
/// load via `RegionEngine.floodFillFrom(points.first)` — the exact same
/// deterministic call the live engine already makes — so only the seed
/// point and a `locked` flag need to survive a save/restore cycle.
class PersistedStroke {
  const PersistedStroke({
    required this.tool,
    required this.color,
    required this.width,
    required this.points,
    required this.locked,
  });

  final StrokeTool tool;
  final Color color;
  final double width;
  final List<PersistedPoint> points;
  final bool locked;

  Map<String, dynamic> toJson() => {
    'tool': tool.name,
    'color': color.toARGB32(),
    'width': width,
    'locked': locked,
    'points': points.map((p) => p.toJson()).toList(),
  };

  /// Returns `null` (rather than throwing) on any malformed entry, so a
  /// single corrupt stroke degrades that one action instead of the whole
  /// lesson — the decoder that calls this simply skips nulls.
  static PersistedStroke? fromJson(Map<String, dynamic> json) {
    try {
      final tool = StrokeTool.values.byName(json['tool'] as String);
      final color = Color(json['color'] as int);
      final width = (json['width'] as num).toDouble();
      final locked = json['locked'] as bool? ?? false;
      final rawPoints = json['points'] as List;
      final points = rawPoints.map((p) => PersistedPoint.fromJson(p as List)).toList();
      if (points.isEmpty) return null;
      return PersistedStroke(tool: tool, color: color, width: width, points: points, locked: locked);
    } catch (_) {
      return null;
    }
  }
}

class PersistedPoint {
  const PersistedPoint(this.x, this.y);
  final double x;
  final double y;

  List<double> toJson() => [x, y];

  static PersistedPoint fromJson(List<dynamic> json) {
    return PersistedPoint((json[0] as num).toDouble(), (json[1] as num).toDouble());
  }
}
