import 'package:flutter/material.dart';

import 'editor_settings.dart';

/// PASS 3.2 §3 — Editor Settings bottom sheet. Opens ON TOP of SCR-EDITOR-001
/// (never navigates to Profile Settings); the Editor stays mounted and
/// dimmed behind it via the modal barrier, so closing returns to exactly
/// the same Coloring state — nothing in the Editor itself is touched by
/// opening/closing this sheet.
Future<void> showEditorSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x66101014), // dims the Editor behind
    builder: (context) => const _EditorSettingsSheet(),
  );
}

class _EditorSettingsSheet extends StatelessWidget {
  const _EditorSettingsSheet();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: EditorSettings.instance,
      builder: (context, _) {
        final settings = EditorSettings.instance;
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 12, 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Settings', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                      IconButton(
                        key: const Key('editor-settings-close'),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, size: 20),
                        style: IconButton.styleFrom(backgroundColor: const Color(0xFFF5F5F6), shape: const CircleBorder()),
                      ),
                    ],
                  ),
                ),
                _ToggleRow(
                  keyValue: 'editor-settings-sound',
                  label: 'Sounds',
                  value: settings.soundEnabled,
                  onChanged: (_) => settings.toggleSound(),
                ),
                _ToggleRow(
                  keyValue: 'editor-settings-color-history',
                  label: 'Color History',
                  value: settings.colorHistoryEnabled,
                  onChanged: (_) => settings.toggleColorHistory(),
                ),
                _ToggleRow(
                  keyValue: 'editor-settings-mirror-mode',
                  label: 'Mirror Mode',
                  value: settings.mirrorModeEnabled,
                  onChanged: (_) => settings.toggleMirrorMode(),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(height: 18),
                ),
                _ChevronRow(
                  keyValue: 'editor-settings-how-to-color',
                  label: 'How to Color',
                  // Safe placeholder — no tutorial system is built in this
                  // pass (explicitly out of scope).
                  onTap: () {},
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.keyValue, required this.label, required this.value, required this.onChanged});

  final String keyValue;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          Switch(
            key: Key(keyValue),
            value: value,
            activeThumbColor: const Color(0xFF7C4DFF),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ChevronRow extends StatelessWidget {
  const _ChevronRow({required this.keyValue, required this.label, required this.onTap});

  final String keyValue;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key(keyValue),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const Icon(Icons.chevron_right, color: Color(0xFF9A9A9E)),
          ],
        ),
      ),
    );
  }
}
