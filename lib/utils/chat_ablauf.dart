// ─── Ablauf gelesener Nachrichten ────────────────────────────────────
// Der Server leert den Inhalt einer Nachricht fuenf Minuten nachdem sie
// gelesen wurde (mark_read.php setzt expires_at, purgeExpiredMessages()
// im WebSocket-Server setzt message = NULL und deleted_at). Das gilt fuer
// JEDE Unterhaltung — die Purge fragt nicht nach der Rolle.
//
// ⚠️ Diese App hat davon bis zum 26.08.2026 nichts gewusst: kein Zuhoerer
// fuer 'message_expired', keine Auswertung von deleted_at. Geloescht wurde
// trotzdem, gemessen waren es 46 von 53 Nachrichten. Sichtbar blieb eine
// leere weisse Blase mit Absender und Uhrzeit — das sah nach einem Fehler
// aus, nicht nach einer abgelaufenen Nachricht.
//
// ⚠️ Warum hier und nicht in `live_chat_dialog.dart` wie in `vorsitzer`:
// dort steht beides mitten im Blasenaufbau und ist damit nur ueber das
// ganze Fenster pruefbar — das laesst sich im Test nicht bauen, weil
// initState eine WebSocket-Verbindung aufmacht. Ausgelagert sind es zwei
// reine Funktionen mit einer einsetzbaren Uhr.

/// Wahr, wenn der Server den Inhalt bereits geleert hat.
///
/// `deleted_at` ist der eindeutige Fall. Der zweite Zweig faengt aeltere
/// Serverantworten ab, die zwar den Inhalt weglassen, das Feld aber nicht
/// mitschicken.
bool istAbgelaufen(Map<String, dynamic> nachricht) {
  if (nachricht['deleted_at'] != null) return true;
  return nachricht['message'] == null && nachricht['is_read'] == true;
}

/// Fortschritt zwischen Lesen und Loeschen, 0.0 bis 1.0.
///
/// `null`, solange nichts laeuft: ungelesen, schon abgelaufen, oder ohne
/// Frist. `jetzt` ist einsetzbar, damit der Test nicht warten muss.
///
/// ⚠️ Die Frist kommt vom Server und wird hier nicht nachgerechnet. Eine
/// eigene Rechnung liefe gegen eine andere Uhr als die Loeschung — die
/// Blase verschwaende dann vor oder nach dem vollen Balken.
double? ablaufFortschritt(Map<String, dynamic> nachricht, {DateTime? jetzt}) {
  if (istAbgelaufen(nachricht)) return null;
  if (nachricht['status'] != 'read') return null;
  if (nachricht['expires_at'] == null) return null;

  final ende = DateTime.tryParse(nachricht['expires_at'].toString());
  if (ende == null) return null;

  final gelesenRoh = nachricht['read_at'];
  final gelesen =
      gelesenRoh != null ? DateTime.tryParse(gelesenRoh.toString()) : null;

  // Ohne read_at bleibt nur die vereinbarte Fensterlaenge als Rueckfall.
  final start = gelesen ?? ende.subtract(const Duration(minutes: 5));
  final gesamt = ende.difference(start).inMilliseconds;
  if (gesamt <= 0) return null;

  final vergangen = (jetzt ?? DateTime.now()).difference(start).inMilliseconds;
  return (vergangen / gesamt).clamp(0.0, 1.0);
}
