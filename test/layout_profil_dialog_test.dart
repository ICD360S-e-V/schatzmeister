// Passt der Profil-Dialog (sieben Reiter) auf jedes Telefon — mit echten
// Daten, auf Deutsch und auf Rumänisch?
//
// Der Dialog war für den Schreibtisch gebaut: 950 × 700 dp, die Reiter
// nebeneinander, Bezeichnungen in festen Spalten. Geöffnet wird er hier wie
// im Dashboard, mit showDialog; die Daten kommen über ApiService.testClient
// (Profil, Geräte, Verifizierung, Visitenkarte) und über den falschen Server
// aus layout_teil8_hilfen.dart (Verwarnungen, Dokumente).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:icd360sev_schatzmeister/l10n/app_localizations.dart';
import 'package:icd360sev_schatzmeister/services/api_service.dart';
import 'package:icd360sev_schatzmeister/services/language_service.dart';
import 'package:icd360sev_schatzmeister/widgets/profile_dialog.dart';

import 'layout_teil8_hilfen.dart';

const _knopf = 'Profil öffnen';

Widget _gastgeber() => Scaffold(
      body: Builder(
        builder: (ctx) => Center(
          child: ElevatedButton(
            onPressed: () => showDialog(
              context: ctx,
              builder: (_) => ProfileDialog(
                userName: kIchName,
                mitgliedernummer: kIch,
                email: kIchMail,
                role: 'schatzmeister',
                userId: kIchId,
                apiService: ApiService(),
                onEmailChanged: (_) {},
              ),
            ),
            child: const Text(_knopf),
          ),
        ),
      ),
    );

Future<void> _warten(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _tippen(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await _warten(tester);
}

Future<void> _pruefe(
  WidgetTester tester,
  Size groesse,
  String sprache,
  Future<void> Function(AppLocalizations l) schritte,
) async {
  tester.view.physicalSize = groesse;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await LanguageService.instance.setLanguage(sprache);

  final f = UeberlaufFaenger()..an();
  Object? fehler;
  try {
    await tester.pumpWidget(rahmenApp(_gastgeber(), sprache));
    await tester.pump();
    await tester.tap(find.text(_knopf));
    await _warten(tester);
    expect(find.byType(ProfileDialog), findsOneWidget);
    // Eingespeist (get_profile.php): die Mobilnummer im Profil-Reiter.
    await bisSichtbar(tester, find.text('+49 1520 98765432'),
        grund: 'Profildaten nicht geladen');
    await schritte(AppLocalizations.of(tester.element(find.byType(ProfileDialog))));
  } finally {
    f.aus();
    fehler = tester.takeException();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
  }
  expect(f.ueberlaeufe, isEmpty,
      reason: 'Profil ${groesse.width} dp [$sprache]:\n'
          '${f.ueberlaeufe.toSet().join('\n')}');
  expect(fehler, isNull);
}

Finder _reiter(String text) =>
    find.descendant(of: find.byType(Tab), matching: find.text(text));

void main() {
  setUpAll(() async {
    await schriftenLaden();
    await geraetAktivieren();
    HttpOverrides.global = FalscherServer(teil8Antworten);
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Teil8Daten.zuruecksetzen();
    ApiService().testClient = mockClient(teil8Antworten);
  });

  group('Profil-Dialog mit Daten', () {
    for (final sprache in kSprachenTeil8) {
      for (final fall in kBreitenTeil8.entries) {
        testWidgets('Profil mit allen drei Formularen — ${fall.key} [$sprache]',
            (tester) async {
          await _pruefe(tester, fall.value, sprache, (l) async {
            expect(find.text(kIchMail), findsOneWidget);
            await _tippen(tester, find.text(l.addPhoneNumber));
            await _tippen(tester, find.text(l.changeEmail));
            await _tippen(tester, find.text(l.changePassword));
            // Alle drei Formulare offen: ihre Speichern-Knöpfe stehen da.
            expect(find.text(l.saveEmail), findsOneWidget);
            expect(find.text(l.savePassword), findsOneWidget);
          });
        });

        testWidgets('alle sieben Reiter — ${fall.key} [$sprache]', (tester) async {
          await _pruefe(tester, fall.value, sprache, (l) async {
            // Je Reiter ein eingespeister Wert, der dort stehen muss.
            final reiter = <String, Finder>{
              l.myDevices: find.text('Xiaomi Redmi Note 11 Pro+ 5G (21091116UG)'),
              l.businessCard: find.text('+49 1520 98765432'),
              l.warnings: find.text('Kassenbuch nicht fristgerecht vorgelegt'),
              l.documents: find.text('Kassenbuch 2025 (Export für die Kassenprüfung)'),
              l.membership: find.text(l.supportingMember),
              l.verification: find.byType(ExpansionTile),
            };
            for (final r in reiter.entries) {
              await _tippen(tester, _reiter(r.key));
              await bisSichtbar(tester, r.value, grund: 'Reiter ${r.key} ist leer');
            }
          });
        });

        for (final variante in const ['A', 'B']) {
          testWidgets('Verifizierung $variante aufgeklappt — ${fall.key} [$sprache]',
              (tester) async {
            Teil8Daten.verifizierung = variante;
            await _pruefe(tester, fall.value, sprache, (l) async {
              await _tippen(tester, _reiter(l.verification));
              final stufen = find.byType(ExpansionTile);
              expect(stufen, findsNWidgets(2));
              await _tippen(tester, stufen.at(0));
              await _tippen(tester, find.byType(ExpansionTile).at(1));
              // A: Stufe 1 geprüft (Anschrift lesbar), Stufe 3 offen;
              // B: Stufe 1 offen (Eingabefelder), Stufe 3 geprüft.
              await bisSichtbar(
                  tester,
                  variante == 'A'
                      ? find.text('Bürgermeister-Hartmann-Straße')
                      : find.widgetWithText(TextField, 'Bürgermeister-Hartmann-Straße'));
              expect(find.text(l.sepaDirectDebit), findsWidgets);
            });
          });
        }
      }
    }
  });
}
