import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:icd360sev_schatzmeister/services/chat_service.dart';
import 'package:icd360sev_schatzmeister/services/logger_service.dart';

/// Die zweite Prüfung zu `kein_inhalt_im_protokoll_test.dart`: nicht am
/// Quelltext, sondern am Lauf. Ein WebSocket auf localhost schickt, was der
/// Chat-Server schickt — eine Chat-Nachricht, eine Ticket-Benachrichtigung,
/// eine Systemmeldung —, jeweils mit einer Marke im Text. Danach darf keine
/// Marke in den Zeilen stehen, die `LoggerService` zum Server lädt.
///
/// ⚠️ MIT TestWidgetsFlutterBinding, anders als `fernwartung_signal_test`:
/// eine Chat-Nachricht erreicht `NotificationService.showChatMessage`, und
/// das baut auf dem Rechner (Linux = Desktop) den `TrayService`, der ohne
/// Bindung an seinem MethodChannel scheitert. Die Bindung ersetzt aber jeden
/// HttpClient durch eine Attrappe — deshalb läuft die Verbindung unter
/// [_EchtesNetz].
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HttpServer server;
  late List<WebSocket> verbindungen;

  setUp(() async {
    verbindungen = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((anfrage) async {
      final ws = await WebSocketTransformer.upgrade(anfrage);
      verbindungen.add(ws);
      ws.listen((roh) {
        final data = jsonDecode(roh as String) as Map<String, dynamic>;
        if (data['type'] == 'auth') {
          ws.add(jsonEncode({
            'type': 'auth_success',
            'user_id': 3,
            'name': 'M. Weber',
            'role': 'schatzmeister',
          }));
        }
      }, onError: (_) {}, cancelOnError: true);
    });
    ChatService.testWsUrl = 'ws://127.0.0.1:${server.port}/';
    final verbunden =
        await HttpOverrides.runWithHttpOverrides(() => ChatService().connect('S00001'), _EchtesNetz());
    expect(verbunden, isTrue);
  });

  tearDown(() async {
    ChatService().disconnect();
    ChatService.testWsUrl = null;
    await server.close(force: true);
  });

  Future<void> kurz() => Future<void>.delayed(const Duration(milliseconds: 150));
  Iterable<String> zeilen() => LoggerService().logs.map((e) => e.message);

  test('eine Chat-Nachricht: kein Wort davon im Protokoll — aber die Zeile ist da', () async {
    verbindungen.single.add(jsonEncode({
      'type': 'new_message',
      'message_id': 901,
      'conversation_id': 34,
      'sender_id': 2,
      'sender_name': 'Vorsitz',
      'sender_role': 'vorsitzer',
      'is_admin': true,
      'message': 'MARKE-CHATTEXT Blutdruck 180 zu 110',
      'created_at': '2026-10-17 10:00:00',
    }));
    await kurz();

    expect(zeilen().where((z) => z.contains('MARKE-CHATTEXT')), isEmpty);
    // Nicht blind: der Weg lief, und er schrieb die Länge.
    expect(zeilen().where((z) => z.startsWith('Chat-Benachrichtigung (') && z.contains('Text 35 Z.')),
        isNotEmpty);
  });

  test('eine Ticket-Benachrichtigung: weder Titel noch Text noch Betreff', () async {
    verbindungen.single.add(jsonEncode({
      'type': 'ticket_notification',
      'ticket_id': 42,
      'notification_type': 'comment_added',
      'title': 'MARKE-TITEL',
      'message': 'MARKE-TICKETTEXT',
      'ticket_subject': 'MARKE-BETREFF',
      'sender_name': 'Vorsitz',
      'timestamp': '2026-10-17 10:00:00',
    }));
    await kurz();

    for (final marke in ['MARKE-TITEL', 'MARKE-TICKETTEXT', 'MARKE-BETREFF']) {
      expect(zeilen().where((z) => z.contains(marke)), isEmpty, reason: marke);
    }
    expect(zeilen(), contains('Ticket-Benachrichtigung angezeigt (Ticket #42)'));
  });

  test('eine Systemmeldung der Verwaltung: auch nicht ihr Titel', () async {
    verbindungen.single.add(jsonEncode({
      'type': 'system_notification',
      'title': 'MARKE-SYSTEMTITEL',
      'message': 'MARKE-SYSTEMTEXT',
    }));
    await kurz();

    expect(zeilen().where((z) => z.contains('MARKE-SYSTEM')), isEmpty);
    expect(zeilen(), contains('Systemmeldung ignoriert (Verwaltungsseite)'));
  });
}

/// Ein echter HttpClient statt der Attrappe der Testbindung.
class _EchtesNetz extends HttpOverrides {}
