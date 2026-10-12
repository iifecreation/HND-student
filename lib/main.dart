// Entry point for the PrinterDoc voice-controlled offline expert system application.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app/routes.dart';
import 'app/theme.dart';
import 'ui/viewmodels/diagnosis_viewmodel.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PrinterDocApp());
}

/// Root application widget configuring providers, themes, and navigation routes.
class PrinterDocApp extends StatelessWidget {
  const PrinterDocApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DiagnosisViewModel(),
      child: MaterialApp(
        title: 'PrinterDoc',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        initialRoute: AppRoutes.home,
        routes: AppRoutes.routes,
      ),
    );
  }
}
