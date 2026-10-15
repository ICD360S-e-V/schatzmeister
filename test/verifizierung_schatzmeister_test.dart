// Profil ▸ Verifizierung des Schatzmeisters — die eigenen Angaben, Stufe für
// Stufe so, wie der Vorstand sie prüft.
//
// Wunsch des Vorsitzenden, 15.10.2026: „tab-ul Verifizierung din profil ar
// trebui sa mearga pentru schatzmeister unde sa isi completeze datele
// adapteaza dupa cum cere vorsitzerul“. Bis dahin fragte der Reiter
// `admin/verifizierung_list.php` — eine Vorstandsrolle, also immer 403 — und
// zeigte deshalb stets „0/0“. Jetzt ist er eine Kopie der Verifizierung der
// Mitglieder-App gegen das EIGENE API `schatzmeister/verifizierung/`.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:icd360sev_schatzmeister/services/api_service.dart';
import 'package:icd360sev_schatzmeister/services/language_service.dart';
import 'package:icd360sev_schatzmeister/widgets/verifizierung_tab.dart';

import 'layout_teil8_hilfen.dart';

void main() {
  late List<http.Request> anfragen;

  setUpAll(() async {
    await geraetAktivieren();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Teil8Daten.zuruecksetzen();
    await LanguageService.instance.setLanguage('de');
    anfragen = [];
    ApiService().testClient = MockClient((r) async {
      anfragen.add(r);
      final a = teil8Antworten(r.method, r.url, r.body) ??
          (status: 200, json: {'success': true, 'message': 'gespeichert'});
      return http.Response(jsonEncode(a.json), a.status,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });
  });

  Future<void> zeigen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(rahmenApp(
        const Scaffold(body: VerifizierungTab(mitgliedernummer: kIch)), 'de'));
    await bisSichtbar(tester, find.byType(ExpansionTile), grund: 'nichts geladen');
  }

  testWidgets('lädt die eigenen Stufen aus schatzmeister/verifizierung/ — nie /member/ oder /admin/',
      (tester) async {
    await zeigen(tester);
    final pfade = anfragen.map((r) => r.url.path).toList();
    expect(pfade, contains('/api/schatzmeister/verifizierung/liste.php'));
    expect(pfade, contains('/api/schatzmeister/verifizierung/staatsangehoerigkeiten.php'));
    for (final p in pfade) {
      expect(p, startsWith('/api/schatzmeister/verifizierung/'), reason: p);
    }
    // Geladen heißt: die Stufen und ihr Fortschritt stehen da.
    expect(find.text('Verifizierungsfortschritt'), findsOneWidget);
    expect(find.text('3/5 Stufen erledigt'), findsOneWidget);
  });

  testWidgets('Stufe 1 speichern geht an persoenlich.php — mit den eigenen Angaben, ohne fremde Nummer',
      (tester) async {
    Teil8Daten.verifizierung = 'B'; // Stufe 1 offen
    await zeigen(tester);
    await tester.tap(find.byType(ExpansionTile).first);
    await tester.pumpAndSettle();
    final speichern = find.widgetWithText(ElevatedButton, 'Speichern');
    await tester.ensureVisible(speichern.first);
    await tester.pumpAndSettle();
    await tester.tap(speichern.first);
    await tester.pumpAndSettle();

    final post = anfragen.where((r) => r.method == 'POST').toList();
    expect(post.map((r) => r.url.path), ['/api/schatzmeister/verifizierung/persoenlich.php']);
    final rumpf = jsonDecode(post.single.body) as Map<String, dynamic>;
    expect(rumpf['vorname'], 'Maria-Elena');
    expect(rumpf['nachname'], 'Popescu-Ionescu');
    expect(rumpf['strasse'], 'Bürgermeister-Hartmann-Straße');
    expect(rumpf['geburtsdatum'], '1984-03-17');
    // Wer, sagt allein das Token — keine Nummer und keine ID im Rumpf.
    expect(rumpf.containsKey('user_id'), isFalse);
    expect(rumpf.containsKey('mitgliedernummer'), isFalse);
    // Die Mobilnummer geht unverändert mit (der Server nimmt nur eine
    // unveränderte an; ändern kann sie hier niemand).
    expect(rumpf['telefon_mobil'], '+49 1520 98765432');
  });

  testWidgets('die Mobilnummer ist nur zu lesen — geändert wird sie über den Vorstand', (tester) async {
    Teil8Daten.verifizierung = 'B';
    await zeigen(tester);
    await tester.tap(find.byType(ExpansionTile).first);
    await tester.pumpAndSettle();
    final mobil = find.widgetWithText(TextField, '+49 1520 98765432');
    expect(tester.widget<TextField>(mobil).enabled, isFalse);
    expect(find.textContaining('Ändern kann sie der Vorstand'), findsOneWidget);
  });

  test('der Reiter und die Aufrufe kennen nur das eigene API des Schatzmeisters', () {
    final tab = File('lib/widgets/verifizierung_tab.dart').readAsStringSync();
    final api = File('lib/services/api_service.dart').readAsStringSync();
    // Der Abschnitt der neuen Aufrufe, vom Kopf bis zu acceptDocument.
    final start = api.indexOf('// ========== VERIFIZIERUNG — EIGENE ANGABEN');
    final ende = api.indexOf('Future<Map<String, dynamic>> acceptDocument', start);
    expect(start, greaterThan(0));
    expect(ende, greaterThan(start));
    final abschnitt = api.substring(start, api.indexOf('\n  }\n', ende));
    expect(abschnitt, contains("'\$baseUrl/schatzmeister/verifizierung'"));
    // Kommentare dürfen die alten Wege nennen (sie erklären, warum nicht) —
    // der Code nicht.
    String ohneKommentare(String q) =>
        q.split('\n').where((z) => !z.trimLeft().startsWith('//')).join('\n');
    for (final q in [tab, abschnitt].map(ohneKommentare)) {
      expect(q, isNot(contains('/member/')));
      expect(q, isNot(contains('/admin/')));
    }
    for (final datei in ['liste', 'staatsangehoerigkeiten', 'persoenlich', 'finanzen', 'zahlung', 'beginn', 'dokument']) {
      expect(abschnitt, contains('\$_verifizierung/$datei.php'), reason: datei);
    }
    // Der Profil-Dialog zeigt die Kopie, nicht mehr den alten Reiter.
    final profil = File('lib/widgets/profile_dialog.dart').readAsStringSync();
    expect(profil, contains('VerifizierungTab(mitgliedernummer: widget.mitgliedernummer)'));
    expect(profil, isNot(contains('getVerifizierung(')));
  });
}
