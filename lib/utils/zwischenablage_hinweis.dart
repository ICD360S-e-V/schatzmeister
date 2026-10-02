import 'package:flutter/material.dart';

import '../services/language_service.dart';
import 'sicher_clipboard.dart';

/// Zeigt „Zwischenablage gelöscht" als SnackBar — wie in der Vorsitzer-App
/// (#1045, 02.10.2026: „sa ne notifice in aplicatie cand clipboard sa
/// sters").
///
/// Über den Navigator der App ([navigator], `NotificationService.navigatorKey`
/// in main.dart): sein ScaffoldMessenger erreicht jeden Bildschirm. Android
/// meldet eine Löschung, die geschah, während die App im Hintergrund war,
/// sobald sie wieder vorn ist — dann mit der Uhrzeit.
void zwischenablageHinweisAnmelden(GlobalKey<NavigatorState> navigator) {
  SicherClipboard.melderSetzen((DateTime zeit, {required bool spaet}) {
    final ctx = navigator.currentContext;
    if (ctx == null) return;
    ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(SnackBar(
      content: _Geloescht(geloeschtText(zeit, spaet: spaet)),
      duration: const Duration(seconds: 3),
    ));
  });
}

/// „Zwischenablage gelöscht" — verspätet mit der Uhrzeit.
String geloeschtText(DateTime zeit, {required bool spaet}) {
  if (!spaet) return tr('Zwischenablage gelöscht', 'Clipboard golit');
  String zwei(int n) => n.toString().padLeft(2, '0');
  final uhr = '${zwei(zeit.hour)}:${zwei(zeit.minute)}:${zwei(zeit.second)}';
  return tr('Zwischenablage um $uhr gelöscht', 'Clipboard golit la $uhr');
}

class _Geloescht extends StatelessWidget {
  const _Geloescht(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    // In der Farbe des Textes der SnackBar: passt ohne eigene Regel.
    final farbe = DefaultTextStyle.of(context).style.color ??
        Theme.of(context).colorScheme.onInverseSurface;
    return Row(
      children: [
        Icon(Icons.content_paste_off, size: 18, color: farbe),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}
