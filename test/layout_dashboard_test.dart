// Passt das Dashboard — der Hauptbildschirm nach der Anmeldung — auf jedes
// Telefon, mit echten Daten, auf Deutsch und auf Rumänisch?
//
// Bis hierher galt es als nicht testbar: es baut in initState eine
// WebSocket-Verbindung auf und startet ein Dutzend Dienste (siehe
// telefon_layout_test.dart). Mit dem falschen Server aus
// layout_teil8_hilfen.dart bekommen alle Dienste ihre Antworten, der
// WebSocket scheitert wie ohne Netz, und das Dashboard baut sich vollständig
// auf: Kopfleiste mit allen Knöpfen, Übersicht, Menü, Tickets, Termine,
// Chat-Auswahl, Live-Chat und (auf dem Schreibtisch) das Wetter.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:icd360sev_schatzmeister/l10n/app_localizations.dart';
import 'package:icd360sev_schatzmeister/screens/dashboard_screen.dart';
import 'package:icd360sev_schatzmeister/services/api_service.dart';
import 'package:icd360sev_schatzmeister/services/chat_service.dart';
import 'package:icd360sev_schatzmeister/services/language_service.dart';
import 'package:icd360sev_schatzmeister/services/ticket_service.dart';
import 'package:icd360sev_schatzmeister/widgets/dashboard_sidebar.dart';

import 'layout_teil8_hilfen.dart';

Widget _dashboard() => const DashboardScreen(
      userName: kIchName,
      currentMitgliedernummer: kIch,
      currentEmail: kIchMail,
      currentRole: 'schatzmeister',
    );

Future<void> _warten(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

/// Baut das Dashboard auf [groesse] in [sprache], führt [schritte] aus und
/// verlangt: kein Überlauf, keine sonstige Ausnahme.
Future<void> _pruefe(
  WidgetTester tester,
  Size groesse,
  String sprache,
  Future<void> Function(AppLocalizations l, bool telefon) schritte,
) async {
  tester.view.physicalSize = groesse;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await LanguageService.instance.setLanguage(sprache);

  final f = UeberlaufFaenger()..an();
  Object? fehler;
  try {
    await tester.pumpWidget(rahmenApp(_dashboard(), sprache));
    await _warten(tester);
    // Eingespeist: zwölf offene Unterschriften → Abzeichen „9+".
    await bisSichtbar(tester, find.text('9+'), grund: 'Unterschriften-Zähler fehlt');
    final l = AppLocalizations.of(tester.element(find.byType(DashboardScreen)));
    await schritte(l, groesse.width < 600);
  } finally {
    f.aus();
    fehler = tester.takeException();
    await tester.pumpWidget(const SizedBox());
    ChatService().disconnect();
    // Verzögerte Wiederholungen der Dienste (ntfy, WebSocket) auslaufen lassen.
    await tester.pump(const Duration(minutes: 10));
  }
  expect(f.ueberlaeufe, isEmpty,
      reason: 'Dashboard ${groesse.width} dp [$sprache]:\n'
          '${f.ueberlaeufe.toSet().join('\n')}');
  expect(fehler, isNull);
}

/// Menüpunkt wählen — auf dem Telefon über die Schublade.
Future<void> _menue(WidgetTester tester, String titel, bool telefon) async {
  if (telefon) {
    await tester.tap(find.byIcon(Icons.menu));
    await _warten(tester);
    await tester.tap(find.descendant(
        of: find.byType(Drawer), matching: find.text(titel)));
  } else {
    await tester.tap(find.descendant(
        of: find.byType(DashboardSidebar), matching: find.text(titel)));
  }
  await _warten(tester);
}

/// Jeden Reiter einmal öffnen — jeder zeigt eine andere Liste. Mit
/// [eintraege] steht in jedem Reiter mindestens ein eingespeister Eintrag.
Future<void> _alleReiter(WidgetTester tester, {Finder? eintraege}) async {
  final anzahl = find.byType(Tab).evaluate().length;
  expect(anzahl, greaterThan(1));
  for (var i = 0; i < anzahl; i++) {
    await tester.ensureVisible(find.byType(Tab).at(i));
    await tester.pump();
    await tester.tap(find.byType(Tab).at(i));
    await _warten(tester);
    if (eintraege != null) {
      await bisSichtbar(tester, eintraege, grund: 'Reiter $i ist leer');
    }
  }
}

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
    TicketService().testClient = mockClient(teil8Antworten);
    ChatService.testWsUrl = 'ws://ws.test/';
  });

  group('Dashboard mit Daten', () {
    for (final sprache in kSprachenTeil8) {
      for (final fall in kBreitenTeil8.entries) {
        testWidgets('Übersicht und Menü — ${fall.key} [$sprache]', (tester) async {
          await _pruefe(tester, fall.value, sprache, (l, telefon) async {
            expect(find.byType(DashboardScreen), findsOneWidget);
            // Übersicht: sechs eingespeiste Tickets.
            expect(find.text('6'), findsWidgets);
            if (telefon) {
              await tester.tap(find.byIcon(Icons.menu));
              await _warten(tester);
              expect(find.byType(Drawer), findsOneWidget);
              expect(
                  find.descendant(
                      of: find.byType(Drawer), matching: find.text(l.myAppointments)),
                  findsOneWidget);
            }
          });
        });

        testWidgets('Meine Tickets — ${fall.key} [$sprache]', (tester) async {
          await _pruefe(tester, fall.value, sprache, (l, telefon) async {
            await _menue(tester, l.myTickets, telefon);
            await bisSichtbar(tester, find.textContaining('Kassenprüfung 2026'));
            await _alleReiter(tester, eintraege: find.byType(ListTile));
          });
        });

        testWidgets('Meine Termine — ${fall.key} [$sprache]', (tester) async {
          await _pruefe(tester, fall.value, sprache, (l, telefon) async {
            await _menue(tester, l.myAppointments, telefon);
            await bisSichtbar(tester, find.textContaining('Mitgliederversammlung 2026'));
            await _alleReiter(tester, eintraege: find.byType(ListTile));
          });
        });

        testWidgets('Chat-Auswahl und Live-Chat — ${fall.key} [$sprache]',
            (tester) async {
          await _pruefe(tester, fall.value, sprache, (l, telefon) async {
            await tester.tap(find.byIcon(Icons.chat_outlined));
            await _warten(tester);
            // Drei Gespräche → erst die Auswahl „Mit wem?".
            expect(find.byType(SimpleDialog), findsOneWidget);
            await tester.tap(find.byType(SimpleDialogOption).first);
            await _warten(tester);
            expect(find.text('Live Chat'), findsNothing,
                reason: 'Kopfzeile nennt das Gegenüber');
            await bisSichtbar(tester, find.textContaining('Kontoauszüge'));
          });
        });
      }
    }
  });

  // Das Wetter steht nur auf breiten Fenstern in der Kopfleiste (auf dem
  // Telefon ist es ausgeblendet). Geprüft wird der Dialog daher auf dem
  // Schreibtisch und auf schmalen Schreibtisch-Fenstern ab 600 dp.
  group('Wetter-Dialog', () {
    for (final sprache in kSprachenTeil8) {
      for (final breite in const [600.0, 800.0, 1280.0]) {
        testWidgets('alle Reiter — ${breite.toInt()} dp [$sprache]', (tester) async {
          await _pruefe(tester, Size(breite, 800), sprache, (l, telefon) async {
            await tester.tap(find.text('-12°C'));
            await _warten(tester);
            expect(find.text(l.weatherIn('Neu-Ulm')), findsOneWidget);
            await _alleReiter(tester);
            // Wochen-Reiter zuletzt: sieben eingespeiste Tage.
            expect(find.text('104'), findsNWidgets(7));
          });
        });
      }
    }
  });
}
