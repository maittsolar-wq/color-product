import 'package:flutter/material.dart';

import '../../core/constants.dart';

/// Reusable screen-space -> artwork-space (0..800) coordinate conversion —
/// the ONE inverse-transform helper every painting tool (Brush, Locked
/// Brush, Fill, Erase) goes through. `displaySize` is the actual on-screen
/// size of the artboard widget (a square, since the artwork is always
/// rendered at 1:1 aspect ratio) — NOT a hardcoded constant, so this stays
/// correct regardless of device size or pixel ratio. All drawing state
/// (stroke points, fill/region masks) is stored in the artwork-space
/// result, never in screen coordinates — see core/constants.dart.
///
/// PASS 3: `scale`/`offset` are the Editor's Zoom/Pan view transform (see
/// EditorController.viewScale/viewOffset). They default to the identity
/// (1.0 / Offset.zero) so callers outside the zoomable artboard are
/// unaffected. The inverse order here (undo pan, then undo zoom, THEN this
/// same base linear mapping) must always mirror EditorPainter's forward
/// transform exactly, or taps and paint would visually diverge under zoom.
Offset artworkPointFromLocal(
  Offset localPosition,
  Size displaySize, {
  double scale = 1.0,
  Offset offset = Offset.zero,
}) {
  if (displaySize.width == 0 || displaySize.height == 0) return Offset.zero;
  final displayPoint = (localPosition - offset) / scale;
  return Offset(
    displayPoint.dx / displaySize.width * kArtworkSize,
    displayPoint.dy / displaySize.height * kArtworkSize,
  );
}
