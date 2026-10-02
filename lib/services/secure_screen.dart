import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Schaltet FLAG_SECURE um.
///
/// Die App setzt FLAG_SECURE beim Start, damit niemand die Finanzansichten
/// abfotografiert oder aufnimmt. Genau das macht aber auch die Aufnahme einer
/// Fernwartung SCHWARZ, solange die App vorne ist. Während einer zugestimmten
/// Sitzung wird die Sperre deshalb aufgehoben und am Ende wieder gesetzt.
/// Außerhalb von Android tut die Klasse nichts.
///
/// ⚠️ Eigene Kanalnamen (`de.icd360sev.schatzmeister/…`), nicht die der
/// Mitglieder-App: die beiden Apps sind getrennt und bleiben es.
class SecureScreen {
  static const MethodChannel _ch =
      MethodChannel('de.icd360sev.schatzmeister/secure_screen');

  /// [secure] false = Aufnahme erlauben (während der Sitzung), true = Sperre
  /// wieder setzen. Gibt zurück, ob die Sperre danach TATSÄCHLICH aus ist —
  /// gemessen im UI-Thread, nicht gewünscht.
  ///
  /// ⚠️ Bleibt FLAG_SECURE stehen, sieht der Vorsitz ein schwarzes Bild und
  /// hält es für ein Netzproblem. Der Rückgabewert geht deshalb mit der Antwort
  /// an die Gegenseite (`bild_frei`).
  static Future<bool> setSecure(bool secure) async {
    if (!Platform.isAndroid) return !secure;
    try {
      final jetztGesperrt =
          await _ch.invokeMethod<bool>('setSecure', {'secure': secure});
      if (jetztGesperrt == null) return !secure;
      return !jetztGesperrt;
    } catch (e) {
      debugPrint('[SecureScreen] FLAG_SECURE nicht umschaltbar: $e');
      return false;
    }
  }
}

/// Der Vordergrunddienst (`mediaProjection`), der die Aufnahme trägt.
///
/// Er ist der Grund, warum die Fernwartung WEITERLÄUFT, wenn die
/// Schatzmeisterin die App verlässt: Android 10+ beendet eine Aufnahme ohne
/// ihn, sobald die App im Hintergrund ist, und Android 14+ startet sie ohne ihn
/// gar nicht erst. Geholfen wird aber meistens GERADE in anderen Apps.
///
/// Seine Benachrichtigung ist zugleich der Ausschalter von überall: ein Tipp
/// öffnet die App, „Beenden" beendet die Sitzung, ohne die App zu öffnen.
class ScreenCaptureFgService {
  static const MethodChannel _ch =
      MethodChannel('de.icd360sev.schatzmeister/screen_capture');

  static VoidCallback? _beiStopp;

  /// ⚠️ Startreihenfolge: **erst die Zustimmung, dann dieser Dienst, dann die
  /// Aufnahme.** Die Android-Doku zu den Diensttypen: „Call
  /// createScreenCaptureIntent() before starting the foreground service … the
  /// user must grant the permission before you can create the service."
  ///
  /// [titel], [text] und [stopp] stehen in der Benachrichtigung — in der
  /// Sprache, die in der App gewählt ist, nicht in der des Telefons.
  /// [beiStopp] läuft, wenn dort „Beenden" getippt wird.
  static Future<void> start({
    required String titel,
    required String text,
    required String stopp,
    required VoidCallback beiStopp,
  }) async {
    // Den Rückweg zuerst anmelden: die Antwort auf „Beenden" darf nicht davon
    // abhängen, ob der Start selbst noch durchläuft.
    _beiStopp = beiStopp;
    _ch.setMethodCallHandler(_vonAndroid);
    if (!Platform.isAndroid) return;
    try {
      await _ch.invokeMethod('start', {
        'titel': titel,
        'text': text,
        'stopp': stopp,
      });
    } catch (e) {
      debugPrint('[ScreenCaptureFgService] start fehlgeschlagen: $e');
    }
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    _beiStopp = null;
    try {
      await _ch.invokeMethod('stop');
    } catch (_) {}
  }

  static Future<dynamic> _vonAndroid(MethodCall call) async {
    if (call.method == 'stoppGetippt') {
      _beiStopp?.call();
    }
    return null;
  }
}
