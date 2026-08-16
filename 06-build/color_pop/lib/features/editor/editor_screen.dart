import 'package:flutter/material.dart';

import 'artwork_coordinates.dart';
import 'editor_controller.dart';
import 'editor_painter.dart';

/// SCR-EDITOR-001 — PASS 2: the real coloring engine foundation. Receives
/// lessonId, resolves the real LessonModel + 800x800 artwork, and provides
/// Brush (Locked/Unlocked), Fill, Erase, Undo/Redo, and per-lesson
/// in-memory progress isolation. Eyedropper, the HSV Playful picker, zoom/
/// pan, dynamic thumbnails, and persistence are explicitly deferred.
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.lessonId});

  final String lessonId;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final EditorController _controller = EditorController(lessonId: widget.lessonId);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _exitEditor() {
    _controller.commitOnExit();
    Navigator.of(context).pop();
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
          return Scaffold(
            backgroundColor: const Color(0xFFF1F1F1),
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              foregroundColor: const Color(0xFF151515),
              leading: BackButton(onPressed: _exitEditor),
              title: Text(
                lesson?.title ?? 'Lesson not found',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
              ),
              centerTitle: true,
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
                const SizedBox(width: 4),
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
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: _Artboard(controller: _controller),
                                ),
                              ),
                              Positioned(
                                right: 8,
                                top: 0,
                                bottom: 0,
                                child: Center(child: _ToolRail(controller: _controller)),
                              ),
                            ],
                          ),
                        ),
                        _BottomControls(controller: _controller),
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
  const _Artboard({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, 8))],
        ),
        clipBehavior: Clip.antiAlias,
        child: !controller.artworkReady
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  final displaySize = constraints.biggest;
                  return Listener(
                    key: const Key('artboard-gesture-area'),
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (event) {
                      controller.onPointerDown(artworkPointFromLocal(event.localPosition, displaySize));
                    },
                    onPointerMove: (event) {
                      controller.onPointerMove(artworkPointFromLocal(event.localPosition, displaySize));
                    },
                    onPointerUp: (_) => controller.onPointerUp(),
                    onPointerCancel: (_) => controller.onPointerCancel(),
                    child: RepaintBoundary(
                      key: const Key('artboard-repaint-boundary'),
                      child: CustomPaint(
                        size: displaySize,
                        painter: EditorPainter(controller),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
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

class _BottomControls extends StatelessWidget {
  const _BottomControls({required this.controller});

  final EditorController controller;

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
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: kEditorPresetColors.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final color = kEditorPresetColors[index];
                final selected = color.toARGB32() == controller.activeColor.toARGB32();
                return GestureDetector(
                  key: Key('palette-color-${color.toARGB32().toRadixString(16)}'),
                  onTap: () => controller.selectColor(color),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      border: Border.all(
                        color: selected ? const Color(0xFF7C4DFF) : const Color(0x14000000),
                        width: selected ? 3 : 1,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
