import 'package:flutter/material.dart';

import '../../core/constants.dart';

/// PASS 4.4 §1/§7: the artboard's gesture/paint area is now the FULL grey
/// workspace rectangle (which may be taller than it is wide), not a small
/// square sized to fit the artwork — "the initial centered artwork
/// rectangle must NOT be the clipping viewport." At rest (viewScale 1), the
/// 800x800 ArtworkSurface fits this fraction of whichever viewport
/// dimension is smaller, so it starts centered with visible grey margin on
/// every side, free to Pan anywhere across the larger viewport from there.
const double kArtworkFitFraction = 0.86;

/// The ONE base fit scale — artwork-space units -> screen pixels at
/// viewScale 1.0 — derived purely from the actual viewport [Size], never
/// from content/subject bounds. Both [EditorPainter] (forward transform)
/// and [artworkPointFromLocal] (inverse transform) call this SAME function,
/// so there is exactly one authoritative viewport formula, not two that
/// merely happen to agree.
double baseFitScale(Size viewportSize) {
  if (viewportSize.width <= 0 || viewportSize.height <= 0) return 0;
  final limiting = viewportSize.width < viewportSize.height ? viewportSize.width : viewportSize.height;
  return limiting * kArtworkFitFraction / kArtworkSize;
}

/// Reusable screen-space -> artwork-space (0..800) coordinate conversion —
/// the ONE inverse-transform helper every painting tool (Brush, Locked
/// Brush, Fill, Erase, Eyedropper) goes through. `displaySize` is the
/// actual on-screen size of the viewport widget (the full grey workspace,
/// not necessarily square) — NOT a hardcoded constant, so this stays
/// correct regardless of device size or pixel ratio. All drawing state
/// (stroke points, fill/region masks) is stored in the artwork-space
/// result, never in screen coordinates — see core/constants.dart.
///
/// `scale`/`offset` are the Editor's Zoom/Pan view transform (see
/// EditorController.viewScale/viewOffset): screen = offset + scale *
/// baseFitScale(displaySize) * artworkPoint. This inverse must always
/// mirror EditorPainter's forward transform exactly, or taps and paint
/// would visually diverge under Pan/Zoom.
Offset artworkPointFromLocal(
  Offset localPosition,
  Size displaySize, {
  double scale = 1.0,
  Offset offset = Offset.zero,
}) {
  final fit = baseFitScale(displaySize);
  if (fit == 0 || scale == 0) return Offset.zero;
  return (localPosition - offset) / (scale * fit);
}
