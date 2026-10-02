import 'dart:async';

import 'package:flutter/material.dart';

import '../services/language_service.dart';

/// Zustimmung VOR jeder Freigabe — übernommen aus der Mitglieder-App.
///
/// Rechtlich der Kern: ausdrücklich, je Sitzung, informiert. Nichts wird
/// geteilt, bevor „Erlauben" getippt ist; nach 60 Sekunden ohne Antwort wird
/// abgelehnt, damit ein unbeaufsichtigtes Telefon nie Zugriff gewährt.
///
/// Texte auf Deutsch und Rumänisch, je nach der in der App gewählten Sprache.
class RemoteConsentDialog extends StatefulWidget {
  final String controllerName;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const RemoteConsentDialog({
    super.key,
    required this.controllerName,
    required this.onAccept,
    required this.onDecline,
  });

  /// Nach so vielen Sekunden gilt die Anfrage als abgelehnt. Der Vorsitz gibt
  /// nach derselben Zeit auf.
  static const int zeitlimitSekunden = 60;

  @override
  State<RemoteConsentDialog> createState() => _RemoteConsentDialogState();
}

class _RemoteConsentDialogState extends State<RemoteConsentDialog> {
  int _remaining = RemoteConsentDialog.zeitlimitSekunden;
  Timer? _timer;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) _finish(accept: false);
    });
  }

  void _finish({required bool accept}) {
    if (_done) return;
    _done = true;
    _timer?.cancel();
    if (accept) {
      widget.onAccept();
    } else {
      widget.onDecline();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final farben = Theme.of(context).colorScheme;
    final name = widget.controllerName;
    return Material(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 440),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: farben.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          // Scrollbar: auf einem kurzen Display oder mit großer Systemschrift
          // darf „Erlauben" nicht unter dem Rand verschwinden.
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  radius: 36,
                  child: Icon(Icons.screen_share, size: 36),
                ),
                const SizedBox(height: 16),
                Text(
                  tr('Fernwartung-Anfrage', 'Cerere de asistență la distanță'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  tr(
                    '„$name" möchte Ihren Bildschirm sehen und steuern, um Ihnen zu helfen. '
                        'Es wird nichts ohne Ihre Zustimmung übertragen.',
                    '„$name" dorește să vă vadă și să vă controleze ecranul pentru a vă ajuta. '
                        'Nu se transmite nimic fără acordul dvs.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: farben.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Flexible(
                      // ⚠️ Anders als in der Mitglieder-App ausdrücklich gesagt:
                      // die Sitzung läuft in anderen Apps weiter. Wer das nicht
                      // weiß, hält das Weiterlaufen für einen Fehler.
                      child: Text(
                        tr(
                          'Die Sitzung läuft auch in anderen Apps weiter. Beenden können Sie '
                              'jederzeit: hier oben mit „Stopp" oder in der Benachrichtigung '
                              'mit „Beenden".',
                          'Sesiunea continuă și în alte aplicații. O puteți opri oricând: '
                              'aici sus cu „Stop" sau din notificare cu „Oprește".',
                        ),
                        style: TextStyle(fontSize: 12, color: farben.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _finish(accept: false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          foregroundColor: farben.error,
                        ),
                        child: Text('${tr('Ablehnen', 'Refuză')} ($_remaining)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _finish(accept: true),
                        style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14)),
                        child: Text(tr('Erlauben', 'Permite')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
