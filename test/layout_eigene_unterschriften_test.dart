// Passen „Meine Unterschriften“ MIT VORGÄNGEN auf jedes Telefon — die
// Liste und alle drei Schritte des Unterschreibens?
//
// test/bildschirme_telefon_test.dart und test/telefon_layout_test.dart
// sehen nur die leere Liste. Der Vorgang selbst — lesen, unterschreiben,
// mit Code bestätigen — hat unten eine Leiste mit „Zurück“ und dem
// Weiter-Knopf in einer Zeile; „Rechtsverbindlich unterschreiben“ und
// „Semnează cu valoare juridică“ sind lang.
//
// Hier antwortet ein Testserver (ApiService().testClient) mit Vorgängen in
// jedem Zustand und langen Titeln, mit einem angeforderten Code und mit
// einem PDF, das (ohne PDFium im Test) nicht geladen werden kann — dann
// steht die Fehleransicht mit „Erneut versuchen“ da. Die Unterschrift wird
// gezeichnet. Geprüft wird auf jeder Breite in beiden Sprachen: kein
// Überlauf, kein Wort mitten im Wort zerrissen, und jeder Schritt war zu
// sehen.
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
import 'package:signature/signature.dart';
import 'package:icd360sev_schatzmeister/l10n/app_localizations.dart';
import 'package:icd360sev_schatzmeister/services/api_service.dart';
import 'package:icd360sev_schatzmeister/services/device_key_service.dart';
import 'package:icd360sev_schatzmeister/services/language_service.dart';
import 'package:icd360sev_schatzmeister/screens/eigene_unterschriften_screen.dart';

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

/// Vorgänge, wie `member/signatur_manage.php` sie liefert (action `list`).
final List<Map<String, dynamic>> vorgaenge = [
  {'id': 11, 'dokument_titel': 'Kassenbericht 2025 mit Anlagen (Kassenprüfung vom 12.09.2026)', 'status': 'offen', 'pdf_seiten': 3},
  {'id': 12, 'dokument_titel': 'Bankvollmacht Sparkasse Neu-Ulm – gemeinsame Vertretung', 'status': 'signiert', 'wartet_auf_mitunterzeichner': true},
  {'id': 13, 'dokument_titel': 'Freistellungsbescheid-Antrag', 'status': 'signiert'},
  {'id': 14, 'dokument_titel': 'Änderung der Beitragsordnung', 'status': 'abgelehnt'},
  {'id': 15, 'dokument_titel': 'Vollmacht Finanzamt', 'status': 'widerrufen'},
  {'id': 16, 'dokument_titel': 'Spendenquittungen Sammelfreigabe', 'status': 'abgelaufen'},
];

/// Testserver für die eigenen Unterschriften.
http.Client unterschriftServer() => MockClient((anfrage) async {
      final datei = anfrage.url.pathSegments.last;
      final Map<String, dynamic> antwort;
      if (datei == 'signatur_manage.php') {
        final aktion = (jsonDecode(anfrage.body) as Map)['action'];
        antwort = switch (aktion) {
          'list' => {'success': true, 'signaturen': vorgaenge},
          'tan_anfordern' => {'success': true, 'gesendet_an': '+49 151 •••• 4711'},
          _ => {'success': false, 'message': 'unbekannt: $aktion'},
        };
      } else {
        // Auch das PDF: JSON statt PDF heißt „gibt es nicht“.
        antwort = {'success': false, 'message': 'kein PDF im Test'};
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
    ApiService().testClient = unterschriftServer();
  });

  group('Eigene Unterschriften mit Vorgängen', () {
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

          void sichtbar(String name, String text) {
            if (find.text(text).evaluate().isEmpty) befunde.add('$name: „$text“ nicht zu sehen');
          }

          await schritt('Liste', () async {
            await tester.pumpWidget(_rahmen(
                EigeneUnterschriftenScreen(apiService: ApiService()), sprache));
          });
          // Erst wenn die geladenen Daten da sind, ist etwas zu prüfen.
          expect(find.text(vorgaenge.first['dokument_titel'] as String), findsOneWidget,
              reason: 'Die Vorgänge kamen nicht an');
          sichtbar('Liste', tr('Von Ihnen unterschrieben · warten auf die zweite Unterschrift',
              'Semnat de dumneavoastră · se așteaptă a doua semnătură'));

          // Schritt 1 mit Seitenzahl: der Hinweis „bis zur letzten Seite“.
          await schritt('Lesen', () async {
            await tester.pumpWidget(_rahmen(
                EigeneUnterschriftLeistenScreen(
                  apiService: ApiService(),
                  signaturId: 11,
                  titel: vorgaenge.first['dokument_titel'] as String,
                  seiten: 3,
                ),
                sprache));
          });
          sichtbar('Lesen', tr('Weiter zur Unterschrift', 'Continuă la semnătură'));
          sichtbar('Lesen', tr('Erneut versuchen', 'Încearcă din nou'));

          // Ohne Seitenzahl geht es weiter: zeichnen, dann der Code.
          await tester.pumpWidget(const SizedBox());
          await schritt('Unterschreiben', () async {
            await tester.pumpWidget(_rahmen(
                EigeneUnterschriftLeistenScreen(
                  apiService: ApiService(),
                  signaturId: 11,
                  titel: vorgaenge.first['dokument_titel'] as String,
                ),
                sprache));
            await tester.pumpAndSettle();
            await tester.tap(find.text(tr('Weiter zur Unterschrift', 'Continuă la semnătură')));
          });
          sichtbar('Unterschreiben', tr('Bitte unterschreiben Sie im weißen Feld.', 'Vă rugăm semnați în câmpul alb.'));
          await tester.drag(find.byType(Signature), const Offset(80, 20));
          await tester.pumpAndSettle();
          await schritt('Code', () async {
            await tester.tap(find.text(tr('Weiter zum Code', 'Continuă la cod')));
          });
          sichtbar('Code', tr('Rechtsverbindlich unterschreiben', 'Semnează cu valoare juridică'));
          await schritt('Code angefordert', () async {
            await tester.tap(find.text(tr('Code anfordern', 'Solicită cod')));
          });
          sichtbar('Code angefordert', tr('Code gesendet an +49 151 •••• 4711', 'Cod trimis la +49 151 •••• 4711'));
          await schritt('Ablehnen', () async {
            await tester.ensureVisible(find.text(tr('Unterschrift ablehnen', 'Refuză semnătura')));
            await tester.pumpAndSettle();
            await tester.tap(find.text(tr('Unterschrift ablehnen', 'Refuză semnătura')));
          });
          if (find.byType(AlertDialog).evaluate().isEmpty) {
            befunde.add('Ablehnen: Dialog ging nicht auf');
          } else {
            await tester.tap(find.text(tr('Abbrechen', 'Anulare')));
            await tester.pumpAndSettle();
          }

          await tester.pumpWidget(const SizedBox());

          expect(befunde, isEmpty,
              reason: 'Eigene Unterschriften auf ${fall.key} [$sprache]:\n'
                  '${befunde.toSet().join('\n')}');
        });
      }
    }
  }, skip: _schriftenDa ? false : 'Roboto fehlt unter $_schriften');
}
