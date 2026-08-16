import 'package:flutter/material.dart';

/// SCR-SETTINGS-001 — placeholder routing only for Pass 1. Real
/// Settings logic (sound/haptic/privacy/terms/rate/version/restore
/// purchase) is explicitly deferred to a later pass.
class SettingsPlaceholderScreen extends StatelessWidget {
  const SettingsPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Settings will be implemented in a later pass.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ),
    );
  }
}
