// Nachrichten im Live-Chat verschwinden fuenf Minuten nach dem Lesen.
// Der Server erledigt das ohnehin; hier wird geprueft, dass die App es
// auch mitbekommt — bis zum 26.08.2026 tat sie das nicht und zeigte
// stattdessen eine leere Blase.
import 'package:flutter_test/flutter_test.dart';
import 'package:icd360sev_schatzmeister/utils/chat_ablauf.dart';
import 'package:icd360sev_schatzmeister/services/chat_service.dart';

// Form wie von api/chat/messages.php geliefert.
Map<String, dynamic> _nachricht({
  Object? inhalt = 'Guten Tag',
  bool gelesen = false,
  String status = 'sent',
  String? gelesenUm,
  String? laeuftAbUm,
  String? geloeschtUm,
}) =>
    {
      'id': 7,
      'message': inhalt,
      'is_read': gelesen,
      'status': status,
      'read_at': gelesenUm,
      'expires_at': laeuftAbUm,
      'deleted_at': geloeschtUm,
    };

void main() {
  group('istAbgelaufen', () {
    test('ungelesene Nachricht laeuft nicht ab', () {
      expect(istAbgelaufen(_nachricht()), isFalse);
    });

    test('gelesen, aber noch mit Inhalt: bleibt stehen', () {
      expect(
        istAbgelaufen(_nachricht(gelesen: true, status: 'read')),
        isFalse,
      );
    });

    test('deleted_at gesetzt: abgelaufen, auch wenn noch Text dasteht', () {
      // Inhalt bewusst NICHT geleert: sonst traefe schon der Rueckfall
      // unten zu und dieser Zweig waere gar nicht geprueft.
      expect(
        istAbgelaufen(_nachricht(
          gelesen: true,
          status: 'read',
          geloeschtUm: '2026-08-26T12:05:00Z',
        )),
        isTrue,
      );
    });

    test('aeltere Antwort ohne deleted_at, aber ohne Inhalt: abgelaufen', () {
      // Rueckfall fuer Serverantworten, die das Feld nicht mitschicken.
      expect(
        istAbgelaufen(_nachricht(inhalt: null, gelesen: true, status: 'read')),
        isTrue,
      );
    });

    test('eigener leerer Anhang-Beitrag gilt NICHT als abgelaufen', () {
      // Ein Bild ohne Begleittext hat message == null, ist aber ungelesen.
      // Ohne die is_read-Bedingung waere es sofort unsichtbar.
      expect(istAbgelaufen(_nachricht(inhalt: null)), isFalse);
    });
  });

  group('ablaufFortschritt', () {
    const gelesen = '2026-08-26T12:00:00Z';
    const laeuftAb = '2026-08-26T12:05:00Z';

    Map<String, dynamic> laufend() => _nachricht(
          gelesen: true,
          status: 'read',
          gelesenUm: gelesen,
          laeuftAbUm: laeuftAb,
        );

    test('direkt nach dem Lesen: 0', () {
      expect(
        ablaufFortschritt(laufend(), jetzt: DateTime.parse(gelesen)),
        0.0,
      );
    });

    test('nach der Haelfte der Zeit: 0,5', () {
      expect(
        ablaufFortschritt(laufend(),
            jetzt: DateTime.parse('2026-08-26T12:02:30Z')),
        closeTo(0.5, 0.001),
      );
    });

    test('ueber die Frist hinaus: gedeckelt bei 1', () {
      expect(
        ablaufFortschritt(laufend(),
            jetzt: DateTime.parse('2026-08-26T12:09:00Z')),
        1.0,
      );
    });

    test('ungelesen: kein Balken', () {
      expect(ablaufFortschritt(_nachricht(laeuftAbUm: laeuftAb)), isNull);
    });

    test('ohne Frist: kein Balken', () {
      expect(
        ablaufFortschritt(_nachricht(gelesen: true, status: 'read')),
        isNull,
      );
    });

    test('bereits abgelaufen: kein Balken', () {
      expect(
        ablaufFortschritt(_nachricht(
          inhalt: null,
          gelesen: true,
          status: 'read',
          laeuftAbUm: laeuftAb,
          geloeschtUm: '2026-08-26T12:05:00Z',
        )),
        isNull,
      );
    });

    test('ohne read_at faellt es auf fuenf Minuten zurueck', () {
      expect(
        ablaufFortschritt(
          _nachricht(gelesen: true, status: 'read', laeuftAbUm: laeuftAb),
          jetzt: DateTime.parse('2026-08-26T12:04:00Z'),
        ),
        closeTo(0.8, 0.001),
      );
    });
  });

  group('Rahmen vom WebSocket', () {
    test('message_expired wird gelesen', () {
      // Genau die Form aus ChatServer::purgeExpiredMessages().
      final e = MessageExpiredEvent.fromJson({
        'type': 'message_expired',
        'conversation_id': 42,
        'message_ids': [101, 102],
        'timestamp': '2026-08-26T12:05:00+02:00',
      });
      expect(e.conversationId, 42);
      expect(e.messageIds, [101, 102]);
    });

    test('read_receipt bringt die Fristen mit', () {
      // Der Server schickt `expires` seit jeher; diese App verwarf es.
      final e = ReadReceiptEvent.fromJson({
        'type': 'read_receipt',
        'conversation_id': 42,
        'message_ids': [101],
        'status': 'read',
        'expires': {'101': '2026-08-26T12:05:00Z'},
        'timestamp': '2026-08-26T12:00:00+02:00',
      });
      expect(e.expires['101'], '2026-08-26T12:05:00Z');
    });

    test('read_receipt ohne expires bleibt gutmuetig', () {
      final e = ReadReceiptEvent.fromJson({
        'conversation_id': 42,
        'message_ids': [101],
        'status': 'delivered',
        'timestamp': '2026-08-26T12:00:00+02:00',
      });
      expect(e.expires, isEmpty);
    });
  });
}
