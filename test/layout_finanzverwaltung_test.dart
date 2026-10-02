// Passt die Finanzverwaltung MIT DATEN auf jedes Telefon?
//
// test/bildschirme_telefon_test.dart und test/telefon_layout_test.dart
// sehen den Bildschirm leer und nur den ersten Reiter. Mit echten Listen
// sah es auf dem Telefon anders aus: die Kopfzeilen der Reiter
// „Banktransaktionen“ und „Spenden“ stellten Jahr, Filter und Knöpfe in
// EINE Zeile, und in den Listen ließen Betrag und Knöpfe dem Namen des
// Spenders auf 320 dp nur noch Platz für ein paar Buchstaben.
//
// Hier antwortet ein Testserver (ApiService().testClient) mit Beiträgen,
// Transaktionen und Spenden mit langen Namen, rumänischen Sonderzeichen und
// großen Beträgen. Geprüft wird auf jeder Breite in beiden Sprachen: kein
// Überlauf, kein Wort mitten im Wort zerrissen, keine abgeschnittene
// Reiter-Beschriftung — in allen drei Reitern, mit aufgeklapptem Mitglied
// und in den Dialogen „Neue Transaktion“, „Neue Spende“ und „Vereinsdaten“.
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
import 'package:icd360sev_schatzmeister/screens/finanzverwaltung_screen.dart';

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

/// Ein Monat der Beitragsübersicht im Format des Servers („MM/YYYY“).
Map<String, dynamic> _monat(String monat, String status) =>
    {'monat': monat, 'status': status, 'betrag': 25};

/// Was `schatzmeister/finanzen/*.php` liefern — so geformt, wie
/// finanzverwaltung_screen.dart es liest.
final Map<String, Map<String, dynamic>> _antworten = {
  'beitragszahlungen.php': {
    'success': true,
    'beitrag_pro_monat': 25,
    'anzahl_monate': 15,
    'stats': {
      'gesamt_mitglieder': 128,
      'mitglieder_mit_schulden': 37,
      'total_schulden': 12345.5,
      'total_bezahlt': 98765.25,
    },
    'liste': [
      {
        'mitgliedernummer': 'M10234',
        'schulden': 275.0,
        'bezahlt_monate': 4,
        'offen_monate': 11,
        'anzahl_monate': 15,
        'bezahlt_betrag': 100.0,
        'monate_details': [
          _monat('08/2025', 'bezahlt'),
          _monat('09/2025', 'offen'),
          _monat('10/2025', 'befreit'),
          _monat('11/2025', 'offen'),
          _monat('12/2025', 'offen'),
          _monat('02/2026', 'bezahlt'),
        ],
      },
      {
        'mitgliedernummer': 'S42759',
        'schulden': 0,
        'bezahlt_monate': 15,
        'offen_monate': 0,
        'anzahl_monate': 15,
        'bezahlt_betrag': 375.0,
        'monate_details': [_monat('09/2025', 'bezahlt')],
      },
      {
        'mitgliedernummer': 'M10007',
        'schulden': 50.0,
        'bezahlt_monate': 13,
        'offen_monate': 2,
        'anzahl_monate': 15,
        'bezahlt_betrag': 325.0,
        'monate_details': [_monat('09/2026', 'offen')],
      },
    ],
  },
  'transaktionen.php': {
    'success': true,
    'einnahmen': 13595.67,
    'ausgaben': 12345.67,
    'saldo': -1250.0,
    'transaktionen': [
      {
        'id': 1,
        'typ': 'einnahme',
        'betrag': '1250.00',
        'datum': '2026-09-30',
        'beschreibung': 'Mitgliedsbeiträge September 2026 (Sammelüberweisung)',
        'empfaenger_absender': 'Bundesagentur für Arbeit – Familienkasse Bayern Nord',
        'kategorie': 'Mitgliedsbeitrag',
      },
      {
        'id': 2,
        'typ': 'ausgabe',
        'betrag': '12345.67',
        'datum': '2026-09-15',
        'beschreibung': 'Miete Vereinsräume Oktober–Dezember',
        'empfaenger_absender': 'Wohnungsbaugenossenschaft Neu-Ulm eG',
        'kategorie': 'Miete',
      },
      {
        'id': 3,
        'typ': 'einnahme',
        'betrag': '25',
        'datum': '2026-09-02',
        'beschreibung': '',
        'empfaenger_absender': 'Ionuț-Alexandru Popescu-Rădulescu',
        'kategorie': 'Spende',
      },
    ],
  },
  'spenden.php': {
    'success': true,
    'total_betrag': 13750.5,
    'anzahl': 3,
    'mit_quittung': 1,
    'spenden': [
      {
        'id': 1,
        'betrag': '1500.00',
        'datum': '2026-08-14',
        'spender_name': 'Ionuț-Alexandru Popescu-Rădulescu',
        'spender_mitgliedernummer': 'M10234',
        'spender_adresse': 'Hauptstraße 123, 89231 Neu-Ulm',
        'zweck': 'Förderung der Bildung und Erziehung',
        'quittung_ausgestellt': 1,
        'notiz': 'Überweisung mit Verwendungszweck „Spende Kinderprojekt“',
      },
      {
        'id': 2,
        'betrag': '250.00',
        'datum': '2026-07-01',
        'spender_name': 'Christiane Mustermann-Schmidt',
        'spender_mitgliedernummer': '',
        'spender_adresse': '',
        'zweck': '',
        'quittung_ausgestellt': 0,
        'notiz': '',
      },
      {
        'id': 3,
        'betrag': '12000.50',
        'datum': '2026-06-30',
        'spender_name': 'Stiftung Bürgerengagement Landkreis Neu-Ulm',
        'spender_mitgliedernummer': '',
        'spender_adresse': 'Kantstraße 8, 89231 Neu-Ulm',
        'zweck': 'Förderung der Jugendhilfe',
        'quittung_ausgestellt': 0,
        'notiz': '',
      },
    ],
  },
  'einstellungen.php': {
    'success': true,
    'data': {
      'vereinsname': 'ICD360S e.V.',
      'adresse': 'Musterstraße 1, 89231 Neu-Ulm',
      'steuernummer': '151/123/45678',
      'finanzamt': 'Finanzamt Neu-Ulm',
      'freistellung_datum': '15.03.2025',
      'freistellung_zeitraum': '2024',
      'zweck': 'Bildung und Erziehung',
    },
  },
};

/// Testserver für die Finanzverwaltung.
http.Client finanzServer() => MockClient((anfrage) async {
      final datei = anfrage.url.pathSegments.last;
      final antwort =
          _antworten[datei] ?? {'success': false, 'message': 'unbekannt: $datei'};
      return http.Response(jsonEncode(antwort), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });

/// Sammelt, was Flutter während [aktion] meldet: Überläufe mit der
/// Codezeile, die sie verursacht, und jeden anderen Fehler (etwa eine
/// ListTile, deren Titel keinen Platz mehr hat) mit seiner ersten Zeile.
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

/// Rollt die Liste des sichtbaren Reiters Stück für Stück bis ans Ende und
/// ruft an jeder Stelle [pruefen] auf — Einträge unterhalb des Bildschirms
/// baut eine ListView gar nicht erst auf, ungerollt blieben sie ungeprüft.
/// Liefert alle Texte, die dabei zu sehen waren.
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

/// Reiter-Beschriftungen, die nicht ganz zu sehen sind.
List<String> _gekuerzteReiter() {
  final funde = <String>[];
  final texte = find.descendant(
      of: find.byType(Tab), matching: find.byType(RichText));
  for (final e in texte.evaluate()) {
    final p = e.renderObject as RenderParagraph;
    if (p.didExceedMaxLines || p.textSize.width > p.size.width + 0.5) {
      funde.add(p.text.toPlainText());
    }
  }
  return funde;
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
    ApiService().testClient = finanzServer();
  });

  group('Finanzverwaltung mit Daten', () {
    for (final sprache in kSprachen) {
      for (final fall in kBreiten.entries) {
        testWidgets('lesbar — ${fall.key} [$sprache]', (tester) async {
          tester.view.physicalSize = fall.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          await LanguageService.instance.setLanguage(sprache);

          final befunde = <String>[];
          // Führt [aktion] aus, rollt die Liste durch und sammelt dabei
          // Überläufe, Fehler und zerrissene Wörter. Liefert die gesehenen
          // Texte.
          Future<Set<String>> schritt(String name, Future<void> Function() aktion,
              {bool rollen = true}) async {
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

          // Jeder Eintrag, den der Testserver geliefert hat, muss beim
          // Durchrollen zu sehen gewesen sein — sonst prüfte der Test einen
          // leeren oder halb aufgebauten Bildschirm.
          void alleGesehen(String name, Set<String> gesehen, List<String> erwartet) {
            for (final text in erwartet) {
              if (!gesehen.contains(text)) befunde.add('$name: „$text“ nie zu sehen');
            }
          }

          Future<void> reiter(int i) async => tester
              .widget<TabBar>(find.byType(TabBar))
              .controller!
              .animateTo(i);

          // Öffnet den Dialog über seinen Knopf, prüft ihn und schließt ihn
          // wieder. Ist der Knopf nicht zu treffen (aus dem Bild gerutscht),
          // ist das ein Befund wie ein Überlauf.
          Future<void> dialogPruefen(String name, String knopf) async {
            await schritt(name, () async {
              await tester.tap(find.text(knopf), warnIfMissed: false);
            }, rollen: false);
            if (find.byType(AlertDialog).evaluate().isEmpty) {
              befunde.add('$name: ging nicht auf — Knopf „$knopf“ nicht erreichbar');
              return;
            }
            await tester.tap(find.text(tr('Abbrechen', 'Anulare')));
            await tester.pumpAndSettle();
          }

          await schritt('Beiträge', () async {
            await tester.pumpWidget(
                _rahmen(const FinanzverwaltungScreen(), sprache));
          }, rollen: false);
          // Erst wenn die geladenen Daten da sind, ist etwas zu prüfen.
          expect(find.text('M10234'), findsOneWidget,
              reason: 'Die Beitragsliste kam nicht an');
          final beitraege = await schritt('Beiträge, Mitglied aufgeklappt', () async {
            await tester.tap(find.text('M10234'));
          });
          alleGesehen('Beiträge', beitraege, [
            'M10234', 'S42759', 'M10007',
            '${tr('September', 'Septembrie')} 2025',
            '${tr('Februar', 'Februarie')} 2026',
          ]);

          final transaktionen = await schritt('Banktransaktionen', () => reiter(1));
          alleGesehen('Banktransaktionen', transaktionen, [
            'Mitgliedsbeiträge September 2026 (Sammelüberweisung)',
            'Miete Vereinsräume Oktober–Dezember',
            '-12345.67 €',
            '+25.00 €',
          ]);
          await dialogPruefen(
              'Dialog Neue Transaktion', tr('Neue Transaktion', 'Tranzacție nouă'));

          final spenden = await schritt('Spenden', () => reiter(2));
          alleGesehen('Spenden', spenden, [
            'Ionuț-Alexandru Popescu-Rădulescu',
            'Christiane Mustermann-Schmidt',
            'Stiftung Bürgerengagement Landkreis Neu-Ulm',
            '+12000.50 €',
          ]);
          await dialogPruefen(
              'Dialog Vereinsdaten', tr('Vereinsdaten', 'Date asociație'));
          await dialogPruefen('Dialog Neue Spende', tr('Neue Spende', 'Donație nouă'));
          befunde.addAll(
              _gekuerzteReiter().map((t) => 'Reiter abgeschnitten: „$t“'));
          await tester.pumpWidget(const SizedBox());

          expect(befunde, isEmpty,
              reason: 'Finanzverwaltung auf ${fall.key} [$sprache]:\n'
                  '${befunde.toSet().join('\n')}');
        });
      }
    }
  }, skip: _schriftenDa ? false : 'Roboto fehlt unter $_schriften');
}
