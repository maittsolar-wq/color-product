import 'package:flutter/material.dart';

import '../core/app_data.dart';
import '../features/splash/splash_screen.dart';
import 'app_shell.dart';

/// Loads categories/lessons AND persisted lesson progress (PASS 4) once
/// before the real app shell renders, so no screen ever has to handle
/// "repository not loaded yet" as a special case, and Home/Library/Search/
/// Profile reflect persisted state from their very first frame.
///
/// PASS 6.1 §1: shows the branded SplashScreen (not a bare spinner) while
/// this load is in flight, with a minimum display guard so fast devices
/// don't just flash it — real init can finish sooner without cutting the
/// Splash short.
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late final Future<void> _loadFuture = Future.wait([
    AppData.lessonRepository.load(),
    AppData.progressRepository.init(),
    Future.delayed(const Duration(seconds: 1)),
  ]);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SplashScreen();
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
