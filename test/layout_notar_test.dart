// Passt der Notar MIT DATEN auf jedes Telefon?
//
// Der Bildschirm stellte sechs Karten — Notardaten, Rechnungen, Besuche,
// Dokumente, Zahlungen, Aufgaben — in zwei Reihen zu je drei nebeneinander.
// Ohne Daten lief nichts über (test/bildschirme_telefon_test.dart), aber
// auf dem Telefon blieben jeder Karte ~100 dp: Namen, Rechnungsnummern und
// Termine waren nicht mehr zu lesen.
//
// Hier antwortet ein Testserver (ApiService().testClient) mit einem Notar
// mit langem Namen und vollständigen Kontaktdaten und mit Einträgen für
// jede Karte. Geprüft wird auf jeder Breite in beiden Sprachen, die Seite
// ganz durchgerollt: kein Überlauf, kein Wort mitten im Wort zerrissen,
// und von jeder Karte war der gelieferte Eintrag zu sehen.
//
// ⚠️ Mit der echten Schrift (Roboto) — die Testschrift zeichnet jede Glyphe
// als 1-em-Quadrat und macht Texte viel breiter als auf dem Gerät.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:icd360sev_schatzmeister/l10n/app_localizations.dart';
import 'package:icd360sev_schatzmeister/services/api_service.dart';
import 'package:icd360sev_schatzmeister/services/device_key_service.dart';
import 'package:icd360sev_schatzmeister/services/language_service.dart';
import 'package:icd360sev_schatzmeister/screens/notar_screen.dart';

/// Android-Telefone, die Grenze zum Tablet, Tablet und Schreibtisch.
const Map<String, Size> kBreiten = {
  '320 dp': Size(320, 640),
  '360 dp': Size(360, 800),
  '393 dp (Redmi)': Size(393, 873),
  '412 dp': Size(412, 915),
  '600 dp': Size(600, 960),
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

/// Was die Notar-Schnittstellen liefern — so geformt, wie notar_screen.dart
/// und die Karten es lesen.
final Map<String, Map<String, dynamic>> _antworten = {
  'get.php': {
    'success': true,
    'data': [
      {
        'id': 7,
        'name': 'Notariat Dr. Maximilian von Hohenzollern-Sigmaringen & Kollegen',
        'name2': 'Notar und Fachanwalt für Gesellschaftsrecht',
        'strasse': 'Maximilianstraße',
        'hausnummer': '35a',
        'plz': '89231',
        'ort': 'Neu-Ulm',
        'telefon': '+49 731 123456-789',
        'fax': '+49 731 123456-799',
        'email': 'kanzlei@notariat-hohenzollern-sigmaringen.de',
        'website': 'https://www.notariat-hohenzollern-sigmaringen.de/termine',
        'notizen': 'Termine nur nach Vereinbarung; Anmeldungen zum Vereinsregister bitte zwei Wochen vorher ankündigen.',
      },
    ],
  },
  'rechnungen.php': {
    'success': true,
    'data': [
      {'rechnungsnummer': 'RE-2026-000417', 'datum': '2026-09-15', 'betrag': 1234.56, 'bezahlt': false},
      {'rechnungsnummer': 'RE-2026-000388', 'datum': '2026-07-02', 'betrag': 89.25, 'bezahlt': true},
    ],
  },
  'besuche.php': {
    'success': true,
    'data': [
      {'zweck': 'Beglaubigung der Satzungsänderung zur Eintragung ins Vereinsregister', 'datum': '2026-10-14', 'uhrzeit': '10:30', 'status': 'geplant'},
      {'zweck': 'Vorbesprechung Satzung', 'datum': '2026-09-01', 'uhrzeit': '14:00', 'status': 'abgeschlossen'},
    ],
  },
  'dokumente.php': {
    'success': true,
    'data': [
      {'titel': 'Beglaubigte Abschrift der Satzung (Fassung vom 12.09.2026)', 'datum': '2026-09-20', 'typ': 'satzung'},
      {'titel': 'Vollmacht Vorstand', 'datum': '2026-09-20', 'typ': 'vollmacht'},
    ],
  },
  'zahlungen.php': {
    'success': true,
    'data': [
      {'verwendungszweck': 'Notarkosten Satzungsänderung RE-2026-000417', 'datum': '2026-09-30', 'betrag': 1234.56, 'zahlungsart': 'ueberweisung'},
    ],
  },
  'aufgaben.php': {
    'success': true,
    'data': [
      {'beschreibung': 'Unterschriftsbeglaubigung für die Anmeldung zum Vereinsregister vorbereiten', 'datum': '2026-10-10', 'uhrzeit': '09:00', 'status': 'offen'},
      {'beschreibung': 'Protokoll der Mitgliederversammlung beilegen', 'datum': '2026-10-01', 'status': 'erledigt'},
    ],
  },
};

/// Testserver für den Notar.
http.Client notarServer() => MockClient((anfrage) async {
      final datei = anfrage.url.pathSegments.last;
      final antwort =
          _antworten[datei] ?? {'success': false, 'message': 'unbekannt: $datei'};
      return http.Response(jsonEncode(antwort), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });

/// Sammelt, was Flutter während [aktion] meldet: Überläufe mit der
/// Codezeile, die sie verursacht, und jeden anderen Fehler mit seiner
/// ersten Zeile.
Future<List<String>> _ueberlaeufe(Future<void> Function() aktion) async {
  final funde = <String>[];
  final vorher = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.toString();
    final ort = RegExp(r'lib/[\w/]+\.dart:\d+').firstMatch(text)?.group(0) ?? '?';
    final m = RegExp(r'overflowed by ([0-9.]+) pixels on the (\w+)')
        .firstMatch(text);
    if (m != null) {
      funde.add('Überlauf ${m.group(1)} px ${m.group(2)} @ $ort');
    } else {
      funde.add('Fehler „${details.exceptionAsString().split('\n').first}“ @ $ort');
    }
  };
  try {
    await aktion();
  } finally {
    FlutterError.onError = vorher;
  }
  return funde;
}

/// Wörter, die mitten im Wort auf zwei Zeilen zerrissen sind — das Zeichen
/// einer zu schmalen Spalte. Ein Umbruch nach einem Bindestrich oder
/// Schrägstrich ist erlaubt: geprüft werden nur Folgen aus Buchstaben und
/// Ziffern.
List<String> _wortbrueche() {
  final funde = <String>[];
  final wort = RegExp(r'[\p{L}\p{N}]+', unicode: true);
  for (final e in find.byType(RichText).evaluate()) {
    final p = e.renderObject;
    if (p is! RenderParagraph || !p.hasSize) continue;
    final text = p.text.toPlainText();
    for (final m in wort.allMatches(text)) {
      final kaesten = p.getBoxesForSelection(
          TextSelection(baseOffset: m.start, extentOffset: m.end));
      if (kaesten.length < 2) continue;
      final erste = kaesten.first;
      if (kaesten.any((k) => k.top >= erste.bottom - 1)) {
        funde.add('„${m.group(0)}“ in „${text.replaceAll('\n', ' ')}“');
      }
    }
  }
  return funde;
}

/// Rollt die Seite Stück für Stück bis ans Ende und ruft an jeder
/// Stelle [pruefen] auf. Liefert alle Texte, die dabei zu sehen waren.
Future<Set<String>> _durchrollen(WidgetTester tester, void Function() pruefen) async {
  final gesehen = <String>{};
  void sammeln() {
    for (final e in find.byType(Text).evaluate()) {
      final daten = (e.widget as Text).data;
      if (daten != null) gesehen.add(daten);
    }
    pruefen();
  }

  sammeln();
  final rollbar = find.byWidgetPredicate((w) =>
      w is Scrollable && axisDirectionToAxis(w.axisDirection) == Axis.vertical);
  if (rollbar.evaluate().isEmpty) return gesehen;
  final position = tester.state<ScrollableState>(rollbar.first).position;
  for (var runde = 0;
      runde < 50 && position.pixels < position.maxScrollExtent - 0.5;
      runde++) {
    position.jumpTo((position.pixels + position.viewportDimension * 0.6)
        .clamp(0.0, position.maxScrollExtent));
    await tester.pumpAndSettle();
    sammeln();
  }
  position.jumpTo(0);
  await tester.pumpAndSettle();
  return gesehen;
}

void main() {
  setUpAll(() async {
    // Ohne Geräteschlüssel wirft ApiService beim Bauen der Kopfzeilen,
    // bevor eine Anfrage den Testserver erreicht.
    FlutterSecureStorage.setMockInitialValues({'device_key': 'test-geraet'});
    await DeviceKeyService().loadStoredDeviceKey();
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
    ApiService().testClient = notarServer();
  });

  group('Notar mit Daten', () {
    for (final sprache in kSprachen) {
      for (final fall in kBreiten.entries) {
        testWidgets('lesbar — ${fall.key} [$sprache]', (tester) async {
          tester.view.physicalSize = fall.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          await LanguageService.instance.setLanguage(sprache);

          final befunde = <String>[];
          void wortbrueche() =>
              befunde.addAll(_wortbrueche().map((w) => 'Wortbruch $w'));
          var gesehen = <String>{};
          final ueber = await _ueberlaeufe(() async {
            await tester.pumpWidget(
                _rahmen(NotarScreen(apiService: ApiService(), onBack: () {}), sprache));
            await tester.pumpAndSettle();
            gesehen = await _durchrollen(tester, wortbrueche);
          });
          befunde.addAll(ueber);
          // Erst wenn die geladenen Daten da sind, ist etwas zu prüfen.
          expect(gesehen, contains(_antworten['get.php']!['data'][0]['name']),
              reason: 'Die Notardaten kamen nicht an');
          for (final text in [
            'RE-2026-000417',
            'Beglaubigung der Satzungsänderung zur Eintragung ins Vereinsregister',
            'Beglaubigte Abschrift der Satzung (Fassung vom 12.09.2026)',
            'Notarkosten Satzungsänderung RE-2026-000417',
            'Unterschriftsbeglaubigung für die Anmeldung zum Vereinsregister vorbereiten',
          ]) {
            if (!gesehen.contains(text)) befunde.add('„$text“ nie zu sehen');
          }

          await tester.pumpWidget(const SizedBox());

          expect(befunde, isEmpty,
              reason: 'Notar auf ${fall.key} [$sprache]:\n'
                  '${befunde.toSet().join('\n')}');
        });
      }
    }
  }, skip: _schriftenDa ? false : 'Roboto fehlt unter $_schriften');
}
