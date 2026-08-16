import 'package:flutter/material.dart';

import '../../core/constants.dart';

/// Reusable screen-space -> artwork-space (0..800) coordinate conversion.
/// `displaySize` is the actual on-screen size of the artboard widget (a
/// square, since the artwork is always rendered at 1:1 aspect ratio) — NOT
/// a hardcoded constant, so this stays correct regardless of device size or
/// pixel ratio. All drawing state (stroke points, fill/region masks) is
/// stored in the artwork-space result, never in screen coordinates — see
/// core/constants.dart.
///
/// This is the single point a future Zoom/Pan pass would extend (inverse
/// pan, then inverse scale, before this same linear mapping) — nothing else
/// in the Editor needs to change to support that later.
Offset artworkPointFromLocal(Offset localPosition, Size displaySize) {
  if (displaySize.width == 0 || displaySize.height == 0) return Offset.zero;
  return Offset(
    localPosition.dx / displaySize.width * kArtworkSize,
    localPosition.dy / displaySize.height * kArtworkSize,
  );
}
