// Passen die Bildschirme auf das Telefon der Schatzmeisterin?
//
// Das Geraet ist ein Redmi 21091116UG: 1080x2400 Pixel bei Dichte 2.75,
// also rund 393 x 873 dp. Die App stammt aus der Vorsitzer-App, die zuerst
// fuer Windows gebaut wurde — auf dieser Breite lief einiges ueber.
//
// Flutter meldet einen Ueberlauf im Test als Ausnahme. `takeException()`
// holt sie ab; ist sie null, passt das Layout.
//
// Alle uebrigen Bildschirme pruefen bildschirme_telefon_test.dart (ohne
// Serverdaten) und die test/layout_*_test.dart (mit Daten) — auch das
// Dashboard: layout_dashboard_test.dart baut es mit falschem Server und einer
// WebSocket-Adresse, die sofort scheitert.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:icd360sev_schatzmeister/l10n/app_localizations.dart';
import 'package:icd360sev_schatzmeister/screens/finanzverwaltung_screen.dart';
import 'package:icd360sev_schatzmeister/screens/eigene_unterschriften_screen.dart';
import 'package:icd360sev_schatzmeister/screens/sprachauswahl_screen.dart';
import 'package:icd360sev_schatzmeister/services/api_service.dart';
import 'package:icd360sev_schatzmeister/services/language_service.dart';

/// Die Breiten, die auf Android tatsaechlich vorkommen — in logischen
/// Pixeln (dp), nicht in Hardware-Pixeln.
///
/// Nachgeschlagen statt geraten (Stand 2026):
///   320  aeltere und sehr guenstige Geraete; ruecklaeufig, aber noch da
///   360  schmalste der gaengigen Breiten, u. a. Samsung Galaxy S (Basis)
///   384  Samsung A-Serie und Ultra-Modelle
///   393  Xiaomi Redmi und Poco bei Pixelverhaeltnis 2,75 — das Geraet der
///        Schatzmeisterin (Redmi 21091116UG)
///   412  Motorola Moto G und andere mit geringerer Dichte
///
/// 360, 384 und 412 machen zusammen gut die Haelfte des Verkehrs aus; wer
/// nur auf einer Breite prueft, prueft an der Mehrheit vorbei. 320 steht
/// als haerteste Probe dabei: was dort passt, passt ueberall.
const Map<String, Size> kAndroidBreiten = {
  '320 dp (alt/guenstig)': Size(320, 640),
  '360 dp (Galaxy S)': Size(360, 800),
  '384 dp (Galaxy A)': Size(384, 854),
  '393 dp (Redmi — ihr Geraet)': Size(393, 873),
  '412 dp (Moto G)': Size(412, 915),
};

/// Jede Pruefung laeuft in beiden Sprachen: rumaenische Texte sind oft
/// laenger als die deutschen und laufen auf schmalen Telefonen zuerst ueber.
const kSprachen = ['de', 'ro'];

Widget _rahmen(Widget kind, String sprache) => MaterialApp(
      locale: Locale(sprache),
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

  for (final sprache in kSprachen) {
  for (final fall in kAndroidBreiten.entries) {
    testWidgets('Finanzverwaltung laeuft nicht ueber — ${fall.key} [$sprache]',
        (tester) async {
      tester.view.physicalSize = fall.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await LanguageService.instance.setLanguage(sprache);

      await tester.pumpWidget(_rahmen(const FinanzverwaltungScreen(), sprache));
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
          reason: 'Layout-Ueberlauf auf ${fall.value.width} dp [$sprache]');
    });
  }
  }

  // ⚠️ Der Aktivierungsbildschirm steht bewusst NICHT hier. Er wartet in
  // initState auf die Geraete-Wiederherstellung; im Test antwortet der
  // Plattform-Kanal nie, der Fortschrittsanzeiger bleibt stehen und
  // Schritt 2 mit den Code-Feldern wird nie erreicht. Ein Test, der das
  // nicht bemerkt, ist gruen, ohne etwas geprueft zu haben — genau das war
  // der erste Anlauf hier.
  //
  // Geprueft wurde diese Zeile stattdessen an der laufenden App auf einem
  // 393 dp breiten Bildschirm: vier Felder zu 78 dp plus Trennstriche und
  // Kartenrand ergaben 416 dp und liefen um 88 dp hinaus. Seit sie sich den
  // Platz per Expanded teilen, passt es.

  // Der Unterschriften-Bildschirm. Er laedt beim Oeffnen die Vorgangsliste;
  // ohne Netz bleibt sie leer, das Geruest wird trotzdem aufgebaut — und
  // genau das soll geprueft werden.
  for (final sprache in kSprachen) {
  for (final fall in kAndroidBreiten.entries) {
    testWidgets('Unterschriften laufen nicht ueber — ${fall.key} [$sprache]',
        (tester) async {
      tester.view.physicalSize = fall.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await LanguageService.instance.setLanguage(sprache);

      await tester.pumpWidget(_rahmen(
        EigeneUnterschriftenScreen(apiService: ApiService()),
        sprache,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull,
          reason: 'Layout-Ueberlauf auf ${fall.value.width} dp [$sprache]');
    });
  }
  }

  // Die Sprachauswahl ist der allererste Bildschirm — sie darf auf keiner
  // Breite ueberlaufen. Auf 320 dp rutscht die zweite Kachel in eine eigene
  // Zeile, statt hinauszulaufen.
  for (final fall in kAndroidBreiten.entries) {
    testWidgets('Sprachauswahl laeuft nicht ueber — ${fall.key}',
        (tester) async {
      tester.view.physicalSize = fall.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_rahmen(const SprachauswahlScreen(), 'de'));
      await tester.pump();

      expect(find.text('Română'), findsOneWidget);
      expect(tester.takeException(), isNull,
          reason: 'Layout-Ueberlauf auf ${fall.value.width} dp');
    });
  }
}
