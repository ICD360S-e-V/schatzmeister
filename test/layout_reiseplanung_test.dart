// Passt die Reiseplanung MIT VERBINDUNGEN auf jedes Telefon?
//
// test/bildschirme_telefon_test.dart sieht nur das leere Suchformular. Auf
// dem Telefon war aber schon das kaum zu bedienen: neben Tauschknopf und
// der 180 dp breiten Spalte mit Abfahrt/Ankunft, Uhrzeit und „Suchen“
// blieben den Feldern „Von“ und „Nach“ auf 393 dp gut 100 dp, auf 320 dp
// keine 50. Und die Ergebniskarten stellten Abfahrtsort, Linien und
// Zielort ungebremst in eine Zeile.
//
// Die Reiseplanung holt Bahnhöfe und Verbindungen mit einem eigenen
// http.Client(). `http.runWithClient` ersetzt ihn im Test durch einen
// Testserver — ohne Prüfhaken im Bildschirm. Geprüft wird auf jeder Breite
// in beiden Sprachen: Bahnhofsvorschläge, gefundene Verbindungen, eine
// aufgeklappte Verbindung mit allen Teilstrecken — kein Überlauf, kein Wort
// mitten im Wort zerrissen, und jede gelieferte Verbindung war zu sehen.
//
// ⚠️ Mit der echten Schrift (Roboto) — die Testschrift zeichnet jede Glyphe
// als 1-em-Quadrat und macht Texte viel breiter als auf dem Gerät.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:icd360sev_schatzmeister/l10n/app_localizations.dart';
import 'package:icd360sev_schatzmeister/services/language_service.dart';
import 'package:icd360sev_schatzmeister/screens/reiseplanung_screen.dart';

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

/// Bahnhöfe, wie int.bahn.de sie liefert (`reiseloesung/orte`).
List<Map<String, dynamic>> _orte(String suchbegriff) {
  if (suchbegriff.toLowerCase().startsWith('neu')) {
    return [
      {'type': 'ST', 'extId': '8004246', 'name': 'Neu-Ulm Bahnhof (Bahnhofstraße)', 'lat': 48.3925, 'lon': 10.0056, 'products': ['REGIONAL', 'S', 'BUS']},
      {'type': 'ST', 'extId': '8000170', 'name': 'Ulm Hauptbahnhof', 'lat': 48.3994, 'lon': 9.9829, 'products': ['ICE', 'IC', 'REGIONAL', 'BUS', 'TRAM']},
      {'type': 'ADR', 'extId': '', 'name': 'Neu-Ulm, Augsburger Straße 12', 'lat': 48.39, 'lon': 10.01, 'products': []},
    ];
  }
  return [
    {'type': 'ST', 'extId': '8000261', 'name': 'München Hauptbahnhof (tief)', 'lat': 48.1402, 'lon': 11.5600, 'products': ['ICE', 'IC', 'REGIONAL', 'S', 'U', 'TRAM', 'BUS']},
    {'type': 'ST', 'extId': '8000013', 'name': 'Augsburg Hauptbahnhof', 'lat': 48.3655, 'lon': 10.8855, 'products': ['ICE', 'REGIONAL', 'TRAM']},
  ];
}

/// Eine Teilstrecke, wie Transitous sie liefert (`plan` → `legs`).
Map<String, dynamic> _strecke(String modus, String von, String nach, DateTime ab,
        DateTime an,
        {String? linie, String? richtung, String? gleisAb, String? gleisAn,
        int verspaetung = 0, int? meter}) =>
    {
      'mode': modus,
      'from': {
        'name': von,
        'scheduledDeparture': ab.toIso8601String(),
        'departure': ab.add(Duration(minutes: verspaetung)).toIso8601String(),
        if (gleisAb != null) 'track': gleisAb,
      },
      'to': {
        'name': nach,
        'scheduledArrival': an.toIso8601String(),
        'arrival': an.add(Duration(minutes: verspaetung)).toIso8601String(),
        if (gleisAn != null) 'track': gleisAn,
      },
      if (linie != null) 'routeShortName': linie,
      if (richtung != null) 'headsign': richtung,
      if (meter != null) 'distance': meter,
    };

Map<String, dynamic> _verbindung(DateTime ab, List<Map<String, dynamic>> strecken,
        DateTime an) =>
    {
      'startTime': ab.toIso8601String(),
      'endTime': an.toIso8601String(),
      'legs': strecken,
    };

/// Drei Verbindungen Neu-Ulm → München: mit Fußweg, Verspätung, vier
/// Linien und langen Bahnhofs- und Richtungsnamen.
Map<String, dynamic> _plan() {
  final t = DateTime.utc(2026, 10, 5, 6, 12);
  DateTime m(int minuten) => t.add(Duration(minutes: minuten));
  return {
    'itineraries': [
      _verbindung(m(0), [
        _strecke('WALK', 'Neu-Ulm, Augsburger Straße 12', 'Neu-Ulm Bahnhof (Bahnhofstraße)', m(0), m(9), meter: 650),
        _strecke('REGIONAL_RAIL', 'Neu-Ulm Bahnhof (Bahnhofstraße)', 'Ulm Hauptbahnhof', m(10), m(14),
            linie: 'RB 57042', richtung: 'Ulm Hbf', gleisAb: '2', gleisAn: '25', verspaetung: 4),
        _strecke('HIGHSPEED_RAIL', 'Ulm Hauptbahnhof', 'Augsburg Hauptbahnhof', m(31), m(72),
            linie: 'ICE 597', richtung: 'München Hbf über Günzburg, Augsburg Hbf', gleisAb: '3', gleisAn: '6'),
        _strecke('SUBURBAN', 'Augsburg Hauptbahnhof', 'Augsburg-Oberhausen', m(80), m(86),
            linie: 'S 4', richtung: 'Augsburg-Oberhausen', gleisAb: '1', gleisAn: '2'),
        _strecke('REGIONAL_FAST_RAIL', 'Augsburg-Oberhausen', 'München Hauptbahnhof (tief)', m(95), m(141),
            linie: 'RE 57155', richtung: 'München Hbf (tief) über Mering, Pasing', gleisAb: '4', gleisAn: '27'),
      ], m(141)),
      _verbindung(m(48), [
        _strecke('LONG_DISTANCE', 'Neu-Ulm Bahnhof (Bahnhofstraße)', 'München Hauptbahnhof (tief)', m(48), m(130),
            linie: 'IC 2265', richtung: 'München Hbf', gleisAb: '1', gleisAn: '22'),
      ], m(130)),
      _verbindung(m(75), [
        _strecke('BUS', 'Neu-Ulm Bahnhof (Bahnhofstraße)', 'Ulm Hauptbahnhof', m(75), m(87),
            linie: 'Bus 74', richtung: 'Ulm, Hauptbahnhof/ZOB'),
        _strecke('HIGHSPEED_RAIL', 'Ulm Hauptbahnhof', 'München Hauptbahnhof (tief)', m(95), m(170),
            linie: 'ICE 517', richtung: 'München Hbf'),
      ], m(170)),
    ],
  };
}

/// Testserver für Bahnhofssuche (int.bahn.de) und Verbindungen (Transitous).
http.Client reiseServer() => MockClient((anfrage) async {
      final Object antwort;
      if (anfrage.url.path.endsWith('/reiseloesung/orte')) {
        antwort = _orte(anfrage.url.queryParameters['suchbegriff'] ?? '');
      } else if (anfrage.url.path.endsWith('/plan')) {
        antwort = _plan();
      } else {
        return http.Response('nicht gefunden', 404);
      }
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

/// Rollt die Ergebnisliste Stück für Stück bis ans Ende und ruft an jeder
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
  final position = tester.state<ScrollableState>(rollbar.last).position;
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
    if (!_schriftenDa) return;
    await _laden('Roboto', [
      'Roboto-Regular.ttf',
      'Roboto-Bold.ttf',
      'Roboto-Medium.ttf',
      'Roboto-Italic.ttf',
    ]);
    await _laden('MaterialIcons', ['MaterialIcons-Regular.otf']);
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Reiseplanung mit Verbindungen', () {
    for (final sprache in kSprachen) {
      for (final fall in kBreiten.entries) {
        testWidgets('lesbar — ${fall.key} [$sprache]', (tester) async {
          tester.view.physicalSize = fall.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          await LanguageService.instance.setLanguage(sprache);

          final befunde = <String>[];
          Future<Set<String>> schritt(String name, Future<void> Function() aktion,
              {bool rollen = false}) async {
            var gesehen = <String>{};
            void wortbrueche() =>
                befunde.addAll(_wortbrueche().map((w) => '$name: Wortbruch $w'));
            final ueber = await _ueberlaeufe(() async {
              await aktion();
              await tester.pumpAndSettle();
              if (rollen) gesehen = await _durchrollen(tester, wortbrueche);
            });
            wortbrueche();
            befunde.addAll(ueber.map((u) => '$name: $u'));
            return gesehen;
          }

          // Der Bildschirm legt seinen http.Client beim Aufbau an — im
          // Bereich von runWithClient ist das der Testserver. Der ganze
          // Ablauf läuft darin: die Übersetzungen laden asynchron, der
          // Bildschirm entsteht erst ein paar Bilder nach pumpWidget.
          await http.runWithClient(() async {
            await schritt('Formular', () async {
              await tester.pumpWidget(
                  _rahmen(ReiseplanungScreen(onBack: () {}), sprache));
            });
            expect(find.byType(ReiseplanungScreen), findsOneWidget);
            final felder = find.byType(TextField);
            expect(felder, findsNWidgets(2), reason: 'Von/Nach fehlen');

            await schritt('Vorschläge „Von“', () async {
              await tester.enterText(felder.at(0), 'Neu-Ulm');
              await tester.pump(const Duration(milliseconds: 400));
            });
            expect(find.text('Neu-Ulm Bahnhof (Bahnhofstraße)'), findsOneWidget,
                reason: 'Die Bahnhofsvorschläge kamen nicht an');
            await tester.tap(find.text('Neu-Ulm Bahnhof (Bahnhofstraße)'));
            await tester.pumpAndSettle();

            await schritt('Vorschläge „Nach“', () async {
              await tester.enterText(felder.at(1), 'München');
              await tester.pump(const Duration(milliseconds: 400));
            });
            expect(find.text('München Hauptbahnhof (tief)'), findsOneWidget,
                reason: 'Die Bahnhofsvorschläge kamen nicht an');
            await tester.tap(find.text('München Hauptbahnhof (tief)'));
            await tester.pumpAndSettle();

            final liste = await schritt('Verbindungen', () async {
              await tester.tap(find.text(tr('Suchen', 'Caută')));
            }, rollen: true);
            final zeit = DateFormat('HH:mm');
            for (final ab in [0, 48, 75]) {
              final text = zeit.format(
                  DateTime.utc(2026, 10, 5, 6, 12).add(Duration(minutes: ab)).toLocal());
              if (!liste.contains(text)) befunde.add('Verbindung um $text nie zu sehen');
            }

            // Die erste Verbindung aufklappen: fünf Teilstrecken mit Fußweg,
            // Verspätung, Gleisen und langen Richtungsangaben.
            final karten = find.byType(ExpansionTile);
            if (karten.evaluate().isEmpty) {
              befunde.add('Keine Verbindungskarte zu sehen');
            } else {
              final teile = await schritt('Verbindung aufgeklappt', () async {
                await tester.tap(karten.first);
              }, rollen: true);
              for (final text in [
                'RE 57155',
                '→ München Hbf (tief) über Mering, Pasing',
                '+4',
              ]) {
                if (!teile.contains(text)) befunde.add('Teilstrecke „$text“ nie zu sehen');
              }
            }

            await tester.pumpWidget(const SizedBox());
            await tester.pump(const Duration(seconds: 1));
          }, reiseServer);

          expect(befunde, isEmpty,
              reason: 'Reiseplanung auf ${fall.key} [$sprache]:\n'
                  '${befunde.toSet().join('\n')}');
        });
      }
    }
  }, skip: _schriftenDa ? false : 'Roboto fehlt unter $_schriften');
}
