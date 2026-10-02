// Passt der Bildschirm Routinenaufgaben MIT DATEN auf jedes Telefon?
//
// test/bildschirme_telefon_test.dart sieht ihn nur leer: ohne Zähler, ohne
// Fortschrittskreis, ohne Kategorie-Filter, ohne eine einzige Aufgabe. Erst
// mit Daten stehen lange Titel, Mitgliedsnamen, Kategorien und Notizen auf
// dem Bildschirm — und in den Dialogen „Routinen verwalten“, „Neue Routine“
// und im Blatt einer Aufgabe. Dort laufen schmale Telefone über.
//
// RoutineService hat keinen Test-Zugang (eigener IOClient). Er baut seinen
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
import 'package:icd360sev_schatzmeister/models/user.dart';
import 'package:icd360sev_schatzmeister/screens/routinenaufgaben_screen.dart';
import 'package:icd360sev_schatzmeister/services/language_service.dart';

/// Telefone wie im gemeinsamen Test, dazu die Übergänge Telefon → Tablet
/// (600), Tablet (800), Schreibtisch knapp über dem Raster (1000) und breit.
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

// ─── Daten: eine volle Woche mit langen Texten ──────────────────────

DateTime get _montag {
  final n = DateTime.now();
  final m = n.subtract(Duration(days: n.weekday - 1));
  return DateTime(m.year, m.month, m.day);
}

String _datum(int tag) {
  final d = _montag.add(Duration(days: tag));
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

const _mitglieder = [
  (1, 'Alexandra-Gabriela Popescu-Constantinescu', 'M10001'),
  (2, 'Maximilian Friedrich von Hohenzollern-Sigmaringen', 'M10002'),
  (3, 'Ștefania Țărănescu', 'M10003'),
];

final List<User> kMitglieder = [
  for (final (id, name, nummer) in _mitglieder)
    User(id: id, mitgliedernummer: nummer, email: 'm$id@example.org', name: name, status: 'active', role: 'mitglied'),
  User(id: 9, mitgliedernummer: 'M10009', email: 'alt@example.org', name: 'Ausgetreten', status: 'deleted', role: 'mitglied'),
];

Map<String, Object?> _ausfuehrung(int id, int tag, String titel, String kategorie, String zeit, int mitglied,
    {String status = 'pending', String? notiz}) {
  final (uid, name, nummer) = _mitglieder[mitglied];
  return {
    'id': id,
    'routine_id': id,
    'scheduled_date': _datum(tag),
    'status': status,
    'notes': notiz,
    'routine_title': titel,
    'routine_category': kategorie,
    'frequency': 'weekly',
    'preferred_time': zeit,
    'user_id': uid,
    'member_name': name,
    'member_nummer': nummer,
  };
}

final List<Map<String, Object?>> kAusfuehrungen = [
  _ausfuehrung(1, 0, 'Jobcenter-Konto prüfen und Nachrichten im Postfach beantworten', 'Jobcenter', '08:30:00', 0,
      notiz: 'Weiterbewilligungsantrag bis Monatsende einreichen, Kontoauszüge der letzten drei Monate beilegen'),
  _ausfuehrung(2, 0, 'Bewerbungen an drei Arbeitgeber schicken', 'Bewerbung', '10:00:00', 1, status: 'done'),
  _ausfuehrung(3, 0, 'Arzttermin vereinbaren', 'Gesundheit', '14:00:00', 2, status: 'skipped', notiz: 'Praxis im Urlaub'),
  _ausfuehrung(4, 1, 'Unterlagen für den Weiterbewilligungsantrag zusammenstellen', 'Dokumente', '09:15:00', 2),
  _ausfuehrung(5, 2, 'Rundfunkbeitrag: Befreiungsantrag stellen', 'Behörden', '11:00:00', 0, status: 'done'),
  _ausfuehrung(6, 2, 'Kontoauszüge prüfen', 'Finanzen', '13:30:00', 1),
  _ausfuehrung(7, 2, 'Rentenversicherung: Kontenklärung beantworten', 'Sozialversicherung und Rentenangelegenheiten', '15:45:00', 2),
  _ausfuehrung(8, 2, 'Verificare cont Jobcenter și răspuns la scrisori', 'Jobcenter', '17:00:00', 2),
  _ausfuehrung(9, 4, 'Wohngeld: Änderungsmitteilung einreichen', 'Behörden', '08:00:00', 1, status: 'done'),
  _ausfuehrung(10, 4, 'Krankenkasse: Bonusheft abstempeln lassen', 'Gesundheit', '16:30:00', 0),
];

final List<Map<String, Object?>> kRoutinen = [
  for (final (i, (titel, haeufigkeit, kategorie)) in [
    ('Jobcenter-Konto prüfen und Nachrichten im Postfach beantworten', 'weekly', 'Jobcenter'),
    ('Bewerbungen an drei Arbeitgeber schicken', 'daily', 'Bewerbung'),
    ('Unterlagen für den Weiterbewilligungsantrag zusammenstellen', 'monthly', 'Dokumente'),
    ('Rentenversicherung: Kontenklärung beantworten', 'yearly', 'Sozialversicherung und Rentenangelegenheiten'),
    ('Verificare cont Jobcenter și răspuns la scrisori', 'weekly', 'Jobcenter'),
  ].indexed)
    {
      'id': i + 1,
      'user_id': _mitglieder[i % 3].$1,
      'title': titel,
      'description': 'Beschreibung $i',
      'frequency': haeufigkeit,
      'day_of_week': haeufigkeit == 'weekly' ? 3 : null,
      'day_of_month': haeufigkeit == 'monthly' || haeufigkeit == 'yearly' ? 15 : null,
      'month_of_year': haeufigkeit == 'yearly' ? 11 : null,
      'category': kategorie,
      'preferred_time': '09:00:00',
      'is_active': i == 2 ? 0 : 1,
      'created_by': 'S1',
      'member_name': _mitglieder[i % 3].$2,
      'member_nummer': _mitglieder[i % 3].$3,
      'created_at': '2026-09-01 10:00:00',
    },
];

/// Antworten wie der Server: routine_executions.php und routine_list.php
/// (Routinen, Kategorien und Statistik kommen aus derselben Liste).
Object? routinenServer(String methode, Uri url) {
  final datei = url.pathSegments.isEmpty ? '' : url.pathSegments.last;
  if (datei == 'routine_executions.php' && methode == 'GET') {
    return {
      'success': true,
      'executions': kAusfuehrungen,
      'stats': {'total': 128, 'done': 64, 'pending': 57, 'skipped': 7},
    };
  }
  if (datei == 'routine_list.php') {
    return {
      'success': true,
      'routines': kRoutinen,
      'categories': ['Jobcenter', 'Bewerbung', 'Dokumente', 'Behörden', 'Gesundheit', 'Finanzen',
          'Sozialversicherung und Rentenangelegenheiten'],
      'stats': {'total_active': 4, 'total_members': 3},
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

/// Rollt die Seite bis ans Ende, damit jede Tageskarte gebaut und gemessen
/// wird (eine ListView baut nur, was in der Nähe des Sichtbaren liegt).
/// Liefert alle Texte, die unterwegs zu sehen waren.
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

Future<void> _aufbauen(WidgetTester tester, Size groesse, String sprache) async {
  tester.view.physicalSize = groesse;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await LanguageService.instance.setLanguage(sprache);
  await tester.pumpWidget(_rahmen(
      RoutinenaufgabenScreen(users: kMitglieder, currentMitgliedernummer: 'S1'), sprache));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _tippen(WidgetTester tester, Finder ziel) async {
  await tester.ensureVisible(ziel);
  await tester.pump();
  await tester.tap(ziel);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(() async {
    HttpOverrides.global = ScheinServer(routinenServer);
    if (!_schriftenDa) return;
    await _laden('Roboto', ['Roboto-Regular.ttf', 'Roboto-Bold.ttf', 'Roboto-Medium.ttf', 'Roboto-Italic.ttf']);
    await _laden('MaterialIcons', ['MaterialIcons-Regular.otf']);
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Routinenaufgaben mit Daten', () {
    for (final sprache in kSprachen) {
      for (final fall in kBreiten.entries) {
        testWidgets('Woche läuft nicht über — ${fall.key} [$sprache]', (tester) async {
          var gesehen = <String>[];
          final fehler = await _sammeln(() async {
            await _aufbauen(tester, fall.value, sprache);
            // Lesbar statt zusammengequetscht: der Titel einer Aufgabe
            // bekommt auf dem Telefon fast die ganze Breite (in fünf
            // Spalten nebeneinander wären es keine 40 dp).
            if (fall.value.width < 600) {
              final titel = find.text('Jobcenter-Konto prüfen und Nachrichten im Postfach beantworten');
              expect(tester.getSize(titel).width, greaterThan(fall.value.width * 0.6));
            }
            gesehen = await _durchrollen(tester);
          });
          // Die Daten sind angekommen: Zähler, alle fünf Tage, die Aufgaben.
          expect(gesehen, containsAll(['128', '64', '57', '50%']));
          expect(gesehen, containsAll([
            tr('Montag', 'Luni'), tr('Dienstag', 'Marți'), tr('Mittwoch', 'Miercuri'),
            tr('Donnerstag', 'Joi'), tr('Freitag', 'Vineri'),
          ]));
          expect(gesehen, contains(tr('Keine Aufgaben', 'Nicio sarcină')));
          expect(gesehen, contains('Krankenkasse: Bonusheft abstempeln lassen'));
          expect(gesehen, contains('Sozialversicherung und Rentenangelegenheiten'));
          await tester.pumpWidget(const SizedBox());
          expect(fehler, isEmpty, reason: '${fall.key} [$sprache]:\n${fehler.toSet().join('\n')}');
        });
      }

      // Auf dem Telefon rollt die ganze Seite. Nach „Erledigt“ lädt der
      // Bildschirm neu; dabei darf die Seite nicht kurz schrumpfen und einen
      // wieder an den Anfang werfen — man arbeitet ja gerade den Mittwoch ab.
      testWidgets('Nach „Erledigt“ bleibt die Seite stehen — 393 dp [$sprache]', (tester) async {
        addTearDown(() => antwortVerzoegerung = Duration.zero);
        await _aufbauen(tester, kBreiten['393 dp (Redmi)']!, sprache);
        ScrollPosition seite() => tester.state<ScrollableState>(find.byType(Scrollable).first).position;
        final karte = find.text('Kontoauszüge prüfen');
        await tester.scrollUntilVisible(karte, 200, scrollable: find.byType(Scrollable).first);
        await tester.pump();
        final vorher = seite().pixels;
        expect(vorher, greaterThan(400));

        antwortVerzoegerung = const Duration(milliseconds: 100);
        await tester.tap(karte);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.descendant(
            of: find.byType(BottomSheet), matching: find.text(tr('Erledigt', 'Finalizat'))));
        final ladeanzeige = find.byWidgetPredicate((w) => w is CircularProgressIndicator && w.value == null);
        var geladen = false;
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 50));
          geladen |= ladeanzeige.evaluate().isNotEmpty;
          expect(seite().pixels, vorher);
        }
        expect(geladen, isTrue, reason: 'die Ladeanzeige war nie zu sehen');
        expect(ladeanzeige, findsNothing);
        expect(find.text('Kontoauszüge prüfen'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });

      for (final breite in ['320 dp', '393 dp (Redmi)', '1280 dp (Schreibtisch)']) {
        testWidgets('Blatt einer erledigten Aufgabe — $breite [$sprache]', (tester) async {
          final fehler = await _sammeln(() async {
            await _aufbauen(tester, kBreiten[breite]!, sprache);
            await _tippen(tester, find.text('Bewerbungen an drei Arbeitgeber schicken'));
          });
          // Erledigt → drei Knöpfe, auch „Zurücksetzen“.
          expect(find.text(tr('Zurücksetzen', 'Resetează')), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
          expect(fehler, isEmpty, reason: '$breite [$sprache]:\n${fehler.toSet().join('\n')}');
        });

        testWidgets('Dialog „Routinen verwalten“ — $breite [$sprache]', (tester) async {
          final fehler = await _sammeln(() async {
            await _aufbauen(tester, kBreiten[breite]!, sprache);
            await _tippen(tester, find.text(tr('Verwalten', 'Administrează')));
          });
          expect(find.text(tr('Routinen verwalten', 'Administrare rutine')), findsOneWidget);
          // Bearbeiten, Aktiv-Schalter und Löschen bleiben an jeder Routine
          // (die Liste baut nur, was ins Fenster passt) …
          final sichtbar = find.byType(ListTile).evaluate().length;
          expect(sichtbar, greaterThan(1));
          expect(find.byType(Switch), findsNWidgets(sichtbar));
          expect(find.byIcon(Icons.edit_outlined), findsNWidgets(sichtbar));
          expect(find.byIcon(Icons.delete_outline), findsNWidgets(sichtbar));
          // … und der Titel bekommt eine lesbare Breite statt einer Spalte
          // von wenigen Buchstaben (mit den Knöpfen rechts daneben blieben
          // ihm auf 320 dp rechnerisch weniger als 0 dp).
          final titel = find.descendant(
              of: find.byType(AlertDialog), matching: find.text(kRoutinen.first['title'] as String));
          expect(tester.getSize(titel).width, greaterThan(120));
          await tester.pumpWidget(const SizedBox());
          expect(fehler, isEmpty, reason: '$breite [$sprache]:\n${fehler.toSet().join('\n')}');
        });

        testWidgets('Dialoge „Neue Routine“ und „Bearbeiten“ — $breite [$sprache]', (tester) async {
          final fehler = await _sammeln(() async {
            await _aufbauen(tester, kBreiten[breite]!, sprache);
            await _tippen(tester, find.text(tr('Neue Routine', 'Rutină nouă')));
            expect(find.text(tr('Neue Routine erstellen', 'Creează rutină nouă')), findsOneWidget);
            await _tippen(tester, find.text(tr('Abbrechen', 'Anulare')));
            await _tippen(tester, find.text(tr('Verwalten', 'Administrează')));
            await _tippen(tester, find.byIcon(Icons.edit_outlined).first);
          });
          expect(find.text(tr('Routine bearbeiten', 'Editează rutina')), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
          expect(fehler, isEmpty, reason: '$breite [$sprache]:\n${fehler.toSet().join('\n')}');
        });
      }
    }
  }, skip: _schriftenDa ? false : 'Roboto fehlt unter $_schriften');
}
