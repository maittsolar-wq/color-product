import 'dart:typed_data';

/// Result of analyzing a decoded artwork's raw RGBA pixels: a barrier mask
/// for flood-fill region detection, and a transparent-background "ink only"
/// overlay for display (source PNGs have an opaque white background, which
/// would otherwise hide the fill/brush layers underneath it).
class ArtworkAnalysis {
  const ArtworkAnalysis({required this.barrierMask, required this.lineArtOverlayRgba});
  final Uint8List barrierMask;
  final Uint8List lineArtOverlayRgba;
}

/// SHARED closed-region flood-fill engine — used by BOTH Locked Brush and
/// Fill (per the approved behavior, one engine, not two). Operates purely
/// on the immutable source artwork's pixels; never mutates them.
///
/// Sufficiently dark/opaque pixels are BARRIERS. A small dilation is applied
/// to a barrier-mask COPY (never to the displayed line-art overlay) so
/// anti-aliased line edges don't leak between regions, without visually
/// thickening the ink. The raster's own edges are an implicit barrier, so
/// the connected white background surrounding the subject is bounded by the
/// true 800x800 artwork edge — exactly like any internal enclosed region.
class RegionEngine {
  RegionEngine({required this.size, required this.barrierMask});

  final int size;
  final Uint8List barrierMask; // 1 = barrier, length == size*size

  /// One-time pixel pass producing both the region-detection barrier mask
  /// and the display overlay. `rgba` must be `size*size*4` bytes
  /// (RGBA8888, as returned by `ui.Image.toByteData`).
  static ArtworkAnalysis analyze(Uint8List rgba, int size) {
    final mask = Uint8List(size * size);
    final overlay = Uint8List(size * size * 4);
    for (int i = 0; i < size * size; i++) {
      final base = i * 4;
      final r = rgba[base], g = rgba[base + 1], b = rgba[base + 2], a = rgba[base + 3];
      final darkness = 255 - (r + g + b) / 3;
      final isDark = a > 40 && darkness > 90; // threshold tolerant of anti-aliased edges
      if (isDark) {
        mask[i] = 1;
        overlay[base + 3] = 255; // opaque black ink; r/g/b already zeroed
      }
    }
    _dilate(mask, size, 1);
    return ArtworkAnalysis(barrierMask: mask, lineArtOverlayRgba: overlay);
  }

  static void _dilate(Uint8List mask, int size, int radius) {
    final copy = Uint8List.fromList(mask);
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        if (copy[y * size + x] != 0) continue;
        var hit = false;
        for (int dy = -radius; dy <= radius && !hit; dy++) {
          for (int dx = -radius; dx <= radius && !hit; dx++) {
            final nx = x + dx, ny = y + dy;
            if (nx < 0 || nx >= size || ny < 0 || ny >= size) continue;
            if (copy[ny * size + nx] != 0) hit = true;
          }
        }
        if (hit) mask[y * size + x] = 1;
      }
    }
  }

  /// Stack-based 4-directional flood fill from (x, y). Returns null if the
  /// start point is itself a barrier (tapped directly on a line) — otherwise
  /// a same-size mask (1 = inside the connected region). Out-of-bounds is an
  /// implicit barrier via the bounds check in `_tryVisit`.
  Uint8List? floodFillFrom(int x, int y) {
    final sx = _clampInt(x, 0, size - 1);
    final sy = _clampInt(y, 0, size - 1);
    final startIdx = sy * size + sx;
    if (barrierMask[startIdx] != 0) return null;

    final visited = Uint8List(size * size);
    final stack = <int>[startIdx];
    visited[startIdx] = 1;
    while (stack.isNotEmpty) {
      final idx = stack.removeLast();
      final cx = idx % size;
      final cy = idx ~/ size;
      _tryVisit(cx - 1, cy, visited, stack);
      _tryVisit(cx + 1, cy, visited, stack);
      _tryVisit(cx, cy - 1, visited, stack);
      _tryVisit(cx, cy + 1, visited, stack);
    }
    return visited;
  }

  void _tryVisit(int x, int y, Uint8List visited, List<int> stack) {
    if (x < 0 || x >= size || y < 0 || y >= size) return;
    final idx = y * size + x;
    if (visited[idx] != 0 || barrierMask[idx] != 0) return;
    visited[idx] = 1;
    stack.add(idx);
  }

  static int _clampInt(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);
}
