import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_data.dart';
import '../../core/constants.dart';
import '../../models/lesson_model.dart';
import '../../models/stroke.dart';
import '../../shared/lesson_thumb_card.dart';
import '../editor/artwork_export_service.dart';
import '../editor/editor_painter.dart';
import '../editor/lesson_artwork_cache.dart';

/// SCR-COMPLETE-001 (PASS 5) — reached only from the Editor's Done action;
/// by the time this pushes, EditorController.completeLesson has already
/// durably persisted the drawing state, preview, and COMPLETED status.
/// [strokes] is the EXACT chronological action list at the moment Done was
/// tapped — the same in-memory list the live Editor was already holding,
/// never re-hydrated from disk here, so the artwork preview and Share/Save
/// exports can never drift from what the user just saw.
class CompletionScreen extends StatefulWidget {
  const CompletionScreen({
    super.key,
    required this.lesson,
    required this.strokes,
    required this.onOpenEditor,
    required this.onBackToHome,
  });

  final LessonModel lesson;
  final List<BrushStroke> strokes;

  /// §11 — a tapped recommendation goes straight to the Editor, never the
  /// Profile artwork popup. The SAME AppShell-owned callback threaded all
  /// the way down from EditorScreen, so the new Editor can itself complete
  /// and recommend further.
  final void Function(String lessonId) onOpenEditor;

  /// §7/§6 — pops every pushed route back to the AppShell root AND selects
  /// the Home tab, so repeated Editor -> Done -> Completion -> Back ->
  /// Editor -> Done cycles never leave a growing stack of stale routes,
  /// and "Back to home" always lands on Home specifically, not whichever
  /// tab happened to be active before.
  final VoidCallback onBackToHome;

  @override
  State<CompletionScreen> createState() => _CompletionScreenState();
}

class _CompletionScreenState extends State<CompletionScreen> {
  bool _isSharing = false;
  bool _isSaving = false;

  // PASS 5.1 — computed exactly ONCE when this screen is created, never
  // re-derived in build(). recommendationsFor() shuffles on every call, so
  // reading it from build() would reshuffle the cards on every unrelated
  // rebuild (e.g. the Share/Save loading-spinner setState calls below).
  // Opening a NEW CompletionScreen instance (a fresh Done tap) computes a
  // fresh random set, which is the intended "may differ next time" result.
  late final List<LessonModel> _recommended = AppData.lessonRepository.recommendationsFor(widget.lesson);

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating));
  }

  /// §14/§12 — generates the SAME export PNG Save uses, writes it to a
  /// throwaway app-cache temp file (never the public Gallery — that's
  /// Save's job), and hands it to the native Android share sheet. A
  /// cancelled share simply returns here — SharePlus.share resolves
  /// normally either way, so there is nothing to detect or special-case.
  Future<void> _handleShare() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final bytes = await renderArtworkForExport(lesson: widget.lesson, strokes: widget.strokes);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/colorpop_${widget.lesson.id}_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } catch (e) {
      debugPrint('[CompletionScreen] share failed: $e');
      _showMessage('Could not share artwork.');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  /// §15/§12 — the SAME export PNG (§14), saved straight to the device's
  /// Gallery/Photos via `gal`'s MediaStore-backed API — no broad legacy
  /// storage permission is ever requested (gal's own Android manifest
  /// declares none; inserting new app-created media needs none on modern
  /// Android).
  Future<void> _handleSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final hasAccess = await Gal.requestAccess();
      if (!hasAccess) {
        _showMessage('Permission needed to save to your device.');
        return;
      }
      final bytes = await renderArtworkForExport(lesson: widget.lesson, strokes: widget.strokes);
      await Gal.putImageBytes(bytes, name: 'colorpop_${widget.lesson.id}_${DateTime.now().millisecondsSinceEpoch}');
      _showMessage('Saved to device');
    } catch (e) {
      debugPrint('[CompletionScreen] save failed: $e');
      _showMessage('Could not save artwork.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // §11 — the STABLE list computed once in initState (see _recommended
    // doc) -- never recomputed here, so it never reshuffles on rebuild.
    final recommended = _recommended;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF151515),
        // §6 — a plain pop, always returning to the SAME Editor instance
        // that pushed this screen (never a fresh one, never a reset) — the
        // mechanism that keeps repeated Done/Back cycles from stacking up
        // duplicate Completion routes.
        leading: BackButton(key: const Key('completion-back'), onPressed: () => Navigator.of(context).pop()),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            const Text('Amazing!', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              'You brought ${widget.lesson.title} to life.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B6B70)),
            ),
            const SizedBox(height: 20),
            _CompletionArtwork(lesson: widget.lesson, strokes: widget.strokes),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('completion-share'),
                    onPressed: _isSharing ? null : _handleShare,
                    icon: _isSharing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C4DFF)),
                          )
                        : const Icon(Icons.ios_share, size: 18),
                    label: const Text('Share'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF7C4DFF),
                      side: const BorderSide(color: Color(0xFF7C4DFF), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('completion-save'),
                    onPressed: _isSaving ? null : _handleSave,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C4DFF)),
                          )
                        : const Icon(Icons.download, size: 18),
                    label: const Text('Save'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF7C4DFF),
                      side: const BorderSide(color: Color(0xFF7C4DFF), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('completion-back-home'),
                onPressed: widget.onBackToHome,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7C4DFF),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Back to home', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
            if (recommended.isNotEmpty) ...[
              const SizedBox(height: 32),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Recommended for you', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: kLessonGridDelegate,
                itemCount: recommended.length,
                itemBuilder: (context, index) {
                  final rec = recommended[index];
                  // §11 — recommendation tap goes straight to the Editor,
                  // never the Profile artwork popup.
                  return LessonThumbCard(key: Key('completion-recommended-${rec.id}'), lesson: rec, onTap: () => widget.onOpenEditor(rec.id));
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// §5 — the large completed-artwork preview MUST be the real coloring
/// engine's composite (white canvas + Fill/Brush/Erase chronology + line
/// art), never a static thumbnail, a 250x250 preview, or an Editor
/// screenshot. Renders through the exact same `paintUserArtwork` function
/// EditorPainter and the export service use.
class _CompletionArtwork extends StatelessWidget {
  const _CompletionArtwork({required this.lesson, required this.strokes});

  final LessonModel lesson;
  final List<BrushStroke> strokes;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Color(0xFFF4F4F5)),
          child: FutureBuilder<LessonArtworkData>(
            future: LessonArtworkCache.load(lesson),
            builder: (context, snapshot) {
              final artwork = snapshot.data;
              if (artwork == null) {
                return const Center(child: CircularProgressIndicator());
              }
              return CustomPaint(
                key: const Key('completion-artwork'),
                painter: _CompletionArtworkPainter(strokes: strokes, lineArtImage: artwork.lineArtImage),
                child: const SizedBox.expand(),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CompletionArtworkPainter extends CustomPainter {
  _CompletionArtworkPainter({required this.strokes, required this.lineArtImage});

  final List<BrushStroke> strokes;
  final ui.Image lineArtImage;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / kArtworkSize;
    canvas.save();
    canvas.scale(scale, scale);
    paintUserArtwork(canvas, strokes: strokes, lineArtImage: lineArtImage);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CompletionArtworkPainter oldDelegate) =>
      oldDelegate.strokes != strokes || oldDelegate.lineArtImage != lineArtImage;
}
