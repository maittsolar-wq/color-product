import 'package:flutter/material.dart';

/// SCR-SETTINGS-001 (PASS 6) — the APP-level Settings screen, reached only
/// via Profile's Settings icon (REQ-PROFILE-006). Deliberately a SEPARATE
/// screen/concept from the existing Editor Settings bottom sheet
/// (editor_settings_sheet.dart) — never merged, never removed.
///
/// Content matches the locked prototype's concrete SCR-SETTINGS-001
/// (index.html) exactly: General (Sounds toggle, Language, How to Color),
/// Support (Contact Us, Rate Us), Legal (Terms of Service, Privacy
/// Policy), and a version footer — see REQ-SET-001..004. No Premium/
/// Restore-Purchase row here: the prototype's concrete Settings screen
/// doesn't have one, and REQ-SET-005 only requires it once monetization is
/// enabled (explicitly out of scope this pass) — Restore Purchase lives on
/// the Paywall screen instead, matching the prototype.
///
/// Rows with no real destination yet (Language/How to Color/Contact Us/
/// Rate Us/Terms/Privacy) render correctly and respond to a tap, but never
/// pretend to succeed — a neutral "coming soon" message, not a fake page.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // PASS 6 §5 — deliberately local/ephemeral (resets each time Settings is
  // opened), not persisted anywhere. This is a distinct app-level toggle
  // from EditorSettings.soundEnabled and must stay that way; wiring real
  // cross-session app-sound persistence is future-pass work.
  bool _soundsEnabled = true;

  void _showComingSoon(String label) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('$label is coming soon.'), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF151515),
        centerTitle: true,
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        leading: BackButton(key: const Key('settings-back'), onPressed: () => Navigator.of(context).pop()),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _SectionLabel('General'),
            _SettingsGroup(
              children: [
                _ToggleRow(
                  keyValue: 'settings-sound-toggle',
                  icon: Icons.volume_up_outlined,
                  label: 'Sounds',
                  value: _soundsEnabled,
                  onChanged: (value) => setState(() => _soundsEnabled = value),
                ),
                _ChevronRow(
                  keyValue: 'settings-row-language',
                  icon: Icons.language,
                  label: 'Language',
                  onTap: () => _showComingSoon('Language'),
                ),
                _ChevronRow(
                  keyValue: 'settings-row-how-to-color',
                  icon: Icons.help_outline,
                  label: 'How to Color',
                  onTap: () => _showComingSoon('How to Color'),
                ),
              ],
            ),
            _SectionLabel('Support'),
            _SettingsGroup(
              children: [
                _ChevronRow(
                  keyValue: 'settings-row-contact-us',
                  icon: Icons.mail_outline,
                  label: 'Contact Us',
                  onTap: () => _showComingSoon('Contact Us'),
                ),
                _ChevronRow(
                  keyValue: 'settings-row-rate-us',
                  icon: Icons.star_border,
                  label: 'Rate Us',
                  onTap: () => _showComingSoon('Rate Us'),
                ),
              ],
            ),
            _SectionLabel('Legal'),
            _SettingsGroup(
              children: [
                _ChevronRow(
                  keyValue: 'settings-row-terms',
                  icon: Icons.description_outlined,
                  label: 'Terms of Service',
                  onTap: () => _showComingSoon('Terms of Service'),
                ),
                _ChevronRow(
                  keyValue: 'settings-row-privacy',
                  icon: Icons.shield_outlined,
                  label: 'Privacy Policy',
                  onTap: () => _showComingSoon('Privacy Policy'),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Version 1.0.0',
                key: Key('settings-version'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Color(0xFFAAAAAA)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF57565B))),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF8F8F9), borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.keyValue,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String keyValue;
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 19, color: const Color(0xFF4A4A4E)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF1C1C1E)))),
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
  const _ChevronRow({required this.keyValue, required this.icon, required this.label, required this.onTap});

  final String keyValue;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key(keyValue),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Icon(icon, size: 19, color: const Color(0xFF4A4A4E)),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF1C1C1E)))),
            const Icon(Icons.chevron_right, size: 20, color: Color(0xFFBEBCB8)),
          ],
        ),
      ),
    );
  }
}
