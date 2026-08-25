import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:icd360sev_schatzmeister/services/api_service.dart';
import 'package:icd360sev_schatzmeister/services/chat_service.dart';
import 'package:icd360sev_schatzmeister/services/http_client_factory.dart';

/// 🔴 Zwei Befunde vom 26.08.2026, beide still:
///
/// 1. Die Anmeldung am WebSocket ging OHNE Token hinaus. Der Server nimmt die
///    Identitaet seit dem 22.07.2026 aus dem Token und weist alles andere mit
///    `auth_error: Authentication required` ab — nachgemessen gegen den
///    Produktivserver. Der Chat dieser App konnte sich seither nicht anmelden.
/// 2. Misslang der Handschlag, stiess niemand einen zweiten Versuch an.
///    `onError` und `onDone` melden sich nur an einem Draht, der einmal stand
///    und dann riss; ein offen gehaltener, aber abgelehnter bleibt stumm.
///
/// ⚠️ Geprueft gegen einen WebSocket-Server auf `localhost`, nicht gegen das
/// Netz: ein Test, der ohne Leitung rot wird, sagt am Ende nichts mehr.
void main() {
  late HttpServer server;
  late List<WebSocket> verbindungen;
  late List<Map<String, dynamic>> empfangen;
  late int nochAblehnen;

  setUp(() async {
    verbindungen = [];
    empfangen = [];
    nochAblehnen = 0;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((anfrage) async {
      final ws = await WebSocketTransformer.upgrade(anfrage);
      verbindungen.add(ws);
      ws.listen((roh) {
        final data = jsonDecode(roh as String) as Map<String, dynamic>;
        empfangen.add(data);
        if (data['type'] != 'auth') return;
        // So verhaelt sich der echte Server: er behaelt den Draht und lehnt
        // nur die Anmeldung ab.
        if (nochAblehnen > 0 || data['token'] == null) {
          if (nochAblehnen > 0) nochAblehnen--;
          ws.add(jsonEncode(
              {'type': 'auth_error', 'error': 'Authentication required'}));
        } else {
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
  });

  tearDown(() async {
    ChatService().disconnect();
    ChatService.testWsUrl = null;
    for (final ws in verbindungen) {
      await ws.close().catchError((_) => null);
    }
    await server.close(force: true);
  });

  group('Die Anmeldung traegt das Token', () {
    test('ohne Token weist der Server ab — genau wie in Wirklichkeit', () async {
      final ergebnis = await ChatService().connect('S12345');
      expect(ergebnis, isFalse);
      expect(empfangen.first['token'], isNull);
    });

    test('mit Token kommt die Anmeldung durch', () async {
      await ApiService().saveTokens('kopf.rumpf.zeichen', 'auffrischung');
      final ergebnis = await ChatService().connect('S12345');
      expect(ergebnis, isTrue, reason: 'das ist der eigentliche Befund');
      expect(empfangen.first['token'], 'kopf.rumpf.zeichen',
          reason: 'im Rumpf, nicht in der Adresse — sonst steht es im Serverlog');
      expect(empfangen.first['mitgliedernummer'], 'S12345');
    });
  });

  group('Nach einem misslungenen Versuch wartet einer', () {
    test('eine abgelehnte Anmeldung stoesst einen neuen Versuch an', () async {
      nochAblehnen = 99;
      final ergebnis = await ChatService().connect('S12345');
      expect(ergebnis, isFalse);
      expect(ChatService().wiederverbindungWartet, isTrue);
      expect(ChatService().versucheBisher, 1,
          reason: 'eine Stoerung darf genau einen der zehn Versuche kosten');
    });

    test('der abgelehnte Draht bleibt nicht offen liegen', () async {
      nochAblehnen = 99;
      await ChatService().connect('S12345');
      for (var i = 0; i < 20 && verbindungen.first.closeCode == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(verbindungen.first.closeCode, isNotNull);
    });

    test('ein Aufruf von aussen laeuft den Zaehler nicht voll', () async {
      nochAblehnen = 99;
      await ChatService().connect('S12345');
      for (var i = 0; i < 5; i++) {
        await ChatService().connect('S12345');
      }
      expect(ChatService().versucheBisher, lessThanOrEqualTo(1),
          reason: 'sonst waere die Grenze von zehn nach fuenf Klicks erreicht');
      expect(ChatService().wiederverbindungWartet, isTrue);
    });

    test('disconnect laesst keinen wartenden Versuch zurueck', () async {
      nochAblehnen = 99;
      await ChatService().connect('S12345');
      expect(ChatService().wiederverbindungWartet, isTrue);
      ChatService().disconnect();
      expect(ChatService().wiederverbindungWartet, isFalse);
    });
  });

  group('Vertrauensanker', () {
    test('es sind zwei, nicht einer', () {
      // Die Kette endet heute nur deshalb bei X1, weil Let's Encrypt zwei
      // Kreuzsignaturen mitschickt. Fallen die weg, endet sie bei X2 — mit nur
      // X1 als Anker schluege dann JEDE Verbindung fehl.
      final anker = HttpClientFactory.vertrauensanker;
      expect('BEGIN CERTIFICATE'.allMatches(anker).length, 2);
      expect(anker, contains('MIIFazCCA1OgAwIBAgIRAIIQz7DSQONZRGPgu2OCiwAw'),
          reason: 'ISRG Root X1');
      expect(anker, contains('MIICGzCCAaGgAwIBAgIQQdKd0XLq7qeAwSxs6S+HUjAK'),
          reason: 'ISRG Root X2');
    });

    test('der Kontext nimmt beide an', () {
      // Ein zweiter Aufbau darf nicht an doppelt gesetzten Ankern scheitern.
      expect(() => HttpClientFactory.createPinnedHttpClient().close(),
          returnsNormally);
      expect(() => HttpClientFactory.createPinnedHttpClient().close(),
          returnsNormally);
    });
  });
}
