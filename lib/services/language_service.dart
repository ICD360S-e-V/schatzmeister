import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Eine Sprache, die das Portal vollständig mitbringt.
class AppLanguage {
  final String code;
  final String nativeName;

  const AppLanguage(this.code, this.nativeName);
}

/// Die vom Schatzmeister gewählte Oberflächensprache.
///
/// Vorher kam die Sprache aus der Geräteeinstellung: ein Telefon auf Deutsch
/// zeigte das Portal auf Deutsch, auch wenn die Schatzmeisterin lieber
/// Rumänisch liest. Jetzt wird beim ersten Start gewählt (wie in der
/// Mitglieder-App) und die Wahl bleibt gespeichert; ändern lässt sie sich
/// auf dem Aktivierungsbildschirm und im Profil.
class LanguageService {
  LanguageService._();
  static final LanguageService instance = LanguageService._();

  static const _prefsKey = 'app_locale_v1';
  static const String fallbackCode = 'de';

  /// Reihenfolge = Reihenfolge der Kacheln auf dem Auswahlbildschirm.
  static const List<AppLanguage> supported = [
    AppLanguage('de', 'Deutsch'),
    AppLanguage('ro', 'Română'),
  ];

  String? _savedCode;
  bool _loaded = false;

  /// MaterialApp hört hierauf, damit ein Wechsel sofort sichtbar wird.
  final ValueNotifier<Locale> localeNotifier =
      ValueNotifier<Locale>(const Locale(fallbackCode));

  /// true, sobald einmal ausdrücklich gewählt wurde.
  bool get hasUserChoice => _savedCode != null;

  /// Aktuell angezeigte Sprache (nie null — ohne Wahl Deutsch).
  String get currentCode => localeNotifier.value.languageCode;

  bool get isRomanian => currentCode == 'ro';

  /// Liest die gespeicherte Wahl. Mehrfach aufrufbar.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefsKey);
      if (code != null && _isSupported(code)) {
        _savedCode = code;
        localeNotifier.value = Locale(code);
      }
    } catch (e) {
      debugPrint('[LanguageService] load failed: $e');
    }
  }

  /// Speichert die Wahl und schaltet die Oberfläche sofort um.
  Future<void> setLanguage(String code) async {
    final resolved = _isSupported(code) ? code.toLowerCase() : fallbackCode;
    _savedCode = resolved;
    localeNotifier.value = Locale(resolved);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, resolved);
    } catch (e) {
      debugPrint('[LanguageService] save failed: $e');
    }
  }

  /// Nur für Tests: vergessenen Zustand wiederherstellen.
  @visibleForTesting
  void resetForTest() {
    _savedCode = null;
    _loaded = false;
    localeNotifier.value = const Locale(fallbackCode);
  }

  bool _isSupported(String code) =>
      supported.any((l) => l.code == code.toLowerCase());
}

/// Text in der gewählten Sprache: `tr('Speichern', 'Salvează')`.
///
/// Deutsch und Rumänisch stehen nebeneinander im Code — genau wie in
/// [AppLocalizations], nur ohne eigenen Getter für jeden Satz. Braucht keinen
/// BuildContext und funktioniert deshalb auch in Diensten (Benachrichtigungen,
/// Fehlermeldungen). Neu gezeichnet wird bei einem Wechsel über main.dart.
String tr(String de, String ro) =>
    LanguageService.instance.isRomanian ? ro : de;
