// Passt die Terminverwaltung (Wochenkalender) MIT DATEN auf jedes Telefon?
//
// test/bildschirme_telefon_test.dart sieht sie nur leer. Erst mit Daten
// stehen Termine mit Uhrzeit, Titel und Teilnehmerzahl, ein Urlaubstag und
// ein Feiertag mit langem Namen im Kalender — die Stellen, an denen sieben
// Tagesspalten auf dem Telefon unlesbar schmal würden.
//
// TerminService hat keinen Test-Zugang (eigener IOClient). Er baut seinen
// HttpClient aber über dart:io, und den liefert hier HttpOverrides — der
// Dienst selbst bleibt unverändert.
//
// Mit der echten Schrift (Roboto), wie im gemeinsamen Test.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:icd360sev_schatzmeister/l10n/app_localizations.dart';
import 'package:icd360sev_schatzmeister/screens/terminverwaltung_screen.dart';
import 'package:icd360sev_schatzmeister/services/language_service.dart';

/// Telefone wie im gemeinsamen Test, dazu die Übergänge Telefon → Tablet
/// (600), Tablet (800), Schreibtisch mit Seitenleiste (1000) und breit.
const Map<String, Size> kBreiten = {
  '320 dp': Size(320, 640),
  '360 dp': Size(360, 800),
  '393 dp (Redmi)': Size(393, 873),
  '412 dp': Size(412, 915),
  '600 dp': Size(600, 960),
  '800 dp (Tablet)': Size(800, 1280),
  '1000 dp': Size(1000, 800),
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

// ─── Schein-Server über dart:io ─────────────────────────────────────

/// Beantwortet jede Anfrage (Methode, URL) mit einem JSON-Objekt.
typedef Beantworter = Object? Function(String methode, Uri url);

/// So lange lässt der Schein-Server mit der Antwort warten (Vorgabe: gar
/// nicht). Mit Verzögerung ist die Ladeanzeige mindestens ein Bild lang
/// zu sehen — sonst wäre alles schon vor dem nächsten Bild geladen.
Duration antwortVerzoegerung = Duration.zero;

/// Liefert jedem `HttpClient()` einen Client, der nie ins Netz geht.
class ScheinServer extends HttpOverrides {
  ScheinServer(this.antwort);
  final Beantworter antwort;

  @override
  HttpClient createHttpClient(SecurityContext? context) => _ScheinClient(antwort);
}

class _ScheinClient implements HttpClient {
  _ScheinClient(this.antwort);
  final Beantworter antwort;

  // ApiService setzt beim Bau Zeitgrenzen (HttpClientFactory).
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _ScheinAnfrage(antwort, method, url);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ScheinAnfrage implements HttpClientRequest {
  _ScheinAnfrage(this.antwort, this.method, this.uri);
  final Beantworter antwort;
  @override
  final String method;
  @override
  final Uri uri;
  @override
  final HttpHeaders headers = _ScheinKopf();
  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  int contentLength = -1;
  @override
  bool persistentConnection = true;

  @override
  Future<void> addStream(Stream<List<int>> stream) => stream.drain<void>();

  @override
  Future<HttpClientResponse> close() async {
    if (antwortVerzoegerung > Duration.zero) await Future<void>.delayed(antwortVerzoegerung);
    return _ScheinAntwort(utf8.encode(jsonEncode(antwort(method, uri) ?? {'success': false})));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ScheinAntwort extends Stream<List<int>> implements HttpClientResponse {
  _ScheinAntwort(this._inhalt);
  final List<int> _inhalt;

  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream<List<int>>.value(_inhalt).listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  final HttpHeaders headers = _ScheinKopf();
  @override
  int get statusCode => 200;
  @override
  int get contentLength => _inhalt.length;
  @override
  bool get isRedirect => false;
  @override
  List<RedirectInfo> get redirects => const [];
  @override
  bool get persistentConnection => false;
  @override
  String get reasonPhrase => 'OK';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ScheinKopf implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  // UTF-8 ansagen, sonst liest package:http den Text als Latin-1.
  @override
  void forEach(void Function(String name, List<String> values) action) =>
      action('content-type', ['application/json; charset=utf-8']);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ─── Daten: eine Woche mit Terminen, Urlaub und Feiertag ────────────

DateTime get _montag {
  final n = DateTime.now();
  final m = n.subtract(Duration(days: n.weekday - 1));
  return DateTime(m.year, m.month, m.day);
}

String _datum(int tag) {
  final d = _montag.add(Duration(days: tag));
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

Map<String, Object?> _termin(int id, int tag, String uhrzeit, int minuten, String titel, String kategorie,
        {int? teilnehmer, int? zugesagt}) =>
    {
      'id': id,
      'title': titel,
      'category': kategorie,
      'description': 'Tagesordnung folgt',
      'termin_date': '${_datum(tag)} $uhrzeit:00',
      'duration_minutes': minuten,
      'location': 'Vereinsheim, Großer Saal',
      'created_by': 1,
      'created_by_name': 'Vorsitzer',
      'status': 'scheduled',
      'created_at': '2026-09-01 10:00:00',
      'total_participants': teilnehmer,
      'confirmed_count': zugesagt,
    };

final List<Map<String, Object?>> kTermine = [
  _termin(1, 0, '09:00', 120, 'Vorstandssitzung: Haushaltsplan 2027 und Mitgliedsbeiträge', 'vorstandssitzung',
      teilnehmer: 7, zugesagt: 5),
  _termin(2, 0, '15:30', 30, 'Rückruf Steuerberaterin', 'sonstiges'),
  _termin(3, 2, '14:30', 90, 'Schulung Datenschutz für ehrenamtliche Helferinnen und Helfer', 'schulung',
      teilnehmer: 24, zugesagt: 18),
  _termin(4, 4, '10:00', 60, 'Adunarea generală extraordinară a membrilor asociației', 'mitgliederversammlung',
      teilnehmer: 120, zugesagt: 87),
  _termin(5, 6, '16:00', 60, 'Jahresabschluss: Belege an die Kassenprüfer übergeben', 'sonstiges'),
];

/// Antworten wie der Server: my_termine.php, urlaub_list.php, feiertage_list.php.
Object? termineServer(String methode, Uri url) {
  final datei = url.pathSegments.isEmpty ? '' : url.pathSegments.last;
  switch (datei) {
    case 'my_termine.php':
      return {'success': true, 'termine': kTermine};
    case 'urlaub_list.php':
      return {
        'success': true,
        'urlaub': [
          {'id': 1, 'start_date': _datum(1), 'end_date': _datum(1), 'beschreibung': 'Urlaub'},
        ],
      };
    case 'feiertage_list.php':
      return {
        'success': true,
        'feiertage': [
          {'datum': _datum(3), 'name': 'Tag der Deutschen Einheit (gesetzlicher Feiertag in allen Bundesländern)'},
        ],
      };
  }
  return {'success': true};
}

// ─── Prüfen ─────────────────────────────────────────────────────────

/// Fängt Überläufe (und jeden anderen Fehler) ab, solange [schritt] läuft.
Future<List<String>> _sammeln(Future<void> Function() schritt) async {
  final fehler = <String>[];
  final vorher = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.toString();
    final m = RegExp(r'overflowed by ([0-9.]+) pixels on the (\w+)').firstMatch(text);
    final ort = RegExp(r'lib/[\w/]+\.dart:\d+').firstMatch(text);
    fehler.add(m == null
        ? 'Fehler: ${details.exceptionAsString()}'
        : '${m.group(1)} px ${m.group(2)} @ ${ort?.group(0) ?? '?'}');
  };
  try {
    await schritt();
  } finally {
    FlutterError.onError = vorher;
  }
  return fehler;
}

/// Rollt die Tagesliste bis ans Ende, damit jeder Tag gebaut und gemessen
/// wird (eine ListView baut nur, was in der Nähe des Sichtbaren liegt).
Future<List<String>> _durchrollen(WidgetTester tester) async {
  final gesehen = <String>[];
  final rollbar = find.byType(Scrollable);
  if (rollbar.evaluate().isEmpty) return gesehen;
  final position = tester.state<ScrollableState>(rollbar.first).position;
  for (var i = 0; i < 80; i++) {
    gesehen.addAll(find.byType(Text).evaluate().map((e) => (e.widget as Text).data ?? ''));
    if (position.pixels >= position.maxScrollExtent) break;
    position.jumpTo((position.pixels + 300).clamp(0, position.maxScrollExtent));
    await tester.pump();
  }
  return gesehen;
}

void main() {
  setUpAll(() async {
    HttpOverrides.global = ScheinServer(termineServer);
    if (!_schriftenDa) return;
    await _laden('Roboto', ['Roboto-Regular.ttf', 'Roboto-Bold.ttf', 'Roboto-Medium.ttf', 'Roboto-Italic.ttf']);
    await _laden('MaterialIcons', ['MaterialIcons-Regular.otf']);
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Terminverwaltung mit Daten', () {
    for (final sprache in kSprachen) {
      for (final fall in kBreiten.entries) {
        testWidgets('Woche läuft nicht über — ${fall.key} [$sprache]', (tester) async {
          tester.view.physicalSize = fall.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          await LanguageService.instance.setLanguage(sprache);

          var gesehen = <String>[];
          final fehler = await _sammeln(() async {
            await tester.pumpWidget(
                _rahmen(const TerminverwaltungScreen(currentMitgliedernummer: 'S1'), sprache));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            gesehen = await _durchrollen(tester);
          });

          // Alle sieben Tage, Urlaub, Feiertag und die Termine stehen da —
          // auf dem Telefon untereinander, sonst als Spalten.
          final l = AppLocalizations(Locale(sprache));
          for (final tag in [l.monday, l.tuesday, l.wednesday, l.thursday, l.friday, l.saturday, l.sunday]) {
            expect(gesehen, contains(tag), reason: tag);
          }
          expect(gesehen, contains(l.vacation));
          expect(gesehen, contains(l.holiday));
          expect(gesehen, contains(startsWith('Tag der Deutschen Einheit')));
          expect(gesehen, contains(startsWith('Vorstandssitzung')));
          expect(gesehen, contains(startsWith('Jahresabschluss')));

          await tester.pumpWidget(const SizedBox());
          expect(fehler, isEmpty, reason: '${fall.key} [$sprache]:\n${fehler.toSet().join('\n')}');
        });
      }

      // Auf dem Telefon rollt die Woche als lange Liste. Das Nachladen (alle
      // 30 Sekunden, oder „Aktualisieren“) ersetzt sie kurz durch die
      // Ladeanzeige — danach muss sie an derselben Stelle stehen, nicht
      // wieder beim Montag.
      testWidgets('Nachladen springt nicht an den Anfang — 393 dp [$sprache]', (tester) async {
        tester.view.physicalSize = kBreiten['393 dp (Redmi)']!;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        addTearDown(() => antwortVerzoegerung = Duration.zero);
        await LanguageService.instance.setLanguage(sprache);
        await tester.pumpWidget(
            _rahmen(const TerminverwaltungScreen(currentMitgliedernummer: 'S1'), sprache));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        ScrollPosition liste() => tester.state<ScrollableState>(find.byType(Scrollable).first).position;
        liste().jumpTo(1200);
        await tester.pump();
        expect(liste().pixels, 1200);

        antwortVerzoegerung = const Duration(milliseconds: 100);
        await tester.tap(find.byIcon(Icons.refresh));
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(Scrollable), findsNothing);

        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(liste().pixels, 1200);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }, skip: _schriftenDa ? false : 'Roboto fehlt unter $_schriften');
}
