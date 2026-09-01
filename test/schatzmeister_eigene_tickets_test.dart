import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:icd360sev_schatzmeister/services/api_service.dart';
import 'package:icd360sev_schatzmeister/services/ticket_service.dart';

/// Zwei Regeln, beide am 01.09.2026 entstanden.
///
/// **1. Der Bearer muss mit.** Bis dahin schickte `TicketService` gar kein
/// `Authorization` — nur `X-Device-Key`. `schatzmeister/tickets/list.php`
/// nimmt die Identität aber ausschliesslich aus dem Token
/// (`smRequireSchatzmeister()`), also kam **401 „Missing Authorization
/// header"** zurück. Im nginx-Log: **287 Aufrufe, 287 mal 401, kein einziges
/// 200** — die Ticketliste auf der Startseite war nie befüllt, seit es sie
/// gibt.
///
/// **2. Keine Ticketverwaltung.** Entscheidung des Users vom 01.09.2026: der
/// Schatzmeister sieht ausschliesslich die EIGENEN Tickets. Der Server setzt
/// das seit demselben Tag durch (`ticketRollenTor(['vorsitzer'])` und
/// `ticketZugriff()` ohne 'schatzmeister'); diese App darf es gar nicht erst
/// versuchen.
///
/// ⚠️ Das PHP liegt in keinem Repo — diese Datei ist die einzige Stelle im
/// Baum, an der beides auffallen kann.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  tearDown(() => ApiService().clearTokens());

  test('die eigene Ticketliste trägt den Bearer', () async {
    await ApiService().saveTokens('DAS-TOKEN', 'DER-REFRESH');

    final gesehen = <String, String>{};
    Uri? ziel;
    TicketService().testClient = MockClient((anfrage) async {
      gesehen.addAll(anfrage.headers);
      ziel = anfrage.url;
      return http.Response(
          jsonEncode({'success': true, 'tickets': <dynamic>[]}), 200,
          headers: {'content-type': 'application/json'});
    });

    await TicketService().getTickets('S42759');

    expect(ziel?.path, endsWith('/schatzmeister/tickets/list.php'),
        reason: 'die eigene Sicht, nicht der gemeinsame Endpunkt');
    expect(gesehen['Authorization'], 'Bearer DAS-TOKEN',
        reason: 'ohne diesen Kopf antwortet der Server mit 401');
  });

  test('ohne Token steht KEIN Authorization da', () async {
    // „Bearer null" wäre schlimmer als gar nichts — der Server wiese es als
    // ungültiges Token ab, statt sauber 401 „fehlt" zu melden.
    final gesehen = <String, String>{};
    TicketService().testClient = MockClient((anfrage) async {
      gesehen.addAll(anfrage.headers);
      return http.Response(jsonEncode({'success': true, 'tickets': <dynamic>[]}), 200,
          headers: {'content-type': 'application/json'});
    });

    await TicketService().getTickets('S42759');

    expect(gesehen.containsKey('Authorization'), isFalse);
  });

  test('diese App kennt keinen Endpunkt der Ticketverwaltung', () {
    // Der Server weist sie ab; hier soll gar nicht erst hingegriffen werden.
    // Geprüft wird der ganze Baum, nicht nur der Dienst — der Griff kann
    // ebenso gut aus einem Bildschirm kommen.
    final treffer = <String>[];
    for (final e in Directory('lib').listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart')) continue;
      final t = e.readAsStringSync();
      for (final verboten in [
        'tickets/admin_list.php',
        'tickets/admin_create.php',
        'getAdminTickets',
        'createTicketForMember(',
      ]) {
        if (t.contains(verboten)) treffer.add('${e.path}: $verboten');
      }
    }
    expect(treffer, isEmpty,
        reason: 'Der Schatzmeister sieht nur die eigenen Tickets');
  });
}
