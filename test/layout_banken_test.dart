// GLS- und VR-Bank passen sich der Breite an — und der Schreibtisch bleibt,
// wie er war.
//
// Beide Bildschirme sind feste Infoseiten ohne Serverdaten; ob etwas
// überläuft, prüft schon test/bildschirme_telefon_test.dart. Hier geht es um
// die Anordnung: ab 900 dp zwei Karten nebeneinander und die Bezeichnung neben
// dem Wert (wie bisher), auf dem Tablet die Karten untereinander, auf dem
// Telefon zusätzlich die Bezeichnung über dem Wert (die IBAN in einer Zeile).
// Mit der echten Schrift (Roboto) wie im gemeinsamen Test.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:icd360sev_schatzmeister/l10n/app_localizations.dart';
import 'package:icd360sev_schatzmeister/services/language_service.dart';
import 'package:icd360sev_schatzmeister/screens/gls_bank_screen.dart';
import 'package:icd360sev_schatzmeister/screens/vr_bank_screen.dart';

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

class _Bank {
  final Widget Function() bauen;
  final String iban;
  const _Bank(this.bauen, this.iban);
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

  final banken = <String, _Bank>{
    'GLS Bank': _Bank(() => GlsBankScreen(onBack: () {}), 'DE12 4306 0967 1234 5678 00'),
    'VR Bank': _Bank(() => VrBankScreen(onBack: () {}), 'DE89 3704 0044 0532 0130 00'),
  };

  Future<void> aufbauen(WidgetTester tester, Size groesse, Widget kind, String sprache) async {
    tester.view.physicalSize = groesse;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await LanguageService.instance.setLanguage(sprache);
    await tester.pumpWidget(_rahmen(kind, sprache));
    await tester.pump();
  }

  group('GLS-/VR-Bank Anordnung', () {
    for (final bank in banken.entries) {
      for (final sprache in ['de', 'ro']) {
        final konto = find.text(sprache == 'de' ? 'Kontoinformationen' : 'Informații cont');
        final karten = find.text(sprache == 'de' ? 'Karten' : 'Carduri');
        final ibanText = find.text('IBAN');
        final ibanWert = find.text(bank.value.iban);

        testWidgets('${bank.key} 1280 dp [$sprache]: wie bisher nebeneinander', (tester) async {
          await aufbauen(tester, const Size(1280, 800), bank.value.bauen(), sprache);
          final k = tester.getTopLeft(konto), c = tester.getTopLeft(karten);
          expect(c.dy, closeTo(k.dy, 0.5), reason: 'Karten-Karte steht neben Kontoinformationen');
          expect(c.dx, greaterThan(k.dx + 400));
          final t = tester.getTopLeft(ibanText), w = tester.getTopLeft(ibanWert);
          expect(w.dy, closeTo(t.dy, 0.5), reason: 'IBAN-Wert in derselben Zeile wie die Bezeichnung');
          expect(w.dx, closeTo(t.dx + 160, 0.5), reason: 'feste 160-dp-Bezeichnungsspalte wie bisher');
          if (bank.key == 'GLS Bank') {
            final a = tester.getTopLeft(find.text(tr('Erneuerbare Energien', 'Energii regenerabile')));
            final b = tester.getTopLeft(find.text(tr('Soziales & Gesundheit', 'Social și sănătate')));
            expect(b.dy, closeTo(a.dy, 0.5), reason: 'drei Nachhaltigkeits-Kacheln je Zeile');
          }
        });

        testWidgets('${bank.key} 800 dp [$sprache]: Karten untereinander, Bezeichnung neben dem Wert',
            (tester) async {
          await aufbauen(tester, const Size(800, 1280), bank.value.bauen(), sprache);
          final k = tester.getTopLeft(konto), c = tester.getTopLeft(karten);
          expect(c.dx, closeTo(k.dx, 0.5));
          expect(c.dy, greaterThan(k.dy + 200));
          final t = tester.getTopLeft(ibanText), w = tester.getTopLeft(ibanWert);
          expect(w.dy, closeTo(t.dy, 0.5));
          expect(w.dx, closeTo(t.dx + 160, 0.5));
        });

        testWidgets('${bank.key} 393 dp [$sprache]: untereinander, Bezeichnung über dem Wert',
            (tester) async {
          await aufbauen(tester, const Size(393, 873), bank.value.bauen(), sprache);
          final k = tester.getTopLeft(konto), c = tester.getTopLeft(karten);
          expect(c.dx, closeTo(k.dx, 0.5), reason: 'eine Spalte');
          expect(c.dy, greaterThan(k.dy + 200));
          final t = tester.getTopLeft(ibanText), w = tester.getTopLeft(ibanWert);
          expect(w.dx, closeTo(t.dx, 0.5), reason: 'Wert unter der Bezeichnung, linksbündig');
          expect(w.dy, greaterThan(t.dy));
          expect(tester.getSize(ibanWert).height, lessThan(24),
              reason: 'IBAN passt in eine Zeile');
          if (bank.key == 'GLS Bank') {
            final a = tester.getTopLeft(find.text(tr('Erneuerbare Energien', 'Energii regenerabile')));
            final b = tester.getTopLeft(find.text(tr('Soziales & Gesundheit', 'Social și sănătate')));
            expect(b.dy, greaterThan(a.dy), reason: 'zwei Kacheln je Zeile');
          }
        });
      }
    }
  }, skip: _schriftenDa ? false : 'Roboto fehlt unter $_schriften');
}
