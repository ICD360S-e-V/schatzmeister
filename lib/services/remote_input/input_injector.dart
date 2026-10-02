import 'dart:io';

import 'input_injector_android.dart';

/// Führt die Eingaben des Vorsitzes auf diesem Gerät aus — die AGENT-Seite der
/// Fernwartung, übernommen aus der Mitglieder-App.
///
/// ⚠️ Nur Android. Die Schatzmeister-App wird nur für Android gebaut; die
/// Schreibtisch-Umsetzungen der Mitglieder-App (SendInput, XTest, CGEvent)
/// gehören nicht hierher. Überall sonst bleibt es beim Zuschauen
/// ([NoopInputInjector]).
///
/// Auf Android: Gesten über den FernwartungService (AccessibilityService) —
/// Tippen, langes Tippen, Wischen, Zurück/Start/Übersicht. Nur wenn die
/// Schatzmeisterin den Dienst in den Android-Einstellungen eingeschaltet hat.
/// ⚠️ Kein Schreiben in Textfelder: der Dienst hat bewusst KEINEN Lesezugriff
/// auf den Bildschirminhalt.
///
/// Koordinaten kommen normiert (0..1) über den geteilten Bildschirm; die
/// Umrechnung auf Pixel geschieht nativ gegen die echte Anzeige.
abstract class InputInjector {
  /// Kann dieses Gerät gerade gesteuert werden? Bei false bleibt es beim
  /// Zuschauen, und genau das wird dem Vorsitz mit der Antwort gemeldet.
  bool get isSupported;

  /// Pixelgröße des geteilten Bildschirms. Auf Android nicht nötig.
  void setScreenSize(int width, int height);

  /// Zeiger auf eine normierte Position (0..1, Ursprung oben links).
  Future<void> mouseMove(double nx, double ny);

  /// Taste drücken (down=true) oder loslassen. 0=links, 1=Mitte, 2=rechts.
  Future<void> mouseButton(int button, bool down);

  /// Rad. Positives dy scrollt nach unten.
  Future<void> mouseWheel(double dx, double dy);

  /// Taste. [hid] ist der USB-HID-Code (PhysicalKeyboardKey.usbHidUsage).
  Future<void> keyEvent({required int hid, String? character, required bool down});

  /// Einmalige Vorbereitung, bevor Eingaben kommen. Android braucht sie, weil
  /// erst zur Laufzeit feststeht, ob der Bedienungshilfen-Dienst läuft.
  Future<void> vorbereiten() async {}

  /// Systemweite Aktion ohne Koordinaten: `back`, `home`, `recents`,
  /// `notifications`.
  Future<void> systemAktion(String name) async {}

  void dispose() {}
}

/// Nur zuschauen: schluckt jede Eingabe.
class NoopInputInjector extends InputInjector {
  final String reason;
  NoopInputInjector([this.reason = 'view-only']);

  @override
  bool get isSupported => false;

  @override
  void setScreenSize(int width, int height) {}

  @override
  Future<void> mouseMove(double nx, double ny) async {}

  @override
  Future<void> mouseButton(int button, bool down) async {}

  @override
  Future<void> mouseWheel(double dx, double dy) async {}

  @override
  Future<void> keyEvent({required int hid, String? character, required bool down}) async {}

  @override
  void dispose() {}
}

/// Der passende Injektor für dieses Gerät.
InputInjector createInputInjector() {
  try {
    if (Platform.isAndroid) {
      // isSupported ist hier zunächst false; RemoteAgentService ruft
      // vorbereiten() ab, und erst dann steht fest, ob gesteuert werden darf.
      return AndroidInputInjector();
    }
  } catch (_) {
    // Platform kann in ungewöhnlichen Einbettungen werfen — dann zuschauen.
  }
  return NoopInputInjector('nur-android');
}
