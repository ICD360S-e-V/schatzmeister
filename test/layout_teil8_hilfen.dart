// Gemeinsame Werkzeuge der Layout-Tests von Teil 8 (Dashboard, Profil,
// Chat-Dialoge, eingehender Anruf). Keine Testdatei — sie wird von den
// layout_*_test.dart-Dateien eingebunden.
//
// ⚠️ Mit der echten Schrift (Roboto), nicht mit der Testschrift: in der
// zeichnet flutter_test jede Glyphe als 1-em-Quadrat, Texte werden dadurch
// viel breiter als auf dem Gerät (wie test/bildschirme_telefon_test.dart).
//
// ⚠️ Der falsche Server unten ersetzt NUR im Test den HttpClient von dart:io
// (HttpOverrides). An den Diensten ändert sich nichts: Verwarnungen,
// Dokumente, Termine, Wetter usw. bauen ihren Client selbst
// (`IOClient(HttpClient())`) und haben keine Test-Naht — über HttpOverrides
// bekommen sie trotzdem echte JSON-Antworten statt der leeren 400 von
// flutter_test.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:icd360sev_schatzmeister/l10n/app_localizations.dart';
import 'package:icd360sev_schatzmeister/services/device_key_service.dart';

/// Android-Telefone, ein Tablet und der Schreibtisch — dort soll alles
/// bleiben, wie es war.
const Map<String, Size> kBreitenTeil8 = {
  '320 dp': Size(320, 640),
  '360 dp': Size(360, 800),
  '393 dp (Redmi)': Size(393, 873),
  '412 dp': Size(412, 915),
  '800 dp (Tablet)': Size(800, 1280),
  '1280 dp (Schreibtisch)': Size(1280, 800),
};

const kSprachenTeil8 = ['de', 'ro'];

final String _schriften =
    '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
final bool schriftenDa = File('$_schriften/Roboto-Regular.ttf').existsSync();

Future<void> _laden(String familie, List<String> dateien) async {
  final loader = FontLoader(familie);
  for (final d in dateien) {
    loader.addFont(Future.value(
        ByteData.sublistView(File('$_schriften/$d').readAsBytesSync())));
  }
  await loader.load();
}

/// Roboto und die Material-Symbole laden (einmal je Testdatei).
Future<void> schriftenLaden() async {
  if (!schriftenDa) return;
  await _laden('Roboto', [
    'Roboto-Regular.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Italic.ttf',
  ]);
  await _laden('MaterialIcons', ['MaterialIcons-Regular.otf']);
}

/// Ein aktiviertes Gerät, wie nach der Aktivierung per Code: ohne
/// Geräteschlüssel verweigert ApiService jede Anfrage („Device not
/// registered"), und die Bildschirme blieben leer.
Future<void> geraetAktivieren() async {
  FlutterSecureStorage.setMockInitialValues(
      {'device_key': 'test-geraeteschluessel', 'device_id': 'test-geraet'});
  await DeviceKeyService().loadStoredDeviceKey();
}

/// Wartet, bis [f] — ein Wert aus den eingespeisten Daten — auf dem
/// Bildschirm steht, und verlangt ihn. So kann kein Fall auf einem leeren
/// Bildschirm grün werden (ohne Geräteschlüssel oder bei falscher
/// Antwortform zeigte der Bildschirm still seinen Leerzustand).
Future<void> bisSichtbar(WidgetTester tester, Finder f, {String? grund}) async {
  for (var i = 0; i < 30 && f.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(f, findsWidgets, reason: grund ?? 'eingespeiste Daten fehlen');
}

/// Dieselben Delegates wie in main.dart.
Widget rahmenApp(Widget home, String sprache) => MaterialApp(
      locale: Locale(sprache),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('de'), Locale('ro')],
      // Wie main.dart (auf Android ohne eigene Schrift).
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4a90d9),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: home,
    );

/// Sammelt jeden Überlauf mit der Codezeile, die ihn verursacht.
class UeberlaufFaenger {
  final ueberlaeufe = <String>[];
  FlutterExceptionHandler? _vorher;

  void an() {
    _vorher = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.toString();
      final m = RegExp(r'overflowed by ([0-9.]+) pixels on the (\w+)')
          .firstMatch(text);
      if (m == null) {
        // Alles andere ist kein Layout-Befund — an den Test weiterreichen.
        _vorher?.call(details);
        return;
      }
      final ort = RegExp(r'lib/[\w/]+\.dart:\d+').firstMatch(text);
      ueberlaeufe.add(
          '${m.group(1)} px ${m.group(2)} @ ${ort?.group(0) ?? '?'}');
    };
  }

  void aus() {
    FlutterError.onError = _vorher;
  }
}

/// Eine Antwort des falschen Servers: Status und JSON-Rumpf.
typedef Antwort = ({int status, Object json});

/// Ermittelt die Antwort zu einer Anfrage; `null` = „nichts Besonderes".
typedef Antworter = Antwort? Function(String methode, Uri url, String rumpf);

const Antwort kLeer = (status: 200, json: {'success': false, 'message': 'test'});

http.Response _alsResponse(Antwort a) => http.Response(
      jsonEncode(a.json),
      a.status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// MockClient für `ApiService().testClient` / `TicketService().testClient`.
http.Client mockClient(Antworter antworter) => MockClient((anfrage) async =>
    _alsResponse(antworter(anfrage.method, anfrage.url, anfrage.body) ?? kLeer));

/// Ersetzt im Test den HttpClient von dart:io.
///
/// Anfragen an [wsHost] (die WebSocket-Adresse, siehe ChatService.testWsUrl)
/// scheitern sofort mit SocketException — so wie ohne Netz. Ohne das liefe
/// der Aufstieg zum WebSocket gegen die 400-Attrappe von flutter_test und
/// hinterliesse einen unbehandelten Fehler.
class FalscherServer extends HttpOverrides {
  FalscherServer(this.antworter, {this.wsHost = 'ws.test'});
  final Antworter antworter;
  final String wsHost;

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _FalscherClient(this);
}

class _FalscherClient implements HttpClient {
  _FalscherClient(this._server);
  final FalscherServer _server;

  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  int? maxConnectionsPerHost;
  @override
  String? userAgent;
  @override
  bool Function(X509Certificate cert, String host, int port)?
      badCertificateCallback;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    if (url.host == _server.wsHost) {
      throw const SocketException('kein Netz im Test');
    }
    return _FalscheAnfrage(method, url, _server.antworter);
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);
  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);
  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);
  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => openUrl('DELETE', url);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FalscheKoepfe implements HttpHeaders {
  final _werte = <String, List<String>>{};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) =>
      _werte[name.toLowerCase()] = ['$value'];
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) =>
      (_werte[name.toLowerCase()] ??= []).add('$value');
  @override
  List<String>? operator [](String name) => _werte[name.toLowerCase()];
  @override
  String? value(String name) => _werte[name.toLowerCase()]?.join(',');
  @override
  void forEach(void Function(String name, List<String> values) action) =>
      _werte.forEach(action);
  @override
  void removeAll(String name) => _werte.remove(name.toLowerCase());
  @override
  ContentType? contentType;
  @override
  bool chunkedTransferEncoding = false;
  @override
  int contentLength = -1;
  @override
  bool persistentConnection = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FalscheAnfrage implements HttpClientRequest {
  _FalscheAnfrage(this.method, this.uri, this._antworter);
  final Antworter _antworter;
  final _rumpf = BytesBuilder();

  @override
  final String method;
  @override
  final Uri uri;
  @override
  final HttpHeaders headers = _FalscheKoepfe();
  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  int contentLength = -1;
  @override
  bool persistentConnection = true;
  @override
  bool bufferOutput = true;
  @override
  Encoding encoding = utf8;

  @override
  void add(List<int> data) => _rumpf.add(data);
  @override
  void write(Object? object) => _rumpf.add(utf8.encode('$object'));
  @override
  Future<void> addStream(Stream<List<int>> stream) => stream.forEach(_rumpf.add);
  @override
  Future<void> flush() async {}

  @override
  Future<HttpClientResponse> close() async {
    final a = _antworter(method, uri, utf8.decode(_rumpf.takeBytes())) ?? kLeer;
    return _FalscheAntwort(a.status, utf8.encode(jsonEncode(a.json)));
  }

  @override
  Future<HttpClientResponse> get done => close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FalscheAntwort extends Stream<List<int>> implements HttpClientResponse {
  _FalscheAntwort(this.statusCode, this._bytes) {
    headers.set('content-type', 'application/json; charset=utf-8');
  }
  final List<int> _bytes;

  @override
  final int statusCode;
  @override
  final HttpHeaders headers = _FalscheKoepfe();
  @override
  String get reasonPhrase => statusCode == 200 ? 'OK' : 'Fehler';
  @override
  int get contentLength => _bytes.length;
  @override
  bool get isRedirect => false;
  @override
  List<RedirectInfo> get redirects => const [];
  @override
  bool get persistentConnection => false;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream<List<int>>.fromIterable([_bytes]).listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ════════════════════════════════════════════════════════════════════════
// Realistische Daten: lange Namen, lange rumänische und deutsche Texte,
// große Beträge — dort brechen Telefone. Die Form folgt dem Code, der sie
// liest (ApiService, TicketService, TerminService, Verwarnung-/Dokumente-
// Dienst, WeatherService).
// ════════════════════════════════════════════════════════════════════════

/// Schalter für Varianten, die sich gegenseitig ausschließen.
class Teil8Daten {
  /// Verifizierung: 'A' = Stufe 1 geprüft, Stufe 3 offen;
  ///                 'B' = Stufe 1 offen, Stufe 3 geprüft.
  static String verifizierung = 'A';

  /// `chat/start.php` antwortet mit Unsinn — der Live-Chat landet dann im
  /// Fehlerzweig, der die Netzwerkleiste des Supports zeigt.
  static bool startChatKaputt = false;

  static void zuruecksetzen() {
    verifizierung = 'A';
    startChatKaputt = false;
  }
}

const kIch = 'S42759';
const kIchId = 7;
const kIchName = 'Maria-Elena Popescu-Ionescu';
const kIchMail = 'maria-elena.popescu-ionescu@icd360s.de';

String _iso(DateTime d) => d.toIso8601String().substring(0, 19);
String _sql(DateTime d) => _iso(d).replaceFirst('T', ' ');
String _tag(DateTime d) => _iso(d).substring(0, 10);

Map<String, dynamic> _profil() => {
      'success': true,
      'mitgliedernummer': kIch,
      'vorname': 'Maria-Elena',
      'nachname': 'Popescu-Ionescu',
      'strasse': 'Bürgermeister-Hartmann-Straße',
      'hausnummer': '112a',
      'plz': '89231',
      'ort': 'Neu-Ulm',
      'bundesland': 'Bayern',
      'land': 'Deutschland',
      'telefon_mobil': '+49 1520 98765432',
      'geburtsdatum': '1984-03-17',
      'geburtsort': 'Timișoara',
      'zahlungsmethode': 'sepa_lastschrift',
      'zahlungstag': 15,
      'status': 'active',
      'role': 'schatzmeister',
      'mitgliedsart': 'foerdermitglied',
      'created_at': '2024-02-01 10:00:00',
      'last_login': _sql(DateTime.now().subtract(const Duration(hours: 2))),
      'mitgliedschaft_datum': '2024-02-15',
      'email': kIchMail,
    };

Map<String, dynamic> _ticket(int id, String betreff, String status, DateTime termin) => {
      'id': id,
      'subject': betreff,
      'message': 'Text',
      'status': status,
      'priority': 'high',
      'category_name': 'Finanzen',
      'admin_mitgliedernummer': 'V00001',
      'member_name': kIchName,
      'member_nummer': kIch,
      'created_at': _sql(termin.subtract(const Duration(days: 3))),
      'scheduled_date': _sql(termin),
      'total_time_seconds': 5400,
    };

Map<String, dynamic> _nachricht(int id, String text, bool eigen,
        {String status = 'read',
        List<Map<String, dynamic>> anhaenge = const [],
        String? reaktion,
        bool dringend = false,
        bool uebersetzt = false,
        String rolle = 'vorsitzer',
        String absender = 'Alexandru-Constantin Popescu-Ionescu'}) =>
    {
      'id': id,
      'message': text,
      'sender_id': eigen ? kIchId : 3,
      'sender_name': eigen ? kIchName : absender,
      'sender_role': eigen ? 'schatzmeister' : rolle,
      'is_own': eigen,
      'status': status,
      'is_read': status == 'read',
      'created_at': _iso(DateTime.now().subtract(Duration(minutes: 90 - id))),
      if (anhaenge.isNotEmpty) 'attachments': anhaenge,
      if (reaktion != null) 'reaction': reaktion,
      if (dringend) 'is_urgent': true,
      if (uebersetzt) 'is_translated': true,
    };

List<Map<String, dynamic>> _nachrichten() => [
      _nachricht(1,
          'Bună ziua! Vă rog să încărcați extrasele de cont pentru trimestrul al treilea până vineri, inclusiv chitanțele pentru cheltuielile de deplasare.',
          false,
          reaktion: 'thumbsUp',
          uebersetzt: true),
      _nachricht(2,
          'Guten Tag! Die Kontoauszüge für das dritte Quartal 2026 lade ich bis Freitag hoch, zusammen mit den Reisekostenbelegen.',
          true),
      _nachricht(3, 'Kassenprüfungsbericht_2026_final_unterschrieben.pdf', false,
          anhaenge: [
            {
              'id': 31,
              'filename': 'Kassenpruefungsbericht_2026_final_unterschrieben_Vorstand.pdf',
              'extension': 'pdf',
              'size': 2345678,
            },
            {
              'id': 32,
              'filename': 'Belegfoto_Bahnfahrt_Ulm-Stuttgart_2026-09-14.jpg',
              'extension': 'jpg',
              'size': 734003,
            },
          ]),
      _nachricht(4,
          'Siehe https://icd360sev.icd360s.de/dokumente/kassenpruefung/2026/protokoll-vorstandssitzung-september',
          true,
          status: 'delivered',
          dringend: true),
      _nachricht(5, 'Mulțumesc frumos!', false, reaktion: 'love', rolle: 'mitglied',
          absender: 'Ioana-Alexandra Constantinescu-Georgescu'),
      _nachricht(6, '[Dateien]', true, status: 'sent', anhaenge: [
        {
          'id': 61,
          'filename': 'Kontoauszug_Sparkasse_Neu-Ulm_Q3_2026_Vereinskonto.pdf',
          'extension': 'pdf',
          'size': 12582912,
        },
      ]),
    ];

Map<String, dynamic> _gespraech(int id, String name, String nr, String letzte,
        {int ungelesen = 0, String status = 'open', bool stumm = false}) =>
    {
      'id': id,
      'member_id': id + 100,
      'member_name': name,
      'member_nr': nr,
      'gegenueber_name': name,
      'gegenueber_nr': nr,
      'mitgliedernummer': nr,
      'status': status,
      'unread_count': ungelesen,
      'last_message': letzte,
      'is_muted': stumm,
      'last_seen': _sql(DateTime.now().subtract(const Duration(hours: 5))),
    };

List<Map<String, dynamic>> _gespraeche() => [
      _gespraech(11, 'Alexandru-Constantin Popescu-Ionescu (Vorsitzender)', 'V00001',
          'Bitte die Kontoauszüge für das dritte Quartal bis Freitag hochladen.',
          ungelesen: 12),
      _gespraech(12, 'Ioana-Alexandra Constantinescu-Georgescu', 'M10234',
          'Mulțumesc frumos pentru ajutor la declarația de impozit!',
          stumm: true),
      _gespraech(13, 'Support ICD360S e.V.', 'S00000', 'Ihr Ticket wurde bearbeitet.',
          status: 'closed'),
    ];

Map<String, dynamic> _wetter() {
  final jetzt = DateTime.now();
  final start = DateTime(jetzt.year, jetzt.month, jetzt.day, jetzt.hour);
  final stunden = List.generate(48, (i) => start.add(Duration(hours: i)));
  final tage = List.generate(7, (i) => DateTime(jetzt.year, jetzt.month, jetzt.day + i));
  return {
    'current': {
      'temperature_2m': -12.4,
      'relative_humidity_2m': 81,
      'weather_code': 2,
      'wind_speed_10m': 38.6,
    },
    'hourly': {
      'time': [for (final s in stunden) _iso(s).substring(0, 16)],
      'temperature_2m': [for (var i = 0; i < 48; i++) -12.5 + i * 0.7],
      'relative_humidity_2m': [for (var i = 0; i < 48; i++) 80],
      'weather_code': [for (var i = 0; i < 48; i++) const [2, 63, 75, 96, 57][i % 5]],
      'wind_speed_10m': [for (var i = 0; i < 48; i++) 118.0 - i],
      'precipitation': [for (var i = 0; i < 48; i++) i.isEven ? 12.7 : 0.0],
    },
    'daily': {
      'time': [for (final t in tage) _tag(t)],
      'weather_code': [for (var i = 0; i < 7; i++) const [2, 63, 75, 96, 57, 0, 3][i]],
      'temperature_2m_max': [for (var i = 0; i < 7; i++) 18.0 + i],
      'temperature_2m_min': [for (var i = 0; i < 7; i++) -14.0 + i],
      'precipitation_sum': [for (var i = 0; i < 7; i++) i.isEven ? 23.4 : 0.0],
      'wind_speed_10m_max': [for (var i = 0; i < 7; i++) 104.0],
    },
  };
}

/// Beantwortet jede Anfrage, die Dashboard, Profil und Chat stellen.
Antwort? teil8Antworten(String methode, Uri url, String rumpf) {
  final p = url.path;
  final jetzt = DateTime.now();

  // ── Dashboard ──────────────────────────────────────────────────────────
  if (p.endsWith('/vereinverwaltung/board_members.php')) {
    return (status: 200, json: {
      'success': true,
      'users': [
        {
          'id': kIchId,
          'mitgliedernummer': kIch,
          'email': kIchMail,
          'name': kIchName,
          'role': 'schatzmeister',
          'status': 'active',
        },
        {
          'id': 3,
          'mitgliedernummer': 'V00001',
          'email': 'vorsitz@icd360s.de',
          'name': 'Alexandru-Constantin Popescu-Ionescu',
          'role': 'vorsitzer',
          'status': 'active',
        },
        for (var i = 0; i < 4; i++)
          {
            'id': 50 + i,
            'mitgliedernummer': 'M1023$i',
            'email': 'mitglied$i@example.org',
            'name': 'Ioana-Alexandra Constantinescu-Georgescu $i',
            'role': 'mitglied',
            'status': 'active',
          },
      ],
    });
  }
  if (p.endsWith('/auth/get_profile.php')) return (status: 200, json: _profil());
  if (p.endsWith('/member/signatur_manage.php')) {
    return (status: 200, json: {
      'success': true,
      'signaturen': [
        for (var i = 0; i < 12; i++) {'id': i, 'status': 'offen'},
      ],
    });
  }
  if (p.endsWith('/schatzmeister/tickets/list.php')) {
    final montag = DateTime(jetzt.year, jetzt.month, jetzt.day)
        .subtract(Duration(days: jetzt.weekday - 1));
    return (status: 200, json: {
      'success': true,
      'tickets': [
        _ticket(1, 'Kassenprüfung 2026 vorbereiten: alle Belege des dritten Quartals einscannen und dem Prüfer übergeben',
            'open', montag.add(const Duration(days: 2, hours: 10))),
        _ticket(2, 'Pregătirea raportului financiar anual pentru adunarea generală a membrilor',
            'in_progress', montag.add(const Duration(days: 4, hours: 14, minutes: 30))),
        _ticket(3, 'SEPA-Lastschriftmandate der Fördermitglieder prüfen', 'waiting_authority',
            montag.add(const Duration(days: 9, hours: 9))),
        _ticket(4, 'Spendenquittungen 2025 versenden', 'done',
            montag.subtract(const Duration(days: 5))),
        _ticket(5, 'Freistellungsbescheid Finanzamt Neu-Ulm anfordern', 'waiting_member',
            montag.add(const Duration(days: 30))),
        _ticket(6, 'Kontovollmacht Sparkasse aktualisieren', 'closed',
            montag.subtract(const Duration(days: 40))),
      ],
    });
  }
  if (p.endsWith('/schatzmeister/termine/my_termine.php')) {
    return (status: 200, json: {
      'success': true,
      'termine': [
        {
          'id': 1,
          'title': 'Ordentliche Mitgliederversammlung 2026 mit Neuwahl des gesamten Vorstands',
          'termin_date': _sql(jetzt.add(const Duration(days: 12))),
          'category': 'mitgliederversammlung',
          'response': 'confirmed',
          'location': 'Bürgerhaus Neu-Ulm, Saal 2 (Erdgeschoss, barrierefrei)',
          'status': 'scheduled',
        },
        {
          'id': 2,
          'title': 'Ședința consiliului director: bugetul pentru anul 2027',
          'termin_date': _sql(DateTime(jetzt.year, jetzt.month, jetzt.day, 18, 30)),
          'category': 'vorstandssitzung',
          'response': 'pending',
          'location': 'Online (Jitsi) — link în invitație',
          'status': 'scheduled',
        },
        {
          'id': 3,
          'title': 'Schulung: Buchhaltung mit der neuen Vereinssoftware',
          'termin_date': _sql(jetzt.subtract(const Duration(days: 20))),
          'category': 'schulung',
          'response': 'declined',
          'location': '',
          'status': 'completed',
        },
      ],
    });
  }

  // ── Wetter (Open-Meteo, Bright Sky) ───────────────────────────────────
  if (url.host == 'geocoding-api.open-meteo.com') {
    return (status: 200, json: {
      'results': [
        {'latitude': 48.39, 'longitude': 10.01},
      ],
    });
  }
  if (url.host == 'api.open-meteo.com') return (status: 200, json: _wetter());
  if (url.host == 'api.brightsky.dev') {
    return (status: 200, json: {
      'alerts': [
        {
          'headline_de': 'Amtliche UNWETTERWARNUNG vor ORKANARTIGEN BÖEN und STARKEM SCHNEEFALL',
          'description_de': 'Es treten oberhalb 800 m orkanartige Böen auf.',
          'severity': 'severe',
          'event_de': 'ORKANARTIGE BÖEN UND STARKER SCHNEEFALL',
          'onset': _iso(jetzt),
          'expires': _iso(jetzt.add(const Duration(hours: 18))),
        },
      ],
    });
  }

  // ── Profil ─────────────────────────────────────────────────────────────
  if (p.endsWith('/auth/my_sessions.php')) {
    return (status: 200, json: {
      'success': true,
      'sessions': [
        {
          'id': 1,
          'device_name': 'Xiaomi Redmi Note 11 Pro+ 5G (21091116UG)',
          'platform': 'Android 14 (HyperOS 1.0.5.0)',
          'ip_address': '2a02:8071:5e81:7c00:d4b2:1f3e:9a6c:42b7',
          'ip_reputation': {
            'clean': false,
            'blacklists': ['zen.spamhaus.org', 'b.barracudacentral.org', 'dnsbl.sorbs.net'],
          },
          'ip_provider': {
            'provider': 'Vodafone Kabel Deutschland GmbH',
            'connection_type': 'Kabel',
          },
          'last_used': _iso(jetzt.subtract(const Duration(minutes: 3))),
          'is_current': true,
        },
        {
          'id': 2,
          'device_name': 'DESKTOP-SCHATZMEISTER-VEREINSBUERO',
          'platform': 'Windows 11 Pro 24H2',
          'ip_address': '93.184.216.34',
          'ip_reputation': {'clean': true},
          'ip_provider': {'provider': 'Deutsche Telekom AG', 'connection_type': 'DSL'},
          'last_used': _iso(jetzt.subtract(const Duration(days: 2))),
          'is_current': false,
        },
      ],
    });
  }
  if (p.endsWith('/admin/verifizierung_list.php')) {
    final a = Teil8Daten.verifizierung == 'A';
    return (status: 200, json: {
      'success': true,
      'stages': [
        {
          'stufe': 1,
          'status': a ? 'geprueft' : 'offen',
          if (a) 'geprueft_am': '2026-05-04 09:12:00',
          if (a) 'geprueft_von_name': 'Alexandru-Constantin Popescu-Ionescu',
        },
        {
          'stufe': 3,
          'status': a ? 'offen' : 'geprueft',
          if (!a) 'geprueft_am': '2026-05-04 09:12:00',
          if (!a) 'geprueft_von_name': 'Alexandru-Constantin Popescu-Ionescu',
        },
      ],
    });
  }
  if (p.endsWith('/schatzmeister/verwarnungen_list.php')) {
    Map<String, dynamic> w(int id, String typ, String grund) => {
          'id': id,
          'user_id': kIchId,
          'user_name': kIchName,
          'mitgliedernummer': kIch,
          'typ': typ,
          'grund': grund,
          'beschreibung':
              'Trotz schriftlicher Erinnerung vom 12.05.2026 wurde die Frist nicht eingehalten; der Vorstand hat einstimmig beschlossen.',
          'datum': '2026-06-12',
          'created_by_name': 'Alexandru-Constantin Popescu-Ionescu (Vorsitzender)',
          'created_at': '2026-06-12 10:00:00',
        };
    return (status: 200, json: {
      'success': true,
      'warnings': [
        w(1, 'letzte_abmahnung',
            'Wiederholte Nichtteilnahme an den Vorstandssitzungen ohne Entschuldigung'),
        w(2, 'abmahnung', 'Kassenbuch nicht fristgerecht vorgelegt'),
        w(3, 'ermahnung', 'Verspätete Weitergabe von Spendenquittungen'),
      ],
      'stats': {'total': 3, 'ermahnung': 1, 'abmahnung': 1, 'letzte_abmahnung': 1},
    });
  }
  if (p.endsWith('/schatzmeister/dokumente_list.php')) {
    Map<String, dynamic> d(int id, String name, String datei, int groesse) => {
          'id': id,
          'user_id': kIchId,
          'dokument_name': name,
          'original_filename': datei,
          'stored_filename': 'x$id',
          'filesize': groesse,
          'mime_type': 'application/octet-stream',
          'beschreibung': 'Eingescannt am Vereinsabend, das Original liegt im Ordner „Mitglieder 2024".',
          'kategorie': 'vereindokumente',
          'uploaded_by': 3,
          'uploaded_by_name': 'Alexandru-Constantin Popescu-Ionescu',
          'created_at': '2024-02-15 12:00:00',
        };
    return (status: 200, json: {
      'success': true,
      'dokumente': [
        d(1, 'Beitrittserklärung und SEPA-Lastschriftmandat (unterschrieben)',
            'Beitrittserklaerung_SEPA_Mandat_Popescu-Ionescu.pdf', 2345678),
        d(2, 'Kassenbuch 2025 (Export für die Kassenprüfung)',
            'Kassenbuch_2025_Export.xlsx', 987654321),
      ],
    });
  }

  // ── Chat ───────────────────────────────────────────────────────────────
  if (p.endsWith('/chat/conversations.php')) {
    return (status: 200, json: {
      'success': true,
      'is_admin': false,
      'conversations': _gespraeche(),
      'stats': {'open': 128, 'total': 1024},
    });
  }
  if (p.endsWith('/chat/start.php')) {
    if (Teil8Daten.startChatKaputt) return (status: 200, json: 'kaputt');
    return (status: 200, json: {'success': true, 'conversation_id': 11});
  }
  if (p.endsWith('/chat/messages.php')) {
    return (status: 200, json: {
      'success': true,
      'data': {'messages': _nachrichten()},
    });
  }
  if (p.endsWith('/chat/support_status.php')) {
    return (status: 200, json: {
      'success': true,
      'online_admins': [
        {'connection_type': 'ethernet', 'latency_ms': 1048, 'network_quality': 'medium'},
      ],
    });
  }
  if (p.endsWith('/admin/status_message.php')) {
    return (status: 200, json: {
      'success': true,
      'data': {
        'is_active': true,
        'message':
            'Ich bin bis zum 14. Oktober im Urlaub — dringende Anfragen bitte an den Vorsitzenden.',
      },
    });
  }
  if (p.endsWith('/chat/scheduled_messages.php')) {
    return (status: 200, json: {
      'success': true,
      'data': [
        {
          'id': 1,
          'send_time': '07:30:00',
          'message': 'Guten Morgen! Bitte denken Sie an Ihre Medikamente und an das Frühstück.',
          'category': 'medikament',
          'days_of_week': '1,3,5',
          'is_active': true,
        },
        {
          'id': 2,
          'send_time': '12:00:00',
          'message': 'Poftă bună la prânz!',
          'category': 'mittagessen',
          'days_of_week': '1,2,3,4,5,6,7',
          'is_active': false,
        },
      ],
    });
  }
  if (p.endsWith('/chat/conversation_scheduled.php')) {
    return (status: 200, json: {
      'success': true,
      'data': [
        {
          'id': 1,
          'send_time': '07:30:00',
          'message': 'Guten Morgen! Bitte denken Sie an Ihre Medikamente und an das Frühstück.',
          'category': 'medikament',
          'days_of_week': '1,2,4,6',
          'is_enabled': true,
        },
      ],
    });
  }
  return null;
}
