import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:icd360sev_schatzmeister/services/logger_service.dart';
import 'package:icd360sev_schatzmeister/services/ticket_service.dart';

/// 🔴 Kein Wortlaut ins Protokoll — kein Chattext, kein Benachrichtigungstext,
/// kein Ticket-Betreff, keine rohe Server-Antwort.
///
/// WAS PASSIERT IST, am 17.10.2026 auf dem Server gezählt: `LoggerService`
/// lädt JEDE Protokollzeile zum Server (`logs/schatzmeister/*.json`, alle
/// 30 s), und dort lagen seit dem 24.08.2026 unter anderem
///   510 × `Chat-Benachrichtigung: "<Absender>" - <Nachricht>`,
/// 1.258 × `Notification angezeigt: "<Titel>" - <Text>` (also jede
///         Chat-Nachricht ein zweites Mal),
///   421 × `NtfyService: Received: <Titel> - <Text>`,
///   273 × Ticket-Betreffe, 668 × rohe Poll-Antworten.
///
/// Die Vorsitzer-App hatte denselben Fehler und hat ihn seit dem 30.08.2026
/// nicht mehr (`test/kein_inhalt_im_protokoll_test.dart` dort, PR #516). Diese
/// Datei ist die Kopie davon — mit zwei Erweiterungen:
///
/// - Sie liest den GANZEN Aufruf, nicht nur das erste Zeichenkettenstück.
///   `'Titel ' '$title'` hätte die Vorlage nicht gesehen.
/// - Sie kennt auch die Wege, auf denen Wortlaut OHNE die Wörter `title`/
///   `message` hineinkommt: `${response.body}`, `${jsonEncode(…)}`, die
///   Kopfzeilen einer Anfrage (Bearer + Geräteschlüssel) und der Titel eines
///   Ereignisses (`${ticketEvent.title}`).
///
/// ⚠️ OHNE AUSNAHMELISTE, wie die Vorlage: eine Regel mit Ausnahmen wird
/// erweitert, eine ohne nicht. Erlaubt bleibt, was über den Inhalt nur die
/// FORM verrät: `.length`, `.id`, `.isEmpty`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Der Anfang jedes Log-Aufrufs, in allen Schreibweisen dieser App.
  final logAnfang = RegExp(
    r'(?<![\w.])(?:_log|_logger|log|LoggerService\(\))\.(?:info|debug|warning|error)\(',
  );

  /// Wie in der Vorsitzer-App: `$message` ist Inhalt, `${message.id}` nicht.
  final wortlaut = RegExp(
    r'\$\{?(title|body|message|senderName|nachricht|betreff|subject|content)'
    r'\b(?!\w)(?!\.(length|id|isEmpty|isNotEmpty))',
  );

  /// Wortlaut, der unter einem anderen Namen kommt.
  final nutzdaten = RegExp(
    // ${response.body}, ${r.body.substring(…)} — die Länge darf bleiben
    r'\$\{[\w.]*\bbody\b(?!\.(length|isEmpty|isNotEmpty))'
    // ${jsonEncode(anfrage)}
    r'|\$\{\s*jsonEncode\('
    // ${request.headers}, ${request.fields}
    r'|\$\{[\w.]*\.(headers|fields)\b'
    // ${ticketEvent.title}, ${json['title']} — aber ${data['comment']['id']}
    // ist eine Nummer, kein Inhalt
    r'|\$\{[\w.]+\.(title|preview|comment|subject)\b(?!\.(length|isEmpty|isNotEmpty))'
    r"""|\$\{[\w.]+\[['"](title|body|text|content|comment|subject|preview)['"]\]"""
    r"""(?!\[['"]id['"]\]|\.(length|isEmpty|isNotEmpty))""",
  );

  /// Alle Log-Aufrufe in lib/ — jeweils der ganze Aufruf bis zur schließenden
  /// Klammer, über Zeilen hinweg.
  List<({String ort, String aufruf})> logAufrufe() {
    final dateien = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
    expect(dateien.length, greaterThan(50), reason: 'zu wenige Dateien — Test blind');
    final ergebnis = <({String ort, String aufruf})>[];
    for (final f in dateien) {
      final q = f.readAsStringSync();
      for (final m in logAnfang.allMatches(q)) {
        var i = m.end;
        var tiefe = 1;
        String? zeichen;
        while (i < q.length && tiefe > 0) {
          final c = q[i];
          if (zeichen != null) {
            if (c == r'\') {
              i += 2;
              continue;
            }
            if (c == zeichen) zeichen = null;
          } else if (c == "'" || c == '"') {
            zeichen = c;
          } else if (c == '(') {
            tiefe++;
          } else if (c == ')') {
            tiefe--;
          }
          i++;
        }
        final zeile = '\n'.allMatches(q.substring(0, m.start)).length + 1;
        ergebnis.add((ort: '${f.path}:$zeile', aufruf: q.substring(m.start, i)));
      }
    }
    expect(ergebnis.length, greaterThan(400), reason: 'zu wenige Log-Aufrufe — Test blind');
    return ergebnis;
  }

  test('kein Log-Aufruf in lib/ trägt Wortlaut oder Namen', () {
    final befunde = [
      for (final a in logAufrufe())
        if (wortlaut.firstMatch(a.aufruf) case final t?) '${a.ort}  ${t.group(0)}',
    ];
    expect(befunde, isEmpty, reason: 'Wortlaut im Protokoll:\n${befunde.join('\n')}');
  });

  test('kein Log-Aufruf trägt rohe Antworten, Anfragen, Kopfzeilen oder Betreffe', () {
    final befunde = [
      for (final a in logAufrufe())
        if (nutzdaten.firstMatch(a.aufruf) case final t?) '${a.ort}  ${t.group(0)}',
    ];
    expect(befunde, isEmpty, reason: 'Nutzdaten im Protokoll:\n${befunde.join('\n')}');
  });

  test('der Wächter sieht auch den zweiten Teil eines geteilten Textes', () {
    // Die Vorlage las nur das erste Zeichenkettenstück — so ein Aufruf wäre
    // durchgerutscht.
    const geteilt = "_log.info('Gesendet: '\n        '\$message', tag: 'X');";
    final m = logAnfang.firstMatch(geteilt)!;
    expect(wortlaut.hasMatch(geteilt.substring(m.start)), isTrue);
    expect(nutzdaten.hasMatch(r"_log.info('x ${response.body}')"), isTrue);
    expect(nutzdaten.hasMatch(r"_log.info('x ${response.body.length} Byte')"), isFalse);
    expect(nutzdaten.hasMatch(r"_log.info('x ${ticketEvent.title}')"), isTrue);
    expect(nutzdaten.hasMatch(r"_log.info('x ${json['title']}')"), isTrue);
    expect(nutzdaten.hasMatch(r"_log.info('id=${data['comment']['id']}')"), isFalse);
    expect(nutzdaten.hasMatch(r"_log.info('x ${data['comment']}')"), isTrue);
    expect(nutzdaten.hasMatch(r"_log.info('x ${jsonEncode(rumpf)}')"), isTrue);
    expect(nutzdaten.hasMatch(r"_log.info('x ${request.headers}')"), isTrue);
  });

  test('am Lauf: ein Ticket-Kommentar steht nicht im Protokoll — weder Anfrage noch Antwort', () async {
    // Bis zum 17.10.2026 schrieb addComment den Kommentar ZWEIMAL hinein:
    // `API: Request body: {…"comment":"…"}` und die Antwort des Servers, die
    // ihn im Wortlaut zurückgibt.
    FlutterSecureStorage.setMockInitialValues({});
    const kommentar = 'MARKE-KOMMENTAR Bescheid vom Jobcenter liegt bei';
    TicketService().testClient = MockClient((anfrage) async {
      expect(anfrage.body, contains(kommentar), reason: 'der Server bekommt ihn natürlich');
      return http.Response(
          jsonEncode({
            'success': true,
            'comment': {
              'id': 5,
              'ticket_id': 7,
              'user_id': 3,
              'user_name': 'M. Weber',
              'user_role': 'schatzmeister',
              'comment': kommentar,
              'created_at': '2026-10-17 10:00:00',
            },
          }),
          201,
          headers: {'content-type': 'application/json'});
    });

    final antwort =
        await TicketService().addComment(mitgliedernummer: 'S42759', ticketId: 7, comment: kommentar);

    expect(antwort?.comment, kommentar, reason: 'der Weg lief durch');
    final zeilen = LoggerService().logs.map((e) => e.message);
    expect(zeilen.where((z) => z.contains('MARKE-KOMMENTAR')), isEmpty);
    expect(zeilen.where((z) => z.contains('comment_length=${kommentar.length}')), isNotEmpty,
        reason: 'die Länge bleibt im Protokoll');
  });

  test('die Länge zu protokollieren bleibt erlaubt und wird genutzt', () {
    // ⚠️ Sonst liesse sich der Wächter erfüllen, indem man gar nichts mehr
    // protokolliert — und verlöre die Auskunft „kam die Benachrichtigung an?",
    // um derentwillen die Zeile existiert.
    final q = File('lib/services/notification_service.dart').readAsStringSync();
    expect(q, contains(r'${title.length}'));
    expect(q, contains(r'${body.length}'));
    expect(q, contains(r'${message.length}'));
  });
}
