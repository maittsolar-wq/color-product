// Basic smoke test: the app boots, loads real lesson content, and shows
// the Home screen with bottom navigation — replaces the stock counter demo
// test now that the counter demo itself has been replaced.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:color_pop/main.dart';

void main() {
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

    // Let the asset load (rootBundle.loadString) complete.
    await tester.pumpAndSettle();

    expect(find.text('Manga'), findsOneWidget);
    expect(find.text('Animal'), findsOneWidget);
    expect(find.text('Nature'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
