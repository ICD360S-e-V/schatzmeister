// Finanzamt MIT Daten auf Telefon, Tablet und Schreibtisch.
//
// bildschirme_telefon_test.dart sieht den Bildschirm nur leer („Keine
// Finanzamt-Daten“). Die drei Karten (Kontakt, Steuernummer/Zuständiger,
// Dokumente) entstehen erst mit Serverdaten — und genau die standen
// nebeneinander und waren auf dem Telefon kaum 60 dp breit. Hier kommen
// lange, echte Werte vom vorgetäuschten Server, dazu der Hochlade-Dialog mit
// den langen rumänischen Kategorien. Gemessen mit Roboto, wie dort.
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:icd360sev_schatzmeister/l10n/app_localizations.dart';
import 'package:icd360sev_schatzmeister/screens/finanzamt_screen.dart';
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

/// Der Server, wie FinanzamtScreen ihn liest: Finanzamt-Eintrag (Notizen
/// zeilenweise „Schlüssel: Wert“), Vorstand, Dokumentenliste.
http.Client _server({required bool mitDokumenten}) => MockClient((anfrage) async {
      final pfad = anfrage.url.path;
      if (pfad.endsWith('/vereinverwaltung/get.php')) {
        return _json({
          'success': true,
          'data': [
            {
              'kategorie': 'finanzamt',
              'name': 'Finanzamt Neu-Ulm mit Außenstelle Illertissen',
              'name2': 'Körperschaftsteuerstelle für gemeinnützige Vereine und Stiftungen',
              'strasse': 'Nelsonallee',
              'hausnummer': '5',
              'plz': '89231',
              'ort': 'Neu-Ulm',
              'telefon': '+49 731 7045-0',
              'fax': '+49 731 7045-500',
              'email': 'poststelle.fa-nu@finanzamt.bayern.de',
              'website': 'https://www.finanzamt.bayern.de/Neu-Ulm/',
              'notizen': 'Steuernummer: 151/123/45678\n'
                  'Gemeinnützigkeit: anerkannt\n'
                  'Öffnungszeiten: Mo–Mi 7:30–15:00 Uhr, Do 7:30–17:30 Uhr, Fr 7:30–12:00 Uhr\n'
                  'Service-Center: 0731 7045-0 (Mo–Do 7:30–17:00 Uhr)',
            },
          ],
        });
      }
      if (pfad.endsWith('/vereinverwaltung/board_members.php')) {
        return _json({
          'success': true,
          'data': {
            'users': [
              {
                'role': 'vorsitzer',
                'status': 'active',
                'vorname': 'Maximilian-Alexander',
                'nachname': 'Schönberger-Constantinescu',
                'mitgliedernummer': 'V00001',
              },
            ],
          },
        });
      }
      if (pfad.endsWith('/admin/finanzamt/dokumente.php')) {
        return _json({
          'success': true,
          'data': {
            'dokumente': !mitDokumenten
                ? []
                : [
                    {
                      'id': 1,
                      'original_name':
                          'Freistellungsbescheid_2025_Finanzamt_Neu-Ulm_Koerperschaftsteuer_ICD360S.pdf',
                      'kategorie': 'freistellungsbescheid',
                      'beschreibung':
                          'Freistellungsbescheid vom 15.01.2026 für die Jahre 2022 bis 2024, Anlage zur Satzungsprüfung nach § 60a AO',
                      'created_at': '2026-01-15 10:12:00',
                    },
                    {
                      'id': 2,
                      'original_name': 'Schreiben_Gemeinnuetzigkeit.png',
                      'kategorie': 'gemeinnuetzigkeit',
                      'beschreibung': '',
                      'created_at': '2026-02-03 08:00:00',
                    },
                    {
                      'id': '3',
                      'original_name': 'Steuerbescheid_2024.docx',
                      'kategorie': 'steuerbescheid',
                      'beschreibung': 'Bescheid über Körperschaftsteuer und Solidaritätszuschlag',
                      'created_at': '2026-03-20 14:30:00',
                    },
                    {
                      'id': 4,
                      'original_name': 'Korrespondenz_Rueckfrage_Zuwendungsbestaetigungen.tiff',
                      'kategorie': 'korrespondenz',
                      'beschreibung': 'Rückfrage zu Zuwendungsbestätigungen',
                      'created_at': '2026-04-01 09:45:00',
                    },
                  ],
          },
        });
      }
      return _json({'success': false, 'message': 'unbekannt: $pfad'});
    });

/// Dateiauswahl ohne Plattform: liefert eine Datei mit langem Namen.
class _Auswahl extends FilePicker {
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async =>
      FilePickerResult([
        PlatformFile(
          name: 'Bescheid_ueber_die_Feststellung_der_Einhaltung_der_satzungsmaessigen_Voraussetzungen.pdf',
          path: '/tmp/bescheid.pdf',
          size: 245760,
        ),
      ]);
}

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

/// Rendert die Ansicht, lässt alle Listen durchlaufen, führt [schritte] aus
/// und liefert jeden Überlauf mit der Zeile im Code.
Future<List<String>> _pruefe(
  WidgetTester tester,
  Size groesse,
  String sprache,
  Widget bildschirm, [
  Future<void> Function()? schritte,
]) async {
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
    await _durchscrollen(tester);
    if (schritte != null) await schritte();
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

  group('Finanzamt mit Daten', () {
    for (final sprache in ['de', 'ro']) {
      for (final fall in kBreiten.entries) {
        testWidgets('Karten mit Dokumenten — ${fall.key} [$sprache]', (tester) async {
          ApiService().testClient = _server(mitDokumenten: true);
          final gesehen = <String>[];
          final fehler = await _pruefe(tester, fall.value, sprache,
              FinanzamtScreen(apiService: ApiService(), onBack: () {}), () async {
            // Erst wenn die gelieferten Daten wirklich dastehen, zählt der Test.
            for (final wert in [
              'Finanzamt Neu-Ulm mit Außenstelle Illertissen',
              '151/123/45678',
              'Maximilian-Alexander Schönberger-Constantinescu',
              'Steuerbescheid_2024.docx',
              'Korrespondenz_Rueckfrage_Zuwendungsbestaetigungen.tiff',
            ]) {
              await _zeigen(tester, find.text(wert));
              if (find.text(wert).evaluate().isNotEmpty) gesehen.add(wert);
            }
          });
          expect(gesehen, hasLength(5), reason: 'alle gelieferten Daten müssen zu sehen sein: $gesehen');
          expect(fehler, isEmpty, reason: '${fall.key} [$sprache]:\n${fehler.join('\n')}');
        });

        testWidgets('ohne Dokumente — ${fall.key} [$sprache]', (tester) async {
          ApiService().testClient = _server(mitDokumenten: false);
          var daten = false;
          final fehler = await _pruefe(tester, fall.value, sprache,
              FinanzamtScreen(apiService: ApiService(), onBack: () {}), () async {
            final name = find.text('Finanzamt Neu-Ulm mit Außenstelle Illertissen').evaluate().isNotEmpty;
            final leer = find.text(sprache == 'de'
                ? 'Noch keine Dokumente\nhochgeladen'
                : 'Niciun document\nîncărcat încă');
            await _zeigen(tester, leer);
            daten = name && leer.evaluate().isNotEmpty;
          });
          expect(daten, isTrue, reason: 'Daten und der leere Dokumentenbereich müssen zu sehen sein');
          expect(fehler, isEmpty, reason: '${fall.key} [$sprache]:\n${fehler.join('\n')}');
        });

        testWidgets('Hochlade-Dialog mit Kategorienliste — ${fall.key} [$sprache]', (tester) async {
          ApiService().testClient = _server(mitDokumenten: true);
          FilePicker.platform = _Auswahl();
          var dialogDa = false;
          var listeOffen = false;
          final fehler = await _pruefe(tester, fall.value, sprache,
              FinanzamtScreen(apiService: ApiService(), onBack: () {}), () async {
            final hochladen = find.byIcon(Icons.upload_file);
            await _zeigen(tester, hochladen);
            await tester.tap(hochladen.first);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            dialogDa = find.byType(AlertDialog).evaluate().isNotEmpty &&
                find.textContaining('Bescheid_ueber_die_Feststellung').evaluate().isNotEmpty;
            // Kategorienliste aufklappen (die langen rumänischen Namen).
            await tester.tap(find.byWidgetPredicate((w) => w is DropdownButtonFormField<String>));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            listeOffen = find.text(sprache == 'de' ? 'Korrespondenz' : 'Corespondență').evaluate().isNotEmpty;
          });
          expect(dialogDa, isTrue, reason: 'der Hochlade-Dialog muss aufgehen');
          expect(listeOffen, isTrue, reason: 'die Kategorienliste muss aufgehen');
          expect(fehler, isEmpty, reason: '${fall.key} [$sprache]:\n${fehler.join('\n')}');
        });
      }
    }
  }, skip: _schriftenDa ? false : 'Roboto fehlt unter $_schriften');
}
