// Passt das Archiv MIT EINTRÄGEN auf jedes Telefon?
//
// test/bildschirme_telefon_test.dart sieht das Archiv nur leer. Mit Daten
// stellte jede Archivkarte Person, Mitgliedsnummer, Dateiname und Größe
// ungebremst in eine Zeile, die fünf Kennzahlen teilten sich die Breite zu
// je ~50 dp („Verschlüsselt“ brach mitten im Wort), und im Dateibetrachter
// stand neben der Anzahl der Dateien ein 250 dp breites Suchfeld.
//
// Hier antwortet ein Testserver (ApiService().testClient) mit drei
// Archiven mit langen Namen, Dateinamen und Beschreibungen, dazu mit einem
// echten ZIP und einer Textdatei für den Betrachter. Geprüft wird auf jeder
// Breite in beiden Sprachen: Liste, Hochladen-Dialog mit Mitgliederliste,
// ZIP- und Textbetrachter — kein Überlauf, kein Wort mitten im Wort
// zerrissen, und jeder gelieferte Eintrag war zu sehen.
//
// ⚠️ Mit der echten Schrift (Roboto) — die Testschrift zeichnet jede Glyphe
// als 1-em-Quadrat und macht Texte viel breiter als auf dem Gerät.
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
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
import 'package:icd360sev_schatzmeister/models/user.dart';
import 'package:icd360sev_schatzmeister/services/api_service.dart';
import 'package:icd360sev_schatzmeister/services/device_key_service.dart';
import 'package:icd360sev_schatzmeister/services/language_service.dart';
import 'package:icd360sev_schatzmeister/screens/archiv_screen.dart';

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

/// Mitglieder für den Hochladen-Dialog.
final List<User> mitglieder = [
  User(id: 1, mitgliedernummer: 'M10234', email: 'ionut.popescu@example.org', name: 'Ionuț-Alexandru Popescu-Rădulescu', status: 'aktiv', role: 'mitglied'),
  User(id: 2, mitgliedernummer: 'S42759', email: 'schatzmeisterin@example.org', name: 'Christiane Mustermann-Schmidt', status: 'aktiv', role: 'schatzmeister'),
  User(id: 3, mitgliedernummer: 'V00001', email: 'vorstand@example.org', name: 'Maximilian von Hohenzollern-Sigmaringen', status: 'aktiv', role: 'vorsitzer'),
];

/// Was `schatzmeister/archiv_list.php` liefert — so geformt, wie
/// archiv_screen.dart es liest.
final List<Map<String, dynamic>> _archive = [
  {
    'id': 1,
    'kategorie': 'whatsapp',
    'is_encrypted': 1,
    'titel': 'WhatsApp-Chat mit Ionuț-Alexandru Popescu-Rădulescu (Mitgliedsbeitrag, Kündigung)',
    'person_name': 'Ionuț-Alexandru Popescu-Rădulescu',
    'mitgliedernummer': 'M10234',
    'original_filename': 'WhatsApp Chat mit Ionuț-Alexandru Popescu-Rădulescu 2026-09-30.zip',
    'filesize': 15728640,
    'beschreibung': 'Absprache zur Ratenzahlung der offenen Mitgliedsbeiträge und Kündigung zum Jahresende',
    'created_at': '2026-09-30 14:23:00',
  },
  {
    'id': 2,
    'kategorie': 'sonstiges',
    'is_encrypted': 0,
    'titel': 'Protokoll Mitgliederversammlung',
    'person_name': 'Vorstand',
    'mitgliedernummer': 'V00001',
    'original_filename': 'protokoll.txt',
    'filesize': 1234,
    'beschreibung': 'Protokoll der außerordentlichen Mitgliederversammlung vom 12.09.2026 mit Beschlüssen zur Beitragsordnung',
    'created_at': '2026-09-12 19:00:00',
  },
  {
    'id': 3,
    'kategorie': 'dokument',
    'is_encrypted': true,
    'titel': 'Kündigungsbestätigung Mitgliedschaft',
    'person_name': 'Christiane Mustermann-Schmidt',
    'mitgliedernummer': '',
    'original_filename': 'Kuendigungsbestaetigung_Mustermann-Schmidt_unterschrieben.pdf',
    'filesize': 245760,
    'beschreibung': '',
    'created_at': '2026-08-14 09:05:00',
  },
];

/// Ein echtes ZIP, wie ein exportierter WhatsApp-Chat.
List<int> _zip() {
  final a = Archive()
    ..addFile(ArchiveFile.string('WhatsApp Chat mit Ionuț-Alexandru Popescu-Rădulescu.txt',
        '30.09.26, 14:02 - Ionuț: Bună ziua, ich möchte die Beiträge in Raten zahlen.'))
    ..addFile(ArchiveFile.bytes('Medien/IMG-20260930-WA0007_Kontoauszug_September_2026.jpg', List.filled(2048, 7)))
    ..addFile(ArchiveFile.bytes('Medien/PTT-20260930-WA0012.opus', List.filled(4096, 3)));
  return ZipEncoder().encodeBytes(a);
}

/// Testserver für das Archiv.
http.Client archivServer() => MockClient((anfrage) async {
      final datei = anfrage.url.pathSegments.last;
      final Map<String, dynamic> antwort;
      if (datei == 'archiv_list.php') {
        antwort = {'success': true, 'archives': _archive};
      } else if (datei == 'archiv_download.php') {
        final id = (jsonDecode(anfrage.body) as Map)['id'];
        antwort = id == 1
            ? {'success': true, 'filename': 'whatsapp_chat.zip', 'data': base64Encode(_zip())}
            : {
                'success': true,
                'filename': 'protokoll.txt',
                'data': base64Encode(utf8.encode(
                    'Protokoll der außerordentlichen Mitgliederversammlung\n\n'
                    'TOP 1: Beitragsordnung — angenommen mit 17 Ja-Stimmen.')),
              };
      } else {
        antwort = {'success': false, 'message': 'unbekannt: $datei'};
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
/// Ziffern. Der Inhalt einer angezeigten Textdatei zählt nicht: er steht in
/// Monospace, und diese Schrift hat der Test nicht.
List<String> _wortbrueche() {
  final funde = <String>[];
  final wort = RegExp(r'[\p{L}\p{N}]+', unicode: true);
  for (final e in find.byType(RichText).evaluate()) {
    final p = e.renderObject;
    if (p is! RenderParagraph || !p.hasSize) continue;
    if (p.text.style?.fontFamily == 'monospace') continue;
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

/// Rollt die Archivliste Stück für Stück bis ans Ende und ruft an jeder
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
    ApiService().testClient = archivServer();
  });

  group('Archiv mit Einträgen', () {
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

          // Öffnet einen Betrachter über das Augen-Symbol der Karte [index],
          // prüft ihn und schließt ihn wieder.
          Future<Set<String>> betrachter(String name, int index) async {
            final auge = find
                .byTooltip(tr('Anzeigen (nur im Speicher)', 'Afișează (doar în memorie)'),
                    skipOffstage: false)
                .at(index);
            await tester.ensureVisible(auge);
            await tester.pumpAndSettle();
            final gesehen = await schritt(name, () => tester.tap(auge));
            for (final e in find.byType(Text).evaluate()) {
              final daten = (e.widget as Text).data;
              if (daten != null) gesehen.add(daten);
            }
            await tester.tap(find.byTooltip(tr('Schließen (Daten werden aus dem Speicher gelöscht)',
                'Închide (datele sunt șterse din memorie)')));
            await tester.pumpAndSettle();
            return gesehen;
          }

          await schritt('Liste', () async {
            await tester.pumpWidget(_rahmen(
                ArchivScreen(apiService: ApiService(), users: mitglieder), sprache));
          });
          // Erst wenn die geladenen Daten da sind, ist etwas zu prüfen.
          expect(find.text(_archive.first['titel'] as String), findsOneWidget,
              reason: 'Die Archivliste kam nicht an');
          final liste = await schritt('Liste gerollt', () async {}, rollen: true);
          for (final a in _archive) {
            for (final feld in ['titel', 'person_name', 'original_filename']) {
              if (!liste.contains(a[feld])) befunde.add('Liste: „${a[feld]}“ nie zu sehen');
            }
          }

          await schritt('Dialog Hochladen', () async {
            await tester.tap(find.text(tr('Hochladen', 'Încarcă')));
          });
          if (find.byType(AlertDialog).evaluate().isEmpty) {
            befunde.add('Dialog Hochladen ging nicht auf');
          } else {
            for (final m in mitglieder) {
              if (find.text(m.name).evaluate().isEmpty) {
                befunde.add('Dialog Hochladen: „${m.name}“ nicht zu sehen');
              }
            }
            await tester.tap(find.text(tr('Abbrechen', 'Anulare')));
            await tester.pumpAndSettle();
          }

          final zip = await betrachter('ZIP-Betrachter', 0);
          for (final text in [
            'WhatsApp Chat mit Ionuț-Alexandru Popescu-Rădulescu.txt',
            'IMG-20260930-WA0007_Kontoauszug_September_2026.jpg',
          ]) {
            if (!zip.contains(text)) befunde.add('ZIP-Betrachter: „$text“ nie zu sehen');
          }
          final txt = await betrachter('Textbetrachter', 1);
          if (!txt.any((t) => t.contains('TOP 1: Beitragsordnung'))) {
            befunde.add('Textbetrachter: Inhalt nie zu sehen');
          }

          await tester.pumpWidget(const SizedBox());

          expect(befunde, isEmpty,
              reason: 'Archiv auf ${fall.key} [$sprache]:\n'
                  '${befunde.toSet().join('\n')}');
        });
      }
    }
  }, skip: _schriftenDa ? false : 'Roboto fehlt unter $_schriften');
}
