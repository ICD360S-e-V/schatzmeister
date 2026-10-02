// Passt der Bildschirm „Ordnungsmaßnahmen" auch MIT Mitgliedern auf jedes
// Telefon — auf Deutsch und auf Rumänisch?
//
// bildschirme_telefon_test.dart sieht ihn nur mit leerer Mitgliederliste.
// Hier steht eine Liste mit langen Namen darin, und das Formular wird
// ausgefüllt: das längste Mitglied gewählt, jede Verstoß-Kategorie einmal
// angetippt (die gewählte steht fett und damit breiter da), jede Maßnahme
// gewählt (beim Ordnungsgeld kommt das Betragsfeld dazu) und ein langer
// Sachverhalt eingetragen. Jeder Überlauf und jeder andere Layout-Fehler
// ist ein Fehler.
//
// Mit der echten Schrift (Roboto) wie in bildschirme_telefon_test.dart.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:icd360sev_schatzmeister/l10n/app_localizations.dart';
import 'package:icd360sev_schatzmeister/models/user.dart';
import 'package:icd360sev_schatzmeister/screens/ordnungsmassnahmen_screen.dart';
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

User _mitglied(int id, String nr, String name, String status, String rolle) =>
    User(
      id: id,
      mitgliedernummer: nr,
      email: 'mitglied$id@example.org',
      name: name,
      status: status,
      role: rolle,
    );

final _mitglieder = <User>[
  _mitglied(1, 'S42759', 'Ionuț-Claudiu Duinea', 'active', 'vorsitzer'),
  _mitglied(2, 'S12345', 'Maria-Magdalena Popescu-Schwarzenberger', 'active',
      'schatzmeister'),
  _mitglied(3, 'M10023', 'Alexandru-Constantin Vasilescu-Bărbulescu',
      'active', 'kassierer'),
  _mitglied(4, 'M10024', 'Hans-Joachim Müller-Lüdenscheidt', 'neu', 'mitglied'),
  _mitglied(5, 'M10025', 'Ștefania-Ecaterina Ionescu-Țăranu', 'suspended',
      'mitglied'),
  _mitglied(6, 'M10026', 'Friedrich-Wilhelm von Hohenzollern-Sigmaringen',
      'active', 'ehrenmitglied'),
  _mitglied(7, 'M10027', 'Anna-Lena Schmidt-Großkopf', 'gekuendigt',
      'foerdermitglied'),
  _mitglied(8, 'M10028', 'Radu Gheorghe', 'geloescht', 'mitglied'),
  _mitglied(9, 'M10029', 'Bartholomäus Zimmermann-Weißenfels', 'active',
      'mitglied'),
];

/// Der längste Name — er steht danach in der Auswahl und in der Vorschau.
final User _langesMitglied = _mitglieder[5];

const _sachverhalt =
    'Am 14.09.2026 hat das Mitglied in der öffentlichen Gruppe '
    '„Vereinsmitglieder Neu-Ulm/Ulm" vertrauliche Informationen aus der '
    'Vorstandssitzung (Beitragsrückstände einzelner Mitglieder, '
    'Mitgliederverwaltungsangelegenheiten) weitergegeben und trotz '
    'Aufforderung nicht gelöscht.';

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

  group('Ordnungsmaßnahmen mit Mitgliedern', () {
    for (final sprache in kSprachen) {
      for (final fall in kBreiten.entries) {
        testWidgets('läuft ausgefüllt nicht über — ${fall.key} [$sprache]',
            (tester) async {
          tester.view.physicalSize = fall.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          await LanguageService.instance.setLanguage(sprache);

          final ueberlaeufe = <String>[];
          final andere = <String>[];
          final vorher = FlutterError.onError;
          FlutterError.onError = (details) {
            final text = details.toString();
            final m = RegExp(r'overflowed by ([0-9.]+) pixels on the (\w+)')
                .firstMatch(text);
            if (m == null) {
              andere.add(details.exceptionAsString().split('\n').first);
              return;
            }
            final ort = RegExp(r'lib/[\w/]+\.dart:\d+').firstMatch(text);
            ueberlaeufe.add(
                '${m.group(1)} px ${m.group(2)} @ ${ort?.group(0) ?? '?'}');
          };

          /// Nach jedem Schritt: bis hierher kein Überlauf, kein anderer
          /// Layout-Fehler (sonst sind die nächsten Schritte sinnlos).
          void pruefen(String schritt) {
            final wo = 'Ordnungsmaßnahmen auf ${fall.key} [$sprache], $schritt';
            expect(ueberlaeufe, isEmpty,
                reason: '$wo:\n${ueberlaeufe.toSet().join('\n')}');
            expect(andere, isEmpty,
                reason: '$wo:\n${andere.toSet().join('\n')}');
          }

          Future<void> antippen(Finder f) async {
            await tester.ensureVisible(f);
            await tester.pumpAndSettle();
            await tester.tap(f);
            await tester.pumpAndSettle();
          }

          final langerEintrag =
              '${_langesMitglied.name} (${_langesMitglied.mitgliedernummer})';
          try {
            await tester.pumpWidget(_rahmen(
                OrdnungsmassnahmenScreen(users: _mitglieder, onBack: () {}),
                sprache));
            await tester.pumpAndSettle();
            pruefen('geladen');

            // 1. Mitglied: Auswahl öffnen, das mit dem längsten Namen wählen.
            await antippen(find.byType(DropdownButtonFormField<User>));
            await tester.tap(find.text(langerEintrag).last);
            await tester.pumpAndSettle();
            pruefen('Mitglied gewählt');

            // 2. Jede Verstoß-Kategorie einmal (gewählt = fett = breiter).
            for (final v in VerwarnungPdfGenerator.verstossKategorien) {
              await antippen(find.text(v.anzeigeTitel).first);
            }
            // Zuletzt die mit der längsten Rechtsgrundlage.
            await antippen(find
                .text(VerwarnungPdfGenerator.verstossKategorien
                    .firstWhere((v) => v.id == 'vereinsschaedigend')
                    .anzeigeTitel)
                .first);
            pruefen('Verstöße angetippt');

            // 3. Langer Sachverhalt.
            final feld = find.byType(TextField).first;
            await tester.ensureVisible(feld);
            await tester.enterText(feld, _sachverhalt);
            await tester.pumpAndSettle();
            pruefen('Sachverhalt eingetragen');

            // 5. Jede Maßnahme, zuletzt das Ordnungsgeld mit Betragsfeld.
            for (final m in VerwarnungPdfGenerator.massnahmen.reversed) {
              await antippen(find.text(m.anzeigeTitel).first);
            }
            await antippen(find
                .text(VerwarnungPdfGenerator.massnahmen
                    .firstWhere((m) => m.id == 'ordnungsgeld')
                    .anzeigeTitel)
                .first);
            await tester.pump(const Duration(milliseconds: 300));
            pruefen('Maßnahmen gewählt');
          } finally {
            FlutterError.onError = vorher;
          }

          // Die Daten sind wirklich angekommen: Name in Auswahl und Vorschau,
          // Betragsfeld des Ordnungsgelds sichtbar.
          expect(find.text(langerEintrag), findsWidgets);
          expect(find.text('(max. 100 €)'), findsOneWidget);

          // „Ordnungsmaßnahmen" ist ein Wort: es muss ganz in die Kopfzeile
          // passen, nicht mit „…" gekürzt oder mitten im Wort umbrochen.
          final titel = tester.renderObject<RenderParagraph>(find.text(
              sprache == 'de' ? 'Ordnungsmaßnahmen' : 'Măsuri disciplinare'));
          expect(titel.didExceedMaxLines, isFalse,
              reason: 'Titel gekürzt auf ${fall.key} [$sprache]');
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }, skip: _schriftenDa ? false : 'Roboto fehlt unter $_schriften');
}
