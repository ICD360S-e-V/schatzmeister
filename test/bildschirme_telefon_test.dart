// Passt JEDER Bildschirm auf jedes Telefon — auf Deutsch und auf Rumänisch?
//
// Die App stammt aus der Vorsitzer-App, die zuerst für Windows gebaut wurde:
// viele Bildschirme stellten drei Karten oder lange Zeilen nebeneinander und
// liefen auf dem Telefon der Schatzmeisterin (Redmi, 393 dp) hinaus. Hier
// wird jeder Bildschirm, der sich im Test aufbauen lässt, auf allen gängigen
// Android-Breiten, einem Tablet und dem Schreibtisch in beiden Sprachen
// gerendert. Jeder Überlauf ist ein Fehler — mit der Zeile im Code, die ihn
// verursacht.
//
// ⚠️ Mit der echten Schrift (Roboto), nicht mit der Testschrift: in der
// zeichnet flutter_test jede Glyphe als 1-em-Quadrat, Texte werden dadurch
// viel breiter als auf dem Gerät. Ein Überlauf, den es auf dem Telefon nicht
// gibt, würde den Test rot färben; einer, den es gibt, hier gemessen.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:icd360sev_schatzmeister/l10n/app_localizations.dart';
import 'package:icd360sev_schatzmeister/models/user.dart';
import 'package:icd360sev_schatzmeister/services/api_service.dart';
import 'package:icd360sev_schatzmeister/services/language_service.dart';
import 'package:icd360sev_schatzmeister/services/ticket_service.dart';
import 'package:icd360sev_schatzmeister/screens/arbeitsagentur_screen.dart';
import 'package:icd360sev_schatzmeister/screens/archiv_screen.dart';
import 'package:icd360sev_schatzmeister/screens/behoerden_screen.dart';
import 'package:icd360sev_schatzmeister/screens/db_mobilitat_unterstutzung_screen.dart';
import 'package:icd360sev_schatzmeister/screens/deutschepost_screen.dart';
import 'package:icd360sev_schatzmeister/screens/dienste_screen.dart';
import 'package:icd360sev_schatzmeister/screens/eigene_unterschriften_screen.dart';
import 'package:icd360sev_schatzmeister/screens/finanzamt_screen.dart';
import 'package:icd360sev_schatzmeister/screens/finanzverwaltung_screen.dart';
import 'package:icd360sev_schatzmeister/screens/gls_bank_screen.dart';
import 'package:icd360sev_schatzmeister/screens/google_nonprofit_screen.dart';
import 'package:icd360sev_schatzmeister/screens/handelsregister_screen.dart';
import 'package:icd360sev_schatzmeister/screens/jpg2pdf_screen.dart';
import 'package:icd360sev_schatzmeister/screens/microsoft_nonprofit_screen.dart';
import 'package:icd360sev_schatzmeister/screens/netzwerk_screen.dart';
import 'package:icd360sev_schatzmeister/screens/notar_screen.dart';
import 'package:icd360sev_schatzmeister/screens/ordnungsmassnahmen_screen.dart';
import 'package:icd360sev_schatzmeister/screens/pdf_manager_screen.dart';
import 'package:icd360sev_schatzmeister/screens/postcard.dart';
import 'package:icd360sev_schatzmeister/screens/reiseplanung_screen.dart';
import 'package:icd360sev_schatzmeister/screens/routinenaufgaben_screen.dart';
import 'package:icd360sev_schatzmeister/screens/sendungsverfolgung.dart';
import 'package:icd360sev_schatzmeister/screens/statistik_screen.dart';
import 'package:icd360sev_schatzmeister/screens/stifter_helfen_screen.dart';
import 'package:icd360sev_schatzmeister/screens/terminverwaltung_screen.dart';
import 'package:icd360sev_schatzmeister/screens/vereinregister_screen.dart';
import 'package:icd360sev_schatzmeister/screens/vereinverwaltung_screen.dart';
import 'package:icd360sev_schatzmeister/screens/vr_bank_screen.dart';

/// Android-Telefone (wie telefon_layout_test), dazu Tablet und Schreibtisch —
/// dort soll alles bleiben, wie es war.
const Map<String, Size> kBreiten = {
  '320 dp': Size(320, 640),
  '360 dp': Size(360, 800),
  '384 dp': Size(384, 854),
  '393 dp (Redmi)': Size(393, 873),
  '412 dp': Size(412, 915),
  '800 dp (Tablet)': Size(800, 1280),
  '1280 dp (Schreibtisch)': Size(1280, 800),
};

const kSprachen = ['de', 'ro'];

final String _schriften =
    '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
final bool _schriftenDa = File('$_schriften/Roboto-Regular.ttf').existsSync();

Future<void> _laden(String familie, List<String> dateien) async {
  final loader = FontLoader(familie);
  for (final d in dateien) {
    loader.addFont(Future.value(
        ByteData.sublistView(File('$_schriften/$d').readAsBytesSync())));
  }
  await loader.load();
}

/// Antwortet auf jede Anfrage mit gültigem JSON, aber ohne Daten — so baut
/// jeder Bildschirm seinen leeren Zustand auf, statt an einer 400-Antwort
/// ohne Inhalt (flutter_test-Vorgabe) mit FormatException abzubrechen.
http.Client _leererServer() => MockClient((_) async => http.Response(
      jsonEncode({'success': false, 'message': 'test'}),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    ));

Widget _rahmen(Widget kind, String sprache) => MaterialApp(
      locale: Locale(sprache),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('de'), Locale('ro')],
      home: Scaffold(body: SafeArea(child: kind)),
    );

/// Rendert [bauen] auf jeder Breite in jeder Sprache und verlangt: kein
/// Überlauf und auch sonst kein Fehler beim Bauen oder Layouten — ein
/// Bildschirm, der auf dem Telefon z. B. keine Höhe findet, ist kaputt, auch
/// wenn nichts übersteht. Fehler aus Netz und Plattform-Kanälen zählen nicht.
void pruefeBildschirm(String name, Widget Function() bauen) {
  group('Bildschirm $name', () {
    for (final sprache in kSprachen) {
      for (final fall in kBreiten.entries) {
        testWidgets('läuft nicht über — ${fall.key} [$sprache]', (tester) async {
          tester.view.physicalSize = fall.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          await LanguageService.instance.setLanguage(sprache);

          final fehler = <String>[];
          final vorher = FlutterError.onError;
          FlutterError.onError = (details) {
            final text = details.toString();
            final ort = RegExp(r'lib/[\w/]+\.dart:\d+').firstMatch(text)?.group(0) ?? '?';
            final m = RegExp(r'overflowed by ([0-9.]+) pixels on the (\w+)')
                .firstMatch(text);
            if (m != null) {
              fehler.add('${m.group(1)} px ${m.group(2)} @ $ort');
              return;
            }
            final bibliothek = details.library ?? '';
            if (bibliothek == 'rendering library' || bibliothek == 'widgets library') {
              fehler.add('Fehler ($bibliothek): '
                  '${details.exceptionAsString().split('\n').first} @ $ort');
            }
          };
          try {
            await tester.pumpWidget(_rahmen(bauen(), sprache));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
          } finally {
            FlutterError.onError = vorher;
          }
          // Übrige Ausnahmen (Netz/Kanäle) abholen, sie sind nicht Gegenstand.
          tester.takeException();
          await tester.pumpWidget(const SizedBox());

          expect(fehler, isEmpty,
              reason: '$name auf ${fall.key} [$sprache]:\n${fehler.toSet().join('\n')}');
        });
      }
    }
  }, skip: _schriftenDa ? false : 'Roboto fehlt unter $_schriften');
}

void main() {
  setUpAll(() async {
    if (!_schriftenDa) return;
    await _laden('Roboto', [
      'Roboto-Regular.ttf',
      'Roboto-Bold.ttf',
      'Roboto-Medium.ttf',
      'Roboto-Italic.ttf',
    ]);
    await _laden('MaterialIcons', ['MaterialIcons-Regular.otf']);
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService().testClient = _leererServer();
    TicketService().testClient = _leererServer();
  });

  final api = ApiService();
  final users = <User>[];
  void zurueck() {}

  pruefeBildschirm('Arbeitsagentur', () => ArbeitsagenturScreen(apiService: api, onBack: zurueck));
  pruefeBildschirm('Archiv', () => ArchivScreen(apiService: api, users: users));
  pruefeBildschirm('Behörden', () => BehoerdenScreen(apiService: api, onBack: zurueck));
  pruefeBildschirm('DB Mobilität', () => DbMobilitaetUnterstuetzungScreen(onBack: zurueck));
  pruefeBildschirm('Deutsche Post', () => DeutschePostScreen(apiService: api, onBack: zurueck));
  pruefeBildschirm('Dienste', () => const DiensteScreen());
  pruefeBildschirm('Eigene Unterschriften', () => EigeneUnterschriftenScreen(apiService: api));
  pruefeBildschirm('Finanzamt', () => FinanzamtScreen(apiService: api, onBack: zurueck));
  pruefeBildschirm('Finanzverwaltung', () => const FinanzverwaltungScreen());
  pruefeBildschirm('GLS Bank', () => GlsBankScreen(onBack: zurueck));
  pruefeBildschirm('Google Nonprofit', () => GoogleNonprofitScreen(apiService: api, onBack: zurueck));
  pruefeBildschirm('Handelsregister', () => HandelsregisterScreen(apiService: api, onBack: zurueck));
  pruefeBildschirm('Jpg2Pdf', () => Jpg2PdfScreen(onBack: zurueck));
  pruefeBildschirm('Microsoft Nonprofit', () => MicrosoftNonprofitScreen(apiService: api, onBack: zurueck));
  pruefeBildschirm('Netzwerk', () => const NetzwerkScreen());
  pruefeBildschirm('Notar', () => NotarScreen(apiService: api, onBack: zurueck));
  pruefeBildschirm('Ordnungsmaßnahmen', () => OrdnungsmassnahmenScreen(users: users, onBack: zurueck));
  pruefeBildschirm('PDF-Manager', () => PdfManagerView(onBack: zurueck));
  pruefeBildschirm('Postcard', () => PostcardView(apiService: api));
  pruefeBildschirm('Reiseplanung', () => ReiseplanungScreen(onBack: zurueck));
  pruefeBildschirm('Routinenaufgaben', () => RoutinenaufgabenScreen(users: users, currentMitgliedernummer: 'S1'));
  pruefeBildschirm('Sendungsverfolgung', () => SendungsverfolgungView(apiService: api));
  pruefeBildschirm('Statistik', () => StatistikScreen(apiService: api, users: users, currentMitgliedernummer: 'S1'));
  pruefeBildschirm('Stifter-helfen', () => StifterHelfenScreen(apiService: api, onBack: zurueck));
  pruefeBildschirm('Terminverwaltung', () => const TerminverwaltungScreen(currentMitgliedernummer: 'S1'));
  pruefeBildschirm('Vereinregister', () => VereinregisterScreen(apiService: api, onBack: zurueck));
  pruefeBildschirm('Vereinverwaltung', () => VereinverwaltungScreen(
        apiService: api,
        users: users,
        getRoleColor: (_) => Colors.grey,
        getRoleText: (r) => r,
      ));
  pruefeBildschirm('VR Bank', () => VrBankScreen(onBack: zurueck));
}
