import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Kopiert in die Zwischenablage — abgesichert, für JEDE Kopie der App. Wie
/// in der Vorsitzer-App (#1045, 02.10.2026); Festlegung des Vorsitzenden:
/// „cand copiem ceva indiferent ce este sa fie 30 de secunde timerul si sa
/// stearga tot clipboard … si sa ne notifice in aplicatie".
///
///  * **Android:** über den nativen Kanal ([kanal], Zwischenablage.kt) als
///    `EXTRA_IS_SENSITIVE` markiert — Tastatur und System-Vorschau zeigen
///    Punkte statt des Werts — und nach höchstens [standardTtl] gelöscht. Der
///    Zeitgeber lebt dort, im Prozess.
///  * **Windows, Linux, macOS, iOS** (und der Test-Host): Flutters
///    [Clipboard.setData] und ein Dart-Timer, der danach '' hineinlegt
///    ([spaeterLeeren]).
///  * Auch ein rohes [Clipboard.setData] — und damit „Kopieren" im
///    Kontextmenü jedes Textfelds — landet hier: `SicherClipboardBindung`
///    fängt es ab (sicher_clipboard_bindung.dart).
///  * Gelöscht → `zwischenablageHinweisAnmelden` zeigt es als SnackBar.
///
/// Bewusst wird das Kopieren NICHT unterbunden (OWASP hat diese Forderung
/// zurückgezogen — es zerstört die Nutzbarkeit mit Passwort-Managern); es wird
/// nur abgesichert.
class SicherClipboard {
  SicherClipboard._();

  static const MethodChannel kanal =
      MethodChannel('de.icd360sev.schatzmeister/clipboard');

  /// Länger bleibt nichts in der Zwischenablage; eine längere Frist wird
  /// gekürzt.
  static const Duration standardTtl = Duration(seconds: 30);

  static Timer? _loeschTimer;

  /// Liegt noch etwas OHNE den Kanal Kopiertes in der Zwischenablage?
  static bool _ohneKanalFaellig = false;

  /// Kopiert [text] und leert die Zwischenablage nach [ttl] — höchstens nach
  /// [standardTtl].
  static Future<void> kopiere(String text,
      {Duration ttl = standardTtl}) async {
    if (await nativ(text, ttl: ttl)) return;
    await Clipboard.setData(ClipboardData(text: text));
    spaeterLeeren(ttl);
  }

  /// Über den nativen Kanal (nur Android): true, wenn [text] darin liegt.
  static Future<bool> nativ(String text, {Duration ttl = standardTtl}) async {
    if (!Platform.isAndroid) return false;
    try {
      final ok = await kanal.invokeMethod<bool>('copySensitive', {
        'text': text,
        'frist': gekuerzt(ttl).inMilliseconds,
      });
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  /// Ohne den Kanal: nach [ttl] (höchstens [standardTtl]) leeren.
  static void spaeterLeeren([Duration ttl = standardTtl]) {
    _ohneKanalFaellig = true;
    _loeschTimer?.cancel();
    _loeschTimer = Timer(gekuerzt(ttl), leere);
  }

  /// Leert die Zwischenablage sofort — nur, wenn noch etwas aus der App
  /// darin liegt.
  static Future<void> leere() async {
    _loeschTimer?.cancel();
    _loeschTimer = null;
    if (Platform.isAndroid) {
      try {
        await kanal.invokeMethod<void>('leere');
      } catch (_) {}
    }
    if (!_ohneKanalFaellig) return;
    _ohneKanalFaellig = false;
    try {
      await Clipboard.setData(const ClipboardData(text: ''));
    } catch (_) {}
    _zeigen(DateTime.now(), spaet: false);
  }

  /// [ttl], auf höchstens [standardTtl] gekürzt.
  @visibleForTesting
  static Duration gekuerzt(Duration ttl) => ttl > standardTtl ? standardTtl : ttl;

  static void Function(DateTime zeit, {required bool spaet})? _melder;

  /// Wer zeigt, dass gelöscht wurde: `zwischenablageHinweisAnmelden`.
  static void melderSetzen(
      void Function(DateTime zeit, {required bool spaet}) melder) {
    _melder = melder;
    kanal.setMethodCallHandler(_vonAndroid);
  }

  /// Nimmt [melder] wieder ab — nur, wenn er noch der aktuelle ist.
  static void melderLoesen(
      void Function(DateTime zeit, {required bool spaet}) melder) {
    if (_melder != melder) return;
    _melder = null;
    kanal.setMethodCallHandler(null);
  }

  /// Android meldet: gelöscht — `spaet`, wenn es geschah, während die App im
  /// Hintergrund war.
  static Future<void> _vonAndroid(MethodCall call) async {
    if (call.method != 'geloescht') return;
    final a = call.arguments;
    final ms = a is Map ? a['zeit'] : null;
    _zeigen(
      ms is int ? DateTime.fromMillisecondsSinceEpoch(ms) : DateTime.now(),
      spaet: a is Map && a['spaet'] == true,
    );
  }

  static void _zeigen(DateTime zeit, {required bool spaet}) =>
      _melder?.call(zeit, spaet: spaet);
}
