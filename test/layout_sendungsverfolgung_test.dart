// Sendungsverfolgung mit echten Sendungen: passt die Liste — und passen ihre
// Dialoge — auf jedes Telefon?
//
// Der gemeinsame Test (bildschirme_telefon_test.dart) sieht die Liste nur
// leer. Hier liefert ein MockClient vier Sendungen wie tracking/dhl.php (lange
// Beschreibungen, lange Statustexte, eine ohne Beschreibung, eine noch nie
// abgefragt), eine lange Fehlermeldung der DHL-Prüfung, einen Sendungsverlauf
// und die Portal-Zugangsdaten. Geprüft werden die Liste, jeder Dialog und die
// Deutsche Post, die die Liste als Unteransicht zeigt und danach Anzahl und
// API-Status auf ihrer Karte — auf 320 bis 1280 dp, Deutsch und Rumänisch,
// mit der echten Schrift (Roboto).
//
// Anders als der gemeinsame Test zählt hier JEDER Fehler beim Aufbau, nicht
// nur ein Überlauf.
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
import 'package:icd360sev_schatzmeister/screens/deutschepost_screen.dart';
import 'package:icd360sev_schatzmeister/screens/sendungsverfolgung.dart';
import 'package:icd360sev_schatzmeister/services/api_service.dart';
import 'package:icd360sev_schatzmeister/services/device_key_service.dart';
import 'package:icd360sev_schatzmeister/services/language_service.dart';

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

/// Die Nummer, mit der die Ansicht beim Start die DHL-API prüft.
const _pruefNummer = '00340434161094042557';

const _beschreibung1 =
    'Kündigungsschutzklage an das Arbeitsgericht Ulm, Kammern Neu-Ulm (Einschreiben mit Rückschein)';
const _status1 = 'Die Sendung wurde im Start-Paketzentrum bearbeitet. - Paketzentrum Günzburg';
const _portalMail = 'schatzmeisterin.icd360s-ev@beispiel-verein-neu-ulm.de';

List<Map<String, dynamic>> _sendungen() {
  final jetzt = DateTime.now().toIso8601String();
  return [
    {
      'id': 1,
      'tracking_number': 'JJD000390007882935154',
      'beschreibung': _beschreibung1,
      'last_status': 'transit',
      'last_status_text': _status1,
      'last_checked': jetzt,
      'created_at': '2026-09-28 09:14:55',
    },
    {
      'id': 2,
      'tracking_number': '00340434518273645091',
      'beschreibung': null,
      'last_status': 'delivered',
      'last_status_text': 'Zugestellt - Die Sendung wurde dem Empfänger am 30.09.2026 erfolgreich zugestellt',
      'last_checked': jetzt,
      'created_at': '2026-09-25 16:02:11',
    },
    {
      'id': 3,
      'tracking_number': 'RR123456785DE',
      'beschreibung': 'Antrag auf Erwerbsminderungsrente – Deutsche Rentenversicherung Schwaben',
      'last_status': null,
      'last_status_text': null,
      'last_checked': null,
      'created_at': '2026-10-02 08:30:00',
    },
    {
      'id': 4,
      'tracking_number': 'CD987654321DE',
      'beschreibung': 'Widerspruch gegen den Bescheid des Jobcenters Neu-Ulm vom 12.09.2026',
      'last_status': 'failure',
      'last_status_text': 'Zustellung fehlgeschlagen - Empfänger nicht angetroffen, Benachrichtigungskarte hinterlassen',
      'last_checked': jetzt,
      'created_at': '2026-09-20 11:45:37',
    },
  ];
}

Map<String, dynamic> _verlauf(String nummer) => {
      'trackingNumber': nummer,
      'status': 'transit',
      'statusText': 'In Zustellung',
      'description': 'Die Sendung wurde in das Zustellfahrzeug geladen. Die Zustellung erfolgt voraussichtlich heute zwischen 10:30 und 14:00 Uhr.',
      'location': 'Zustellbasis Neu-Ulm, Deutschland',
      'timestamp': '2026-10-02T08:12:00+02:00',
      'productName': 'DHL Paket International Premium mit Sendungsverfolgung',
      'events': [
        for (final (zeit, text, ort) in [
          ('2026-10-02T08:12:00', 'Die Sendung wurde in das Zustellfahrzeug geladen.', 'Zustellbasis Neu-Ulm, Deutschland'),
          ('2026-10-01T22:40:00', 'Die Sendung wurde im Ziel-Paketzentrum bearbeitet.', 'Paketzentrum Günzburg, Deutschland'),
          ('2026-10-01T15:03:00', 'Die Sendung wurde im Start-Paketzentrum bearbeitet.', 'Paketzentrum Aschheim bei München, Deutschland'),
          ('2026-10-01T11:27:00', 'Die Sendung wurde vom Absender in der Filiale eingeliefert.', 'Postfiliale 512 Neu-Ulm, Bahnhofstraße 1'),
          ('2026-09-30T18:00:00', 'Die Auftragsdaten zu dieser Sendung wurden vom Absender elektronisch an DHL übermittelt.', ''),
        ])
          {'timestamp': zeit, 'statusCode': 'transit', 'status': text, 'description': text, 'location': ort},
      ],
    };

http.Response _json(Object daten) => http.Response(
      jsonEncode(daten),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// Antwortet wie tracking/dhl.php und tracking/dhl_settings.php.
http.Client _server() => MockClient((anfrage) async {
      final pfad = anfrage.url.path;
      final q = anfrage.url.queryParameters;
      if (pfad.endsWith('/tracking/dhl.php') && q['action'] == 'list') {
        return _json({'success': true, 'data': _sendungen()});
      }
      if (pfad.endsWith('/tracking/dhl.php') && q['action'] == 'track') {
        if (q['number'] == _pruefNummer) {
          // Lange Fehlermeldung: steht in der Status-Pille und auf der Karte
          // der Deutschen Post.
          return _json({
            'success': false,
            'message': 'DHL API: Ungültige Antwort vom Server (HTTP 503 Service Unavailable) – bitte später erneut versuchen',
          });
        }
        return _json({'success': true, 'tracking': [_verlauf(q['number']!)]});
      }
      if (pfad.endsWith('/tracking/dhl_settings.php')) {
        return _json({
          'success': true,
          'data': {
            'email': _portalMail,
            'password': 'Sehr-langes-Passwort-fuer-das-DHL-Portal-2026!',
          },
        });
      }
      return _json({'success': false, 'message': 'test'});
    });

/// Führt [ablauf] aus und gibt jeden Fehler zurück, den Flutter dabei
/// meldet — Überläufe mit der Zeile im Code, die ihn verursacht.
Future<List<String>> _fehlerBei(WidgetTester tester, Future<void> Function() ablauf) async {
  final fehler = <String>[];
  final vorher = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.toString();
    final ort = RegExp(r'lib/[\w/]+\.dart:\d+').firstMatch(text)?.group(0) ?? '?';
    final m = RegExp(r'overflowed by ([0-9.]+) pixels on the (\w+)').firstMatch(text);
    fehler.add(m != null
        ? '${m.group(1)} px ${m.group(2)} @ $ort'
        : '${details.exceptionAsString().split('\n').first} @ $ort');
  };
  try {
    await ablauf();
  } finally {
    FlutterError.onError = vorher;
  }
  return fehler;
}

Future<void> _warten(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Pumpt, bis [ziel] auf dem Bildschirm steht (höchstens 3 s), und verlangt es
/// dann: Übersetzungen und Antworten kommen asynchron, und ein Test darf nie
/// auf einem leeren Bildschirm grün werden.
Future<void> _bisSichtbar(WidgetTester tester, Finder ziel) async {
  for (var i = 0; i < 30 && ziel.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(ziel, findsWidgets);
}

Future<void> _tippen(WidgetTester tester, Finder ziel) async {
  await tester.ensureVisible(ziel);
  await tester.pump();
  await tester.tap(ziel);
  await _warten(tester);
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
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // Ohne Geräteschlüssel wirft ApiService vor jeder Anfrage.
    FlutterSecureStorage.setMockInitialValues({'device_key': 'TEST-GERAET'});
    await DeviceKeyService().loadStoredDeviceKey();
    ApiService().testClient = _server();
  });

  for (final sprache in kSprachen) {
    for (final fall in kBreiten.entries) {
      group('Sendungen ${fall.key} [$sprache]', () {
        Future<void> aufbauen(WidgetTester tester, Widget bildschirm) async {
          tester.view.physicalSize = fall.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          await LanguageService.instance.setLanguage(sprache);
          await tester.pumpWidget(_rahmen(bildschirm, sprache));
          await _warten(tester);
        }

        /// Baut die Sendungsliste auf und führt danach [weiter] aus.
        Future<void> liste(WidgetTester tester, [Future<void> Function()? weiter]) async {
          final fehler = await _fehlerBei(tester, () async {
            await aufbauen(tester, SendungsverfolgungView(apiService: ApiService()));
            // Die Liste ist wirklich da (sonst prüfte der Test nur „leer"),
            // ebenso die lange Fehlermeldung der DHL-Prüfung in der Pille.
            await _bisSichtbar(tester, find.text(_beschreibung1));
            await _bisSichtbar(tester, find.textContaining('HTTP 503'));
            expect(find.byType(ListTile), findsNWidgets(4));
            if (weiter != null) await weiter();
          });
          await tester.pumpWidget(const SizedBox());
          expect(fehler, isEmpty, reason: fehler.toSet().join('\n'));
        }

        testWidgets('Liste', (tester) => liste(tester));

        testWidgets('Dialog Sendungsdetails', (tester) => liste(tester, () async {
              await _tippen(tester, find.byType(ListTile).first);
              expect(find.byType(AlertDialog), findsOneWidget);
              // Der volle Statustext steht nur im Dialog (die Liste kürzt ihn).
              await _bisSichtbar(tester, find.text(_status1));
            }));

        testWidgets('Dialog Sendungsverlauf', (tester) => liste(tester, () async {
              await _tippen(tester, find.byIcon(Icons.refresh).first);
              await _bisSichtbar(tester, find.textContaining('DHL Paket International Premium'));
              await _bisSichtbar(tester, find.text('Die Sendung wurde in das Zustellfahrzeug geladen.'));
              expect(find.byType(AlertDialog), findsOneWidget);
            }));

        testWidgets('Dialog Sendung hinzufügen', (tester) => liste(tester, () async {
              await _tippen(tester, find.byIcon(Icons.add_circle_outline));
              expect(find.byType(AlertDialog), findsOneWidget);
            }));

        testWidgets('Dialog DHL-Portal', (tester) => liste(tester, () async {
              await _tippen(tester, find.byIcon(Icons.settings));
              await _bisSichtbar(tester, find.text(_portalMail));
              expect(find.byType(AlertDialog), findsOneWidget);
            }));

        testWidgets('Deutsche Post: Übersicht, Sendungen, zurück', (tester) async {
          final fehler = await _fehlerBei(tester, () async {
            await aufbauen(tester, DeutschePostScreen(apiService: ApiService(), onBack: () {}));
            await _bisSichtbar(tester, find.byIcon(Icons.track_changes));
            await _tippen(tester, find.byIcon(Icons.track_changes).first);
            await _bisSichtbar(tester, find.text(_beschreibung1));
            expect(find.byType(ListTile), findsNWidgets(4));
            // Zurück zur Übersicht: die Karte zeigt jetzt Anzahl und Status.
            await _tippen(tester, find.byIcon(Icons.arrow_back).first);
            await _bisSichtbar(tester, find.text('4'));
            await _bisSichtbar(tester, find.textContaining('HTTP 503'));
          });
          await tester.pumpWidget(const SizedBox());
          expect(fehler, isEmpty, reason: fehler.toSet().join('\n'));
        });
      }, skip: _schriftenDa ? false : 'Roboto fehlt unter $_schriften');
    }
  }
}
