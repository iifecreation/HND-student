// Basic smoke test verifying the PrinterDocApp root widget mounts properly.

import 'package:flutter_test/flutter_test.dart';
import 'package:printer_doc/main.dart';

void main() {
  testWidgets('PrinterDocApp builds smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PrinterDocApp());
    expect(find.text('PrinterDoc Edge Diagnostics'), findsOneWidget);
  });
}
