import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'color_picker_sheet.dart';
import 'editor_controller.dart';
import 'editor_painter.dart';
import 'editor_settings_sheet.dart';

/// SCR-EDITOR-001 — the real coloring engine. Brush (Locked/Unlocked),
/// Fill, Erase, Undo/Redo, per-lesson in-memory progress isolation (PASS
/// 2/2.1), Zoom/Pan, Eyedropper and Playful HSV picker (PASS 3), and
/// Save/Done + Expanded/Focus mode + MRU color history (PASS 3.1).
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.lessonId});

  final String lessonId;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final EditorController _controller = EditorController(lessonId: widget.lessonId);
  final GlobalKey _repaintBoundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller.sampleColorAt = _captureColorAt;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _exitEditor() {
    _controller.commitOnExit();
    Navigator.of(context).pop();
  }

  /// PASS 3.1 §4 — commits in-memory progress now (without leaving the
  /// Editor) and visually acknowledges it. No Completion behavior.
  void _handleSave() {
    _controller.saveNow();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Progress saved'), duration: Duration(seconds: 1), behavior: SnackBarBehavior.floating),
      );
  }

  /// PASS 4.5 — reads the FINAL rendered/composited artboard around
  /// [localPosition] — captures the same RepaintBoundary the Editor itself
  /// displays (white canvas + Fill/Brush/Erase chronology + line art, at
  /// the current Zoom/Pan transform), exactly what the user sees, never a
  /// separate source-only or paint-only layer.
  ///
  /// Returns a small CROP centered on the sample point (not the whole
  /// boundary) — this is both the loupe's direct magnified-rendering
  /// source (§3/§4) and, via one cheap readback of that tiny image, the
  /// live sampled color (§5). Cropping BEFORE the CPU/GPU readback keeps
  /// every live-drag tick cheap regardless of how large the workspace is
  /// (§13) — this never does a full-boundary pixel readback, let alone a
  /// PNG export.
  Future<EyedropperCapture?> _captureColorAt(Offset localPosition) async {
    final renderObject = _repaintBoundaryKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) return null;
    final displaySize = renderObject.size;
    if (displaySize.width == 0 || displaySize.height == 0) return null;

    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final fullImage = await renderObject.toImage(pixelRatio: pixelRatio);

    const cropLogical = kLoupeDiameter / kLoupeMagnification;
    final cropSize = (cropLogical * pixelRatio).ceil().clamp(1, fullImage.width);
    final cropSizeDouble = cropSize.toDouble();
    final imageCenter = localPosition * pixelRatio;
    final maxLeft = math.max(0.0, fullImage.width - cropSizeDouble);
    final maxTop = math.max(0.0, fullImage.height - cropSizeDouble);
    final srcLeft = (imageCenter.dx - cropSizeDouble / 2).clamp(0.0, maxLeft);
    final srcTop = (imageCenter.dy - cropSizeDouble / 2).clamp(0.0, maxTop);
    final srcRect = Rect.fromLTWH(srcLeft, srcTop, cropSizeDouble, cropSizeDouble);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(fullImage, srcRect, Rect.fromLTWH(0, 0, cropSize.toDouble(), cropSize.toDouble()), Paint());
    final picture = recorder.endRecording();
    final cropImage = await picture.toImage(cropSize, cropSize);
    picture.dispose();
    fullImage.dispose();

    final byteData = await cropImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      cropImage.dispose();
      return null;
    }
    final bytes = byteData.buffer.asUint8List();
    final centerIndex = ((cropSize ~/ 2) * cropSize + (cropSize ~/ 2)) * 4;
    final color = Color.fromARGB(bytes[centerIndex + 3], bytes[centerIndex], bytes[centerIndex + 1], bytes[centerIndex + 2]);

    return (image: cropImage, color: color);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) _controller.commitOnExit();
      },
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final lesson = _controller.lesson;
          final expanded = _controller.expandedMode;
          return Scaffold(
            backgroundColor: const Color(0xFFF1F1F1),
            // PASS 3.2 §2: no lesson-name title — the top toolbar is
            // actions-only. Omitting `title` entirely (rather than passing
            // an empty widget) means AppBar never reserves blank title
            // space, so leading/actions lay out naturally without a gap.
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              foregroundColor: const Color(0xFF151515),
              leading: BackButton(onPressed: _exitEditor),
              actions: [
                IconButton(
                  onPressed: _controller.canUndo ? _controller.undo : null,
                  icon: const Icon(Icons.undo),
                ),
                IconButton(
                  onPressed: _controller.canRedo ? _controller.redo : null,
                  icon: const Icon(Icons.redo),
                ),
                _LockToggleButton(controller: _controller),
                IconButton(
                  key: const Key('editor-settings-open'),
                  onPressed: () => showEditorSettingsSheet(context),
                  icon: const Icon(Icons.settings_outlined),
                ),
                const SizedBox(width: 4),
                _SaveDoneButton(onSave: _handleSave),
                const SizedBox(width: 8),
              ],
            ),
            body: lesson == null
                ? const Center(child: Text('This lesson could not be found.'))
                : SafeArea(
                    child: Column(
                      children: [
                        Expanded(
                          child: Stack(
                            children: [
                              // PASS 4.4 §7: the artboard now fills this ENTIRE
                              // area (minus a thin fixed margin) — this whole
                              // grey rectangle is the Pan/Zoom viewport, not a
                              // small square sized to the artwork's aspect
                              // ratio. The 800x800 sheet starts centered inside
                              // it (via EditorController.ensureViewportInitialized)
                              // but is free to roam the full rectangle from there.
                              Positioned.fill(
                                child: Padding(
                                  padding: EdgeInsets.all(expanded ? 12 : 24),
                                  child: _Artboard(controller: _controller, repaintBoundaryKey: _repaintBoundaryKey),
                                ),
                              ),
                              if (!expanded)
                                Positioned(
                                  right: 8,
                                  top: 0,
                                  bottom: 0,
                                  // PASS 3.2 §4: pushed further down again
                                  // (0.55 -> 0.78, normal mode only — see the
                                  // `!expanded` guard above) so it visually
                                  // ends near the palette instead of floating
                                  // at artwork mid-height. Still a responsive
                                  // fractional alignment within the SAME
                                  // full-height Positioned box, not a fixed
                                  // pixel offset, so it can never overlap the
                                  // separate bottom-controls container below.
                                  child: Align(
                                    alignment: const Alignment(0, 0.78),
                                    child: _ToolRail(controller: _controller),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        expanded ? _ExpandedBottomBar(controller: _controller) : _BottomControls(controller: _controller),
                      ],
                    ),
                  ),
          );
        },
      ),
    );
  }
}

class _Artboard extends StatelessWidget {
  const _Artboard({required this.controller, required this.repaintBoundaryKey});

  final EditorController controller;
  final GlobalKey repaintBoundaryKey;

  @override
  Widget build(BuildContext context) {
    // PASS 4.4 §1/§4/§7: this whole rectangle (NOT a square sized to the
    // artwork) is the Pan/Zoom viewport — "the initial centered artwork
    // rectangle must NOT be the clipping viewport." There is no white/
    // framed Container here anymore: the white 800x800 sheet, its own drop
    // shadow, the user paint, and the line art are ALL drawn by
    // EditorPainter as one composited ArtworkSurface, inside the one
    // transform applied there — never a separate widget-level layer. The
    // Scaffold's light grey shows through everywhere the transformed sheet
    // doesn't currently cover.
    if (!controller.artworkReady) {
      return const Center(child: CircularProgressIndicator());
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final displaySize = constraints.biggest;
        controller.ensureViewportInitialized(displaySize);
        return Stack(
          fit: StackFit.expand,
          children: [
            Listener(
              key: const Key('artboard-gesture-area'),
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) => controller.handlePointerDown(event.pointer, event.localPosition, displaySize),
              onPointerMove: (event) => controller.handlePointerMove(event.pointer, event.localPosition, displaySize),
              onPointerUp: (event) => controller.handlePointerUp(event.pointer),
              onPointerCancel: (event) => controller.handlePointerCancel(event.pointer),
              // KeyedSubtree keeps the ValueKey test contract
              // ('artboard-repaint-boundary') intact while ALSO giving
              // production code a GlobalKey handle (below) straight onto
              // the same RenderRepaintBoundary, for the Eyedropper's pixel
              // capture.
              child: KeyedSubtree(
                key: const Key('artboard-repaint-boundary'),
                child: RepaintBoundary(
                  key: repaintBoundaryKey,
                  child: CustomPaint(
                    size: displaySize,
                    painter: EditorPainter(controller),
                  ),
                ),
              ),
            ),
            if (controller.activeTool == EditorTool.eyedropper &&
                controller.eyedropperSourceImage != null &&
                controller.eyedropperPreviewLocalPosition != null)
              _EyedropperLoupe(
                position: controller.eyedropperPreviewLocalPosition!,
                image: controller.eyedropperSourceImage!,
                color: controller.eyedropperPreviewColor,
                workspaceSize: displaySize,
              ),
          ],
        );
      },
    );
  }
}

/// PASS 4.5 — the live magnifying loupe: a floating circular preview of the
/// ACTUAL rendered artwork around the sample point (never a solid color
/// swatch alone), positioned above the finger by default so the fingertip
/// never covers it, flipping below when there isn't room above (§2).
/// Purely visual — IgnorePointer so it never steals the drag.
class _EyedropperLoupe extends StatelessWidget {
  const _EyedropperLoupe({
    required this.position,
    required this.image,
    required this.color,
    required this.workspaceSize,
  });

  final Offset position;
  final ui.Image image;
  final Color? color;
  final Size workspaceSize;

  static const double _fingerClearance = 20;

  @override
  Widget build(BuildContext context) {
    final aboveTop = position.dy - _fingerClearance - kLoupeDiameter;
    final placeAbove = aboveTop >= 0;
    final top = placeAbove ? aboveTop : position.dy + _fingerClearance;
    final maxLeft = math.max(0.0, workspaceSize.width - kLoupeDiameter);
    final maxTop = math.max(0.0, workspaceSize.height - kLoupeDiameter);
    final left = (position.dx - kLoupeDiameter / 2).clamp(0.0, maxLeft);

    // Positioned must be the direct child of the surrounding Stack -- wrap
    // the CONTENT in IgnorePointer instead of wrapping Positioned itself,
    // or Stack's ParentDataWidget mechanism can't apply StackParentData to
    // the (differently-typed) RenderObject IgnorePointer introduces.
    return Positioned(
      left: left,
      top: top.clamp(0.0, maxTop),
      child: IgnorePointer(
        child: Container(
          key: const Key('eyedropper-loupe'),
          width: kLoupeDiameter,
          height: kLoupeDiameter,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Color(0x40000000), blurRadius: 10, offset: Offset(0, 3))],
          ),
          child: CustomPaint(painter: _LoupePainter(image: image, sampleColor: color)),
        ),
      ),
    );
  }
}

/// Draws [image] (already a small crop centered on the sample point — see
/// EditorScreen._captureColorAt) scaled up to fill the loupe circle, plus a
/// border ring reflecting the sampled color (§6) and a small center
/// crosshair marking the exact sample pixel.
class _LoupePainter extends CustomPainter {
  _LoupePainter({required this.image, required this.sampleColor});

  final ui.Image image;
  final Color? sampleColor;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final center = Offset(radius, radius);

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();

    canvas.drawCircle(
      center,
      radius - 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = sampleColor ?? const Color(0xFFBDBDBD),
    );
    canvas.drawCircle(
      center,
      radius - 0.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white,
    );

    // Center crosshair marking the exact sample pixel -- a small white disc
    // with a dark outline stays visible against any content color.
    canvas.drawCircle(center, 4, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFF333333),
    );
  }

  @override
  bool shouldRepaint(covariant _LoupePainter oldDelegate) {
    return oldDelegate.image != image || oldDelegate.sampleColor != sampleColor;
  }
}

class _ToolRail extends StatelessWidget {
  const _ToolRail({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 18)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToolButton(
            key: const Key('tool-brush'),
            icon: Icons.brush,
            label: 'Brush',
            selected: controller.activeTool == EditorTool.brush,
            onTap: () => controller.selectTool(EditorTool.brush),
          ),
          _ToolButton(
            key: const Key('tool-fill'),
            icon: Icons.format_color_fill,
            label: 'Fill',
            selected: controller.activeTool == EditorTool.fill,
            onTap: () => controller.selectTool(EditorTool.fill),
          ),
          _ToolButton(
            key: const Key('tool-erase'),
            icon: Icons.auto_fix_normal,
            label: 'Erase',
            selected: controller.activeTool == EditorTool.erase,
            onTap: () => controller.selectTool(EditorTool.erase),
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({super.key, required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFEEE8FF) : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 56,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: selected ? const Color(0xFF7C4DFF) : const Color(0xFF5B5B5E)),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: selected ? const Color(0xFF7C4DFF) : const Color(0xFF5B5B5E),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LockToggleButton extends StatelessWidget {
  const _LockToggleButton({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('lock-toggle'),
      onPressed: controller.toggleLock,
      tooltip: controller.locked ? 'Locked (tap to unlock)' : 'Unlocked (tap to lock)',
      icon: Image.asset(
        controller.locked ? 'assets/icons/lock.png' : 'assets/icons/unlock.png',
        width: 20,
        height: 20,
      ),
    );
  }
}

/// PASS 3.1 §4 — the approved top-right primary control: prominent purple
/// circular check button (matches the locked prototype's done-circle).
/// Commits in-memory progress; explicitly does NOT open a Completion screen
/// (deferred to a later pass).
class _SaveDoneButton extends StatelessWidget {
  const _SaveDoneButton({required this.onSave});

  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('editor-save-done'),
      color: const Color(0xFF7C4DFF),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onSave,
        child: const Padding(
          padding: EdgeInsets.all(9),
          child: Icon(Icons.check, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _BottomControls extends StatelessWidget {
  const _BottomControls({required this.controller});

  final EditorController controller;

  void _openPlayfulPicker(BuildContext context) {
    showPlayfulColorPicker(
      context,
      initialColor: controller.activeColor,
      onSave: controller.commitCustomColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Slider(
            value: controller.brushSliderValue,
            min: 0,
            max: 100,
            activeColor: const Color(0xFF7C4DFF),
            onChanged: (value) => controller.setBrushSliderValue(value),
          ),
          // PASS 3.1 §7 — MRU color history (max 10) replaces the old fixed
          // preset row + separate custom slot entirely.
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: controller.colorHistory.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final color = controller.colorHistory[index];
                final selected = color.toARGB32() == controller.activeColor.toARGB32();
                return _PaletteSwatch(
                  keyValue: 'palette-color-${color.toARGB32().toRadixString(16)}',
                  color: color,
                  selected: selected,
                  onTap: () => controller.selectColor(color),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _QuickToolButton(
                    keyValue: 'tool-eyedropper',
                    icon: Icons.colorize,
                    label: 'Pick',
                    selected: controller.activeTool == EditorTool.eyedropper,
                    onTap: controller.activateEyedropper,
                  ),
                  const SizedBox(width: 14),
                  _QuickToolButton(
                    keyValue: 'tool-playful',
                    icon: Icons.auto_awesome,
                    label: 'Playful',
                    selected: false,
                    onTap: () => _openPlayfulPicker(context),
                  ),
                ],
              ),
              IconButton(
                key: const Key('maximize-button'),
                onPressed: controller.toggleExpandedMode,
                tooltip: 'Expand',
                icon: Image.asset('assets/icons/maximize.png', width: 22, height: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// PASS 3.1 §5 — Expanded/Focus mode's ONE bottom row: Active Tool + Active
/// Color on the left, Minimize on the right, all on the same centerY (a
/// single Row with default crossAxisAlignment.center already guarantees
/// this). Everything else (slider, palette, Pick, Playful, tool rail) is
/// hidden while expanded.
class _ExpandedBottomBar extends StatelessWidget {
  const _ExpandedBottomBar({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(
        children: [
          _ActiveToolPill(controller: controller),
          const SizedBox(width: 10),
          Container(
            key: const Key('expanded-active-color'),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: controller.activeColor,
              border: Border.all(color: const Color(0x1F000000), width: 1.5),
            ),
          ),
          const Spacer(),
          IconButton(
            key: const Key('minimize-button'),
            onPressed: controller.toggleExpandedMode,
            tooltip: 'Minimize',
            icon: Image.asset('assets/icons/minimize.png', width: 22, height: 22),
          ),
        ],
      ),
    );
  }
}

/// The only tool-switch surface available while Expanded — cycles
/// Brush -> Fill -> Erase -> Brush; the full rail is intentionally hidden.
class _ActiveToolPill extends StatelessWidget {
  const _ActiveToolPill({required this.controller});

  final EditorController controller;

  static const _icons = {
    EditorTool.brush: Icons.brush,
    EditorTool.fill: Icons.format_color_fill,
    EditorTool.erase: Icons.auto_fix_normal,
  };
  static const _labels = {
    EditorTool.brush: 'Brush',
    EditorTool.fill: 'Fill',
    EditorTool.erase: 'Erase',
  };

  @override
  Widget build(BuildContext context) {
    // Eyedropper isn't reachable while Expanded (Pick is hidden); fall back
    // to Brush's glyph defensively if it were somehow still active.
    final tool = _icons.containsKey(controller.activeTool) ? controller.activeTool : EditorTool.brush;
    return Material(
      key: const Key('expanded-active-tool'),
      color: const Color(0xFFEEE8FF),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: controller.cycleTool,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_icons[tool], size: 18, color: const Color(0xFF7C4DFF)),
              const SizedBox(width: 6),
              Text(_labels[tool]!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF7C4DFF))),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaletteSwatch extends StatelessWidget {
  const _PaletteSwatch({required this.keyValue, required this.color, required this.selected, required this.onTap});

  final String keyValue;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // White needs a visible neutral border even when unselected, or it
    // disappears against the white bottom-controls background (§19).
    final needsNeutralBorder = color.toARGB32() == const Color(0xFFF4F4F4).toARGB32() || color.toARGB32() == 0xFFFFFFFF;
    return GestureDetector(
      key: Key(keyValue),
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: selected
                ? const Color(0xFF7C4DFF)
                : (needsNeutralBorder ? const Color(0x29000000) : const Color(0x14000000)),
            width: selected ? 3 : 1,
          ),
        ),
      ),
    );
  }
}

class _QuickToolButton extends StatelessWidget {
  const _QuickToolButton({
    required this.keyValue,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String keyValue;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: Key(keyValue),
      color: selected ? const Color(0xFFEEE8FF) : const Color(0xFFF5F5F6),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: selected ? const Color(0xFF7C4DFF) : const Color(0xFF5B5B5E)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? const Color(0xFF7C4DFF) : const Color(0xFF5B5B5E),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
