import 'package:flutter/material.dart';

/// Landesflagge für die Sprachauswahl, aus drei Streifen gezeichnet.
///
/// Beide Flaggen sind schlichte Trikoloren — dafür lohnt weder ein
/// SVG-Paket noch ein Emoji, das ohne Farb-Emoji-Schrift (Linux, manche
/// Windows-Fassungen) als leeres Kästchen erscheint.
class Flagge extends StatelessWidget {
  final String code;
  final double breite;

  const Flagge({super.key, required this.code, this.breite = 48});

  // Offizielle Farbwerte.
  static const _deutschland = [Color(0xFF000000), Color(0xFFDD0000), Color(0xFFFFCE00)];
  static const _rumaenien = [Color(0xFF002B7F), Color(0xFFFCD116), Color(0xFFCE1126)];

  @override
  Widget build(BuildContext context) {
    final rumaenisch = code == 'ro';
    final farben = rumaenisch ? _rumaenien : _deutschland;
    final streifen = [for (final f in farben) Expanded(child: ColoredBox(color: f))];
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: breite,
        height: breite * 0.75,
        // Deutschland: waagerecht, Rumänien: senkrecht. stretch, weil ein
        // ColoredBox ohne Kind quer zur Achse sonst 0 breit bleibt.
        child: rumaenisch
            ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: streifen)
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: streifen),
      ),
    );
  }
}
