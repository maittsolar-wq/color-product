// Unit tests for the shared closed-region flood-fill engine (RegionEngine)
// — the core algorithm behind both Locked Brush and Fill. Pure Dart logic,
// no widget/rendering dependencies, so these run fast and exercise the
// engine directly against synthetic pixel grids.

import 'dart:typed_data';

import 'package:color_pop/features/editor/region_engine.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _solidWhiteRgba(int size) {
  final rgba = Uint8List(size * size * 4);
  for (int i = 0; i < size * size; i++) {
    rgba[i * 4] = 255;
    rgba[i * 4 + 1] = 255;
    rgba[i * 4 + 2] = 255;
    rgba[i * 4 + 3] = 255;
  }
  return rgba;
}

void _setBlackPixel(Uint8List rgba, int size, int x, int y) {
  final base = (y * size + x) * 4;
  rgba[base] = 0;
  rgba[base + 1] = 0;
  rgba[base + 2] = 0;
  rgba[base + 3] = 255;
}

void main() {
  group('RegionEngine.analyze', () {
    test('marks black pixels as barriers and white pixels as non-barrier', () {
      const size = 20;
      final rgba = _solidWhiteRgba(size);
      _setBlackPixel(rgba, size, 10, 10);

      final analysis = RegionEngine.analyze(rgba, size);

      // The exact pixel is a barrier.
      expect(analysis.barrierMask[10 * size + 10], 1);
      // A pixel well away from the (dilated-by-1) black pixel is not.
      expect(analysis.barrierMask[2 * size + 2], 0);
    });

    test('line-art overlay is transparent everywhere except dark pixels', () {
      const size = 10;
      final rgba = _solidWhiteRgba(size);
      _setBlackPixel(rgba, size, 5, 5);

      final analysis = RegionEngine.analyze(rgba, size);
      final darkBase = (5 * size + 5) * 4;
      expect(analysis.lineArtOverlayRgba[darkBase + 3], 255); // opaque ink
      final whiteBase = (0 * size + 0) * 4;
      expect(analysis.lineArtOverlayRgba[whiteBase + 3], 0); // transparent background
    });
  });

  group('RegionEngine.floodFillFrom', () {
    test('returns null when the start point is itself a barrier', () {
      const size = 20;
      final rgba = _solidWhiteRgba(size);
      _setBlackPixel(rgba, size, 10, 10);
      final analysis = RegionEngine.analyze(rgba, size);
      final engine = RegionEngine(size: size, barrierMask: analysis.barrierMask);

      expect(engine.floodFillFrom(10, 10), isNull);
    });

    test('a vertical barrier line splits the artwork into two separate regions', () {
      const size = 20;
      final rgba = _solidWhiteRgba(size);
      // Full-height vertical black line at x=10 -- splits the image in two.
      for (int y = 0; y < size; y++) {
        _setBlackPixel(rgba, size, 10, y);
      }
      final analysis = RegionEngine.analyze(rgba, size);
      final engine = RegionEngine(size: size, barrierMask: analysis.barrierMask);

      final leftMask = engine.floodFillFrom(2, 2)!;
      final rightMask = engine.floodFillFrom(18, 2)!;

      // Each side reaches its own far pixel...
      expect(leftMask[2 * size + 2], 1);
      expect(rightMask[2 * size + 18], 1);
      // ...but never crosses into the other side (the whole point of the
      // barrier -- this is what makes a Locked Brush stroke or a Fill tap
      // stay within one closed region instead of leaking through).
      expect(leftMask[2 * size + 18], 0);
      expect(rightMask[2 * size + 2], 0);
    });

    test('the connected outer background reaches every true edge pixel (no artificial inset frame)', () {
      const size = 30;
      final rgba = _solidWhiteRgba(size);
      // A small closed black square "subject" near the center, entirely
      // surrounded by connected white background.
      for (int y = 12; y <= 18; y++) {
        for (int x = 12; x <= 18; x++) {
          final onBorder = x == 12 || x == 18 || y == 12 || y == 18;
          if (onBorder) _setBlackPixel(rgba, size, x, y);
        }
      }
      final analysis = RegionEngine.analyze(rgba, size);
      final engine = RegionEngine(size: size, barrierMask: analysis.barrierMask);

      // Tap just outside the subject, near a corner of the artwork.
      final backgroundMask = engine.floodFillFrom(1, 1)!;

      // The connected background must reach the TRUE 0..size-1 edges on all
      // four sides -- exactly the "full outer background fill, no
      // artificial white inner frame" requirement.
      expect(backgroundMask[0 * size + 0], 1); // top-left true corner
      expect(backgroundMask[0 * size + (size - 1)], 1); // top-right true corner
      expect(backgroundMask[(size - 1) * size + 0], 1); // bottom-left true corner
      expect(backgroundMask[(size - 1) * size + (size - 1)], 1); // bottom-right true corner

      // But the fully-enclosed interior of the subject square is NOT part
      // of that same region (it's a separate closed region).
      final insideSubject = engine.floodFillFrom(15, 15)!;
      expect(insideSubject[15 * size + 15], 1);
      expect(insideSubject[0 * size + 0], 0);
    });
  });
}
