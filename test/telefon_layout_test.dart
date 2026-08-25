// Passen die Bildschirme auf das Telefon der Schatzmeisterin?
//
// Das Geraet ist ein Redmi 21091116UG: 1080x2400 Pixel bei Dichte 2.75,
// also rund 393 x 873 dp. Die App stammt aus der Vorsitzer-App, die zuerst
// fuer Windows gebaut wurde — auf dieser Breite lief einiges ueber.
//
// Flutter meldet einen Ueberlauf im Test als Ausnahme. `takeException()`
// holt sie ab; ist sie null, passt das Layout.
//
// ⚠️ Nicht jeder Bildschirm laesst sich so pruefen: DashboardScreen baut in
// initState eine WebSocket-Verbindung auf und scheitert im Test an den
// fehlenden Plattform-Kanaelen, bevor es zum Layout kommt.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:icd360sev_schatzmeister/l10n/app_localizations.dart';
import 'package:icd360sev_schatzmeister/screens/finanzverwaltung_screen.dart';

/// Bildschirm der Schatzmeisterin in logischen Pixeln.
const Size kTelefon = Size(393, 873);

/// Schmaler als das, was im Verein vorkommt — wer hier passt, passt ueberall.
const Size kSchmal = Size(320, 640);

Widget _rahmen(Widget kind) => MaterialApp(
      locale: const Locale('de'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('de'), Locale('ro')],
      home: kind,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final fall in {'Telefon': kTelefon, 'schmal': kSchmal}.entries) {
    testWidgets('Finanzverwaltung laeuft nicht ueber — ${fall.key}',
        (tester) async {
      tester.view.physicalSize = fall.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_rahmen(const FinanzverwaltungScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Vor dieser Pruefung meldete der Bildschirm hier zwei Ueberlaeufe:
      // die Titelzeile mit 79 dp und die Beitragszeile mit 371 dp. Beide
      // kamen von einem Row ohne Expanded.
      // Vor dieser Pruefung meldete der Bildschirm drei Ueberlaeufe:
      // die Titelzeile mit 79 dp, die Beitragszeile mit 371 dp und auf
      // 320 dp der Kennzahl-Chip mit 43 dp. Alle drei kamen daher, dass ein
      // Row seine Kinder ohne Flex nebeneinander stellte.
      expect(tester.takeException(), isNull,
          reason: 'Layout-Ueberlauf auf ${fall.value.width} dp');
    });
  }
}
