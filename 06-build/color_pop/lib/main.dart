import 'package:flutter/material.dart';

import 'app/app_bootstrap.dart';

void main() {
  runApp(const ColorPopApp());
}

class ColorPopApp extends StatelessWidget {
  const ColorPopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Color Pop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7C4DFF)),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const AppBootstrap(),
    );
  }
}
