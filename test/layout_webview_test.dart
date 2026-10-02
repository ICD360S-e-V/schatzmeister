// Passt die Kopfleiste des eingebauten Browsers auf jedes Telefon?
//
// Der Browser (WebViewScreen) öffnet Impressum, Datenschutz und das
// Geschäftskundenportal der Deutschen Post. Die Webansicht selbst läuft im
// Test nicht (auf Linux öffnet der Bildschirm den Systembrowser, hier
// antwortet url_launcher mit „geht nicht“). Geprüft wird darum, was der
// Bildschirm selbst zeichnet: Titel, die fünf Navigationsknöpfe, die
// Adresszeile und die Meldung — auf jeder Breite in beiden Sprachen.
//
// Vorher standen alle fünf Knöpfe neben dem Titel: auf 393 dp blieben ihm
// gut 80 dp, auf 320 dp fast nichts.
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
import 'package:icd360sev_schatzmeister/services/language_service.dart';
import 'package:icd360sev_schatzmeister/screens/webview_screen.dart';

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
    // Der Systembrowser „lässt sich nicht öffnen“: der Bildschirm bleibt
    // stehen und zeigt seine Meldung.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/url_launcher'),
            (aufruf) async => false);
  });

  group('Browser-Kopfleiste', () {
    for (final sprache in kSprachen) {
      for (final fall in kBreiten.entries) {
        testWidgets('lesbar — ${fall.key} [$sprache]', (tester) async {
          tester.view.physicalSize = fall.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          await LanguageService.instance.setLanguage(sprache);
          // Der längste Titel, den die App dem Browser gibt.
          final titel = tr('Deutsche Post Login', 'Autentificare Deutsche Post');

          final befunde = <String>[];
          final ueber = await _ueberlaeufe(() async {
            await tester.pumpWidget(_rahmen(
                WebViewScreen(
                  title: titel,
                  url: 'https://geschaeftskunden.deutschepost.de/portal/login?ziel=postcard-verwaltung&sprache=de',
                ),
                sprache));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 500));
          });
          befunde
            ..addAll(ueber)
            ..addAll(_wortbrueche().map((w) => 'Wortbruch $w'));

          // Der Titel darf enden mit „…“, aber nicht zusammengedrückt werden:
          // mindestens 200 dp (oder seine volle Länge, wenn er kürzer ist).
          final titelText = tester.renderObject<RenderParagraph>(find.descendant(
              of: find.byType(AppBar), matching: find.text(titel)));
          final voll = titelText.getMaxIntrinsicWidth(double.infinity);
          final noetig = voll < 200 ? voll : 200;
          if (titelText.size.width + 0.5 < noetig) {
            befunde.add('Titel auf ${titelText.size.width.toStringAsFixed(0)} dp zusammengedrückt');
          }

          // Alle fünf Knöpfe müssen auf dem Bildschirm liegen.
          final l = AppLocalizations.of(tester.element(find.byType(WebViewScreen)));
          final bildschirm = Offset.zero & fall.value;
          for (final tipp in [l.backNav, l.forwardNav, l.refreshNav, l.homePage, l.openInBrowser]) {
            final knopf = find.byTooltip(tipp);
            if (knopf.evaluate().length != 1) {
              befunde.add('Knopf „$tipp“ ${knopf.evaluate().length}× vorhanden');
            } else if (!bildschirm.contains(tester.getCenter(knopf))) {
              befunde.add('Knopf „$tipp“ liegt außerhalb des Bildschirms');
            }
          }
          if (find.text(l.couldNotOpenBrowser).evaluate().isEmpty) {
            befunde.add('Meldung „${l.couldNotOpenBrowser}“ nicht zu sehen');
          }

          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 5));

          expect(befunde, isEmpty,
              reason: 'Browser auf ${fall.key} [$sprache]:\n'
                  '${befunde.toSet().join('\n')}');
        });
      }
    }
  }, skip: _schriftenDa ? false : 'Roboto fehlt unter $_schriften');
}
