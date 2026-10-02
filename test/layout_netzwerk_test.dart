// Netzwerk mit echten Listen: passt jede Modulansicht auf jedes Telefon?
//
// Der gemeinsame Test (bildschirme_telefon_test.dart) sieht nur die
// Übersicht ohne Daten. Hier liefert ein MockClient für jedes Modul
// (Krankenhäuser, Praxen, Drogerie, Märkte, Krankenkassen) neun Einträge in
// drei Gruppen — lange Namen, Beschreibungen, Webadressen und Gruppennamen —
// erst gruppiert, dann nach einer Gruppe gefiltert. Auf 320 bis 1280 dp, auf
// Deutsch und Rumänisch, mit der echten Schrift (Roboto).
//
// Anders als der gemeinsame Test zählt hier JEDER Fehler beim Aufbau, nicht
// nur ein Überlauf: eine Karte, die auf dem Telefon ihre Höhe nicht findet,
// meldet keinen Überlauf, sondern eine Ausnahme.
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
import 'package:icd360sev_schatzmeister/screens/netzwerk_screen.dart';
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

/// Ein Modul so, wie die App es vom Server bekommt.
class _Modul {
  final String datei; // stadtverwaltung/<datei>
  final String datenSchluessel; // Liste in der Antwort
  final String filterFeld; // Gruppierung und Filter (?<filterFeld>=…)
  final String? labelFeld; // Anzeigename der Gruppe, falls eigenes Feld
  final IconData symbol; // Symbol der Karte auf der Übersicht
  final List<Map<String, dynamic>> eintraege;

  _Modul(this.datei, this.datenSchluessel, this.filterFeld, this.labelFeld,
      this.symbol, this.eintraege);

  List<Map<String, dynamic>> get stats {
    final zaehler = <String, int>{};
    final labels = <String, String>{};
    for (final e in eintraege) {
      final k = e[filterFeld] as String;
      zaehler[k] = (zaehler[k] ?? 0) + 1;
      if (labelFeld != null) labels[k] = e[labelFeld] as String;
    }
    return [
      for (final k in zaehler.keys)
        {filterFeld: k, if (labelFeld != null) labelFeld!: labels[k], 'anzahl': zaehler[k]},
    ];
  }
}

/// Neun Einträge in drei Gruppen, mit langen, aber echten Werten.
List<Map<String, dynamic>> _neun(
  String filterFeld,
  String? labelFeld,
  List<(String, String)> gruppen,
  Map<String, dynamic> Function(int i) eintrag,
) =>
    [
      for (var i = 0; i < 9; i++)
        {
          ...eintrag(i),
          filterFeld: gruppen[i % 3].$1,
          if (labelFeld != null) labelFeld: gruppen[i % 3].$2,
        },
    ];

final _module = <String, _Modul>{
  'krankenhaeuser': _Modul(
    'krankenhaeuser.php', 'krankenhaeuser', 'typ', 'typ_label', Icons.local_hospital,
    _neun('typ', 'typ_label', [
      ('maximal', 'Krankenhaus der Schwerpunkt- und Maximalversorgung (Universitätsklinikum)'),
      ('regel', 'Krankenhaus der Grund- und Regelversorgung'),
      ('fach', 'Fachklinik'),
    ], (i) => {
          'name': 'Universitätsklinikum Ulm – Klinik für Innere Medizin I (Gastroenterologie, Endokrinologie) $i',
          'beschreibung': 'Zentrale Notaufnahme rund um die Uhr, Herzkatheterlabor, Stroke Unit, Intensivstation und Palliativstation',
          'website': 'https://www.uniklinik-ulm.de/innere-medizin-i/notaufnahme-und-ambulanzen.html',
        }),
  ),
  'praxen': _Modul(
    'praxen.php', 'praxen', 'kategorie', null, Icons.medical_services,
    _neun('kategorie', null, [
      ('Allgemeinmedizin und hausärztliche Versorgung', ''),
      ('Zahnmedizin', ''),
      ('Orthopädie und Unfallchirurgie', ''),
    ], (i) => {
          'name': 'Gemeinschaftspraxis Dr. med. Alexandra Hohenstein-Schwarzenberger & Kollegen $i',
          'umgangsname': 'Hausärztin (Allgemeinmedizin, Naturheilverfahren, Akupunktur)',
          'standort': 'Neu-Ulm, Augsburger Straße 112 (Ärztehaus am Bahnhof, 3. Obergeschoss, Aufzug vorhanden)',
          'website': 'https://www.hausarztpraxis-hohenstein-schwarzenberger.de/sprechzeiten',
        }),
  ),
  'drogerie': _Modul(
    'drogerien.php', 'drogerie', 'typ', 'typ_label', Icons.local_pharmacy,
    _neun('typ', 'typ_label', [
      ('apotheke', 'Apotheke (mit Notdienst und Botendienst)'),
      ('drogerie', 'Drogeriemarkt'),
      ('sanitaetshaus', 'Sanitätshaus und Orthopädietechnik'),
    ], (i) => {
          'name': 'dm-drogerie markt GmbH + Co. KG – Filiale Neu-Ulm Glacis-Galerie $i',
          'filialen_anzahl': 2087,
          'beschreibung': 'Drogerieartikel, Babynahrung, Naturkosmetik, Fotoservice und Apothekenabholstation',
          'website': 'https://www.dm.de/store/de-1234/neu-ulm/glacis-galerie-bahnhofstrasse-1',
        }),
  ),
  'maerkte': _Modul(
    'maerkte.php', 'maerkte', 'typ', 'typ_label', Icons.store,
    _neun('typ', 'typ_label', [
      ('supermarkt', 'Supermarkt / Verbrauchermarkt (Vollsortiment)'),
      ('discounter', 'Discounter'),
      ('wochenmarkt', 'Wochenmarkt und Bauernmarkt'),
    ], (i) => {
          'name': 'Kaufland Neu-Ulm-Pfuhl – Hypermarkt mit Frischetheke, Backshop und Getränkemarkt $i',
          'filialen_anzahl': 13750,
          'standort': 'Neu-Ulm-Pfuhl, Hauptstraße 85–89 (Parkplatz mit Ladestationen)',
          'website': 'https://filiale.kaufland.de/service/filiale/neu-ulm-pfuhl-hauptstrasse-4711.html',
        }),
  ),
  'krankenkasse': _Modul(
    'krankenkassen.php', 'krankenkassen', 'typ', 'typ_label', Icons.health_and_safety,
    _neun('typ', 'typ_label', [
      ('aok', 'Gesetzliche Krankenversicherung (Allgemeine Ortskrankenkasse)'),
      ('bkk', 'Betriebskrankenkasse'),
      ('pkv', 'Private Krankenversicherung'),
    ], (i) => {
          'name': 'AOK Bayern – Die Gesundheitskasse, Direktion Neu-Ulm / Günzburg $i',
          'zusatzbeitrag': '2.69',
          'bundesweit': i.isEven ? 1 : 0,
          'beschreibung': 'Geschäftsstelle mit Kundenberatung, Pflegeberatung und Präventionskursen',
          'website': 'https://www.aok.de/pk/bayern/neu-ulm-guenzburg/geschaeftsstellen/',
        }),
  ),
};

http.Response _json(Object daten) => http.Response(
      jsonEncode(daten),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// Antwortet wie stadtverwaltung/*.php: die Liste des Moduls (mit Filter
/// nur die Einträge der Gruppe) und die Zahlen je Gruppe.
http.Client _server() => MockClient((anfrage) async {
      for (final m in _module.values) {
        if (anfrage.url.path.endsWith('/stadtverwaltung/${m.datei}')) {
          final filter = anfrage.url.queryParameters[m.filterFeld];
          final liste = filter == null
              ? m.eintraege
              : m.eintraege.where((e) => e[m.filterFeld] == filter).toList();
          return _json({'success': true, m.datenSchluessel: liste, 'stats': m.stats});
        }
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
      group('Netzwerk ${fall.key} [$sprache]', () {
        Future<void> aufbauen(WidgetTester tester) async {
          tester.view.physicalSize = fall.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          await LanguageService.instance.setLanguage(sprache);
          await tester.pumpWidget(_rahmen(const NetzwerkScreen(), sprache));
          await _warten(tester);
        }

        testWidgets('Übersicht und Behörden-Ansicht', (tester) async {
          final fehler = await _fehlerBei(tester, () async {
            await aufbauen(tester);
            await _bisSichtbar(tester, find.byIcon(Icons.local_hospital));
            await _tippen(tester, find.byIcon(Icons.account_balance).first);
            await _bisSichtbar(tester, find.text('Bundesagentur für Arbeit'));
          });
          await tester.pumpWidget(const SizedBox());
          expect(fehler, isEmpty, reason: fehler.toSet().join('\n'));
        });

        for (final modul in _module.entries) {
          testWidgets('${modul.key}: gruppiert und gefiltert', (tester) async {
            final m = modul.value;
            final fehler = await _fehlerBei(tester, () async {
              await aufbauen(tester);
              await _bisSichtbar(tester, find.byIcon(m.symbol));
              await _tippen(tester, find.byIcon(m.symbol).first);
              // Die Liste ist wirklich da (sonst prüfte der Test nur den
              // leeren Zustand): neun Einträge, gruppiert, mit Gruppenkopf.
              await _bisSichtbar(tester, find.text(m.eintraege.first['name'] as String));
              expect(find.text(sprache == 'de' ? '9 Einträge' : '9 intrări'), findsOneWidget);
              final ersteGruppe = m.eintraege.first[m.labelFeld ?? m.filterFeld] as String;
              // Filter-Chip und Gruppenkopf tragen denselben Text.
              expect(find.text('$ersteGruppe (3)'), findsNWidgets(2));

              // Erste Gruppe als Filter: nur noch ihre drei Einträge.
              final chip = tester.widget<FilterChip>(find.byType(FilterChip).at(1));
              chip.onSelected!(true);
              await _bisSichtbar(tester, find.text(sprache == 'de' ? '3 Einträge' : '3 intrări'));
              expect(find.text(m.eintraege.first['name'] as String), findsOneWidget);
              expect(find.text(m.eintraege[1]['name'] as String), findsNothing);
            });
            await tester.pumpWidget(const SizedBox());
            expect(fehler, isEmpty, reason: fehler.toSet().join('\n'));
          });
        }
      }, skip: _schriftenDa ? false : 'Roboto fehlt unter $_schriften');
    }
  }
}
