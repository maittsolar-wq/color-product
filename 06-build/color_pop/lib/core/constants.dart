/// The fixed source coordinate system every real lesson artwork uses (see
/// assets/data/lessons.json). ALL Editor drawing state (stroke points, the
/// fill buffer, region masks) is stored in this coordinate system, never
/// raw screen/device pixels — required for correct behavior regardless of
/// on-screen display size or device pixel ratio, and ready for a future
/// zoom/pan pass (only the display <-> artwork conversion step would need
/// to change, not how state is stored).
const int kArtworkSize = 800;
