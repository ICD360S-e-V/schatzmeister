// Passt der Ticket-Dialog (fünf Reiter) MIT DATEN auf jedes Telefon — auf
// Deutsch und auf Rumänisch?
//
// Der Dialog war fest 800 × 700 dp breit; auf dem Telefon der Schatzmeisterin
// (Redmi, 393 dp) blieben davon 313 dp. Hier bekommt er realistische, eher
// lange Werte: ein langer Betreff mit Übersetzung, Kommentare von Mitglied und
// Vorstand, Anhänge mit langen Dateinamen, Zeiteinträge mit laufender Uhr.
// Daten über `TicketService().testClient` (MockClient).
//
// ⚠️ Mit der echten Schrift (Roboto), nicht mit der Testschrift (1-em-Quadrate).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:icd360sev_schatzmeister/l10n/app_localizations.dart';
import 'package:icd360sev_schatzmeister/services/language_service.dart';
import 'package:icd360sev_schatzmeister/services/ticket_service.dart';
import 'package:icd360sev_schatzmeister/widgets/ticket_details_dialog.dart';

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

/// [erledigt]: Status „Erledigt" (zeigt „Wieder öffnen") und eine laufende Uhr;
/// sonst „Warten auf Unterlagen" ohne laufende Uhr.
Ticket _ticket({required bool erledigt}) => Ticket(
      id: 12873,
      subject:
          'Antrag auf Erstattung der Fahrtkosten zur außerordentlichen Mitgliederversammlung (Bahn, 2. Klasse, Hin- und Rückfahrt)',
      message:
          'Sehr geehrte Damen und Herren,\n\nich bitte um Erstattung meiner Fahrtkosten zur außerordentlichen Mitgliederversammlung am 12.09.2026 in Neu-Ulm. '
          'Die Fahrkarten (Ulm Hbf – Neu-Ulm und zurück) sowie die Quittung des Busunternehmens habe ich als Anhang beigefügt. '
          'Meine Bankverbindung hat sich seit dem letzten Antrag nicht geändert.\n\nMit freundlichen Grüßen\nAlexandru-Constantin Popescu-Weißenberger',
      status: erledigt ? 'done' : 'waiting_documents',
      priority: 'high',
      categoryName: 'Mitgliedschaft & Beiträge / Erstattungen und Auslagen',
      adminName: 'Ioana Dumitrescu-Hoffmann (Schatzmeisterin, Vorstand)',
      memberName: 'Alexandru-Constantin Popescu-Weißenberger',
      memberNummer: 'M100187',
      createdAt: _jetzt.subtract(const Duration(days: 12)),
      updatedAt: _jetzt.subtract(const Duration(hours: 3)),
      closedAt: erledigt ? _jetzt.subtract(const Duration(days: 1)) : null,
      scheduledDate: DateTime(2026, 10, 14, 9, 30),
    );

Map<String, dynamic> _kommentare() => {
      'success': true,
      'comments': [
        {
          'id': 1,
          'ticket_id': 12873,
          'user_id': 4711,
          'user_name': 'Alexandru-Constantin Popescu-Weißenberger',
          'user_role': 'mitglied',
          'user_nummer': 'M100187',
          'comment':
              'Guten Tag, anbei die fehlende Quittung des Busunternehmens. Bitte prüfen Sie, ob noch etwas fehlt – ich bin ab Montag für drei Wochen im Ausland.',
          'original_comment':
              'Bună ziua, atașez chitanța lipsă de la compania de autobuz. Vă rog să verificați dacă mai lipsește ceva – de luni sunt plecat trei săptămâni în străinătate.',
          'is_translated': true,
          'is_internal': false,
          'created_at': _iso(_jetzt.subtract(const Duration(days: 2))),
        },
        {
          'id': 2,
          'ticket_id': 12873,
          'user_id': 1,
          'user_name': 'Ioana Dumitrescu-Hoffmann (Schatzmeisterin)',
          'user_role': 'schatzmeister',
          'user_nummer': 'S1',
          'comment':
              'Interne Notiz: Quittung ist lesbar, Betrag 23,80 € stimmt mit dem Fahrplan überein. Auszahlung mit dem nächsten Sammellauf.',
          'is_internal': true,
          'created_at': _iso(_jetzt.subtract(const Duration(minutes: 40))),
        },
      ],
      'attachments': [
        {
          'id': 11,
          'comment_id': 1,
          'filename': 'a.enc',
          'original_filename': 'Fahrkarte_DB_Ulm_Hbf-Neu-Ulm_12.09.2026_Hin-und-Rueckfahrt_2.Klasse.pdf',
          'filesize': 2457600,
          'mime_type': 'application/pdf',
          'uploaded_by_name': 'Alexandru-Constantin Popescu-Weißenberger',
          'created_at': _iso(_jetzt.subtract(const Duration(days: 12))),
        },
        {
          'id': 12,
          'filename': 'b.enc',
          'original_filename': 'Quittung_Busunternehmen.jpg',
          'filesize': 845312,
          'mime_type': 'image/jpeg',
          'uploaded_by_name': 'Alexandru-Constantin Popescu-Weißenberger',
          'created_at': _iso(_jetzt.subtract(const Duration(days: 2))),
        },
        {
          'id': 13,
          'filename': 'c.enc',
          'original_filename': 'Unterlagen.zip',
          'filesize': 734,
          'mime_type': 'application/zip',
          'uploaded_by_name': 'Vorstand',
          'created_at': _iso(_jetzt.subtract(const Duration(hours: 5))),
        },
      ],
      'ticket_translation': {
        'subject': 'Antrag auf Erstattung der Fahrtkosten zur außerordentlichen Mitgliederversammlung',
        'original_subject':
            'Cerere de rambursare a cheltuielilor de transport pentru adunarea generală extraordinară',
        'subject_is_translated': true,
        'message': 'Ich bitte um Erstattung meiner Fahrtkosten zur Mitgliederversammlung.',
        'original_message':
            'Vă rog să-mi rambursați cheltuielile de transport pentru adunarea generală.',
        'message_is_translated': true,
      },
    };

Map<String, dynamic> _zeiten({required bool laeuft}) {
  final laufend = {
    'id': 23,
    'ticket_id': 12873,
    'user_id': 1,
    'category': 'wartezeit',
    'started_at': _iso(_jetzt.subtract(const Duration(minutes: 12))),
    'duration_seconds': 0,
    'is_running': 1,
    'is_manual': 0,
    'created_at': _iso(_jetzt.subtract(const Duration(minutes: 12))),
  };
  return {
    'success': true,
    'time_entries': [
      {
        'id': 21,
        'ticket_id': 12873,
        'user_id': 1,
        'category': 'wartezeit',
        'started_at': '2026-09-30 00:00:00',
        'duration_seconds': 5400,
        'note':
            'Wartezeit im Bürgerbüro Neu-Ulm wegen der beglaubigten Kopie der Fahrkarten (Nummer 47 gezogen)',
        'is_running': 0,
        'is_manual': 1,
        'created_at': '2026-09-30 12:00:00',
      },
      {
        'id': 22,
        'ticket_id': 12873,
        'user_id': 1,
        'category': 'fahrzeit',
        'started_at': '2026-09-29 08:05:00',
        'stopped_at': '2026-09-29 09:47:00',
        'duration_seconds': 6120,
        'is_running': 0,
        'is_manual': 0,
        'created_at': '2026-09-29 08:05:00',
      },
      if (laeuft) laufend,
    ],
    'summary': {
      'fahrzeit_seconds': 6120,
      'arbeitszeit_seconds': 45000,
      'wartezeit_seconds': 5400,
      'gesamt_seconds': 56520,
    },
    if (laeuft) 'running_entry': laufend,
  };
}

http.Response _json(Object body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

http.Client _ticketServer({required bool laeuft}) => MockClient((anfrage) async {
      final p = anfrage.url.path;
      if (p.endsWith('/tickets/mark_viewed.php')) return _json({'success': true});
      if (p.endsWith('/tickets/comments/list.php')) return _json(_kommentare());
      if (p.endsWith('/tickets/time/list.php')) return _json(_zeiten(laeuft: laeuft));
      return _json({'success': false, 'message': 'test'});
    });

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

/// Reiter des Ticket-Dialogs, erkannt an ihrem Sinnbild.
const _reiter = <IconData>[
  Icons.info_outline,
  Icons.chat_bubble_outline,
  Icons.folder_outlined,
  Icons.timer_outlined,
  Icons.history,
];

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

  for (final erledigt in [false, true]) {
    group('Ticket-Dialog mit Daten (${erledigt ? 'erledigt, Uhr läuft' : 'wartet auf Unterlagen'})', () {
      for (final sprache in kSprachen) {
        for (final fall in kBreiten.entries) {
          testWidgets('alle Reiter laufen nicht über — ${fall.key} [$sprache]', (tester) async {
            tester.view.physicalSize = fall.value;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);
            await LanguageService.instance.setLanguage(sprache);
            TicketService().testClient = _ticketServer(laeuft: erledigt);

            final fehler = _Fehler()..an();
            final besucht = <IconData>[];
            try {
              await tester.pumpWidget(_rahmen(
                _Oeffner((_) => TicketDetailsDialog(
                      ticket: _ticket(erledigt: erledigt),
                      mitgliedernummer: 'S1',
                      onTicketAction: (_, __) {},
                    )),
                sprache,
              ));
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 500));
              expect(find.byType(TicketDetailsDialog), findsOneWidget);

              /// Öffnet über [knopf] einen Dialog, prüft, dass er da ist
              /// (Überläufe sammelt [fehler]), und schließt ihn wieder.
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
                besucht.add(icon);

                // Jeder Reiter muss seine Daten zeigen — sonst prüfte der
                // Test nur leere Zustände.
                switch (icon) {
                  case Icons.info_outline:
                    expect(find.text('Alexandru-Constantin Popescu-Weißenberger'), findsOneWidget);
                    expect(find.textContaining('Ioana Dumitrescu-Hoffmann'), findsOneWidget);
                    // übersetzter Betreff aus dem Server
                    expect(find.text('Antrag auf Erstattung der Fahrtkosten zur außerordentlichen Mitgliederversammlung'),
                        findsOneWidget);
                  case Icons.chat_bubble_outline:
                    expect(find.textContaining('anbei die fehlende Quittung'), findsOneWidget);
                    // Auf kleinen Telefonen liegt der zweite Kommentar unter dem
                    // Falz — die Liste baut ihn erst beim Hinscrollen.
                    await tester.dragUntilVisible(
                      find.textContaining('Interne Notiz'),
                      find.byType(ListView).first,
                      const Offset(0, -150),
                    );
                    await tester.pump();
                    expect(find.textContaining('Interne Notiz'), findsOneWidget);
                  case Icons.folder_outlined:
                    expect(find.textContaining('Fahrkarte_DB_Ulm_Hbf'), findsOneWidget);
                    // Anhängen-Menü öffnen und schließen
                    await _tippe(tester, find.byIcon(Icons.upload_file));
                    expect(find.byType(PopupMenuItem<String>), findsNWidgets(2));
                    Navigator.of(tester.element(find.byType(PopupMenuItem<String>).first)).pop();
                    await tester.pump();
                    await tester.pump(const Duration(milliseconds: 600));
                  case Icons.timer_outlined:
                    expect(find.text('12h 30m'), findsOneWidget);
                    // Auf kleinen Telefonen liegen die Einträge unter Uhr und
                    // Summen — erst hinscrollen.
                    await tester.dragUntilVisible(
                      find.textContaining('Bürgerbüro Neu-Ulm'),
                      find.byType(ListView).first,
                      const Offset(0, -150),
                    );
                    await tester.pump();
                    expect(find.textContaining('Bürgerbüro Neu-Ulm'), findsOneWidget);
                    // Zeit von Hand nachtragen, Eintrag löschen
                    await kurzOeffnen(find.byIcon(Icons.add).first);
                    await kurzOeffnen(find.byIcon(Icons.delete_outline).first);
                  case Icons.history:
                    break;
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
}
