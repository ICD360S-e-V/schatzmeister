import 'dart:io';

import 'package:flutter/material.dart';

import '../services/language_service.dart';
import '../services/remote_input/input_injector_android.dart';

/// Zeile im Profil: darf der Vorsitz dieses Telefon während einer Fernwartung
/// bedienen? Wie in der Mitglieder-App (Profil ▸ Fernwartung).
///
/// ⚠️ Der Schalter kann NICHT selbst einschalten: eine App darf sich einen
/// Bedienungshilfen-Dienst nicht erteilen. Er öffnet die Systemseite, und der
/// Zustand wird beim Zurückkommen neu gelesen — sonst stünde hier „aus",
/// während die Steuerung längst läuft.
///
/// Nur Android; anderswo zeichnet die Zeile nichts.
class FernsteuerungZeile extends StatefulWidget {
  const FernsteuerungZeile({super.key, this.istAndroid});

  /// Nur für Tests: Android vortäuschen bzw. ausschließen.
  final bool? istAndroid;

  @override
  State<FernsteuerungZeile> createState() => _FernsteuerungZeileState();
}

class _FernsteuerungZeileState extends State<FernsteuerungZeile>
    with WidgetsBindingObserver {
  bool _an = false;

  bool get _android => widget.istAndroid ?? Platform.isAndroid;

  @override
  void initState() {
    super.initState();
    if (_android) {
      WidgetsBinding.instance.addObserver(this);
      _lesen();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _lesen();
  }

  Future<void> _lesen() async {
    final an = await AndroidInputInjector.istAktiviert();
    if (mounted) setState(() => _an = an);
  }

  Future<void> _einstellungen() async {
    final offen = await AndroidInputInjector.einstellungenOeffnen();
    if (!offen && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr(
          'Bitte unter Einstellungen ▸ Bedienungshilfen „ICD360S Schatzmeister – Fernwartung" einschalten.',
          'Vă rugăm să porniți „ICD360S Trezorier – asistență la distanță" în Setări ▸ Accesibilitate.',
        )),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_android) return const SizedBox.shrink();
    final grau = Colors.grey.shade600;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(Icons.screen_share_outlined, color: grau, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('Fernwartung', 'Asistență la distanță'),
                style: TextStyle(fontSize: 12, color: grau),
              ),
              const SizedBox(height: 2),
              Text(
                _an
                    ? tr('Steuerung ist eingeschaltet', 'Controlul este pornit')
                    : tr('Steuerung erlauben', 'Permite controlul'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                tr(
                  'Der Vorsitz kann Ihr Telefon während einer Fernwartung bedienen, auch in '
                      'anderen Apps. Sie stimmen jeder Sitzung einzeln zu; ohne Sitzung geschieht '
                      'nichts. Der Dienst kann Ihren Bildschirm nicht lesen.',
                  'Conducerea asociației vă poate folosi telefonul în timpul unei sesiuni de '
                      'asistență, și în alte aplicații. Aprobați fiecare sesiune separat; fără '
                      'sesiune nu se întâmplă nimic. Serviciul nu poate citi ecranul.',
                ),
                style: TextStyle(fontSize: 12, color: grau),
              ),
            ],
          ),
        ),
        Switch(
          key: const ValueKey('fernsteuerung_schalter'),
          value: _an,
          onChanged: (_) => _einstellungen(),
        ),
      ],
    );
  }
}
