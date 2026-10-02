import 'package:flutter/material.dart';

import '../services/language_service.dart';
import '../widgets/flagge.dart';

/// Sprachauswahl Deutsch / Rumänisch — nach dem Vorbild der Mitglieder-App.
///
/// Beim ersten Start steht sie vor der Geräteaktivierung, lässt sich nicht
/// überspringen und ersetzt sich nach der Wahl durch [danach]. Vom
/// Aktivierungsbildschirm oder aus dem Profil geöffnet ([allowBack]),
/// schließt sie sich nach der Wahl selbst.
class SprachauswahlScreen extends StatelessWidget {
  final Widget? danach;
  final bool allowBack;

  const SprachauswahlScreen({
    super.key,
    this.danach,
    this.allowBack = false,
  });

  @override
  Widget build(BuildContext context) {
    final hatGewaehlt = LanguageService.instance.hasUserChoice;
    final aktuell = LanguageService.instance.currentCode;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.teal.shade700, Colors.teal.shade900],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    if (allowBack)
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        tooltip: tr('Zurück', 'Înapoi'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'ICD360S e.V',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Schatzmeister Portal',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Zweisprachig und bewusst nicht übersetzt: die Sprache
                        // steht ja gerade erst zur Wahl.
                        Text(
                          'Sprache wählen / Selectează limba',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            for (final lang in LanguageService.supported)
                              _kachel(
                                context,
                                lang,
                                // Ohne Wahl sieht keine Kachel vorgewählt aus —
                                // sonst wirkte Deutsch nur als Rückfall gesetzt.
                                hatGewaehlt && lang.code == aktuell,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kachel(BuildContext context, AppLanguage lang, bool gewaehlt) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('sprache_${lang.code}'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => _waehlen(context, lang.code),
        child: Container(
          width: 140,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: gewaehlt ? 0.25 : 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: gewaehlt ? Colors.white : Colors.white.withValues(alpha: 0.3),
              width: gewaehlt ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flagge(code: lang.code, breite: 64),
              const SizedBox(height: 12),
              Text(
                lang.nativeName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                lang.code.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _waehlen(BuildContext context, String code) async {
    await LanguageService.instance.setLanguage(code);
    if (!context.mounted) return;
    final weiter = danach;
    if (weiter != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => weiter),
      );
    } else {
      Navigator.of(context).pop();
    }
  }
}
