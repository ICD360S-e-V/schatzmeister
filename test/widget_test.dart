// Basic Flutter widget test for ICD360S Schatzmeister App

import 'package:flutter_test/flutter_test.dart';
import 'package:icd360sev_schatzmeister/main.dart';

void main() {
  testWidgets('App loads login screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SchatzmeisterApp());

    // Verify login screen is displayed
    expect(find.text('ICD360S e.V'), findsOneWidget);
    expect(find.text('Schatzmeister Portal'), findsOneWidget);
    expect(find.text('Anmelden'), findsOneWidget);
  });
}
