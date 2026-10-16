import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Abgleich App ↔ Server (Etappe 2.6, 16.10.2026), Befund 7: die App kannte
/// 22 Endpunkte, die NUR der Vorsitzer benutzen darf — 20 unter `admin/`
/// (`requireAdminRole()` oder `$user['role'] !== 'vorsitzer'` im Endpunkt
/// selbst) und die automatischen Nachrichten unter `chat/` — dazu
/// `auth/register.php`, den es gar nicht gibt. Jeder Aufruf hätte nur 403
/// bzw. 404 bekommen. Im nginx-Protokoll (53 Tage) kam keiner vor außer dem
/// alten Reiter „Verifizierung“ (74 × 403, am 15.10. ersetzt): die
/// Bildschirme dazu hingen seit dem 24.08.2026 an keinem Menü. Am 16.10.
/// ging alles hinaus — Wunsch des Vorsitzenden: „elimina codul mort“.
///
/// Der Schatzmeister hat sein eigenes API (`schatzmeister/…`, Entscheidung
/// vom 02.10.2026). Diese Datei hält fest, dass nichts davon zurückkommt —
/// gleich ob aus einem Dienst oder aus einem Bildschirm.
///
/// ⚠️ Das PHP liegt in keinem Repo — diese Datei ist die einzige Stelle im
/// Baum, an der so ein Aufruf auffallen kann.
void main() {
  /// Jede Code-Zeile unter lib/ mit ihrer Stelle — Kommentare zählen nicht.
  Iterable<(String, String)> codeZeilen() sync* {
    for (final e in Directory('lib').listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart')) continue;
      final zeilen = e.readAsLinesSync();
      for (var i = 0; i < zeilen.length; i++) {
        if (zeilen[i].trimLeft().startsWith('//')) continue;
        yield ('${e.path}:${i + 1}', zeilen[i]);
      }
    }
  }

  test('kein Aufruf unter admin/ — das ist der Namensraum des Vorsitzers', () {
    final treffer = [
      for (final (ort, zeile) in codeZeilen())
        if (zeile.contains('/admin/')) '$ort: ${zeile.trim()}',
    ];
    expect(treffer, isEmpty,
        reason: 'admin/ lässt nur den Vorsitzer zu — für den Schatzmeister immer 403');
  });

  test('keine automatischen Nachrichten des Vorsitzers unter chat/', () {
    final treffer = [
      for (final (ort, zeile) in codeZeilen())
        for (final endpunkt in ['chat/scheduled_messages.php', 'chat/conversation_scheduled.php'])
          if (zeile.contains(endpunkt)) '$ort: $endpunkt',
    ];
    expect(treffer, isEmpty, reason: 'requireAdminRole() — für den Schatzmeister immer 403');
  });

  test('kein auth/register.php — den Endpunkt gibt es nicht', () {
    final treffer = [
      for (final (ort, zeile) in codeZeilen())
        if (zeile.contains('auth/register.php')) ort,
    ];
    expect(treffer, isEmpty, reason: 'die Anmeldung läuft über den Assistenten; register.php → 404');
  });
}
