// Vereinregister MIT Daten auf Telefon, Tablet und Schreibtisch.
//
// bildschirme_telefon_test.dart sieht nur den leeren Bildschirm. Erst mit
// Serverdaten erscheinen die Registernummer in der Kopfzeile, die Karte des
// Amtsgerichts, die Vereinsdaten — und der Dialog „Vereineinstellungen“ mit
// zwei Spalten Eingabefeldern. Hier kommen lange, echte Werte vom
// vorgetäuschten Server; gemessen mit Roboto, wie dort.
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
import 'package:icd360sev_schatzmeister/screens/vereinregister_screen.dart';
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

const _vereinsname =
    'ICD360S e.V. – Internationale Gemeinschaft für Digitalisierung und soziale Teilhabe';

/// Der Server, wie VereinregisterScreen ihn liest: Registergericht
/// (kategorie=behoerde) und die Vereineinstellungen.
http.Client _server({required bool mitVereinsdaten}) => MockClient((anfrage) async {
      final pfad = anfrage.url.path;
      if (pfad.endsWith('/vereinverwaltung/get.php')) {
        return _json({
          'success': true,
          'data': [
            {
              'kategorie': 'behoerde',
              'name': 'Amtsgericht Memmingen – Registergericht für den Landgerichtsbezirk Memmingen',
              'name2': 'Vereinsregister, Abteilung für Registersachen',
              'strasse': 'Hallhof',
              'hausnummer': '1',
              'plz': '87700',
              'ort': 'Memmingen',
              'telefon': '+49 8331 105-0',
              'fax': '+49 8331 105-200',
              'email': 'poststelle-registergericht@ag-mm.bayern.de',
              'website': 'https://www.justiz.bayern.de/gerichte-und-behoerden/amtsgerichte/memmingen/',
            },
          ],
        });
      }
      if (pfad.endsWith('/schatzmeister/finanzen/einstellungen.php')) {
        return _json({
          'success': true,
          'data': mitVereinsdaten
              ? {
                  'vereinsname': _vereinsname,
                  'adresse': 'Bahnhofstraße 117a, Hinterhaus, 3. Obergeschoss, 89231 Neu-Ulm',
                  'telefon_fix': '+49 731 98765432',
                  'fax': '+49 731 98765433',
                  'mobil': '+49 151 23456789',
                  'email': 'vorstand-und-geschaeftsstelle@icd360s.de',
                  'gruendungsdatum': '01.01.2025',
                  'registernummer': 'VR 201335',
                  'registergericht': 'Amtsgericht Memmingen, Bayern',
                }
              : {
                  'vereinsname': '',
                  'registernummer': 'VR 201335',
                  'registergericht': 'Amtsgericht Memmingen, Bayern',
                },
        });
      }
      return _json({'success': false, 'message': 'unbekannt: $pfad'});
    });

/// Scrollt die äußere Liste, bis [ziel] gebaut ist, und holt es ins Bild.
Future<void> _zeigen(WidgetTester tester, Finder ziel) async {
  final liste = find
      .byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down)
      .first;
  for (var i = 0; i < 30 && ziel.evaluate().isEmpty; i++) {
    await tester.drag(liste, const Offset(0, -200));
    await tester.pump();
  }
  if (ziel.evaluate().isEmpty) return; // die Prüfung danach sagt, was fehlt
  await tester.ensureVisible(ziel.first);
  await tester.pump();
}

/// Rendert die Ansicht, führt [schritte] aus und liefert jeden Überlauf mit
/// der Zeile im Code.
Future<List<String>> _pruefe(
  WidgetTester tester,
  Size groesse,
  String sprache,
  Widget bildschirm,
  Future<void> Function() schritte,
) async {
  tester.view.physicalSize = groesse;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await LanguageService.instance.setLanguage(sprache);

  final ueberlaeufe = <String>[];
  final vorher = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.toString();
    final m = RegExp(r'overflowed by ([0-9.]+) pixels on the (\w+)').firstMatch(text);
    if (m == null) {
      vorher?.call(details);
      return;
    }
    final ort = RegExp(r'lib/[\w/]+\.dart:\d+').firstMatch(text);
    ueberlaeufe.add('${m.group(1)} px ${m.group(2)} @ ${ort?.group(0) ?? '?'}');
  };
  try {
    await tester.pumpWidget(_rahmen(bildschirm, sprache));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await schritte();
  } finally {
    FlutterError.onError = vorher;
  }
  await tester.pumpWidget(const SizedBox());
  return ueberlaeufe.toSet().toList();
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

  group('Vereinregister mit Daten', () {
    for (final sprache in ['de', 'ro']) {
      for (final fall in kBreiten.entries) {
        testWidgets('Gericht, Vereinsdaten und Einstellungen-Dialog — ${fall.key} [$sprache]',
            (tester) async {
          ApiService().testClient = _server(mitVereinsdaten: true);
          final gesehen = <String>[];
          var dialogFelder = 0;
          final fehler = await _pruefe(tester, fall.value, sprache,
              VereinregisterScreen(apiService: ApiService(), onBack: () {}), () async {
            // Erst wenn die gelieferten Daten wirklich dastehen, zählt der Test.
            for (final wert in [
              'Amtsgericht Memmingen – Registergericht für den Landgerichtsbezirk Memmingen',
              'Bahnhofstraße 117a, Hinterhaus, 3. Obergeschoss, 89231 Neu-Ulm',
              'vorstand-und-geschaeftsstelle@icd360s.de',
              '01.01.2025',
            ]) {
              await _zeigen(tester, find.text(wert));
              if (find.text(wert).evaluate().isNotEmpty) gesehen.add(wert);
            }
            // Registernummer in der Kopfzeile, Vereinsname im Kasten und in der Karte.
            if (find.text('VR 201335').evaluate().isNotEmpty) gesehen.add('VR 201335');
            // Einstellungen-Dialog über den Stift der Vereinsdaten-Karte.
            final stift = find.byIcon(Icons.edit);
            await _zeigen(tester, stift);
            await tester.tap(stift.first);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            dialogFelder = find
                .descendant(of: find.byType(AlertDialog), matching: find.byType(TextField))
                .evaluate()
                .length;
          });
          expect(gesehen, hasLength(5), reason: 'alle gelieferten Daten müssen zu sehen sein: $gesehen');
          expect(dialogFelder, 9, reason: 'der Dialog muss mit allen neun Feldern aufgehen');
          expect(fehler, isEmpty, reason: '${fall.key} [$sprache]:\n${fehler.join('\n')}');
        });

        testWidgets('ohne Vereinsdaten: Hinweis-Karte und Dialog — ${fall.key} [$sprache]',
            (tester) async {
          ApiService().testClient = _server(mitVereinsdaten: false);
          var gericht = false;
          var dialogFelder = 0;
          final fehler = await _pruefe(tester, fall.value, sprache,
              VereinregisterScreen(apiService: ApiService(), onBack: () {}), () async {
            gericht = find
                .text('Amtsgericht Memmingen – Registergericht für den Landgerichtsbezirk Memmingen')
                .evaluate()
                .isNotEmpty;
            final hinweis = find.text(sprache == 'de' ? 'Vereinsdaten hinzufügen' : 'Adăugați date asociație');
            await _zeigen(tester, hinweis);
            await tester.tap(hinweis.first);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            dialogFelder = find
                .descendant(of: find.byType(AlertDialog), matching: find.byType(TextField))
                .evaluate()
                .length;
          });
          expect(gericht, isTrue, reason: 'die Daten des Gerichts müssen zu sehen sein');
          expect(dialogFelder, 9, reason: 'der Dialog muss mit allen neun Feldern aufgehen');
          expect(fehler, isEmpty, reason: '${fall.key} [$sprache]:\n${fehler.join('\n')}');
        });
      }
    }
  }, skip: _schriftenDa ? false : 'Roboto fehlt unter $_schriften');
}
