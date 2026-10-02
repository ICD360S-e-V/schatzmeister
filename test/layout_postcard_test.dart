// Passt die POSTCARD-Verwaltung MIT KARTEN auf jedes Telefon?
//
// test/bildschirme_telefon_test.dart sieht die Liste nur leer. Mit Karten
// kommen die Kartendetails dazu — die nachgebildete POSTCARD mit fester
// Höhe, darunter PIN und Kartennummer neben einer 110 dp breiten
// Beschriftung — sowie die Dialoge zum Hinzufügen, Bearbeiten und für das
// Geschäftskundenkonto.
//
// Hier antwortet ein Testserver (ApiService().testClient) mit drei Karten
// (lange Bezeichnung, inaktiv, hohes Tageslimit) und Kontodaten. Geprüft
// wird auf jeder Breite in beiden Sprachen: Liste, Kartendetails,
// Bearbeiten, Karte hinzufügen und Konto — kein Überlauf, kein Wort mitten
// im Wort zerrissen, und jede gelieferte Karte war zu sehen. Die Liste
// steht wie in der Deutschen Post in einem Rand von 24 dp.
//
// ⚠️ Mit der echten Schrift (Roboto) — die Testschrift zeichnet jede Glyphe
// als 1-em-Quadrat und macht Texte viel breiter als auf dem Gerät. Die
// Kartennummer verlangt „Courier“; Android hat die nicht und nimmt Roboto,
// darum bekommt sie hier ebenfalls Roboto.
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
import 'package:icd360sev_schatzmeister/screens/postcard.dart';

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

/// Was `platform/postcard_list.php` liefert — so geformt, wie postcard.dart
/// es liest.
final List<Map<String, dynamic>> karten = [
  {'id': 1, 'bezeichnung': 'Karte 1 - Vorsitzender Maximilian von Hohenzollern-Sigmaringen', 'kartennummer': '53141598342501012', 'pin': '4711', 'tageslimit': 250, 'aktiv': true},
  {'id': 2, 'bezeichnung': 'Schatzmeisterin', 'kartennummer': '53141598342501029', 'pin': '', 'tageslimit': 10, 'aktiv': false},
  {'id': 3, 'bezeichnung': '', 'kartennummer': '5314159834', 'pin': '0815', 'tageslimit': 1000, 'aktiv': true},
];

/// Testserver für die POSTCARD-Verwaltung.
http.Client postcardServer() => MockClient((anfrage) async {
      final datei = anfrage.url.pathSegments.last;
      final Map<String, dynamic> antwort = switch (datei) {
        'postcard_list.php' => {'success': true, 'karten': karten},
        'postcard_account_get.php' => {
            'success': true,
            'account': {
              'website': 'https://geschaeftskunden.deutschepost.de/portal/login?ziel=postcard-verwaltung',
              'username': 'icd360s-schatzmeisterin@beispiel-verein.de',
              'password': 'geheim',
            },
          },
        _ => {'success': false, 'message': 'unbekannt: $datei'},
      };
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

void main() {
  setUpAll(() async {
    // Ohne Geräteschlüssel wirft ApiService beim Bauen der Kopfzeilen,
    // bevor eine Anfrage den Testserver erreicht.
    FlutterSecureStorage.setMockInitialValues({'device_key': 'test-geraet'});
    await DeviceKeyService().loadStoredDeviceKey();
    if (!_schriftenDa) return;
    final roboto = [
      'Roboto-Regular.ttf',
      'Roboto-Bold.ttf',
      'Roboto-Medium.ttf',
      'Roboto-Italic.ttf',
    ];
    await _laden('Roboto', roboto);
    await _laden('Courier', roboto);
    await _laden('MaterialIcons', ['MaterialIcons-Regular.otf']);
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService().testClient = postcardServer();
  });

  group('POSTCARD mit Karten', () {
    for (final sprache in kSprachen) {
      for (final fall in kBreiten.entries) {
        testWidgets('lesbar — ${fall.key} [$sprache]', (tester) async {
          tester.view.physicalSize = fall.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          await LanguageService.instance.setLanguage(sprache);

          final befunde = <String>[];
          Future<void> schritt(String name, Future<void> Function() aktion) async {
            final ueber = await _ueberlaeufe(() async {
              await aktion();
              await tester.pumpAndSettle();
            });
            befunde
              ..addAll(_wortbrueche().map((w) => '$name: Wortbruch $w'))
              ..addAll(ueber.map((u) => '$name: $u'));
          }

          bool dialogOffen(String name) {
            if (find.byType(AlertDialog).evaluate().isNotEmpty) return true;
            befunde.add('$name ging nicht auf');
            return false;
          }

          Future<void> schliessen(String knopf) async {
            await tester.tap(find.text(knopf).last);
            await tester.pumpAndSettle();
          }

          await schritt('Liste', () async {
            await tester.pumpWidget(_rahmen(
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: PostcardView(apiService: ApiService()),
                ),
                sprache));
          });
          // Erst wenn die geladenen Daten da sind, ist etwas zu prüfen.
          expect(find.text(karten.first['bezeichnung'] as String), findsOneWidget,
              reason: 'Die Kartenliste kam nicht an');
          for (final text in [
            karten[1]['bezeichnung'] as String,
            tr('Karte 3', 'Card 3'),
            tr('Inaktiv', 'Inactiv'),
          ]) {
            if (find.text(text).evaluate().isEmpty) befunde.add('Liste: „$text“ nicht zu sehen');
          }

          await schritt('Kartendetails', () async {
            await tester.tap(find.text(karten.first['bezeichnung'] as String));
          });
          if (dialogOffen('Kartendetails')) {
            if (find.text('53141598342501012').evaluate().isEmpty) {
              befunde.add('Kartendetails: Kartennummer nicht zu sehen');
            }
            await schritt('Karte bearbeiten', () async {
              await tester.tap(find.text(tr('Bearbeiten', 'Editează')));
            });
            if (dialogOffen('Karte bearbeiten')) await schliessen(tr('Zurück', 'Înapoi'));
            await schliessen(tr('Schließen', 'Închide'));
          }

          await schritt('Karte hinzufügen', () async {
            await tester.tap(find.byTooltip(tr('Karte hinzufügen', 'Adaugă card')));
          });
          if (dialogOffen('Karte hinzufügen')) await schliessen(tr('Abbrechen', 'Anulare'));

          await schritt('Konto', () async {
            await tester.tap(find.byTooltip(tr('Konto-Einstellungen', 'Setări cont')));
          });
          if (dialogOffen('Konto')) {
            if (find.text('icd360s-schatzmeisterin@beispiel-verein.de').evaluate().isEmpty) {
              befunde.add('Konto: Benutzername nicht zu sehen');
            }
            await schliessen(tr('Abbrechen', 'Anulare'));
          }

          await tester.pumpWidget(const SizedBox());

          expect(befunde, isEmpty,
              reason: 'POSTCARD auf ${fall.key} [$sprache]:\n'
                  '${befunde.toSet().join('\n')}');
        });
      }
    }
  }, skip: _schriftenDa ? false : 'Roboto fehlt unter $_schriften');
}
