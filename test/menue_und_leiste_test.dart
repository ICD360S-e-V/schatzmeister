// Sichtprüfung der beiden Stellen, die am 2026-08-23 dazugekommen sind:
// die vier neuen Menüeinträge und die Impressumsleiste.
//
// WARUM ALS WIDGET-TEST UND NICHT IM LAUFENDEN PROGRAMM
// Die App startet auf dem Aktivierungsbildschirm; bis zum Dashboard käme man
// nur mit einem echten Aktivierungscode. Diese beiden Bausteine hängen aber
// an keinem Anmeldezustand — sie lassen sich einzeln aufbauen und ansehen.
// Die erzeugten PNGs liegen unter test/bilder/.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icd360sev_schatzmeister/l10n/app_localizations.dart';
import 'package:icd360sev_schatzmeister/widgets/dashboard_sidebar.dart';
import 'package:icd360sev_schatzmeister/widgets/legal_footer.dart';

Widget _rahmen(Widget kind, {Size groesse = const Size(300, 700)}) {
  return MaterialApp(
    locale: const Locale('de'),
    // Dieselben Delegates wie in main.dart. Ohne die globalen fehlen
    // MaterialLocalizations, und schon ein Tooltip wirft.
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('de'), Locale('ro')],
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: groesse.width,
          height: groesse.height,
          child: kind,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('Seitenleiste zeigt alle neun Einträge', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_rahmen(
      DashboardSidebar(
        userName: 'S42759',
        mitgliedernummer: 'S42759',
        selectedMenuIndex: 0,
        onMenuSelected: (_) {},
      ),
    ));
    await tester.pump();

    // Die vier Einträge, die vorher an keinem Menü hingen.
    expect(find.text('Archiv'), findsOneWidget);
    expect(find.text('Routineaufgaben'), findsOneWidget);
    expect(find.text('Statistik'), findsOneWidget);
    expect(find.text('Dienste'), findsOneWidget);

    // Und die fünf, die es schon gab — damit ein Umbau nicht unbemerkt
    // welche verdrängt.
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Finanzverwaltung'), findsOneWidget);
  });

  testWidgets('Auswahl meldet den richtigen Index', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final gewaehlt = <int>[];
    await tester.pumpWidget(_rahmen(
      DashboardSidebar(
        userName: 'S42759',
        mitgliedernummer: 'S42759',
        selectedMenuIndex: 0,
        onMenuSelected: gewaehlt.add,
      ),
    ));
    await tester.pump();

    // Index 5..8 sind die neuen. Ein Tippfehler in der Verdrahtung würde
    // hier auffallen, im Analyse-Lauf dagegen nicht.
    for (final eintrag in {'Archiv': 5, 'Routineaufgaben': 6, 'Statistik': 7, 'Dienste': 8}.entries) {
      await tester.tap(find.text(eintrag.key));
      await tester.pump();
      expect(gewaehlt.last, eintrag.value, reason: eintrag.key);
    }
  });

  // Erzeugt test/bilder/seitenleiste.png. Mit --update-goldens neu schreiben,
  // danach ist die Datei ein Vergleichsbild: eine Umgestaltung, die Einträge
  // verschiebt oder abschneidet, faellt beim naechsten Lauf auf.
  testWidgets('Seitenleiste — Bild', (tester) async {
    tester.view.physicalSize = const Size(300, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_rahmen(
      DashboardSidebar(
        userName: 'S42759',
        mitgliedernummer: 'S42759',
        selectedMenuIndex: 5,
        onMenuSelected: (_) {},
      ),
    ));
    await tester.pump();

    await expectLater(
      find.byType(DashboardSidebar),
      matchesGoldenFile('bilder/seitenleiste.png'),
    );
  });

  // Die Leiste hing bis 2026-08-23 an `bottomNavigationBar: null`. Damit
  // fehlten nicht nur Impressum und Datenschutz — Pflichtangaben —, sondern
  // auch der einzige Aufrufer von `UpdateService.checkForUpdate()`. Der Test
  // haelt beides fest.
  testWidgets('Leiste zeigt Impressum und Datenschutz', (tester) async {
    tester.view.physicalSize = const Size(900, 200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_rahmen(
      const LegalFooter(),
      groesse: const Size(900, 120),
    ));
    await tester.pump();

    expect(find.text('Impressum'), findsOneWidget);
    expect(find.text('Datenschutz'), findsOneWidget);

    // Abbauen, sonst meldet der Testlauf den 5-Minuten-Takt als offenen Timer.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
