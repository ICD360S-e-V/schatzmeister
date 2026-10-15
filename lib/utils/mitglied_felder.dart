/// Die gemeinsamen Werte der Beitrittsangaben.
///
/// Dieselben Werte speichern das Online-Formular (icd360s.de/anmeldung.php),
/// der Assistent dieser App und die Verifizierung im Vorstandspanel — vorher
/// hatte jeder der drei seine eigene Liste (Geschlecht als 'maennlich' hier,
/// 'M' dort; vier Familienstände hier, acht dort; Aufenthaltsstatus als
/// Schlüssel hier, als Etikett dort). Gespeichert wird immer der Wert aus
/// diesen Listen, angezeigt die Übersetzung.
///
/// ⚠️ Altwerte: ältere Datensätze tragen noch 'maennlich', 'weiblich',
/// 'divers', 'keine_angabe' bzw. beim Aufenthaltsstatus das deutsche Etikett
/// des Vorstandspanels. Jede Vorbelegung läuft deshalb über die Abbildungen
/// hier — nie direkt über den gespeicherten Text.
///
/// ⚠️ KOPIE von `lib/utils/mitglied_felder.dart` der Mitglieder-App (Stand
/// 15.10.2026) für die Verifizierung des Schatzmeisters
/// (`widgets/verifizierung_tab.dart`). Die WERTE müssen Zeichen für Zeichen
/// dieselben bleiben wie dort und in `api/helpers/mitglied_felder.php` — nur
/// die Anzeige läuft hier über `tr(de, ro)` statt über die ARB-Dateien.
library;

import '../services/language_service.dart';

// ── Geschlecht ─────────────────────────────────────────────────────────────

/// M männlich · W weiblich · D divers · X ohne Angabe (§ 22 Abs. 3 PStG).
const geschlechtWerte = <String>['M', 'W', 'D', 'X'];

/// Gespeicherter Wert (auch ein Altwert) → Code, oder null.
String? geschlechtCode(String? roh) {
  final g = (roh ?? '').trim().toLowerCase();
  return switch (g) {
    'm' || 'maennlich' || 'männlich' => 'M',
    'w' || 'weiblich' || 'f' => 'W',
    'd' || 'divers' => 'D',
    'x' || 'keine_angabe' || 'ohne_angabe' => 'X',
    _ => null,
  };
}

String geschlechtAnzeige(String? roh) =>
    switch (geschlechtCode(roh)) {
      'M' => tr('Männlich', 'Bărbat'),
      'W' => tr('Weiblich', 'Femeie'),
      'D' => tr('Divers', 'Divers'),
      'X' => tr('Keine Angabe', 'Prefer să nu spun'),
      _ => (roh ?? '').trim(),
    };

// ── Familienstand ──────────────────────────────────────────────────────────

/// Die Liste der Verifizierung im Vorstandspanel. Dort gibt es zusätzlich
/// 'unbekannt' — den setzt nur der Vorstand, gewählt wird er hier nicht.
const familienstandWerte = <String>[
  'ledig',
  'verheiratet',
  'eingetragene_lebenspartnerschaft',
  'getrennt_lebend',
  'geschieden',
  'verwitwet',
  'eheaehnliche_gemeinschaft',
];

String familienstandAnzeige(String? wert) =>
    switch ((wert ?? '').trim()) {
      'ledig' => tr('Ledig', 'Necăsătorit/ă'),
      'verheiratet' => tr('Verheiratet', 'Căsătorit/ă'),
      'eingetragene_lebenspartnerschaft' =>
        tr('Eingetragene Lebenspartnerschaft', 'Parteneriat civil înregistrat'),
      'getrennt_lebend' => tr('Getrennt lebend', 'Separat(ă) în fapt'),
      'geschieden' => tr('Geschieden', 'Divorțat/ă'),
      'verwitwet' => tr('Verwitwet', 'Văduv/ă'),
      'eheaehnliche_gemeinschaft' => tr('Eheähnliche Gemeinschaft', 'Uniune consensuală (concubinaj)'),
      // 'unbekannt' (nur Vorstand) und alles andere unverändert.
      final w => w,
    };

// ── Aufenthaltsstatus ──────────────────────────────────────────────────────

/// Schlüssel → deutsches Etikett. Die App schickt den Schlüssel; der Server
/// speichert dieses Etikett, und genau so zeigt es das Vorstandspanel.
///
/// ⚠️ Die Texte müssen Zeichen für Zeichen denen auf dem Server gleichen —
/// sonst findet [aufenthaltSchluessel] einen gespeicherten Wert nicht wieder.
const aufenthaltEtiketten = <String, String>{
  'deutsch': 'deutsche Staatsangehörigkeit',
  'doppelt_de': 'Doppelte Staatsbürgerschaft (DE + andere)',
  'eu_eea_freizuegigkeit':
      'EU-/EWR-Bürger — Freizügigkeitsrecht (§ 2 FreizügG/EU)',
  'aufenthaltserlaubnis': 'Aufenthaltserlaubnis (§ 7 AufenthG)',
  'niederlassungserlaubnis': 'Niederlassungserlaubnis (§ 9 AufenthG)',
  'daueraufenthalt_eu': 'Erlaubnis zum Daueraufenthalt-EU (§ 9a AufenthG)',
  'blaue_karte_eu': 'Blaue Karte EU (§ 18b AufenthG)',
  'asylberechtigt': 'Asylberechtigt (Art. 16a GG)',
  'fluechtling_gfk':
      'Anerkannte/r Flüchtling (GFK, § 25 Abs. 2 Alt. 1 AufenthG)',
  'subsidiaerer_schutz': 'Subsidiärer Schutz (§ 25 Abs. 2 Alt. 2 AufenthG)',
  'aufenthaltsgestattung': 'Aufenthaltsgestattung (§ 55 AsylG)',
  'duldung': 'Duldung (§ 60a AufenthG)',
  'humanitaer': 'Aufenthaltserlaubnis aus humanitären Gründen (§ 25 AufenthG)',
  'ukraine_24': 'Aufenthaltserlaubnis § 24 AufenthG (Ukraine-Vertriebene)',
  'sonstige': 'Sonstiges',
};

/// Auswahl für Staatsangehörige außerhalb von Deutschland und EU/EWR/CH,
/// in Anzeigereihenfolge. [aufenthaltDrittstaatFuer] stellt § 24 nach vorn,
/// wenn die Staatsangehörigkeit ukrainisch ist.
const aufenthaltDrittstaat = <String>[
  'aufenthaltserlaubnis',
  'niederlassungserlaubnis',
  'daueraufenthalt_eu',
  'blaue_karte_eu',
  'asylberechtigt',
  'fluechtling_gfk',
  'subsidiaerer_schutz',
  'aufenthaltsgestattung',
  'duldung',
  'humanitaer',
  'ukraine_24',
  'sonstige',
];

/// Auswahl bei deutscher Staatsangehörigkeit.
const aufenthaltDeutsch = <String>['deutsch', 'doppelt_de'];

/// [aufenthaltDrittstaat], bei ukrainischer Staatsangehörigkeit mit § 24
/// zuerst — der häufigste Fall bei den Mitgliedern.
List<String> aufenthaltDrittstaatFuer(String? staatsangehoerigkeit) {
  final s = (staatsangehoerigkeit ?? '').trim().toLowerCase();
  if (!s.startsWith('ukrain')) return aufenthaltDrittstaat;
  return ['ukraine_24', ...aufenthaltDrittstaat.where((k) => k != 'ukraine_24')];
}

/// Etiketten früherer Fassungen (Online-Formular, Vorstandspanel) → Schlüssel.
/// Kleingeschrieben, damit der Vergleich nicht an Groß/Klein hängt.
const _aufenthaltFruehereEtiketten = <String, String>{
  'deutsche staatsangehörigkeit': 'deutsch',
  'aufenthaltserlaubnis (befristet, § 7 aufenthg)': 'aufenthaltserlaubnis',
  'niederlassungserlaubnis (unbefristet, § 9 aufenthg)':
      'niederlassungserlaubnis',
  'anerkannter flüchtling (gfk, § 25 abs. 2 aufenthg)': 'fluechtling_gfk',
  'anerkannte/r flüchtling (§ 25 abs. 1 aufenthg)': 'fluechtling_gfk',
  'aufenthaltsgestattung — asylverfahren läuft (§ 55 asylg)':
      'aufenthaltsgestattung',
  'aufenthaltserlaubnis aus humanitären gründen (§ 25 abs. 3-5 aufenthg)':
      'humanitaer',
};

/// Gespeicherter Wert → Schlüssel. Kennt den Schlüssel selbst, das Etikett
/// (ohne Rücksicht auf Groß/Klein) und Etiketten früherer Fassungen.
/// Null, wenn der Wert keinem Schlüssel entspricht — dann ist es ein Etikett,
/// das nur der Vorstand vergibt, und es muss UNVERÄNDERT bleiben.
String? aufenthaltSchluessel(String? gespeichert) {
  final s = (gespeichert ?? '').trim();
  if (s.isEmpty) return null;
  if (aufenthaltEtiketten.containsKey(s)) return s;
  final klein = s.toLowerCase();
  for (final e in aufenthaltEtiketten.entries) {
    if (e.value.toLowerCase() == klein) return e.key;
  }
  return _aufenthaltFruehereEtiketten[klein];
}

/// Anzeige eines Schlüssels oder gespeicherten Werts. Rechtsbegriffe bleiben
/// deutsch (sie verweisen auf §§ AufenthG/AsylG), erklärt wird in der
/// Sprache des Mitglieds.
String aufenthaltAnzeige(String? gespeichert) =>
    switch (aufenthaltSchluessel(gespeichert)) {
      'deutsch' => tr('Kein Aufenthaltstitel erforderlich — Deutscher Staatsangehöriger.', 'Niciun titlu de ședere necesar — cetățean german.'),
      'doppelt_de' => tr('Doppelte Staatsbürgerschaft (deutsch und eine weitere)', 'Dublă cetățenie (germană și încă una)'),
      'eu_eea_freizuegigkeit' => tr('EU-/EWR-/CH-Bürger — Freizügigkeit.', 'Cetățean UE/SEE/CH — libertatea de circulație (Freizügigkeit).'),
      'aufenthaltserlaubnis' =>
        'Aufenthaltserlaubnis (${tr('befristet', 'permis temporar')})',
      'niederlassungserlaubnis' =>
        'Niederlassungserlaubnis (${tr('unbefristet', 'permis permanent')})',
      'daueraufenthalt_eu' => 'Daueraufenthalt-EU',
      'blaue_karte_eu' => 'Blaue Karte EU',
      'asylberechtigt' => 'Asylberechtigt (Art. 16a GG)',
      'fluechtling_gfk' => 'Anerkannter Flüchtling (GFK § 25 Abs. 2)',
      'subsidiaerer_schutz' => 'Subsidiärer Schutz (§ 25 Abs. 2 Satz 1 Alt. 2)',
      'aufenthaltsgestattung' =>
        'Aufenthaltsgestattung (${tr('Asylverfahren', 'în procedura de azil')})',
      'duldung' => 'Duldung (§ 60a)',
      'humanitaer' => 'Humanitärer Aufenthalt (§ 25)',
      'ukraine_24' =>
        'Aufenthaltserlaubnis § 24 (${tr('Vertriebene aus der Ukraine', 'persoane strămutate din Ucraina')})',
      'sonstige' => tr('Sonstige (bitte im Chat angeben)', 'Altele (te rog precizează în chat)'),
      // Ein Etikett, das nur der Vorstand vergibt — so, wie es ist.
      _ => (gespeichert ?? '').trim(),
    };

// ── Mitgliedsart ───────────────────────────────────────────────────────────

/// Was ein Antragsteller oder Mitglied selbst wählt. Die Ehrenmitgliedschaft
/// verleiht die Mitgliederversammlung (Satzung § 6 Abs. 1b) — gewählt wird
/// sie nicht, angezeigt wird sie, wenn sie gespeichert ist.
const mitgliedsartWaehlbar = <String>['ordentlich', 'foerdermitglied'];

String mitgliedsartAnzeige(String? wert) =>
    switch ((wert ?? '').trim()) {
      'ordentlich' || 'ordentliches_mitglied' => tr('Ordentliches Mitglied', 'Membru ordinar'),
      'foerdermitglied' => tr('Fördermitglied', 'Membru susținător'),
      'ehrenmitglied' => tr('Ehrenmitglied', 'Membru de onoare'),
      final w => w,
    };

// ── Finanzielle Situation ──────────────────────────────────────────────────
//
// ⚠️ Seit 05.10.2026 (Vorstand): Eine Ermäßigung gibt es nur auf Antrag, NUR
// MIT NACHWEIS und nach Prüfung — bei Bürgergeld, Leistungen vom Sozialamt,
// Arbeitslosengeld I, Krankengeld, Rente oder Behinderung. Ohne Nachweis keine
// Ermäßigung; alle anderen zahlen den vollen Beitrag. Vorher versprach die App
// „beitragsfrei". Hochgeladen wird weiterhin nichts — der Nachweis wird
// gebracht oder geschickt. Unter 18 ist die Mitgliedschaft beitragsfrei — fest,
// ohne Prüfung. Gleich im Online-Formular, in der Verifizierung des
// Vorstandspanels und auf dem Server.

/// Was ein Erwachsener selbst wählt.
const finanzielleSituationWerte = <String>[
  'buergergeld',
  'sozialamt',
  'alg1',
  'krankengeld',
  'rente',
  'behinderung',
  'nein',
];

/// Unter 18 — beitragsfrei, ohne Prüfung. Wird nicht gewählt, sondern
/// gesetzt, wenn der Antragsteller noch nicht 18 ist ([istMinderjaehrigAm]).
const finanzielleSituationMinderjaehrig = 'minderjaehrig';

/// Beantragte Ermäßigung — nur mit Nachweis; der Vorstand prüft und
/// entscheidet. Das ist KEINE Zusage; bis 05.10.2026 hieß es „beitragsfrei".
const ermaessigungWerte = <String>{
  'buergergeld',
  'sozialamt',
  'alg1',
  'krankengeld',
  'rente',
  'behinderung',
};

bool istErmaessigungBeantragt(String? finanzielleSituation) =>
    ermaessigungWerte.contains(finanzielleSituation);

bool istBeitragsfreiMinderjaehrig(String? finanzielleSituation) =>
    finanzielleSituation == finanzielleSituationMinderjaehrig;

/// Stufe 4 (Zahlungsweg) entfällt: bei beantragter Ermäßigung bis zur
/// Entscheidung des Vorstands, unter 18 ganz.
bool zahlungswegEntfaellt(String? finanzielleSituation) =>
    istErmaessigungBeantragt(finanzielleSituation) ||
    istBeitragsfreiMinderjaehrig(finanzielleSituation);

/// Noch nicht 18 — aus dem gespeicherten Geburtsdatum (JJJJ-MM-TT).
/// Ohne gültiges Datum: false; dann wählt man wie ein Erwachsener.
bool istMinderjaehrigAm(String? geburtsdatumIso, {DateTime? heute}) {
  final geburt = DateTime.tryParse(geburtsdatumIso ?? '');
  if (geburt == null) return false;
  final tag = heute ?? DateTime.now();
  var alter = tag.year - geburt.year;
  if (tag.month < geburt.month ||
      (tag.month == geburt.month && tag.day < geburt.day)) {
    alter--;
  }
  return alter < 18;
}

/// Der Nachweis des Grundes — genannt, nicht hochgeladen: er wird gebracht
/// oder geschickt, und ohne ihn gibt es keine Ermäßigung. Null für alles ohne
/// Ermäßigung.
String? nachweisFuer(String? finanzielleSituation) =>
    switch (finanzielleSituation) {
      'buergergeld' => tr('Bescheid vom Jobcenter', 'decizie (Bescheid) de la Jobcenter'),
      'sozialamt' => tr('Bescheid vom Sozialamt', 'decizie (Bescheid) de la Sozialamt'),
      'alg1' => tr('Bescheid der Arbeitsagentur', 'decizie (Bescheid) de la Arbeitsagentur'),
      'krankengeld' => tr('Bescheid der Krankenkasse', 'decizie (Bescheid) de la casa de asigurări de sănătate (Krankenkasse)'),
      'rente' => tr('Rentenbescheid', 'decizie de pensie (Rentenbescheid)'),
      'behinderung' => tr('Schwerbehindertenausweis', 'legitimație de persoană cu handicap grav (Schwerbehindertenausweis)'),
      _ => null,
    };

/// Anzeige eines gespeicherten Werts.
String finanzielleSituationAnzeige(String? wert) =>
    switch ((wert ?? '').trim()) {
      'buergergeld' => tr('Ich beziehe Bürgergeld', 'Primesc Bürgergeld'),
      'sozialamt' => tr('Ich beziehe Sozialamt-Leistungen', 'Primesc ajutor de la Sozialamt'),
      'alg1' => tr('Ich beziehe Arbeitslosengeld I (ALG I)', 'Primesc Arbeitslosengeld I (ALG I)'),
      'krankengeld' => tr('Ich beziehe Krankengeld', 'Primesc Krankengeld (concediu medical prelungit)'),
      'rente' => tr('Ich beziehe eine Rente', 'Primesc pensie'),
      'behinderung' => tr('Ich habe eine Behinderung (Schwerbehindertenausweis)', 'Am o dizabilitate (Schwerbehindertenausweis)'),
      'nein' => tr('Nichts davon trifft auf mich zu', 'Nu mi se aplică nimic din acestea'),
      'minderjaehrig' => tr('Unter 18 — beitragsfrei', 'Sub 18 ani — fără cotizație'),
      final w => w,
    };

// ── Zahlung ────────────────────────────────────────────────────────────────

/// SEPA-Lastschrift bietet die App nicht an: dafür braucht es ein
/// unterschriebenes Mandat. Der Vorstand kann sie weiterhin eintragen.
const zahlungsmethodeWaehlbar = <String>['ueberweisung', 'dauerauftrag'];

/// 1 bis 28 — der 29., 30. und 31. gibt es nicht in jedem Monat.
const zahlungstagMax = 28;

String zahlungsmethodeAnzeige(String? wert) =>
    switch ((wert ?? '').trim()) {
      'ueberweisung' => tr('Überweisung', 'Transfer bancar'),
      'dauerauftrag' => tr('Dauerauftrag', 'Ordin permanent'),
      'sepa_lastschrift' => tr('SEPA-Lastschrift', 'Debit direct SEPA'),
      final w => w,
    };

// ── Telefon ────────────────────────────────────────────────────────────────

enum TelefonFehler { leer, keineNummer, ohneVorwahlNull, ohneVorwahl, laenge }

/// Ergebnis von [telefonPruefen]: entweder [nummer] (kanonisch, `+<Land>…`)
/// oder [fehler] mit dem, was die Meldung braucht.
class TelefonPruefung {
  final String? nummer;
  final TelefonFehler? fehler;

  /// Bei [TelefonFehler.ohneVorwahlNull]: so war es vermutlich gemeint.
  final String? vorschlag;

  /// Die eingegebenen Ziffern, für die Meldung.
  final String ziffern;

  const TelefonPruefung({
    this.nummer,
    this.fehler,
    this.vorschlag,
    this.ziffern = '',
  });

  bool get gueltig => nummer != null;
}

final _steuerzeichen = RegExp(r'\p{C}', unicode: true);
final _nullInKlammern = RegExp(r'(\+\s*\d{1,3})\s*\(\s*0\s*\)');
final _keineZiffer = RegExp(r'\D');

/// Dieselbe Regel wie `telefonPruefen()` in api/helpers/telefon.php auf dem
/// Server — und wie das Online-Formular. Vorher nahm die App jede Folge aus
/// Ziffern, Leerzeichen und `+` an („0151 …" ohne Ländervorwahl); der Server
/// und das Vorstandspanel wiesen dieselbe Nummer später ab.
///
/// ⚠️ Die Ländervorwahl ist Pflicht. Eine führende Null wird NICHT als
/// deutsch geraten: eine rumänische „0755…" würde sonst still zu „+49755…".
TelefonPruefung telefonPruefen(String? roh) {
  if (roh == null || roh.trim().isEmpty) {
    return const TelefonPruefung(fehler: TelefonFehler.leer);
  }
  // Unsichtbare Zeichen zuerst — Android schickt beim Kopieren aus dem
  // Adressbuch Richtungsmarken (U+202A/U+202C) mit.
  var s = roh.replaceAll(_steuerzeichen, '');
  // „+49 (0)160 …": die eingeklammerte Null weg, BEVOR die Ziffern gezählt
  // werden — sonst entsteht +490160…, eine Nummer, die es nicht gibt.
  s = s.replaceAllMapped(_nullInKlammern, (m) => m.group(1)!);
  final hattePlus = s.trimLeft().startsWith('+');
  var ziffern = s.replaceAll(_keineZiffer, '');
  if (ziffern.isEmpty) {
    return const TelefonPruefung(fehler: TelefonFehler.keineNummer);
  }
  if (ziffern.startsWith('00')) {
    ziffern = ziffern.substring(2);
  } else if (hattePlus) {
    // steht schon so da
  } else if (ziffern.startsWith('0')) {
    return TelefonPruefung(
      fehler: TelefonFehler.ohneVorwahlNull,
      vorschlag: '+49${ziffern.substring(1)}',
      ziffern: ziffern,
    );
  } else {
    return TelefonPruefung(fehler: TelefonFehler.ohneVorwahl, ziffern: ziffern);
  }
  if (ziffern.length < 7 || ziffern.length > 15) {
    return TelefonPruefung(fehler: TelefonFehler.laenge, ziffern: ziffern);
  }
  return TelefonPruefung(nummer: '+$ziffern', ziffern: ziffern);
}

/// Die Meldung zu [p] in der Sprache des Mitglieds, oder null wenn gültig.
/// [TelefonFehler.leer] gibt [leer] zurück — ob ein leeres Feld ein Fehler
/// ist, entscheidet der Aufrufer (Mobil Pflicht, Festnetz freiwillig).
String? telefonMeldung(TelefonPruefung p, {String? leer}) =>
    switch (p.fehler) {
      null => null,
      TelefonFehler.leer => leer,
      TelefonFehler.keineNummer => tr('Ungültige Telefonnummer', 'Număr de telefon invalid'),
      TelefonFehler.ohneVorwahlNull =>
        _tWizardErrPhoneVorwahl(p.vorschlag ?? '', p.ziffern),
      TelefonFehler.ohneVorwahl => tr('Bitte mit Ländervorwahl, zum Beispiel +49 176 1234567.', 'Te rog cu prefixul țării, de exemplu +49 176 1234567.'),
      TelefonFehler.laenge => _tWizardErrPhoneLaenge(p.ziffern.length),
    };

// ── Texte mit Platzhaltern (aus den ARB-Dateien der Mitglieder-App) ──

String _tWizardErrPhoneLaenge(Object anzahl) =>
    tr('Die Nummer hat $anzahl Ziffern — das kann nicht stimmen.',
        'Numărul are $anzahl cifre — nu poate fi corect.');

String _tWizardErrPhoneVorwahl(Object vorschlag, Object eingabe) =>
    tr('Bitte mit Ländervorwahl — bei einer deutschen Nummer also $vorschlag statt $eingabe.',
        'Te rog cu prefixul țării — pentru un număr german deci $vorschlag în loc de $eingabe.');
