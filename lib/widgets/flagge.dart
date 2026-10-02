import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Landesflagge für die Sprachauswahl.
///
/// Dieselben SVG-Dateien wie in der Mitglieder-App (`assets/flags/<code>.svg`,
/// aus dem Satz flag-icons, 4:3) und dieselbe Darstellung: abgerundete Ecken,
/// `BoxFit.cover`. Ein Emoji wäre ohne Farb-Emoji-Schrift (Linux, manche
/// Windows-Fassungen) nur ein leeres Kästchen.
class Flagge extends StatelessWidget {
  final String code;
  final double breite;

  const Flagge({super.key, required this.code, this.breite = 48});

  /// Pfad der Flaggendatei zu einem Sprachcode.
  static String asset(String code) => 'assets/flags/$code.svg';

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: breite,
        height: breite * 0.75,
        child: SvgPicture.asset(
          asset(code),
          fit: BoxFit.cover,
          semanticsLabel: code.toUpperCase(),
        ),
      ),
    );
  }
}
