import 'package:flutter_test/flutter_test.dart';
import 'package:icd360sev_schatzmeister/utils/protokoll_schutz.dart';

void main() {
  test('Rufnummer: nur die Zahl der Ziffern, nie die Ziffern selbst', () {
    expect(protokollNummer('+49 731 80159736'), 'Rufnummer (13 Ziffern)');
    expect(protokollNummer('0160/94482053'), 'Rufnummer (12 Ziffern)');
    expect(protokollNummer(null), 'anonym');
    expect(protokollNummer('  '), 'anonym');
    expect(protokollNummer('anonymous'), 'anonym');
    expect(protokollNummer('Max Mustermann'), 'ohne Ziffern');
    expect(protokollNummer('+49 731 80159736'), isNot(contains('731')));
  });

  test('Position: auf eine Nachkommastelle gerundet', () {
    expect(protokollPosition(48.39841, 9.99155), '≈48.4/10.0');
    expect(protokollPosition(null, 9.9), 'ohne Position');
    expect(protokollPosition(48.39841, 9.99155), isNot(contains('3984')));
  });

  test('Pfad einer App-Datei: nur der Dateiname, kein Benutzerverzeichnis', () {
    expect(protokollDatei(r'C:\Users\Max Mustermann\AppData\Local\schatzmeister-1.6.4.msix'), 'schatzmeister-1.6.4.msix');
    expect(protokollDatei('/data/user/0/de.icd360sev.schatzmeister/cache/schatzmeister-1.6.4.apk'), 'schatzmeister-1.6.4.apk');
    expect(protokollDatei(null), '-');
    expect(protokollDatei(''), '-');
  });

  test('Datei eines Mitglieds: nur Endung und Länge', () {
    expect(protokollEndung('Bescheid_Mustermann.PDF'), '.pdf (23 Zeichen)');
    expect(protokollEndung('ohne_endung'), '.? (11 Zeichen)');
    expect(protokollEndung('.versteckt'), '.? (10 Zeichen)');
    expect(protokollEndung(null), '-');
  });
}
