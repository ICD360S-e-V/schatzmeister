// Ist die Arbeitsagentur auf dem Telefon LESBAR — in allen drei Reitern?
//
// test/bildschirme_telefon_test.dart sieht nur den ersten Reiter und nur
// Überläufe. Auf dem Redmi (393 dp) lief aber nichts über, und trotzdem war
// der Bildschirm kaum zu lesen: drei Kennzahl-Karten nebeneinander mit je
// ~100 dp brachen die Wörter mitten durch („Monat slohn“, „Minijo b-“,
// „Profiti eren“), die Reiter-Beschriftungen waren abgeschnitten, und im
// zweiten Reiter lief die Kopfzeile der Entgelttabelle um 104 dp hinaus.
//
// Darum prüft dieser Test jeden Reiter auf jeder Breite in beiden Sprachen
// auf drei Dinge: kein Überlauf, kein Wort, das über zwei Zeilen zerrissen
// ist, und keine abgeschnittene Reiter-Beschriftung.
//
// ⚠️ Mit der echten Schrift (Roboto) — die Testschrift zeichnet jede Glyphe
// als 1-em-Quadrat und macht Texte viel breiter als auf dem Gerät.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:icd360sev_schatzmeister/l10n/app_localizations.dart';
import 'package:icd360sev_schatzmeister/services/api_service.dart';
import 'package:icd360sev_schatzmeister/services/language_service.dart';
import 'package:icd360sev_schatzmeister/screens/arbeitsagentur_screen.dart';

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

  group('Arbeitsagentur, alle drei Reiter', () {
    for (final sprache in kSprachen) {
      for (final fall in kBreiten.entries) {
        testWidgets('lesbar — ${fall.key} [$sprache]', (tester) async {
          tester.view.physicalSize = fall.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          await LanguageService.instance.setLanguage(sprache);

          final befunde = <String>[];
          for (var reiter = 0; reiter < 3; reiter++) {
            final ueber = await _ueberlaeufe(() async {
              if (reiter == 0) {
                await tester.pumpWidget(_rahmen(
                    ArbeitsagenturScreen(apiService: ApiService(), onBack: () {}),
                    sprache));
              } else {
                tester
                    .widget<TabBar>(find.byType(TabBar))
                    .controller!
                    .animateTo(reiter);
              }
              await tester.pumpAndSettle();
            });
            final r = 'Reiter ${reiter + 1}';
            befunde
              ..addAll(ueber.map((u) => '$r: $u'))
              ..addAll(_wortbrueche().map((w) => '$r: Wortbruch $w'));
          }
          befunde.addAll(
              _gekuerzteReiter().map((t) => 'Reiter abgeschnitten: „$t“'));
          await tester.pumpWidget(const SizedBox());

          expect(befunde, isEmpty,
              reason: 'Arbeitsagentur auf ${fall.key} [$sprache]:\n'
                  '${befunde.toSet().join('\n')}');
        });
      }
    }
  }, skip: _schriftenDa ? false : 'Roboto fehlt unter $_schriften');
}
