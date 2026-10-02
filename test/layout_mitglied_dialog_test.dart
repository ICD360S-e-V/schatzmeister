// Passt der Mitglieder-Dialog (alle neun Reiter) MIT DATEN auf jedes
// Telefon — auf Deutsch und auf Rumänisch?
//
// Der gemeinsame Test (bildschirme_telefon_test.dart) sieht nur Bildschirme
// ohne Serverdaten. Der Mitglieder-Dialog lebt aber von den Daten: lange
// Namen, IPv6-Adressen, Bescheide, Ermäßigungsanträge, Notizen, Termine.
// Hier bekommt er realistische, eher lange Werte — genau dort liefen die
// Zeilen auf dem Telefon der Schatzmeisterin (Redmi, 393 dp) hinaus.
//
// Datenquellen:
// - ApiService: `testClient` (MockClient).
// - VerwarnungService, DokumenteService, TerminService haben KEINE Test-Naht;
//   sie bauen ihren `IOClient(HttpClient())` beim ersten Gebrauch selbst.
//   Über Darts eigenes `HttpOverrides` bekommen sie hier statt des Netzes
//   eine Attrappe — an den Diensten selbst ändert sich nichts.
//
// ⚠️ Mit der echten Schrift (Roboto), nicht mit der Testschrift (1-em-Quadrate).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:icd360sev_schatzmeister/l10n/app_localizations.dart';
import 'package:icd360sev_schatzmeister/models/user.dart';
import 'package:icd360sev_schatzmeister/services/api_service.dart';
import 'package:icd360sev_schatzmeister/services/device_key_service.dart';
import 'package:icd360sev_schatzmeister/services/language_service.dart';
import 'package:icd360sev_schatzmeister/widgets/user_details_dialog.dart';

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

// ───────────────────────── Testdaten ─────────────────────────

final _jetzt = DateTime.now();
String _iso(DateTime d) => d.toIso8601String().substring(0, 19).replaceAll('T', ' ');
String _tag(DateTime d) => d.toIso8601String().substring(0, 10);

User _mitglied() => User(
      id: 4711,
      mitgliedernummer: 'M100187',
      email: 'alexandru-constantin.popescu-weissenberger@icd360s-mitglieder.de',
      name: 'Alexandru-Constantin Popescu-Weißenberger',
      vorname: 'Alexandru-Constantin',
      vorname2: 'Mihai',
      nachname: 'Popescu-Weißenberger',
      geburtsdatum: '14.03.1987',
      strasse: 'Friedrich-Ebert-Straße',
      hausnummer: '123a',
      plz: '89231',
      ort: 'Neu-Ulm (Pfuhl)',
      telefonMobil: '+49 1512 3456789',
      status: 'gekuendigt_verein',
      role: 'mitgliedergrunder',
      createdAt: DateTime(2024, 1, 15, 9, 41),
      lastLogin: DateTime(2026, 9, 30, 22, 17),
      mitgliedschaftDatum: DateTime(2024, 2, 1),
      mitgliedsart: 'foerdermitglied',
      zahlungsmethode: null,
      deactivatedAt: DateTime(2026, 9, 1, 3, 0),
      deactivationReason:
          'Automatisch deaktiviert: 30 Tage keine Anmeldung nach Kündigung durch den Verein',
    );

Map<String, dynamic> _benutzerDetails() => {
      'success': true,
      'devices': [
        {
          'device_name': 'Xiaomi Redmi Note 13 Pro 5G (Alexandru, privat)',
          'platform': 'Android 14 (HyperOS 1.0.5.0.UNOEUXM)',
          'device_type': 'phone',
          'os_version': 'Android 14 (API 34), Sicherheitspatch 2026-09-01',
          'app_version': '1.0.34+87',
          'connection_type': 'Mobilfunk 5G (Telefónica Germany GmbH & Co. OHG)',
          'is_vpn': 0,
          'battery_level': 87,
          'battery_state': 'charging',
          'disk_total_gb': 256,
          'disk_free_gb': 112.4,
          'smart_status': 'Verified (95% Gesund)',
          'os_up_to_date': 0,
          'os_updates_count': 3,
          'last_used_at': '2026-10-02 14:33:12',
          'is_active': 1,
          'is_rooted': 1,
          'disk_encrypted': 1,
          'firewall_active': 0,
        },
        {
          'device_name': 'DESKTOP-SCHATZMEISTERIN-7Q2K (Windows 11 Pro 24H2)',
          'platform': 'Windows 11 Pro',
          'device_type': 'desktop',
          'os_version': 'Windows 11 Pro 24H2 (Build 26100.4061)',
          'app_version': '1.0.34+87',
          'is_vpn': 1,
          'disk_total_gb': 953.8,
          'disk_free_gb': 401.2,
          'smart_status': 'healthy',
          'os_up_to_date': 1,
          'last_used_at': '2026-09-29 18:02:44',
          'is_active': 0,
          'disk_encrypted': 0,
          'firewall_active': 1,
        },
      ],
      'sessions': [
        {
          'id': 991,
          'device_name': 'Windows 11 Pro – DESKTOP-SCHATZMEISTERIN-7Q2K (ICD360S e.V Schatzmeister)',
          'platform': 'Windows 11',
          'ip_address': '2a02:8109:b6bf:e100:1c4e:0ff2:fe3a:9b11',
          'ip_reputation': {
            'clean': false,
            'blacklists': ['Spamhaus ZEN', 'SORBS DUHL', 'Barracuda Reputation Block List'],
          },
          'ip_provider': {
            'provider': 'Vodafone Kabel Deutschland GmbH',
            'connection_type': 'Kabel (DOCSIS 3.1)',
          },
          'created_at': '2026-10-01 08:15:00',
          'expires_at': '2026-10-31 08:15:00',
        },
        {
          'id': 992,
          'device_name': 'Xiaomi Redmi Note 13 Pro 5G',
          'platform': 'Android 14',
          'ip_address': '176.94.211.187',
          'ip_reputation': {'clean': true},
          'ip_provider': {
            'provider': 'Telefónica Germany GmbH & Co. OHG',
            'connection_type': 'Mobilfunk (5G)',
          },
          'created_at': '2026-10-02 07:01:00',
          'expires_at': '2026-11-01 07:01:00',
        },
      ],
    };

Map<String, dynamic> _verifizierung() => {
      'success': true,
      'finanzielle_situation': 'buergergeld',
      'document_acceptances': {
        'satzung': '2024-01-15 09:41:00',
        'datenschutz': null,
        'widerrufsbelehrung': '2024-01-15 09:42:00',
      },
      'stages': [
        for (var s = 1; s <= 8; s++)
          {
            'stufe': s,
            'status': const ['geprueft', 'ausgefuellt', 'abgelehnt', 'offen'][s % 4],
            if (s.isEven) 'geprueft_am': '2026-09-${10 + s} 16:45:00',
            if (s.isEven) 'geprueft_von_name': 'Ioana Dumitrescu-Hoffmann (Schatzmeisterin)',
            if (s == 3)
              'notiz':
                  'Bescheid des Jobcenters Neu-Ulm liegt nur als unscharfes Foto vor – bitte erneut als PDF einreichen.',
          },
      ],
    };

Map<String, dynamic> _befreiungen() => {
      'success': true,
      'is_befreit': true,
      'befreiungen': [
        {
          'id': 31,
          'status': 'abgelehnt',
          'behoerde': 'sozialamt',
          'gueltig_von': '2026-01-01',
          'gueltig_bis': '2026-12-31',
          'bescheid_datum': '2025-12-18',
          'notiz':
              'Abgelehnt: Bescheid ist abgelaufen und nennt eine andere Bedarfsgemeinschaft; neuen Bescheid anfordern.',
          'geprueft_am': '2026-01-07 11:20:00',
          'geprueft_von_name': 'Ioana Dumitrescu-Hoffmann',
          'original_filename': 'Bewilligungsbescheid_Grundsicherung_Landratsamt_Neu-Ulm_2026.pdf',
          'filesize': 2457600,
        },
        {
          'id': 32,
          'status': 'eingereicht',
          'behoerde': 'jobcenter',
          'gueltig_von': '2026-02-01',
          'gueltig_bis': '2027-01-31',
          'original_filename': 'Jobcenter_Bescheid_Buergergeld_Februar_2026.jpg',
          'filesize': 845312,
        },
      ],
    };

Map<String, dynamic> _ermaessigungen() => {
      'success': true,
      'antraege': [
        {
          'id': 51,
          'status': 'eingereicht',
          'antrag_typ': 'ausbildungsbeihilfe',
          'gueltig_von': '2026-09-01',
          'gueltig_bis': '2027-08-31',
          'eingereicht_am': '2026-09-19 10:04:00',
          'tage_offen': 13,
          'original_filename': 'BAB_Bewilligung_Agentur_fuer_Arbeit_Ulm_2026-2027.pdf',
          'filesize': 1310720,
          'check_dokument_lesbar': 1,
          'check_leistungsart_erkennbar': 0,
          'check_aktuell_12monate': 0,
          'notiz': 'Mitglied bittet um rückwirkende Ermäßigung ab September.',
        },
        {
          'id': 52,
          'status': 'abgelehnt',
          'antrag_typ': 'arbeitslosengeld',
          'gueltig_von': '2025-03-01',
          'eingereicht_am': '2025-03-04 08:30:00',
          'ablehnungsgrund':
              'Der Bescheid ist älter als zwölf Monate und die Leistungsart ist nicht erkennbar. Bitte den aktuellen Bewilligungsbescheid der Agentur für Arbeit nachreichen.',
          'geprueft_am': '2025-03-20 14:00:00',
          'geprueft_von_name': 'Ioana Dumitrescu-Hoffmann',
          'check_dokument_lesbar': 1,
          'check_leistungsart_erkennbar': 0,
          'check_aktuell_12monate': 0,
        },
        {
          'id': 53,
          'status': 'genehmigt',
          'antrag_typ': 'kinderzuschlag',
          'gueltig_von': '2024-06-01',
          'gueltig_bis': '2025-05-31',
          'eingereicht_am': '2024-05-28 19:12:00',
          'geprueft_am': '2024-06-02 09:00:00',
          'geprueft_von_name': 'Ioana Dumitrescu-Hoffmann',
          'check_dokument_lesbar': 1,
          'check_leistungsart_erkennbar': 1,
          'check_aktuell_12monate': 1,
        },
      ],
    };

Map<String, dynamic> _notizen() => {
      'success': true,
      'notizen': [
        {
          'id': 71,
          'kategorie': 'kommunikation',
          'wichtig': true,
          'created_at': '2026-10-01 18:42:00',
          'notiz':
              'Rückruf vereinbart: Mitglied ist nur abends nach 18 Uhr erreichbar und bittet um Kommunikation auf Rumänisch. Unterlagen zur Kündigung wurden per Post an die neue Adresse in Neu-Ulm geschickt.',
          'erstellt_von_name': 'Ioana Dumitrescu-Hoffmann',
          'erstellt_von_nummer': 'S1',
        },
        {
          'id': 72,
          'kategorie': 'verhalten',
          'wichtig': false,
          'created_at': '2026-09-12 09:05:00',
          'notiz': 'Hat in der Mitgliederversammlung wiederholt unterbrochen.',
          'erstellt_von_name': 'Vorstand',
          'erstellt_von_nummer': 'V1',
        },
      ],
    };

Map<String, dynamic> _verwarnungen() => {
      'success': true,
      'warnings': [
        {
          'id': 81,
          'user_id': 4711,
          'user_name': 'Alexandru-Constantin Popescu-Weißenberger',
          'mitgliedernummer': 'M100187',
          'typ': 'letzte_abmahnung',
          'grund': 'Grobe Verletzung der Vereinsdisziplin und Störung der Mitgliederversammlung (§6 Abs. 6 Satzung)',
          'beschreibung':
              'In der Mitgliederversammlung vom 12.09.2026 wurde die Versammlungsleitung mehrfach unterbrochen; trotz Ermahnung wurde der Saal erst nach 20 Minuten verlassen.',
          'datum': '2026-09-14',
          'created_by_name': 'Ioana Dumitrescu-Hoffmann (Schatzmeisterin)',
          'created_at': '2026-09-14 10:00:00',
        },
        {
          'id': 82,
          'user_id': 4711,
          'typ': 'ermahnung',
          'grund': 'Zahlungsverzug Mitgliedsbeitrag (§4 Beitragsordnung)',
          'datum': '2026-03-02',
          'created_by_name': 'Vorstand',
          'created_at': '2026-03-02 10:00:00',
        },
      ],
      'stats': {'total': 3, 'ermahnung': 1, 'abmahnung': 1, 'letzte_abmahnung': 1},
    };

Map<String, dynamic> _dokumente() => {
      'success': true,
      'dokumente': [
        {
          'id': 91,
          'user_id': 4711,
          'dokument_name': 'Beitrittserklärung mit SEPA-Lastschriftmandat (unterschrieben)',
          'original_filename': 'Beitrittserklaerung_Popescu-Weissenberger_2024.pdf',
          'stored_filename': 'x.enc',
          'filesize': 1843200,
          'mime_type': 'application/pdf',
          'beschreibung': 'Original liegt im Vereinsordner 2024, Fach 3.',
          'kategorie': 'vereindokumente',
          'dokument_typ': 'aufnahmebestaetigung',
          'is_encrypted': 1,
          'uploaded_by': 1,
          'uploaded_by_name': 'Ioana Dumitrescu-Hoffmann (Schatzmeisterin)',
          'created_at': '2024-01-16 12:00:00',
        },
        {
          'id': 92,
          'user_id': 4711,
          'dokument_name': 'Sozialversicherungsausweis (Vorder- und Rückseite)',
          'original_filename': 'Sozialversicherungsausweis_Scan_2026.jpeg',
          'stored_filename': 'y.enc',
          'filesize': 734003,
          'mime_type': 'image/jpeg',
          'kategorie': 'behoerde',
          'dokument_typ': 'sozialversicherung',
          'ablauf_datum': _tag(_jetzt.add(const Duration(days: 20))),
          'days_until_expiry': 20,
          'is_encrypted': 1,
          'uploaded_by': 1,
          'uploaded_by_name': 'Ioana Dumitrescu-Hoffmann',
          'created_at': '2026-02-03 08:00:00',
        },
        {
          'id': 93,
          'user_id': 4711,
          'dokument_name': 'Bescheinigung Krankenkasse',
          'original_filename': 'AOK_Bayern_Mitgliedsbescheinigung.pdf',
          'stored_filename': 'z.enc',
          'filesize': 98304,
          'mime_type': 'application/pdf',
          'kategorie': 'behoerde',
          'dokument_typ': 'krankenkasse',
          'ablauf_datum': '2026-01-31',
          'is_encrypted': 0,
          'uploaded_by': 1,
          'uploaded_by_name': 'Vorstand',
          'created_at': '2025-02-01 08:00:00',
        },
      ],
    };

Map<String, dynamic> _termine() => {
      'success': true,
      'termine': [
        {
          'id': 101,
          'title':
              'Außerordentliche Mitgliederversammlung zur Satzungsänderung §6 und Wahl der Kassenprüfer',
          'category': 'mitgliederversammlung',
          'description':
              'Tagesordnung: 1. Begrüßung 2. Satzungsänderung §6 3. Wahl der Kassenprüfer 4. Verschiedenes. Bitte Personalausweis mitbringen.',
          'termin_date': _iso(_jetzt.add(const Duration(days: 9))),
          'duration_minutes': 150,
          'location': 'Bürgerhaus Neu-Ulm, Großer Saal (2. OG), Augsburger Straße 15, 89231 Neu-Ulm',
          'created_by': 1,
          'status': 'scheduled',
          'created_at': '2026-09-20 10:00:00',
          'total_participants': 42,
          'confirmed_count': 27,
          'ticket_id': 1288,
          'ticket_subject': 'Fahrkostenerstattung zur Mitgliederversammlung beantragt (Bahn, 2. Klasse)',
        },
        {
          'id': 102,
          'title': 'Schulung: Mitgliederportal und Beitragsbefreiung',
          'category': 'schulung',
          'description': '',
          'termin_date': _iso(_jetzt.subtract(const Duration(days: 30))),
          'duration_minutes': 90,
          'location': 'Online (Jitsi)',
          'created_by': 1,
          'status': 'cancelled',
          'created_at': '2026-08-01 10:00:00',
          'total_participants': 12,
          'confirmed_count': 3,
        },
      ],
    };

http.Response _json(Object body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// Antworten des ApiService (über `testClient`).
http.Client _apiServer() => MockClient((anfrage) async {
      final p = anfrage.url.path;
      if (p.endsWith('/admin/user_details.php')) return _json(_benutzerDetails());
      if (p.endsWith('/admin/verifizierung_list.php')) return _json(_verifizierung());
      if (p.endsWith('/schatzmeister/befreiung_list.php')) return _json(_befreiungen());
      if (p.endsWith('/schatzmeister/ermaessigung_list.php')) return _json(_ermaessigungen());
      if (p.endsWith('/schatzmeister/notizen_list.php')) return _json(_notizen());
      return _json({'success': false, 'message': 'test'});
    });

/// Antworten der Dienste ohne Test-Naht (über `HttpOverrides`).
Object? _netzAntwort(Uri url) {
  final p = url.path;
  if (p.endsWith('/schatzmeister/verwarnungen_list.php')) return _verwarnungen();
  if (p.endsWith('/schatzmeister/dokumente_list.php')) return _dokumente();
  if (p.endsWith('/admin/termine_list.php')) return _termine();
  return null;
}

// ───────────────────── HttpClient-Attrappe ─────────────────────

class _Netz extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _Client();
}

class _Client implements HttpClient {
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async => _Anfrage(url);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Anfrage implements HttpClientRequest {
  _Anfrage(this.uri);

  @override
  final Uri uri;
  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  int contentLength = -1;
  @override
  bool persistentConnection = true;
  @override
  final HttpHeaders headers = _Kopf();

  @override
  Future<void> addStream(Stream<List<int>> stream) => stream.drain<void>();

  @override
  Future<HttpClientResponse> close() async {
    final body = _netzAntwort(uri);
    return _Antwort(
      body == null ? 404 : 200,
      utf8.encode(jsonEncode(body ?? {'success': false, 'message': 'test'})),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Antwort extends Stream<List<int>> implements HttpClientResponse {
  _Antwort(this.statusCode, this._bytes);

  final List<int> _bytes;
  @override
  final int statusCode;
  @override
  int get contentLength => _bytes.length;
  @override
  final HttpHeaders headers = _Kopf(json: true);
  @override
  bool get isRedirect => false;
  @override
  List<RedirectInfo> get redirects => const [];
  @override
  bool get persistentConnection => false;
  @override
  String get reasonPhrase => statusCode == 200 ? 'OK' : 'Not Found';

  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream<List<int>>.value(_bytes)
          .listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Kopf implements HttpHeaders {
  _Kopf({bool json = false})
      : _werte = {
          if (json) 'content-type': ['application/json; charset=utf-8'],
        };

  final Map<String, List<String>> _werte;

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) =>
      _werte[name.toLowerCase()] = ['$value'];

  @override
  void forEach(void Function(String name, List<String> values) action) => _werte.forEach(action);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ───────────────────────── Rahmen ─────────────────────────

/// Öffnet [dialog] wie die App: über `showDialog` (Barriere, SafeArea).
class _Oeffner extends StatefulWidget {
  const _Oeffner(this.dialog);
  final WidgetBuilder dialog;

  @override
  State<_Oeffner> createState() => _OeffnerState();
}

class _OeffnerState extends State<_Oeffner> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showDialog<void>(context: context, builder: widget.dialog);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
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

/// Sammelt Überläufe und andere Layout-/Baufehler (mit Codezeile).
class _Fehler {
  final ueberlaeufe = <String>[];
  final andere = <String>[];
  FlutterExceptionHandler? _vorher;

  void an() {
    _vorher = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.toString();
      final ort = RegExp(r'lib/[\w/]+\.dart:\d+').firstMatch(text)?.group(0) ?? '?';
      final m = RegExp(r'overflowed by ([0-9.]+) pixels on the (\w+)').firstMatch(text);
      if (m != null) {
        ueberlaeufe.add('${m.group(1)} px ${m.group(2)} @ $ort');
        return;
      }
      final lib = details.library ?? '';
      if (lib.contains('rendering') || lib.contains('widgets')) {
        andere.add('${details.exceptionAsString().split('\n').first} @ $ort');
      }
    };
  }

  void aus() => FlutterError.onError = _vorher;
}

Future<void> _tippe(WidgetTester tester, Finder f) async {
  // Nur die NÄCHSTE Bildlaufleiste bewegen — `tester.ensureVisible` schöbe
  // auch die Seiten der TabBarView (PageView) mit und blätterte dabei um.
  final element = tester.element(f);
  final scrollable = Scrollable.maybeOf(element);
  if (scrollable != null && scrollable.widget.controller is! PageController) {
    await scrollable.position.ensureVisible(element.renderObject!);
  }
  await tester.pump();
  await tester.tap(f, warnIfMissed: false);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Reiter des Mitglieder-Dialogs, erkannt an ihrem Sinnbild.
const _reiter = <IconData>[
  Icons.account_circle,
  Icons.devices,
  Icons.warning_amber,
  Icons.folder_open,
  Icons.card_membership,
  Icons.verified_user,
  Icons.discount,
  Icons.sticky_note_2,
  Icons.calendar_month,
];

void main() {
  setUpAll(() async {
    HttpOverrides.global = _Netz();
    // Der ApiService schickt ohne aktiviertes Gerät gar nichts ab.
    FlutterSecureStorage.setMockInitialValues({});
    await DeviceKeyService().setActivatedCredentials('TEST-GERAET', 'TEST-ID');
    if (!_schriftenDa) return;
    await _laden('Roboto', [
      'Roboto-Regular.ttf',
      'Roboto-Bold.ttf',
      'Roboto-Medium.ttf',
      'Roboto-Italic.ttf',
    ]);
    await _laden('MaterialIcons', ['MaterialIcons-Regular.otf']);
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService().testClient = _apiServer();
  });

  group('Mitglieder-Dialog mit Daten', () {
    for (final sprache in kSprachen) {
      for (final fall in kBreiten.entries) {
        testWidgets('alle Reiter laufen nicht über — ${fall.key} [$sprache]', (tester) async {
          tester.view.physicalSize = fall.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          await LanguageService.instance.setLanguage(sprache);

          final fehler = _Fehler()..an();
          final besucht = <String>[];
          try {
            await tester.pumpWidget(_rahmen(
              _Oeffner((_) => UserDetailsDialog(
                    user: _mitglied(),
                    apiService: ApiService(),
                    onUpdated: () {},
                    adminMitgliedernummer: 'S1',
                  )),
              sprache,
            ));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 500));
            expect(find.byType(UserDetailsDialog), findsOneWidget);

            /// Öffnet über [knopf] einen Dialog des Mitglieder-Dialogs, prüft,
            /// dass er da ist (Überläufe sammelt [fehler]), und schließt ihn.
            Future<void> kurzOeffnen(Finder knopf) async {
              await _tippe(tester, knopf);
              expect(find.byType(AlertDialog), findsOneWidget, reason: '$knopf');
              Navigator.of(tester.element(find.byType(AlertDialog))).pop();
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 600));
              expect(find.byType(AlertDialog), findsNothing);
            }

            for (final icon in _reiter) {
              final tab = find.widgetWithIcon(Tab, icon);
              expect(tab, findsOneWidget, reason: 'Reiter $icon');
              await _tippe(tester, tab);
              besucht.add('$icon');

              // Jeder Reiter muss seine Daten zeigen — sonst prüfte der Test
              // nur leere Zustände.
              switch (icon) {
                case Icons.account_circle:
                  expect(find.textContaining('popescu-weissenberger@'), findsOneWidget);
                  // Rolle bearbeiten (Auswahlfeld im schmalen Dialog)
                  await kurzOeffnen(find.byIcon(Icons.edit).at(2));
                case Icons.devices:
                  expect(find.textContaining('Xiaomi Redmi Note 13 Pro 5G (Alexandru'), findsOneWidget);
                  expect(find.textContaining('2a02:8109'), findsOneWidget);
                case Icons.warning_amber:
                  expect(find.textContaining('Grobe Verletzung'), findsOneWidget);
                  await kurzOeffnen(find.byIcon(Icons.delete_outline).first);
                case Icons.folder_open:
                  expect(find.textContaining('Beitrittserklärung mit SEPA'), findsOneWidget);
                  // Zweiter Unterreiter: Behörden-Unterlagen
                  await _tippe(tester, find.widgetWithIcon(Tab, Icons.account_balance));
                  expect(find.textContaining('Sozialversicherungsausweis'), findsOneWidget);
                case Icons.card_membership:
                  expect(find.textContaining('Bewilligungsbescheid_Grundsicherung'), findsOneWidget);
                  // Status-Dialog und Bescheid-Hochladen öffnen und schließen
                  await kurzOeffnen(find.byIcon(Icons.edit).last);
                  await kurzOeffnen(find.byIcon(Icons.upload_file).first);
                case Icons.verified_user:
                  // Alle Stufen aufklappen — ihr Inhalt wird erst dann gebaut.
                  final n = find.byType(ExpansionTile).evaluate().length;
                  expect(n, 8);
                  for (var i = 0; i < n; i++) {
                    final kopf = find.descendant(
                      of: find.byType(ExpansionTile).at(i),
                      matching: find.byType(ListTile),
                    );
                    await _tippe(tester, kopf.first);
                  }
                  expect(find.textContaining('Friedrich-Ebert-Straße'), findsOneWidget);
                  // Ablehnen-Dialog einer Stufe
                  await kurzOeffnen(find.descendant(
                    of: find.byType(ExpansionTile).first,
                    matching: find.byIcon(Icons.close),
                  ));
                case Icons.discount:
                  expect(find.textContaining('BAB_Bewilligung'), findsOneWidget);
                case Icons.sticky_note_2:
                  expect(find.textContaining('Rückruf vereinbart'), findsOneWidget);
                case Icons.calendar_month:
                  expect(find.textContaining('Außerordentliche Mitgliederversammlung'), findsOneWidget);
              }
            }
          } finally {
            fehler.aus();
          }
          tester.takeException();
          await tester.pumpWidget(const SizedBox());

          expect(fehler.ueberlaeufe, isEmpty,
              reason: 'Überlauf auf ${fall.key} [$sprache]:\n${fehler.ueberlaeufe.toSet().join('\n')}');
          expect(fehler.andere, isEmpty,
              reason: 'Layoutfehler auf ${fall.key} [$sprache]:\n${fehler.andere.toSet().join('\n')}');
          expect(besucht.length, _reiter.length);
        });
      }
    }
  }, skip: _schriftenDa ? false : 'Roboto fehlt unter $_schriften');
}
