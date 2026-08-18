import 'dart:math';

import 'package:flutter/material.dart';

/// SCR-ENTRY-001 — Splash. Shown by AppBootstrap while the real content
/// load (lessons + progress) is in flight, plus a short minimum-display
/// guard so fast devices don't just flash it. Purely decorative/branding —
/// no navigation, no bottom nav, no back gesture (it sits below AppShell
/// in the widget tree, not pushed as a route).
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF7FF),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Soft pastel watercolor wash — layered translucent blobs rather
          // than a real image asset (none exists in assets/).
          const _WatercolorBackground(),
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 4),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF7C4DFF), Color(0xFFE879C7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: const Text(
                    'Color Pop',
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Create  •  Relax  •  Inspire',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8A7FA3),
                    letterSpacing: 0.4,
                  ),
                ),
                const Spacer(flex: 5),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 64),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: const LinearProgressIndicator(
                      minHeight: 4,
                      backgroundColor: Color(0xFFF0ECFF),
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7C4DFF)),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WatercolorBackground extends StatelessWidget {
  const _WatercolorBackground();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Positioned(
              top: -70,
              left: -60,
              child: _blob(220, const Color(0xFFF0C6E8)),
            ),
            Positioned(
              top: 40,
              right: -80,
              child: _blob(260, const Color(0xFFD9C6F5)),
            ),
            Positioned(
              bottom: -90,
              left: -40,
              child: _blob(240, const Color(0xFFC9D6F7)),
            ),
            Positioned(
              bottom: 60,
              right: -50,
              child: _blob(180, const Color(0xFFF3D3E7)),
            ),
            ..._sparklePositions(constraints.maxWidth, constraints.maxHeight),
          ],
        );
      },
    );
  }

  Widget _blob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.55), color.withValues(alpha: 0.0)],
        ),
      ),
    );
  }

  static List<Widget> _sparklePositions(double width, double height) {
    final rand = Random(7);
    return List.generate(9, (i) {
      final top = rand.nextDouble() * 0.85 * height;
      final left = rand.nextDouble() * width;
      final size = 10.0 + rand.nextDouble() * 12;
      return Positioned(
        top: top,
        left: left,
        child: Icon(
          i.isEven ? Icons.auto_awesome : Icons.star_rounded,
          size: size,
          color: const Color(0xFF7C4DFF).withValues(alpha: 0.18 + rand.nextDouble() * 0.14),
        ),
      );
    });
  }
}
