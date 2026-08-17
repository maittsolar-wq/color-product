// Basic smoke test: the app boots, loads real lesson content, and shows
// the Home screen with bottom navigation — replaces the stock counter demo
// test now that the counter demo itself has been replaced.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:color_pop/main.dart';

/// PASS 4: AppBootstrap now also awaits ProgressRepository.init(), which
/// calls path_provider to find the app's documents directory and then does
/// real dart:io file I/O. This points path_provider at a throwaway temp
/// directory instead — the standard pattern for testing path_provider-
/// dependent code. Separately, real (non-Timer) async work like file I/O
/// never completes inside `testWidgets`' FakeAsync pump zone -- only inside
/// `tester.runAsync` -- so plain `pumpAndSettle()` alone hangs; see the
/// drain loop below.
class _FakePathProviderPlatform extends PathProviderPlatform with MockPlatformInterfaceMixin {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    final dir = await Directory.systemTemp.createTemp('color_pop_test_docs_');
    return dir.path;
  }
}

void main() {
  setUpAll(() {
    PathProviderPlatform.instance = _FakePathProviderPlatform();
  });

  testWidgets('App boots and shows Home with bottom navigation', (WidgetTester tester) async {
    // PASS 3.2: Home's category rows grew taller (larger thumbnails), which
    // pushed the "Nature" section below the default (much shorter) test
    // surface. Use a realistic phone-sized viewport instead of shrinking
    // the assertions.
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ColorPopApp());

    // Initial frame: bootstrap loading indicator.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Let both the asset load (rootBundle.loadString) and the real file I/O
    // (ProgressRepository.init(), path_provider) complete. Interleaving
    // real delays with tester.pump() inside runAsync lets both kinds of
    // async work — channel-based and real dart:io — resolve together.
    await tester.runAsync(() async {
      for (var i = 0; i < 30; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();

    expect(find.text('Manga'), findsOneWidget);
    expect(find.text('Animal'), findsOneWidget);
    expect(find.text('Nature'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
