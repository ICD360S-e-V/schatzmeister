// Passt der Bildschirm „Statistik" auch MIT Daten auf jedes Telefon — auf
// Deutsch und auf Rumänisch?
//
// bildschirme_telefon_test.dart sieht ihn nur ohne Serverdaten. Hier kommen
// Mitglieder in allen Rollen (auch Ehren- und Fördermitglieder, deren Zeilen
// nur dann erscheinen), große Beträge, Spenden und eine Arbeitswoche über
// dem Limit mit allen sieben Tagen. Jeder Überlauf und jeder andere
// Layout-Fehler ist ein Fehler.
//
// Mit der echten Schrift (Roboto) wie in bildschirme_telefon_test.dart.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:icd360sev_schatzmeister/l10n/app_localizations.dart';
import 'package:icd360sev_schatzmeister/models/user.dart';
import 'package:icd360sev_schatzmeister/screens/statistik_screen.dart';
import 'package:icd360sev_schatzmeister/services/api_service.dart';
import 'package:icd360sev_schatzmeister/services/device_key_service.dart';
import 'package:icd360sev_schatzmeister/services/language_service.dart';
import 'package:icd360sev_schatzmeister/services/ticket_service.dart';

const Map<String, Size> kBreiten = {
  '320 dp': Size(320, 640),
  '360 dp': Size(360, 800),
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

User _mitglied(int id, String name, String status, String rolle) => User(
      id: id,
      mitgliedernummer: 'M${10000 + id}',
      email: 'mitglied$id@example.org',
      name: name,
      status: status,
      role: rolle,
    );

final _mitglieder = <User>[
  _mitglied(1, 'Ionuț-Claudiu Duinea', 'active', 'vorsitzer'),
  _mitglied(2, 'Maria-Magdalena Popescu-Schwarzenberger', 'active',
      'schatzmeister'),
  _mitglied(3, 'Alexandru-Constantin Vasilescu-Bărbulescu', 'active',
      'kassierer'),
  _mitglied(4, 'Hans-Joachim Müller-Lüdenscheidt', 'neu', 'mitglied'),
  _mitglied(5, 'Ștefania-Ecaterina Ionescu-Țăranu', 'suspended', 'mitglied'),
  _mitglied(6, 'Friedrich-Wilhelm von Hohenzollern-Sigmaringen', 'active',
      'ehrenmitglied'),
  _mitglied(7, 'Anna-Lena Schmidt-Großkopf', 'gekuendigt', 'foerdermitglied'),
  _mitglied(8, 'Bartholomäus Zimmermann-Weißenfels', 'gekuendigt_verein',
      'mitglied'),
];

http.Response _json(Object daten) => http.Response(jsonEncode(daten), 200,
    headers: {'content-type': 'application/json; charset=utf-8'});

/// Antwortet so, wie StatistikScreen und TicketService.getWeeklyTimeSummary
/// es lesen — mit großen Beträgen und einer Woche über dem Limit.
http.Client _server() => MockClient((anfrage) async {
      final pfad = anfrage.url.path;
      if (pfad.endsWith('/finanzen/beitragszahlungen.php')) {
        return _json({
          'success': true,
          'beitrag_pro_monat': 25,
          'stats': {
            'gesamt_mitglieder': 1287,
            'mitglieder_mit_schulden': 143,
            'total_schulden': 128456.75,
            'total_bezahlt': 2456789.5,
          },
        });
      }
      if (pfad.endsWith('/finanzen/spenden.php')) {
        return _json({
          'success': true,
          'anzahl': 1534,
          'total_betrag': 1234567.89,
          'mit_quittung': 412,
        });
      }
      if (pfad.endsWith('/tickets/time/weekly.php')) {
        const tage = [
          '2026-09-28', '2026-09-29', '2026-09-30', '2026-10-01',
          '2026-10-02', '2026-10-03', '2026-10-04',
        ];
        return _json({
          'success': true,
          'kw': 40,
          'week_start': tage.first,
          'week_end': tage.last,
          'summary': {
            'fahrzeit_seconds': 8 * 3600 + 25 * 60,
            'arbeitszeit_seconds': 131 * 3600 + 40 * 60,
            'wartezeit_seconds': 4 * 3600 + 5 * 60,
            'gesamt_seconds': 144 * 3600 + 10 * 60,
          },
          'daily': [
            for (final (i, tag) in tage.indexed)
              {'date': tag, 'total_seconds': (i + 15) * 3600 + i * 7 * 60},
          ],
          'running_seconds': 1800,
          'max_weekly_seconds': 40 * 3600,
        });
      }
      return _json({'success': false, 'message': 'test'});
    });

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
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // ApiService schickt ohne registriertes Gerät gar nichts ab — der
    // Geräteschlüssel kommt wie in der App aus dem sicheren Speicher.
    FlutterSecureStorage.setMockInitialValues({'device_key': 'test-geraet'});
    await DeviceKeyService().loadStoredDeviceKey();
    ApiService().testClient = _server();
    TicketService().testClient = _server();
  });

  group('Statistik mit Daten', () {
    for (final sprache in kSprachen) {
      for (final fall in kBreiten.entries) {
        testWidgets('läuft mit Daten nicht über — ${fall.key} [$sprache]',
            (tester) async {
          tester.view.physicalSize = fall.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          await LanguageService.instance.setLanguage(sprache);

          final ueberlaeufe = <String>[];
          final andere = <String>[];
          final vorher = FlutterError.onError;
          FlutterError.onError = (details) {
            final text = details.toString();
            final m = RegExp(r'overflowed by ([0-9.]+) pixels on the (\w+)')
                .firstMatch(text);
            if (m == null) {
              andere.add(details.exceptionAsString().split('\n').first);
              return;
            }
            final ort = RegExp(r'lib/[\w/]+\.dart:\d+').firstMatch(text);
            ueberlaeufe.add(
                '${m.group(1)} px ${m.group(2)} @ ${ort?.group(0) ?? '?'}');
          };
          try {
            await tester.pumpWidget(_rahmen(
                StatistikScreen(
                  apiService: ApiService(),
                  users: _mitglieder,
                  currentMitgliedernummer: 'S12345',
                ),
                sprache));
            for (var i = 0; i < 5; i++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
          } finally {
            FlutterError.onError = vorher;
          }

          // Die Daten sind wirklich angekommen (sonst prüfte der Test nur
          // wieder den leeren Zustand).
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(find.text('2456789.50 €'), findsOneWidget);
          expect(find.text('1234567.89 €'), findsOneWidget);
          expect(find.text(sprache == 'de' ? 'KW 40' : 'Săpt. 40'),
              findsOneWidget);
          expect(find.text(sprache == 'de' ? 'Limit' : 'Limită'),
              findsOneWidget);
          expect(find.text('144h 40m'), findsOneWidget);
          expect(find.text('04.10.'), findsOneWidget);
          expect(
              find.text(sprache == 'de'
                  ? 'Fördermitglieder'
                  : 'Membri susținători'),
              findsOneWidget);

          expect(ueberlaeufe, isEmpty,
              reason: 'Statistik auf ${fall.key} [$sprache]:\n'
                  '${ueberlaeufe.toSet().join('\n')}');
          expect(andere, isEmpty,
              reason: 'Statistik auf ${fall.key} [$sprache]:\n'
                  '${andere.toSet().join('\n')}');
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }, skip: _schriftenDa ? false : 'Roboto fehlt unter $_schriften');
}
