import 'dart:math' as math;

import 'package:flutter/material.dart';

/// PASS 3 — Playful HSV Color Picker (§13-20). A draft-until-Save bottom
/// sheet: Back discards, Save commits through EditorController's ONE color
/// commit path (`commitCustomColor`) so this can never create a second,
/// unsynchronized color state.
///
/// Uses Flutter's own HSVColor for HSV<->Color conversion (§16) rather than
/// hand-rolled math — it already covers exact white/black/gray/pastel/
/// saturated/dark cases correctly.
Future<void> showPlayfulColorPicker(
  BuildContext context, {
  required Color initialColor,
  required ValueChanged<Color> onSave,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x66101014), // dims the Editor behind (§13)
    builder: (context) => _ColorPickerSheet(initialColor: initialColor, onSave: onSave),
  );
}

class _ColorPickerSheet extends StatefulWidget {
  const _ColorPickerSheet({required this.initialColor, required this.onSave});

  final Color initialColor;
  final ValueChanged<Color> onSave;

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  late HSVColor _draft = HSVColor.fromColor(widget.initialColor);

  @override
  Widget build(BuildContext context) {
    final draftColor = _draft.toColor();
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(14),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  key: const Key('playful-back'),
                  onPressed: () => Navigator.of(context).pop(), // discard draft (§18)
                  icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                  style: IconButton.styleFrom(backgroundColor: const Color(0xFFF5F5F6), shape: const CircleBorder()),
                ),
                const Text('Playful Color', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                IconButton(
                  key: const Key('playful-save'),
                  onPressed: () {
                    widget.onSave(draftColor); // commitCustomColor — the ONE color state source (§20)
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.check_circle, color: Color(0xFF7C4DFF), size: 26),
                ),
              ],
            ),
            const SizedBox(height: 18),
            AspectRatio(
              aspectRatio: 1,
              child: _HueSatValuePicker(
                hsv: _draft,
                onHueChanged: (hue) => setState(() => _draft = _draft.withHue(hue)),
                onSatValChanged: (s, v) => setState(() => _draft = _draft.withSaturation(s).withValue(v)),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: draftColor,
                border: Border.all(color: const Color(0x14000000), width: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Outer Hue ring (0..360°, continuous spectrum) + inner Saturation/Value
/// square (§14-15). The square sits entirely inside the ring's inner
/// radius, so a Stack with the square on top naturally routes ring-band
/// touches to the ring and square touches to the square — no manual
/// hit-region math needed.
class _HueSatValuePicker extends StatelessWidget {
  const _HueSatValuePicker({required this.hsv, required this.onHueChanged, required this.onSatValChanged});

  final HSVColor hsv;
  final ValueChanged<double> onHueChanged;
  final void Function(double saturation, double value) onSatValChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest.shortestSide;
        // PASS 3.1 §2 fix: the square's CORNERS (its diagonal, not just its
        // side) must stay inside the ring's inner edge or they visually
        // overlap the ring — the previous 0.62 side at a 0.12 ring width put
        // the corners well past the ring's inner radius. At 0.55 (the low
        // end of the requested 55-62% range) with a 0.085 ring width, the
        // corner-to-inner-edge gap is a clearly visible ~2.6% of the picker
        // diameter on every side.
        final ringWidth = size * 0.085;
        final innerSize = size * 0.55;
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              GestureDetector(
                key: const Key('hue-ring'),
                behavior: HitTestBehavior.opaque,
                // Both a stationary tap AND a drag must work: PanGestureRecognizer
                // alone never fires for a tap that doesn't clear the touch-slop
                // threshold, so a plain tap on the ring would silently do nothing
                // without this.
                onTapDown: (d) => _handleRingTouch(d.localPosition, size),
                onPanStart: (d) => _handleRingTouch(d.localPosition, size),
                onPanUpdate: (d) => _handleRingTouch(d.localPosition, size),
                child: CustomPaint(
                  size: Size(size, size),
                  painter: _HueRingPainter(hue: hsv.hue, ringWidth: ringWidth),
                ),
              ),
              GestureDetector(
                key: const Key('sat-value-square'),
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _handleSquareTouch(d.localPosition, innerSize),
                onPanStart: (d) => _handleSquareTouch(d.localPosition, innerSize),
                onPanUpdate: (d) => _handleSquareTouch(d.localPosition, innerSize),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: innerSize,
                    height: innerSize,
                    child: _SatValueSquare(hsv: hsv, size: innerSize),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleRingTouch(Offset local, double size) {
    final center = Offset(size / 2, size / 2);
    final angleRad = math.atan2(local.dy - center.dy, local.dx - center.dx);
    final degrees = angleRad * 180 / math.pi;
    onHueChanged((degrees + 360) % 360);
  }

  void _handleSquareTouch(Offset local, double innerSize) {
    final s = (local.dx / innerSize).clamp(0.0, 1.0);
    final v = 1 - (local.dy / innerSize).clamp(0.0, 1.0);
    onSatValChanged(s, v);
  }
}

class _HueRingPainter extends CustomPainter {
  _HueRingPainter({required this.hue, required this.ringWidth});

  final double hue;
  final double ringWidth;

  static final List<Color> _hueStops = [
    for (final h in [0, 60, 120, 180, 240, 300, 360]) HSVColor.fromAHSV(1, h.toDouble() % 360, 1, 1).toColor(),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - ringWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth
      ..shader = SweepGradient(colors: _hueStops).createShader(rect);
    canvas.drawCircle(center, radius, ringPaint);

    final handleAngle = hue * math.pi / 180;
    final handleCenter = center + Offset(math.cos(handleAngle), math.sin(handleAngle)) * radius;
    final handleColor = HSVColor.fromAHSV(1, hue, 1, 1).toColor();
    canvas.drawCircle(handleCenter, ringWidth / 2 + 3, Paint()..color = Colors.white);
    canvas.drawCircle(handleCenter, ringWidth / 2 - 1, Paint()..color = handleColor);
    canvas.drawCircle(
      handleCenter,
      ringWidth / 2 + 3,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0x33000000),
    );
  }

  @override
  bool shouldRepaint(covariant _HueRingPainter oldDelegate) => oldDelegate.hue != hue || oldDelegate.ringWidth != ringWidth;
}

/// top-left = white, top-right = pure hue, bottom = black — required
/// visual behaviour (§15), achieved with two stacked linear gradients: a
/// horizontal white->hue base, and a vertical transparent->black overlay.
class _SatValueSquare extends StatelessWidget {
  const _SatValueSquare({required this.hsv, required this.size});

  final HSVColor hsv;
  final double size;

  @override
  Widget build(BuildContext context) {
    final pureHue = HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor();
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [Colors.white, pureHue]),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black]),
            ),
          ),
        ),
        Positioned(
          left: hsv.saturation * size - 10,
          top: (1 - hsv.value) * size - 10,
          child: IgnorePointer(
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hsv.toColor(),
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 3)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
