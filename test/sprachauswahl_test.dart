// Sprachauswahl Deutsch / Rumänisch beim ersten Start.
//
// Die Schatzmeisterin liest lieber Rumänisch, ihr Telefon steht aber auf
// Deutsch. Vorher folgte das Portal stur der Geräteeinstellung; jetzt wird
// beim ersten Start gewählt, und die Wahl bleibt gespeichert.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:icd360sev_schatzmeister/main.dart';
import 'package:icd360sev_schatzmeister/screens/login_with_code_screen.dart';
import 'package:icd360sev_schatzmeister/screens/sprachauswahl_screen.dart';
import 'package:icd360sev_schatzmeister/services/language_service.dart';
import 'package:icd360sev_schatzmeister/services/notification_service.dart';
import 'package:icd360sev_schatzmeister/widgets/flagge.dart';

/// Ein Text, der nur über tr() übersetzt ist und als const eingehängt wird —
/// genau der Fall, den ein bloßes setState im MaterialApp nicht erreicht.
class _NurTr extends StatelessWidget {
  const _NurTr();

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Text(tr('Speichern', 'Salvează')));
}

Future<void> _starten(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  LanguageService.instance.resetForTest();
  await LanguageService.instance.load();
}

void main() {
  testWidgets('erster Start: Sprachauswahl mit deutscher und rumänischer Flagge',
      (tester) async {
    await _starten({});
    await tester.pumpWidget(const SchatzmeisterApp());
    await tester.pump();

    expect(find.byType(SprachauswahlScreen), findsOneWidget);
    expect(find.byType(LoginWithCodeScreen), findsNothing);
    expect(find.text('Deutsch'), findsOneWidget);
    expect(find.text('Română'), findsOneWidget);
    expect(find.byType(Flagge), findsNWidgets(2));
    // Ohne Zurück-Knopf: der erste Start lässt sich nicht überspringen.
    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });

  testWidgets('Rumänisch wählen: gespeichert, Oberfläche auf Rumänisch, weiter zur Aktivierung',
      (tester) async {
    await _starten({});
    await tester.pumpWidget(const SchatzmeisterApp());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('sprache_ro')));
    // Kein pumpAndSettle: die Aktivierung zeigt einen endlosen
    // Fortschrittsanzeiger, solange sie das (im Test stumme) Netz fragt.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(SprachauswahlScreen), findsNothing);
    expect(find.byType(LoginWithCodeScreen), findsOneWidget);
    expect(LanguageService.instance.currentCode, 'ro');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_locale_v1'), 'ro');
    final ctx = tester.element(find.byType(LoginWithCodeScreen));
    expect(Localizations.localeOf(ctx).languageCode, 'ro');
  });

  testWidgets('gespeicherte Wahl: keine Auswahl mehr, gleich Rumänisch',
      (tester) async {
    await _starten({'app_locale_v1': 'ro'});
    await tester.pumpWidget(const SchatzmeisterApp());
    await tester.pump();

    expect(find.byType(SprachauswahlScreen), findsNothing);
    expect(find.byType(LoginWithCodeScreen), findsOneWidget);
    final ctx = tester.element(find.byType(LoginWithCodeScreen));
    expect(Localizations.localeOf(ctx).languageCode, 'ro');
  });

  testWidgets('Wechsel zeichnet auch konstante tr()-Texte neu', (tester) async {
    await _starten({'app_locale_v1': 'de'});
    await tester.pumpWidget(const SchatzmeisterApp());
    await tester.pump();

    NotificationService.navigatorKey.currentState!
        .push(MaterialPageRoute(builder: (_) => const _NurTr()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Speichern'), findsOneWidget);

    await LanguageService.instance.setLanguage('ro');
    await tester.pump();
    expect(find.text('Salvează'), findsOneWidget);
    expect(find.text('Speichern'), findsNothing);

    await LanguageService.instance.setLanguage('de');
    await tester.pump();
    expect(find.text('Speichern'), findsOneWidget);
  });

  testWidgets('von der Aktivierung geöffnet: Zurück-Knopf, schließt sich nach der Wahl',
      (tester) async {
    await _starten({'app_locale_v1': 'de'});
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.push(MaterialPageRoute(
        builder: (_) => const SprachauswahlScreen(allowBack: true)));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.byTooltip('Zurück'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sprache_ro')));
    await tester.pumpAndSettle();
    expect(find.byType(SprachauswahlScreen), findsNothing);
    expect(LanguageService.instance.currentCode, 'ro');
  });

  testWidgets('Flaggen sind wirklich gefüllt: drei Streifen in voller Größe',
      (tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Flagge(code: 'de', breite: 64),
          Flagge(code: 'ro', breite: 64),
        ]),
      ),
    ));
    // Ein ColoredBox ohne Kind bleibt quer zur Streifenrichtung 0 breit,
    // wenn niemand ihn streckt — die Flagge war dann unsichtbar.
    final streifen = find.byType(ColoredBox);
    expect(streifen, findsNWidgets(6));
    for (final e in streifen.evaluate()) {
      final groesse = tester.getSize(find.byWidget(e.widget));
      expect(groesse.width * groesse.height, greaterThan(0));
    }
    // Deutschland waagerecht: volle Breite, ein Drittel Höhe.
    expect(tester.getSize(streifen.at(0)), const Size(64, 16));
    // Rumänien senkrecht: ein Drittel Breite, volle Höhe.
    expect(tester.getSize(streifen.at(3)).height, 48);
    expect(tester.getSize(streifen.at(3)).width, closeTo(64 / 3, 0.01));
  });

  test('tr() folgt der gewählten Sprache, unbekannte Codes fallen auf Deutsch',
      () async {
    await _starten({});
    expect(LanguageService.instance.hasUserChoice, isFalse);
    expect(tr('Ja', 'Da'), 'Ja');
    await LanguageService.instance.setLanguage('ro');
    expect(tr('Ja', 'Da'), 'Da');
    await LanguageService.instance.setLanguage('fr');
    expect(LanguageService.instance.currentCode, 'de');
    expect(tr('Ja', 'Da'), 'Ja');
  });
}
