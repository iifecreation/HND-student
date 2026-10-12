// Defines application navigation routes and route generation.

import 'package:flutter/material.dart';
import '../ui/screens/about_screen.dart';
import '../ui/screens/diagnosis_screen.dart';
import '../ui/screens/history_screen.dart';
import '../ui/screens/home_screen.dart';
import '../ui/screens/kb_screen.dart';
import '../ui/screens/settings_screen.dart';

/// Central route names and routing table for PrinterDoc.
class AppRoutes {
  static const String home = '/';
  static const String diagnosis = '/diagnosis';
  static const String kb = '/kb';
  static const String history = '/history';
  static const String settings = '/settings';
  static const String about = '/about';

  static Map<String, WidgetBuilder> get routes => {
        home: (_) => const HomeScreen(),
        diagnosis: (_) => const DiagnosisScreen(),
        kb: (_) => const KbScreen(),
        history: (_) => const HistoryScreen(),
        settings: (_) => const SettingsScreen(),
        about: (_) => const AboutScreen(),
      };
}
