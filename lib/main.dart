// Entry point for the PrinterDoc voice-controlled offline expert system application.

import 'package:flutter/material.dart';

void main() {
  runApp(const PrinterDocApp());
}

/// Root application widget configuring themes and initial routes.
class PrinterDocApp extends StatelessWidget {
  const PrinterDocApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PrinterDoc',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const Scaffold(
        body: Center(
          child: Text('PrinterDoc Expert System'),
        ),
      ),
    );
  }
}
