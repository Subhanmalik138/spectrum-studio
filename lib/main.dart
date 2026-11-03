import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const SpectrumStudioApp());
}

/// Spectrum Studio — a 3D music visualizer studio.
///
/// Workflow: pick a song -> add a background -> title/artist -> pick one of
/// six audio-reactive 3D templates -> preview -> export a real MP4.
/// Everything works offline after installation; projects are stored locally.
class SpectrumStudioApp extends StatelessWidget {
  const SpectrumStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spectrum Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0812),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFF7C4DFF),
          surface: Color(0xFF171222),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0B0812),
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
