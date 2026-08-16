import 'package:flutter/material.dart';

import '../core/app_data.dart';
import 'app_shell.dart';

/// Loads categories/lessons once before the real app shell renders, so no
/// screen ever has to handle "repository not loaded yet" as a special case.
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late final Future<void> _loadFuture = AppData.lessonRepository.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load lesson content.\n${snapshot.error}', textAlign: TextAlign.center),
              ),
            ),
          );
        }
        return const AppShell();
      },
    );
  }
}
