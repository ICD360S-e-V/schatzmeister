// Handelsregister MIT Suchergebnissen auf Telefon, Tablet und Schreibtisch.
//
// bildschirme_telefon_test.dart sieht nur die leere Suchmaske. Die Treffer-
// karten (lange Firmennamen, Gericht, Register-Nr., Dokument-Chips) und die
// Trefferzahl im Kopf der Ergebnisse entstehen erst nach einer Suche.
// HandelsregisterClientService spricht handelsregister.de direkt über
// dart:io an; hier antwortet über HttpOverrides eine vorgetäuschte Seite
// (ViewState + Ergebnistabelle, wie der Dienst sie ausliest) — der Dienst
// selbst bleibt unverändert. Gemessen mit Roboto, wie dort.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icd360sev_schatzmeister/l10n/app_localizations.dart';
import 'package:icd360sev_schatzmeister/screens/handelsregister_screen.dart';
import 'package:icd360sev_schatzmeister/services/api_service.dart';
import 'package:icd360sev_schatzmeister/services/language_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Map<String, Size> kBreiten = {
  '320 dp': Size(320, 640),
  '360 dp': Size(360, 800),
  '393 dp (Redmi)': Size(393, 873),
  '412 dp': Size(412, 915),
  '800 dp (Tablet)': Size(800, 1280),
  '1280 dp (Schreibtisch)': Size(1280, 800),
};

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

const _langerName = 'Schwäbische Präzisionsmaschinenbau- und Verwaltungsgesellschaft '
    'mit beschränkter Haftung & Co. Kommanditgesellschaft';

/// Eine Seite für jede Anfrage: ViewState (Schritte 1–3) und die
/// Ergebnistabelle (table[role=grid] tr[data-ri], fünf Zellen).
const _seite = '''
<html><body>
<form id="ergebnissForm" action="/rp_web/ergebnisse.xhtml">
<input type="hidden" name="javax.faces.ViewState" value="TEST-VIEWSTATE" />
</form>
<table role="grid"><tbody>
<tr data-ri="0"><td>1</td><td>Bayern Amtsgericht Memmingen VR 201335</td>
<td>ICD360S e.V. – Internationale Gemeinschaft für Digitalisierung, Integration und soziale Teilhabe</td>
<td>Neu-Ulm</td><td>aktuell eingetragen</td></tr>
<tr data-ri="1"><td>2</td><td>Baden-Württemberg Amtsgericht Stuttgart HRB 765432</td>
<td>$_langerName</td>
<td>Stuttgart-Bad Cannstatt</td><td>aktuell eingetragen</td></tr>
<tr data-ri="2"><td>3</td><td>Nordrhein-Westfalen Amtsgericht Düsseldorf HRB 123456</td>
<td>Rheinisch-Westfälische Wasserversorgungs- und Abwasserentsorgungsgesellschaft mbH</td>
<td>Düsseldorf</td><td>gelöscht</td></tr>
</tbody></table>
</body></html>
''';

class _Client implements HttpClient {
  @override
  String? userAgent;
  @override
  Duration? connectionTimeout;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _Anfrage();
  @override
  Future<HttpClientRequest> postUrl(Uri url) async => _Anfrage();
  @override
  void close({bool force = false}) {}
  // Weitere Einstellungen (Zeitlimits usw.) sind hier ohne Belang.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      invocation.isSetter ? null : super.noSuchMethod(invocation);
}

class _Anfrage implements HttpClientRequest {
  @override
  final HttpHeaders headers = _Kopf();
  @override
  bool followRedirects = true;
  @override
  void write(Object? object) {}
  @override
  Future<HttpClientResponse> close() async => _Antwort();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Kopf implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  String? value(String name) => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Antwort extends Stream<List<int>> implements HttpClientResponse {
  @override
  int get statusCode => 200;
  @override
  bool get isRedirect => false;
  @override
  final HttpHeaders headers = _Kopf();
  @override
  List<Cookie> get cookies => const [];
  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream<List<int>>.fromIterable([utf8.encode(_seite)])
          .listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Lässt jede senkrechte Liste einmal von oben bis unten laufen: eine
/// ListView baut nur, was zu sehen ist — ein Überlauf weiter unten fiele
/// sonst nicht auf.
Future<void> _durchscrollen(WidgetTester tester) async {
  final listen = find
      .byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down)
      .evaluate()
      .map((e) => (e as StatefulElement).state as ScrollableState)
      .toList();
  for (final liste in listen) {
    if (!liste.mounted) continue;
    final pos = liste.position;
    // Zusammengedrückte Liste (Höhe 0): nichts zu sehen, nichts zu scrollen.
    if (pos.viewportDimension < 1) continue;
    for (var i = 0, p = 0.0; i < 100; i++, p += pos.viewportDimension / 2) {
      pos.jumpTo(p.clamp(0.0, pos.maxScrollExtent));
      await tester.pump();
      if (p >= pos.maxScrollExtent) break;
    }
    pos.jumpTo(0);
    await tester.pump();
  }
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

  group('Handelsregister mit Treffern', () {
    for (final sprache in ['de', 'ro']) {
      for (final fall in kBreiten.entries) {
        testWidgets('Suche und Trefferkarten — ${fall.key} [$sprache]', (tester) async {
          tester.view.physicalSize = fall.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          await LanguageService.instance.setLanguage(sprache);

          final ueberlaeufe = <String>{};
          final gesehen = <String>[];
          final vorher = FlutterError.onError;
          FlutterError.onError = (details) {
            final text = details.toString();
            final m = RegExp(r'overflowed by ([0-9.]+) pixels on the (\w+)').firstMatch(text);
            if (m == null) {
              vorher?.call(details);
              return;
            }
            final ort = RegExp(r'lib/[\w/]+\.dart:\d+').firstMatch(text);
            ueberlaeufe.add('${m.group(1)} px ${m.group(2)} @ ${ort?.group(0) ?? '?'}');
          };
          // Außerhalb der vorgetäuschten Seite anlegen: ApiService baut sich
          // beim ersten Aufruf einen eigenen HTTP-Client.
          final api = ApiService();
          try {
            await HttpOverrides.runZoned(() async {
              await tester.pumpWidget(_rahmen(
                  HandelsregisterScreen(apiService: api, onBack: () {}), sprache));
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 300));
              await _durchscrollen(tester);

              // Registernummer eintragen und suchen.
              await tester.enterText(find.byType(TextField).first, '201335');
              // Das Feld scrollt sich animiert ins Bild; solange eine Liste
              // scrollt, nimmt sie keine Tipps an.
              await tester.pump(const Duration(milliseconds: 500));
              final suchen = find.byWidgetPredicate((w) => w is ElevatedButton);
              await tester.ensureVisible(suchen);
              await tester.pump(const Duration(milliseconds: 500));
              await tester.tap(suchen);
              // Der Dienst wartet zwischen den Schritten je 0,5 s.
              for (var i = 0; i < 10; i++) {
                await tester.pump(const Duration(milliseconds: 300));
              }
              await _durchscrollen(tester);

              // Erst wenn die gelieferten Treffer wirklich dastehen, zählt der Test.
              final liste = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);
              for (final wert in [
                tr('3 Treffer', '3 rezultate găsite'),
                'ICD360S e.V. – Internationale Gemeinschaft für Digitalisierung, Integration und soziale Teilhabe',
                _langerName,
                'Rheinisch-Westfälische Wasserversorgungs- und Abwasserentsorgungsgesellschaft mbH',
              ]) {
                for (var i = 0; i < 30 && find.text(wert).evaluate().isEmpty; i++) {
                  await tester.drag(liste.first, const Offset(0, -200));
                  await tester.pump();
                }
                if (find.text(wert).evaluate().isNotEmpty) gesehen.add(wert);
              }
            }, createHttpClient: (_) => _Client());
          } finally {
            FlutterError.onError = vorher;
          }
          await tester.pumpWidget(const SizedBox());

          expect(gesehen, hasLength(4), reason: 'die gelieferten Treffer müssen zu sehen sein: $gesehen');
          expect(ueberlaeufe, isEmpty, reason: '${fall.key} [$sprache]:\n${ueberlaeufe.join('\n')}');
        });
      }
    }
  }, skip: _schriftenDa ? false : 'Roboto fehlt unter $_schriften');
}
