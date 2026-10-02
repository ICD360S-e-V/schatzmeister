import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:icd360sev_schatzmeister/services/chat_service.dart';

/// Fernwartung: die Rahmen zwischen Vorsitz und Schatzmeister-App, geprüft
/// gegen einen WebSocket auf localhost.
///
/// ⚠️ Bewusst OHNE TestWidgetsFlutterBinding (wie `ws_anmeldung_test.dart`):
/// die Bindung ersetzt jeden HttpClient durch eine Attrappe, und dann kommt
/// keine WebSocket-Verbindung mehr zustande.
void main() {
  // ─────────────────────────────────────────────────────────────────────────
  group('Signalisierung über den Chat', () {
    late HttpServer server;
    late List<WebSocket> verbindungen;
    late List<Map<String, dynamic>> empfangen;

    setUp(() async {
      verbindungen = [];
      empfangen = [];
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((anfrage) async {
        final ws = await WebSocketTransformer.upgrade(anfrage);
        verbindungen.add(ws);
        ws.listen((roh) {
          final data = jsonDecode(roh as String) as Map<String, dynamic>;
          empfangen.add(data);
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
      expect(await ChatService().connect('S00001'), isTrue);
    });

    tearDown(() async {
      ChatService().disconnect();
      ChatService.testWsUrl = null;
      await server.close(force: true);
    });

    Future<void> kurz() => Future<void>.delayed(const Duration(milliseconds: 80));

    test('ein Angebot des Vorsitzes kommt als RemoteOfferEvent an', () async {
      final ankunft = ChatService().remoteOfferStream.first;
      verbindungen.single.add(jsonEncode({
        'type': 'remote_offer',
        'conversation_id': 34,
        'controller_id': 2,
        'controller_name': 'Vorsitz',
        'sdp': 'v=0 angebot',
        'sdp_type': 'offer',
      }));
      final e = await ankunft.timeout(const Duration(seconds: 2));
      expect(e.conversationId, 34);
      expect(e.controllerId, '2');
      expect(e.controllerName, 'Vorsitz');
      expect(e.sdp, 'v=0 angebot');
    });

    test('ICE und Sitzungsende des Vorsitzes kommen an', () async {
      final ice = ChatService().remoteIceStream.first;
      final ende = ChatService().remoteEndedStream.first;
      verbindungen.single.add(jsonEncode({
        'type': 'remote_ice',
        'conversation_id': 34,
        'candidate': 'candidate:1 1 tcp 1 1.2.3.4 9 typ relay',
        'sdp_mid': '0',
        'sdp_mline_index': 0,
      }));
      verbindungen.single.add(jsonEncode({
        'type': 'remote_ended',
        'conversation_id': 34,
        'ended_by': 'Vorsitz',
        'reason': 'disconnected',
      }));
      final i = await ice.timeout(const Duration(seconds: 2));
      final e = await ende.timeout(const Duration(seconds: 2));
      expect(i.candidate, startsWith('candidate:1'));
      expect(e.reason, 'disconnected');
    });

    test('Antwort, Absage, Ende und ICE gehen als eigene Rahmen hinaus', () async {
      ChatService().sendRemoteAnswer(34, 'v=0 antwort', 'answer',
          plattform: 'android', steuerung: true, bildFrei: true);
      ChatService().sendRemoteReject(34, 'busy');
      ChatService().sendRemoteEnd(34);
      ChatService().sendRemoteIce(34, 'candidate:x', '0', 0);
      await kurz();

      Map<String, dynamic> rahmen(String typ) =>
          empfangen.singleWhere((d) => d['type'] == typ);
      final antwort = rahmen('remote_answer');
      expect(antwort['plattform'], 'android');
      expect(antwort['steuerung'], isTrue);
      expect(antwort['bild_frei'], isTrue);
      expect(rahmen('remote_reject')['reason'], 'busy');
      expect(rahmen('remote_end')['conversation_id'], 34);
      expect(rahmen('remote_ice')['candidate'], 'candidate:x');
      expect(empfangen.where((d) => d['type'] == 'ice_candidate'), isEmpty,
          reason: 'die Fernwartung darf nie in den Anrufweg geraten');
    });
  });
}
