// Vereinverwaltung MIT Daten auf Telefon, Tablet und Schreibtisch.
//
// bildschirme_telefon_test.dart sieht nur die Übersicht ohne Daten. Hier
// geht der Test durch jede Ansicht dieses Bildschirms (Partner, Hetzner,
// INWX, IT-Beschaffung, Notar, Banken, Vorstand) — mit echten Vorstands-
// mitgliedern (lange Doppelnamen), Notar-Einträgen vom vorgetäuschten Server
// und offenen Plattform-Aufgaben. Ansichten anderer Bildschirme (Behörden,
// Deutsche Post, Banken, Stifter-helfen, …) prüfen deren eigene Tests.
// Gemessen mit Roboto, wie in bildschirme_telefon_test.dart.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:icd360sev_schatzmeister/l10n/app_localizations.dart';
import 'package:icd360sev_schatzmeister/models/user.dart';
import 'package:icd360sev_schatzmeister/screens/vereinverwaltung_screen.dart';
import 'package:icd360sev_schatzmeister/services/api_service.dart';
import 'package:icd360sev_schatzmeister/services/device_key_service.dart';
import 'package:icd360sev_schatzmeister/services/language_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Map<String, Size> kBreiten = {
  '320 dp': Size(320, 640),
  '360 dp': Size(360, 800),
  '393 dp (Redmi)': Size(393, 873),
  '412 dp': Size(412, 915),
  '800 dp (Tablet)': Size(800, 1280),
  '1280 dp (Schreibtisch)': Size(1280, 800),
};

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

http.Response _json(Object daten) => http.Response(jsonEncode(daten), 200,
    headers: {'content-type': 'application/json; charset=utf-8'});

const _notar = 'Notariat Dr. Konstantin Schönberger-Wittelsbach & Kollegen';

/// Der Server, wie VereinverwaltungScreen ihn liest: alle Einträge der
/// Vereinverwaltung (davon zeigt er die Notare) und je Plattform die Aufgaben.
http.Client _server() => MockClient((anfrage) async {
      final pfad = anfrage.url.path;
      if (pfad.endsWith('/vereinverwaltung/get.php')) {
        return _json({
          'success': true,
          'data': [
            {
              'kategorie': 'notar',
              'name': _notar,
              'name2': 'Notare in Bürogemeinschaft, Amtssitz Neu-Ulm',
              'strasse': 'Augsburger Straße',
              'hausnummer': '112–114',
              'plz': '89231',
              'ort': 'Neu-Ulm',
              'telefon': '+49 731 1234567-0',
              'fax': '+49 731 1234567-99',
              'email': 'kanzlei.schoenberger-wittelsbach@notariat-neu-ulm.de',
              'website': 'https://www.notariat-schoenberger-wittelsbach-neu-ulm.de/vereinsregister',
              'notizen': 'Beglaubigung der Anmeldung zum Vereinsregister (Satzungsänderung § 6 Abs. 6) '
                  'vom 12.03.2026; Rechnung Nr. 2026-0315 beglichen.',
            },
            {
              'kategorie': 'notar',
              'name': 'Notarin Ioana-Alexandra Constantinescu',
              'ort': 'Ulm',
            },
            {'kategorie': 'partner', 'name': 'nicht hier'},
          ],
        });
      }
      if (pfad.endsWith('/platform/aufgaben_list.php')) {
        return _json({
          'success': true,
          'aufgaben': [
            {'erledigt': false},
            {'erledigt': 0},
            {'erledigt': true},
          ],
        });
      }
      return _json({'success': false, 'message': 'unbekannt: $pfad'});
    });

final _mitglieder = [
  User(id: 1, mitgliedernummer: 'V00001', email: 'v@icd360s.de',
      name: 'Maximilian-Alexander Schönberger-Constantinescu', status: 'active', role: 'vorsitzer'),
  User(id: 2, mitgliedernummer: 'S00002', email: 's@icd360s.de',
      name: 'Ioana-Alexandra Dumitrescu-Popescu', status: 'active', role: 'schatzmeister'),
  User(id: 3, mitgliedernummer: 'K00003', email: 'k@icd360s.de',
      name: 'Wolfgang Amadeus Grünberger-Hohenstein', status: 'suspended', role: 'kassierer'),
  User(id: 4, mitgliedernummer: 'M00004', email: 'm@icd360s.de',
      name: 'Elisabeth Charlotte von Hohenzollern-Sigmaringen', status: 'active', role: 'mitgliedergrunder'),
  User(id: 5, mitgliedernummer: 'M00005', email: 'x@icd360s.de',
      name: 'Kein Vorstand', status: 'active', role: 'mitglied'),
];

String _rolle(String r) => switch (r) {
      'vorsitzer' => tr('Vorsitzender', 'Președinte'),
      'schatzmeister' => tr('Schatzmeisterin', 'Trezorieră'),
      'kassierer' => tr('Kassierer', 'Casier'),
      'mitgliedergrunder' => tr('Gründungsmitglied', 'Membru fondator'),
      _ => r,
    };

/// Lässt jede senkrechte Liste einmal von oben bis unten laufen: eine
/// ListView baut nur, was zu sehen ist — ein Überlauf weiter unten fiele
/// sonst nicht auf.
Future<void> _durchscrollen(WidgetTester tester) async {
  final listen = find
      .byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down)
      .evaluate()
      .map((e) => (e as StatefulElement).state as ScrollableState)
      .toList();
  for (final liste in listen) {
    if (!liste.mounted) continue;
    final pos = liste.position;
    // Zusammengedrückte Liste (Höhe 0): nichts zu sehen, nichts zu scrollen.
    if (pos.viewportDimension < 1) continue;
    for (var i = 0, p = 0.0; i < 100; i++, p += pos.viewportDimension / 2) {
      pos.jumpTo(p.clamp(0.0, pos.maxScrollExtent));
      await tester.pump();
      if (p >= pos.maxScrollExtent) break;
    }
    pos.jumpTo(0);
    await tester.pump();
  }
}

/// Scrollt die Liste, bis [ziel] gebaut ist, holt es ins Bild und tippt es an.
/// Karten werden über ihren Titel gefunden: die Listen bauen nur, was zu
/// sehen ist, ein Symbol-Index („das zweite account_balance“) wäre unsicher.
Future<void> _oeffnen(WidgetTester tester, Finder ziel) async {
  final liste = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);
  for (var i = 0; i < 30 && ziel.evaluate().isEmpty && liste.evaluate().isNotEmpty; i++) {
    await tester.drag(liste.first, const Offset(0, -200));
    await tester.pump();
  }
  await tester.ensureVisible(ziel);
  await tester.pump();
  await tester.tap(ziel);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _zurueck(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.arrow_back));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
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
    // ApiService schickt nichts ohne Geräteschlüssel (X-Device-Key).
    FlutterSecureStorage.setMockInitialValues({'device_key': 'TEST-GERAET', 'device_id': 'TEST-ID'});
    await DeviceKeyService().loadStoredDeviceKey();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Vereinverwaltung mit Daten', () {
    for (final sprache in ['de', 'ro']) {
      for (final fall in kBreiten.entries) {
        testWidgets('alle eigenen Ansichten — ${fall.key} [$sprache]', (tester) async {
          tester.view.physicalSize = fall.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          await LanguageService.instance.setLanguage(sprache);
          ApiService().testClient = _server();

          // Jeder Überlauf mit der Ansicht, in der er auftrat.
          var ansicht = 'Übersicht';
          final ueberlaeufe = <String>{};
          final fehlt = <String>[];
          final vorher = FlutterError.onError;
          FlutterError.onError = (details) {
            final text = details.toString();
            final m = RegExp(r'overflowed by ([0-9.]+) pixels on the (\w+)').firstMatch(text);
            if (m == null) {
              vorher?.call(details);
              return;
            }
            final ort = RegExp(r'lib/[\w/]+\.dart:\d+').firstMatch(text);
            ueberlaeufe.add('$ansicht: ${m.group(1)} px ${m.group(2)} @ ${ort?.group(0) ?? '?'}');
          };
          // Listen bauen nur, was zu sehen ist: bis zum Text scrollen.
          Future<void> pruefeText(String text) async {
            await _scrollenBis(tester, find.text(text));
            if (find.text(text).evaluate().isEmpty) fehlt.add('$ansicht: „$text“');
          }

          try {
            await tester.pumpWidget(_rahmen(
                VereinverwaltungScreen(
                  apiService: ApiService(),
                  users: _mitglieder,
                  getRoleColor: (_) => Colors.indigo,
                  getRoleText: _rolle,
                ),
                sprache));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            await _durchscrollen(tester);

            ansicht = 'Partner';
            await _oeffnen(tester, find.text(tr('Partner & Dienstleister', 'Parteneri și furnizori')));
            await _durchscrollen(tester);

            ansicht = 'Hetzner';
            await _oeffnen(tester, find.text('Hetzner'));
            await pruefeText('Dedicated Server: 148.251.68.9 (Proxmox)');
            await _durchscrollen(tester);
            await _zurueck(tester);

            ansicht = 'INWX';
            await _oeffnen(tester, find.text('INWX'));
            await pruefeText(tr('Nameserver-Einstellungen', 'Setări nameserver'));
            await _durchscrollen(tester);
            await _zurueck(tester);

            ansicht = 'IT-Beschaffung';
            await _oeffnen(tester, find.text(tr('IT-Beschaffungsplattform', 'Platformă achiziții IT')));
            await _durchscrollen(tester);
            // Offene Aufgaben vom Server: zwei von dreien je Plattform.
            if (find.text(tr('2 offene Aufgaben', '2 sarcini deschise')).evaluate().isEmpty) {
              fehlt.add('IT-Beschaffung: offene Aufgaben');
            }
            await _zurueck(tester); // → Partner
            await _zurueck(tester); // → Übersicht

            ansicht = 'Notar';
            await _oeffnen(tester, find.text('Notar'));
            await pruefeText(_notar);
            await pruefeText('Notarin Ioana-Alexandra Constantinescu');
            await _durchscrollen(tester);
            await _zurueck(tester);

            ansicht = 'Banken';
            await _oeffnen(tester, find.text(tr('Banken', 'Bănci')));
            await pruefeText('GLS Bank');
            await _durchscrollen(tester);
            await _zurueck(tester);

            ansicht = 'Vorstand';
            await _oeffnen(tester, find.text(tr('Vorstand', 'Conducere')));
            for (final m in _mitglieder.take(4)) {
              await pruefeText(m.name);
            }
            if (find.text('Kein Vorstand').evaluate().isNotEmpty) fehlt.add('Vorstand: Mitglied ohne Amt angezeigt');
            await _durchscrollen(tester);
          } finally {
            FlutterError.onError = vorher;
          }
          await tester.pumpWidget(const SizedBox());

          expect(fehlt, isEmpty, reason: 'gelieferte Daten fehlen: ${fehlt.join(', ')}');
          expect(ueberlaeufe, isEmpty, reason: '${fall.key} [$sprache]:\n${ueberlaeufe.join('\n')}');
        });
      }
    }
  }, skip: _schriftenDa ? false : 'Roboto fehlt unter $_schriften');

  // Alle Ansichten haben denselben Aufbau (Kopfzeile + Liste). Ohne eigenen
  // Schlüssel je Ansicht übernahm die nächste Liste die Scrollposition der
  // vorigen: unten in der Übersicht „Notar“ angetippt — und die Notarliste
  // begann mitten im ersten Eintrag.
  testWidgets('jede Ansicht beginnt oben, nicht an der Scrollposition der vorigen', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await LanguageService.instance.setLanguage('de');
    ApiService().testClient = _server();
    await tester.pumpWidget(_rahmen(
        VereinverwaltungScreen(
          apiService: ApiService(),
          users: _mitglieder,
          getRoleColor: (_) => Colors.indigo,
          getRoleText: _rolle,
        ),
        'de'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    ScrollPosition position() => tester
        .state<ScrollableState>(find
            .byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down)
            .first)
        .position;
    position().jumpTo(position().maxScrollExtent);
    await tester.pump();
    expect(position().pixels, greaterThan(100), reason: 'die Übersicht muss gescrollt sein');

    await _oeffnen(tester, find.text('Notar'));
    expect(find.text(_notar), findsOneWidget);
    expect(position().pixels, 0, reason: 'die Notarliste beginnt oben');
    await tester.pumpWidget(const SizedBox());
  }, skip: !_schriftenDa);
}

/// Scrollt die Liste, bis [ziel] gebaut ist (ohne es anzutippen).
Future<void> _scrollenBis(WidgetTester tester, Finder ziel) async {
  final liste = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);
  for (var i = 0; i < 30 && ziel.evaluate().isEmpty && liste.evaluate().isNotEmpty; i++) {
    await tester.drag(liste.first, const Offset(0, -200));
    await tester.pump();
  }
}
