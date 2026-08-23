// Basic Flutter widget test for ICD360S Schatzmeister App

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:icd360sev_schatzmeister/main.dart';
import 'package:icd360sev_schatzmeister/screens/login_with_code_screen.dart';

void main() {
  // Der Einstieg ist seit 2026-08-23 die Geräteaktivierung per Code, nicht
  // mehr der Passwort-Login. Der alte Test suchte nach „Anmelden" und schlug
  // schon vor dieser Umstellung fehl — die Texte stammten aus einer noch
  // älteren Fassung des Login-Bildschirms.
  setUp(() {
    // Ohne Mock wirft SharedPreferences im Test (kein Plattform-Kanal).
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App startet auf dem Aktivierungsbildschirm', (tester) async {
    await tester.pumpWidget(const SchatzmeisterApp());
    // Ein Frame extra: die Lokalisierungs-Delegates lösen asynchron auf, davor
    // steht unter MaterialApp noch gar kein Inhalt.
    await tester.pump();

    expect(find.byType(LoginWithCodeScreen), findsOneWidget);

    // Erster Frame: der Bildschirm prüft noch, ob dieses Gerät bereits
    // aktiviert ist, und zeigt so lange nur den Fortschrittsanzeiger.
    // Kein pumpAndSettle() — die Prüfung fragt das Netz, das im Test nicht
    // antwortet; pumpAndSettle würde in den Timeout laufen.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
