import 'dart:async';
import 'dart:io';

import '../services/language_service.dart';
import '../services/logger_service.dart';

/// Wandelt eine Ausnahme in eine verständliche Meldung (Deutsch/Rumänisch).
/// Die technischen Einzelheiten gehen ins Protokoll.
///
/// Kopie von `lib/utils/error_helpers.dart` der Mitglieder-App (15.10.2026),
/// mit `tr(de, ro)` statt AppLocalizations — gebraucht von der Verifizierung
/// (`widgets/verifizierung_tab.dart`).
String getUserFriendlyError(Object error, {String? tag}) {
  LoggerService().error('$error', tag: tag ?? 'ERROR');

  final keinNetz = tr('Keine Internetverbindung. Bitte überprüfen Sie Ihr Netzwerk.',
      'Nu există conexiune la internet. Verificați rețeaua.');
  final zeit = tr('Server antwortet nicht. Bitte versuchen Sie es später erneut.',
      'Serverul nu răspunde. Încercați din nou mai târziu.');
  final server = tr('Serverfehler. Bitte versuchen Sie es später erneut.',
      'Eroare de server. Încercați din nou mai târziu.');
  final verbindung = tr('Verbindungsfehler. Bitte versuchen Sie es später erneut.',
      'Eroare de conexiune. Încercați din nou mai târziu.');

  if (error is SocketException) return keinNetz;
  if (error is TimeoutException) return zeit;
  if (error is HttpException || error is FormatException) return server;
  if (error is HandshakeException || error is TlsException) return verbindung;
  final msg = error.toString().toLowerCase();
  if (msg.contains('socketexception') || msg.contains('no route') || msg.contains('network is unreachable')) {
    return keinNetz;
  }
  if (msg.contains('timeout') || msg.contains('timed out')) return zeit;
  if (msg.contains('connection refused') || msg.contains('connection reset')) return server;
  if (msg.contains('certificate') || msg.contains('handshake')) return verbindung;
  return tr('Ein unerwarteter Fehler ist aufgetreten. Bitte versuchen Sie es später erneut.',
      'A apărut o eroare neașteptată. Încercați din nou mai târziu.');
}
