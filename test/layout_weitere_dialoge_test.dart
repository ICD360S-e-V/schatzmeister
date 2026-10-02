// Passen die übrigen Dialoge und Bausteine (Notar, Termine, Update,
// Diagnose, Änderungsprotokoll, Dateibetrachter, Debug-Konsole, Visitenkarte,
// Fußleiste) MIT DATEN auf jedes Telefon — auf Deutsch und auf Rumänisch?
//
// Der gemeinsame Test (bildschirme_telefon_test.dart) erreicht sie nicht:
// sie öffnen sich erst auf Knopfdruck oder brauchen Daten. Hier bekommen sie
// realistische, eher lange Werte (Doppelnamen, lange Betreffe, Notariats-
// namen), und jeder Fall prüft, dass die gefütterten Daten wirklich zu sehen
// sind — ein leerer Bildschirm kann den Test nicht grün machen.
//
// Die Notar-Karten laufen dreifach: in fester Höhe (je Karte), ohne
// Höhenvorgabe untereinander in einer scrollenden Seite (so könnte der
// Notar-Bildschirm sie auf dem Telefon zeigen) und — nur ab 800 dp — im
// bisherigen Raster 2 × 3 des Schreibtischs.
//
// ⚠️ Mit der echten Schrift (Roboto), nicht mit der Testschrift (1-em-Quadrate).
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
import 'package:icd360sev_schatzmeister/services/logger_service.dart';
import 'package:icd360sev_schatzmeister/services/termin_service.dart';
import 'package:icd360sev_schatzmeister/services/ticket_service.dart';
import 'package:icd360sev_schatzmeister/services/update_service.dart';
import 'package:icd360sev_schatzmeister/widgets/changelog.dart';
import 'package:icd360sev_schatzmeister/widgets/debug_console.dart';
import 'package:icd360sev_schatzmeister/widgets/diagnostic_consent_dialog.dart';
import 'package:icd360sev_schatzmeister/widgets/file_viewer_dialog.dart';
import 'package:icd360sev_schatzmeister/widgets/legal_footer.dart';
import 'package:icd360sev_schatzmeister/widgets/notar_cards.dart';
import 'package:icd360sev_schatzmeister/widgets/notar_dialogs.dart';
import 'package:icd360sev_schatzmeister/widgets/termin_dialogs.dart';
import 'package:icd360sev_schatzmeister/widgets/update_dialog.dart';
import 'package:icd360sev_schatzmeister/widgets/visitenkarte.dart';

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

const _langerName = 'Alexandru-Constantin Popescu-Weißenberger von Hohenzollern-Sigmaringen';

final _notar = <String, dynamic>{
  'id': 3,
  'name': 'Notariat Dr. Maximilian Hohenstein-Bergmann & Kollegen',
  'name2': 'Notarin Dr. Elisabeth Freifrau von Brandenstein-Zeppelin',
  'strasse': 'Friedrich-Ebert-Straße',
  'hausnummer': '123a',
  'plz': '89231',
  'ort': 'Neu-Ulm (Pfuhl)',
  'telefon': '+49 731 98765-4321',
  'fax': '+49 731 98765-4399',
  'email': 'kanzlei.hohenstein-bergmann@notariat-neu-ulm-beispiel.de',
  'website': 'https://www.notariat-hohenstein-bergmann-neu-ulm.de/termine/online-buchung',
  'notizen':
      'Termine nur dienstags und donnerstags vormittags; der Vorstand bringt den Vereinsregisterauszug und alle Personalausweise mit.',
};

final _rechnungen = <Map<String, dynamic>>[
  {'rechnungsnummer': 'RE-2026-000187/NOT-NU (Beglaubigung Satzungsänderung)', 'datum': '2026-09-14', 'betrag': 1234.56, 'bezahlt': false},
  {'rechnungsnummer': 'RE-2026-000112/NOT-NU', 'datum': '2026-06-02', 'betrag': 89.25, 'bezahlt': true},
];

final _besuche = <Map<String, dynamic>>[
  {'zweck': 'Beglaubigung der Satzungsänderung §6 und Anmeldung zum Vereinsregister beim Amtsgericht Memmingen', 'datum': '2026-10-08', 'uhrzeit': '09:30:00', 'status': 'geplant'},
  {'zweck': 'Vorbesprechung Satzung', 'datum': '2026-08-20', 'uhrzeit': null, 'status': 'abgeschlossen'},
  {'zweck': 'Unterschriften Vorstand', 'datum': '2026-07-01', 'status': 'abgesagt'},
];

final _dokumente = <Map<String, dynamic>>[
  {'titel': 'Notarielle Beglaubigung der Unterschriften des Vorstands (Anmeldung VR 201234)', 'datum': '2026-09-14', 'typ': 'urkunde'},
  {'titel': 'Vollmacht Schatzmeisterin', 'datum': '2026-09-01', 'typ': 'vollmacht'},
];

final _aufgaben = <Map<String, dynamic>>[
  {'id': 41, 'beschreibung': 'Vereinsregisterauszug beim Amtsgericht Memmingen anfordern und an das Notariat senden', 'datum': '2026-10-05', 'uhrzeit': '10:00:00', 'status': 'offen', 'notizen': 'Gebühr 10 € vorab überweisen.'},
  {'id': 42, 'beschreibung': 'Personalausweise kopieren', 'datum': '2026-09-30', 'status': 'erledigt'},
];

final _zahlungen = <Map<String, dynamic>>[
  {'verwendungszweck': 'Notarkosten Beglaubigung Satzungsänderung RE-2026-000187/NOT-NU', 'datum': '2026-09-20', 'betrag': 1234.56, 'zahlungsart': 'ueberweisung'},
  {'verwendungszweck': null, 'datum': '2026-06-05', 'betrag': 89.25, 'zahlungsart': 'karte'},
];

List<User> _mitglieder() => [
      for (var i = 0; i < 6; i++)
        User(
          id: 100 + i,
          mitgliedernummer: 'M10018$i',
          email: 'mitglied$i@example.de',
          name: i.isEven ? _langerName : 'Ioana Dumitrescu-Hoffmann',
          status: 'active',
          role: i == 0 ? 'schatzmeister' : 'mitglied',
        ),
    ];

List<Ticket> _tickets() => [
      Ticket(
        id: 1288,
        subject: 'Fahrkostenerstattung zur außerordentlichen Mitgliederversammlung beantragt (Bahn, 2. Klasse, Hin- und Rückfahrt)',
        message: 'x',
        status: 'open',
        priority: 'high',
        createdAt: DateTime(2026, 9, 20),
      ),
    ];

Termin _termin() => Termin(
      id: 101,
      title: 'Außerordentliche Mitgliederversammlung zur Satzungsänderung §6 und Wahl der Kassenprüfer',
      category: 'mitgliederversammlung',
      description: 'Tagesordnung: 1. Begrüßung 2. Satzungsänderung §6 3. Wahl der Kassenprüfer 4. Verschiedenes.',
      terminDate: DateTime(2026, 10, 11, 14, 0),
      durationMinutes: 150,
      location: 'Bürgerhaus Neu-Ulm, Großer Saal (2. OG), Augsburger Straße 15, 89231 Neu-Ulm',
      createdBy: 1,
      status: 'scheduled',
      createdAt: DateTime(2026, 9, 20),
    );

final _update = UpdateInfo(
  version: '1.0.35',
  buildNumber: 88,
  downloadUrl: 'https://icd360sev.icd360s.de/downloads/schatzmeister/ICD360S_Schatzmeister_1.0.35_Setup.exe',
  changelog: '• Alle Dialoge passen sich jetzt an die Breite des Telefons an (Redmi, 393 dp)\n'
      '• Ticket-Zeiterfassung: Einträge auf kleinen Telefonen erreichbar\n'
      '• Rumänische Übersetzung der Beitragsbefreiung und der Ermäßigungsanträge vervollständigt',
);

Map<String, dynamic> _changelog() => {
      'success': true,
      'versions': [
        {
          'version': '1.0.35',
          'date': '2026-10-02',
          'is_latest': true,
          'changes': [
            'Mitglieder-Dialog: alle neun Reiter passen auf Telefone ab 320 dp, Beschriftung steht über dem Wert',
            'Ticket-Dialog: ganzer Bildschirm auf dem Telefon, Reiter wischbar',
          ],
        },
        {
          'version': '1.0.34',
          'date': '2026-09-28',
          'changes': ['Rumänisch für Nonprofit-Plattformen, Dienste, Behörden'],
        },
      ],
    };

Map<String, dynamic> _profil() => {
      'success': true,
      'name': _langerName,
      'email': 'alexandru-constantin.popescu-weissenberger@icd360s-mitglieder.de',
      'role': 'schatzmeister',
      'telefon_mobil': '+49 1512 3456789 (nur abends nach 18 Uhr, Rumänisch bevorzugt)',
    };

http.Response _json(Object body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

http.Client _apiServer() => MockClient((anfrage) async {
      final p = anfrage.url.path;
      if (p.endsWith('/changelog_schatzmeister.php')) return _json(_changelog());
      if (p.endsWith('/auth/get_profile.php')) return _json(_profil());
      return _json({'success': false, 'message': 'test'});
    });

/// Ein 2 × 2-PNG für den Dateibetrachter.
final _bild = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAFUlEQVR42mP8z8BQz0AEYBxVSF+FABJADq0VvRiCAAAAAElFTkSuQmCC');

// ───────────────────────── Rahmen ─────────────────────────

/// Ruft [los] nach dem ersten Bild auf — dort öffnen die Fälle ihre Dialoge
/// genau wie die App (`showDialog`, eigene `show…Dialog`-Funktionen).
class _Starter extends StatefulWidget {
  const _Starter(this.los);
  final void Function(BuildContext context) los;

  @override
  State<_Starter> createState() => _StarterState();
}

class _StarterState extends State<_Starter> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.los(context);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

Widget _dialog(WidgetBuilder builder) =>
    _Starter((ctx) => showDialog<void>(context: ctx, builder: builder));

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

/// Ein geprüfter Baustein: was gezeigt wird und woran man sieht, dass die
/// gefütterten Daten angekommen sind.
class _Fall {
  const _Fall(this.name, this.zeigen, this.daten, {this.abBreite = 0});
  final String name;
  final Widget Function() zeigen;
  final Finder Function() daten;

  /// Nur ab dieser Bildschirmbreite (das Schreibtisch-Raster der Notar-Karten).
  final double abBreite;
}

Widget _notarKarte(int i) => switch (i) {
      0 => NotarDataCard(data: _notar, onEdit: () {}),
      1 => NotarRechnungenCard(rechnungen: _rechnungen, isLoading: false, onAdd: () {}),
      2 => NotarBesucheCard(besuche: _besuche, isLoading: false, onAdd: () {}),
      3 => NotarDokumenteCard(dokumente: _dokumente, isLoading: false, onAdd: () {}),
      4 => NotarZahlungenCard(zahlungen: _zahlungen, isLoading: false, onAdd: () {}),
      _ => NotarAufgabenCard(aufgaben: _aufgaben, isLoading: false, onAdd: () {}, onTap: (_) {}),
    };

late final String _bildPfad;

List<_Fall> _faelle() {
  final api = ApiService();
  return [
    _Fall('Notar: Daten bearbeiten',
        () => _Starter((ctx) => showEditNotarDialog(context: ctx, data: _notar, apiService: api)),
        () => find.text('Notariat Dr. Maximilian Hohenstein-Bergmann & Kollegen')),
    _Fall('Notar: neue Rechnung',
        () => _Starter((ctx) => showAddRechnungDialog(context: ctx, notarId: 3, apiService: api)),
        () => find.byType(TextFormField)),
    _Fall('Notar: neuer Besuch',
        () => _Starter((ctx) => showAddBesuchDialog(context: ctx, notarId: 3, apiService: api)),
        () => find.byType(TextFormField)),
    _Fall('Notar: neues Dokument',
        () => _Starter((ctx) => showAddDokumentDialog(context: ctx, notarId: 3, apiService: api)),
        () => find.byType(TextFormField)),
    _Fall('Notar: Aufgabe bearbeiten',
        () => _Starter((ctx) => showAufgabeDetailDialog(context: ctx, aufgabe: _aufgaben.first, apiService: api)),
        () => find.text(_aufgaben.first['beschreibung'] as String)),
    _Fall('Notar: neue Aufgabe',
        () => _Starter((ctx) => showAddAufgabeDialog(context: ctx, notarId: 3, apiService: api)),
        () => find.byType(TextFormField)),
    _Fall('Notar: neue Zahlung',
        () => _Starter((ctx) => showAddZahlungDialog(context: ctx, notarId: 3, apiService: api)),
        () => find.byType(TextFormField)),
    _Fall('Notar-Karten in fester Höhe',
        () => SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                for (var i = 0; i < 6; i++) SizedBox(height: 300, child: _notarKarte(i)),
              ]),
            ),
        () => find.textContaining('Hohenstein-Bergmann')),
    _Fall('Notar-Karten ohne Höhenvorgabe (untereinander, scrollend)',
        () => SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(children: [for (var i = 0; i < 6; i++) _notarKarte(i)]),
            ),
        () => find.textContaining('Vereinsregisterauszug beim Amtsgericht')),
    _Fall('Notar-Karten im Schreibtisch-Raster 2 × 3',
        () => Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                for (final zeile in [
                  [0, 1, 2],
                  [3, 4, 5],
                ]) ...[
                  if (zeile.first == 3) const SizedBox(height: 16),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final i in zeile) ...[
                          if (i != zeile.first) const SizedBox(width: 16),
                          Expanded(child: _notarKarte(i)),
                        ],
                      ],
                    ),
                  ),
                ],
              ]),
            ),
        () => find.textContaining('RE-2026-000187'),
        abBreite: 800),
    _Fall('Termin anlegen',
        () => _dialog((_) => CreateTerminDialog(
              terminService: TerminService(),
              users: _mitglieder(),
              tickets: _tickets(),
              onTerminCreated: () {},
            )),
        () => find.textContaining('Popescu-Weißenberger')),
    _Fall('Termin bearbeiten',
        () => _dialog((_) => EditTerminDialog(
              termin: _termin(),
              terminService: TerminService(),
              users: _mitglieder(),
              tickets: _tickets(),
              onTerminUpdated: () {},
            )),
        () => find.text('Bürgerhaus Neu-Ulm, Großer Saal (2. OG), Augsburger Straße 15, 89231 Neu-Ulm')),
    _Fall('Update verfügbar', () => _dialog((_) => UpdateDialog(updateInfo: _update)),
        () => find.textContaining('Ticket-Zeiterfassung')),
    _Fall('Diagnose-Einwilligung', () => _dialog((_) => const DiagnosticConsentDialog()),
        () => find.byIcon(Icons.security)),
    _Fall('Änderungsprotokoll', () => _dialog((_) => const ChangelogDialog()),
        () => find.text('1.0.35')),
    _Fall('Dateibetrachter',
        () => _dialog((_) => FileViewerDialog(
              filePath: _bildPfad,
              fileName: 'Kontoauszug_September_2026_Sparkasse_Neu-Ulm_Girokonto_DE12345678901234567890.png',
            )),
        () => find.textContaining('Kontoauszug_September_2026')),
    _Fall('Debug-Konsole', () => _dialog((_) => const DebugConsole()),
        () => find.textContaining('Verbindung zum Server')),
    _Fall('Visitenkarte im Reiter', () => Visitenkarte(mitgliedernummer: 'S1', apiService: api),
        () => find.text('Popescu-Weißenberger von Hohenzollern-Sigmaringen')),
    _Fall('Visitenkarte in niedrigem Reiter (300 dp)',
        () => Align(
              alignment: Alignment.topCenter,
              child: SizedBox(height: 300, child: Visitenkarte(mitgliedernummer: 'S1', apiService: api)),
            ),
        () => find.text('Alexandru-Constantin')),
    _Fall('Fußleiste', () => const Scaffold(body: SizedBox.expand(), bottomNavigationBar: LegalFooter()),
        () => find.textContaining('v${UpdateService.currentVersion}')),
  ];
}

void main() {
  setUpAll(() async {
    // Der ApiService schickt ohne aktiviertes Gerät gar nichts ab.
    FlutterSecureStorage.setMockInitialValues({});
    await DeviceKeyService().setActivatedCredentials('TEST-GERAET', 'TEST-ID');
    final ordner = Directory.systemTemp.createTempSync('teil9_bild_');
    _bildPfad = '${ordner.path}/kontoauszug.png';
    File(_bildPfad).writeAsBytesSync(_bild);
    for (var i = 0; i < 12; i++) {
      LoggerService().info(
          'Verbindung zum Server icd360sev.icd360s.de hergestellt (Versuch ${i + 1}), Antwortzeit ${120 + i} ms, Gerät DESKTOP-SCHATZMEISTERIN-7Q2K',
          tag: 'NETZ');
    }
    LoggerService().warning('Sehr lange Zeile ohne Leerzeichen: ${'a1b2c3d4' * 30}', tag: 'TEST');
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

  for (final fallName in _faelle().map((f) => f.name)) {
    group('Baustein $fallName mit Daten', () {
      for (final sprache in kSprachen) {
        for (final breite in kBreiten.entries) {
          testWidgets('läuft nicht über — ${breite.key} [$sprache]', (tester) async {
            final fall = _faelle().firstWhere((f) => f.name == fallName);
            if (breite.value.width < fall.abBreite) return;
            tester.view.physicalSize = breite.value;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);
            await LanguageService.instance.setLanguage(sprache);

            final fehler = _Fehler()..an();
            try {
              await tester.pumpWidget(_rahmen(fall.zeigen(), sprache));
              // Dialog öffnen, Daten laden (MockClient), Übergänge abwarten
              for (var i = 0; i < 6; i++) {
                await tester.pump(const Duration(milliseconds: 200));
              }
              expect(fall.daten(), findsWidgets, reason: 'Daten von „$fallName“ nicht zu sehen');
            } finally {
              fehler.aus();
            }
            tester.takeException();
            await tester.pumpWidget(const SizedBox());

            expect(fehler.ueberlaeufe, isEmpty,
                reason: '$fallName auf ${breite.key} [$sprache]:\n${fehler.ueberlaeufe.toSet().join('\n')}');
            expect(fehler.andere, isEmpty,
                reason: '$fallName auf ${breite.key} [$sprache]:\n${fehler.andere.toSet().join('\n')}');
          });
        }
      }
    }, skip: _schriftenDa ? false : 'Roboto fehlt unter $_schriften');
  }
}
