import 'package:flutter/foundation.dart';

/// PASS 3.2 §3 — Editor Settings in-memory state. Explicitly NOT persisted
/// to disk/preferences yet (that's a later pass) — lives for the app
/// process lifetime only, the same singleton pattern already used by
/// LessonPreviewCache. Scoped app-wide (not per-lesson/per-EditorController)
/// so toggles survive closing and reopening the sheet, or opening a
/// different lesson, within the same session — but reset on app restart.
///
/// Sounds / Color History / Mirror Mode are UI-state toggles ONLY in this
/// pass: none of them are wired to real audio, mirrored canvas rendering,
/// or palette-history-disabling behavior. Wiring real functionality behind
/// them would be inventing undocumented behavior beyond what was asked for
/// this pass.
class EditorSettings extends ChangeNotifier {
  EditorSettings._();
  static final EditorSettings instance = EditorSettings._();

  bool soundEnabled = true;
  bool colorHistoryEnabled = true;
  bool mirrorModeEnabled = false;

  void toggleSound() {
    soundEnabled = !soundEnabled;
    notifyListeners();
  }

  void toggleColorHistory() {
    colorHistoryEnabled = !colorHistoryEnabled;
    notifyListeners();
  }

  void toggleMirrorMode() {
    mirrorModeEnabled = !mirrorModeEnabled;
    notifyListeners();
  }
}
