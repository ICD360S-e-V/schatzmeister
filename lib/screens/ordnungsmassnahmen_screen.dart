import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import '../models/user.dart';
import '../services/verwarnung_service.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';

/// Verstoß-Kategorien basierend auf der Satzung des ICD360S e.V.
class VerstossKategorie {
  final String id;
  // titel/paragraph/beschreibung bleiben deutsch: sie gehen als `grund` an den
  // Server, werden mit gespeicherten Verwarnungen verglichen und stehen im
  // PDF-Schreiben. Angezeigt werden die anzeige*-Getter.
  final String titel;
  final String paragraph;
  final String beschreibung;
  final String titelRo;
  final String paragraphRo;
  final String beschreibungRo;
  final IconData icon;
  final Color color;

  const VerstossKategorie({
    required this.id,
    required this.titel,
    required this.paragraph,
    required this.beschreibung,
    required this.titelRo,
    required this.paragraphRo,
    required this.beschreibungRo,
    required this.icon,
    required this.color,
  });

  String get anzeigeTitel => tr(titel, titelRo);
  String get anzeigeParagraph => tr(paragraph, paragraphRo);
  String get anzeigeBeschreibung => tr(beschreibung, beschreibungRo);
}

/// Ordnungsmaßnahmen gemäß §6 Abs. 6 Satzung
class Massnahme {
  final String id;
  // titel/beschreibung bleiben deutsch (PDF-Schreiben); angezeigt werden die
  // anzeige*-Getter.
  final String titel;
  final String beschreibung;
  final String titelRo;
  final String beschreibungRo;
  final IconData icon;
  final Color color;

  const Massnahme({
    required this.id,
    required this.titel,
    required this.beschreibung,
    required this.titelRo,
    required this.beschreibungRo,
    required this.icon,
    required this.color,
  });

  String get anzeigeTitel => tr(titel, titelRo);
  String get anzeigeBeschreibung => tr(beschreibung, beschreibungRo);
}

const _verstossKategorien = <VerstossKategorie>[
  VerstossKategorie(
    id: 'datenschutz',
    titel: 'Verstoß gegen den Datenschutz',
    titelRo: 'Încălcarea protecției datelor',
    paragraph: '§11 Satzung / DSGVO',
    paragraphRo: '§11 Statut / GDPR',
    beschreibung:
        'Unbefugte Weitergabe personenbezogener Daten, Verletzung der '
        'Vertraulichkeit, Verstoß gegen die Datenschutz-Grundverordnung.',
    beschreibungRo:
        'Divulgarea neautorizată a datelor cu caracter personal, încălcarea '
        'confidențialității, încălcarea Regulamentului general privind '
        'protecția datelor (GDPR).',
    icon: Icons.security,
    color: Colors.red,
  ),
  VerstossKategorie(
    id: 'satzung',
    titel: 'Verstoß gegen die Satzung',
    titelRo: 'Încălcarea statutului',
    paragraph: '§6 Abs. 6 Satzung',
    paragraphRo: '§6 alin. 6 Statut',
    beschreibung:
        'Allgemeiner Verstoß gegen Bestimmungen der Vereinssatzung.',
    beschreibungRo:
        'Încălcare generală a prevederilor statutului asociației.',
    icon: Icons.description,
    color: Colors.orange,
  ),
  VerstossKategorie(
    id: 'vereinsschaedigend',
    titel: 'Vereinsschädigendes Verhalten',
    titelRo: 'Comportament dăunător asociației',
    paragraph: '§6 Abs. 3 / §6 Abs. 6 Satzung',
    paragraphRo: '§6 alin. 3 / §6 alin. 6 Statut',
    beschreibung:
        'Handlungen, die den Verein, seine Mitglieder oder seinen Ruf '
        'schädigen oder das Vereinsleben stören.',
    beschreibungRo:
        'Acțiuni care dăunează asociației, membrilor sau reputației ei '
        'ori perturbă viața asociației.',
    icon: Icons.dangerous,
    color: Colors.deepOrange,
  ),
  VerstossKategorie(
    id: 'pflichtverletzung',
    titel: 'Verletzung der Mitgliedspflichten',
    titelRo: 'Încălcarea obligațiilor de membru',
    paragraph: '§6 Satzung',
    paragraphRo: '§6 Statut',
    beschreibung:
        'Nichteinhaltung der aus der Mitgliedschaft resultierenden Pflichten '
        '(z.B. Beitragszahlung, Mitwirkungspflichten).',
    beschreibungRo:
        'Nerespectarea obligațiilor care decurg din calitatea de membru '
        '(de ex. plata cotizației, obligații de cooperare).',
    icon: Icons.assignment_late,
    color: Colors.amber,
  ),
  VerstossKategorie(
    id: 'beitragsrueckstand',
    titel: 'Beitragsrückstand',
    titelRo: 'Restanță la cotizație',
    paragraph: '§6 Abs. 3 / Abs. 4 Satzung',
    paragraphRo: '§6 alin. 3 / alin. 4 Statut',
    beschreibung:
        'Nichtzahlung des Mitgliedsbeitrags über einen längeren Zeitraum '
        '(Streichung möglich nach 6 Monaten Rückstand).',
    beschreibungRo:
        'Neplata cotizației pe o perioadă mai lungă '
        '(radierea este posibilă după 6 luni de restanță).',
    icon: Icons.money_off,
    color: Colors.brown,
  ),
  VerstossKategorie(
    id: 'rufschaedigung',
    titel: 'Rufschädigung des Vereins',
    titelRo: 'Afectarea reputației asociației',
    paragraph: '§6 Abs. 6 Satzung',
    paragraphRo: '§6 alin. 6 Statut',
    beschreibung:
        'Öffentliche oder private Äußerungen, die das Ansehen des Vereins '
        'oder seiner Mitglieder herabsetzen.',
    beschreibungRo:
        'Declarații publice sau private care afectează imaginea asociației '
        'sau a membrilor săi.',
    icon: Icons.record_voice_over,
    color: Colors.purple,
  ),
  VerstossKategorie(
    id: 'vertraulichkeit',
    titel: 'Verstoß gegen die Vertraulichkeit',
    titelRo: 'Încălcarea confidențialității',
    paragraph: '§11 Satzung',
    paragraphRo: '§11 Statut',
    beschreibung:
        'Weitergabe vertraulicher Vereinsinformationen an Dritte, '
        'Bruch des Beratungsgeheimnisses.',
    beschreibungRo:
        'Divulgarea către terți a informațiilor confidențiale ale asociației, '
        'încălcarea secretului deliberărilor.',
    icon: Icons.lock_open,
    color: Colors.indigo,
  ),
  VerstossKategorie(
    id: 'vereinsfrieden',
    titel: 'Störung des Vereinsfriedens',
    titelRo: 'Tulburarea armoniei din asociație',
    paragraph: '§6 Abs. 6 Satzung',
    paragraphRo: '§6 alin. 6 Statut',
    beschreibung:
        'Handlungen oder Äußerungen, die den inneren Frieden des Vereins '
        'gefährden oder zu Konflikten unter Mitgliedern führen.',
    beschreibungRo:
        'Acțiuni sau declarații care pun în pericol armonia internă a '
        'asociației sau duc la conflicte între membri.',
    icon: Icons.warning_amber,
    color: Colors.teal,
  ),
  VerstossKategorie(
    id: 'sonstiges',
    titel: 'Sonstiger Verstoß',
    titelRo: 'Altă încălcare',
    paragraph: '§6 Abs. 6 Satzung',
    paragraphRo: '§6 alin. 6 Statut',
    beschreibung:
        'Weitere Pflichtverletzungen oder vereinsschädigendes Verhalten, '
        'das nicht in die obigen Kategorien fällt.',
    beschreibungRo:
        'Alte încălcări ale obligațiilor sau comportamente dăunătoare '
        'asociației care nu se încadrează în categoriile de mai sus.',
    icon: Icons.more_horiz,
    color: Colors.grey,
  ),
];

const _massnahmen = <Massnahme>[
  Massnahme(
    id: 'verwarnung',
    titel: 'Schriftliche Verwarnung',
    titelRo: 'Avertisment scris',
    beschreibung:
        'Formale schriftliche Verwarnung gemäß §6 Abs. 6 Nr. 1a der Satzung. '
        'Das Mitglied wird auf sein Fehlverhalten hingewiesen und zur '
        'künftigen Unterlassung aufgefordert.',
    beschreibungRo:
        'Avertisment scris formal conform §6 alin. 6 pct. 1a din statut. '
        'Membrul este atenționat asupra abaterii și i se cere să nu o mai '
        'repete.',
    icon: Icons.warning,
    color: Colors.orange,
  ),
  Massnahme(
    id: 'ordnungsgeld',
    titel: 'Ordnungsgeld (bis 100 €)',
    titelRo: 'Amendă (până la 100 €)',
    beschreibung:
        'Verhängung eines Ordnungsgeldes bis zu 100 € gemäß §6 Abs. 6 Nr. 1b '
        'der Satzung.',
    beschreibungRo:
        'Aplicarea unei amenzi de până la 100 € conform §6 alin. 6 pct. 1b '
        'din statut.',
    icon: Icons.euro,
    color: Colors.red,
  ),
  Massnahme(
    id: 'ausschluss',
    titel: 'Ausschluss aus dem Verein',
    titelRo: 'Excluderea din asociație',
    beschreibung:
        'Ausschluss aus dem Verein gemäß §6 Abs. 6 Nr. 1c / §6 Abs. 3 '
        'der Satzung. Schärfste Ordnungsmaßnahme.',
    beschreibungRo:
        'Excluderea din asociație conform §6 alin. 6 pct. 1c / §6 alin. 3 '
        'din statut. Cea mai severă măsură disciplinară.',
    icon: Icons.person_remove,
    color: Colors.red,
  ),
];

/// Static helper to generate a Verwarnung PDF from any context.
/// Used both by OrdnungsmassnahmenScreen and by user_details_dialog.
class VerwarnungPdfGenerator {
  /// Generate PDF bytes for a Verwarnung.
  /// [userName] and [mitgliedernummer] identify the member.
  /// [massnahmeId] is one of: 'verwarnung', 'ordnungsgeld', 'ausschluss'
  /// [verstossId] matches one of the _verstossKategorien ids
  /// [sachverhalt] is the description of what happened
  /// [vorfallDatum] is the date of the incident
  /// [ordnungsgeldBetrag] is the fine amount (only for ordnungsgeld)
  static Future<({List<int> bytes, String fileName})?> generate({
    required String userName,
    required String mitgliedernummer,
    required String massnahmeId,
    required String massnahmeTitel,
    required String verstossTitel,
    required String verstossParagraph,
    required String verstossBeschreibung,
    required String sachverhalt,
    required DateTime vorfallDatum,
    String? ordnungsgeldBetrag,
    DateTime? schreibenDatum,
  }) async {
    try {
      // Load Noto Sans fonts for diacritics support (ă, ț, ș, ü, ö, ß, etc.)
      final fontRegular = await PdfGoogleFonts.notoSansRegular();
      final fontBold = await PdfGoogleFonts.notoSansBold();
      final fontItalic = await PdfGoogleFonts.notoSansItalic();
      final fontBoldItalic = await PdfGoogleFonts.notoSansBoldItalic();

      final pdf = pw.Document();
      final df = DateFormat('dd.MM.yyyy');
      final datum = schreibenDatum ?? DateTime.now();
      final heute = df.format(datum);
      final vorfallStr = df.format(vorfallDatum);

      // Base theme with Noto Sans
      final baseTheme = pw.ThemeData.withFont(
        base: fontRegular,
        bold: fontBold,
        italic: fontItalic,
        boldItalic: fontBoldItalic,
      );

      final aktenzeichen =
          'OM-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
      final fristDatum = df.format(datum.add(const Duration(days: 14)));

      String massnahmeText;
      switch (massnahmeId) {
        case 'verwarnung':
          massnahmeText =
              'eine schriftliche Verwarnung gemäß §6 Abs. 6 Nr. 1a der Satzung';
        case 'ordnungsgeld':
          massnahmeText =
              'ein Ordnungsgeld in Höhe von ${ordnungsgeldBetrag ?? "50"} € gemäß §6 Abs. 6 Nr. 1b der Satzung';
        case 'ausschluss':
          massnahmeText =
              'den Ausschluss aus dem Verein gemäß §6 Abs. 6 Nr. 1c / §6 Abs. 3 der Satzung';
        default:
          massnahmeText =
              'eine Ordnungsmaßnahme gemäß §6 Abs. 6 der Satzung';
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(50),
          theme: baseTheme,
          build: (pw.Context context) {
            return [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Briefkopf
                  pw.Text('ICD360S e.V.',
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Text('c/o Ionuț-Claudiu Duinea',
                      style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Elsa-Brändström-Str. 13, 89231 Neu-Ulm',
                      style: const pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(height: 6),
                  pw.Divider(thickness: 2, color: PdfColors.red800),
                  pw.SizedBox(height: 20),

                  // Empfänger
                  pw.Text(userName,
                      style: pw.TextStyle(
                          fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Mitgliedsnummer: $mitgliedernummer',
                      style: const pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(height: 30),

                  // Datum + Aktenzeichen
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Aktenzeichen: $aktenzeichen',
                          style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('Neu-Ulm, den $heute',
                          style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.SizedBox(height: 24),

                  // Betreff
                  pw.Text('Betreff: $massnahmeTitel – $verstossTitel',
                      style: pw.TextStyle(
                          fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 6),
                  pw.Text('Rechtsgrundlage: $verstossParagraph',
                      style: pw.TextStyle(
                          fontSize: 10,
                          fontStyle: pw.FontStyle.italic,
                          color: PdfColors.grey700)),
                  pw.SizedBox(height: 20),

                  // Anrede
                  pw.Text('Sehr geehrte/r $userName,',
                      style: const pw.TextStyle(fontSize: 11)),
                  pw.SizedBox(height: 12),

                  // Einleitung
                  pw.Text(
                      'der Vorstand des ICD360S e.V. hat in seiner Sitzung am '
                      '$heute festgestellt, dass Sie gegen Bestimmungen der '
                      'Vereinssatzung verstoßen haben. Wir teilen Ihnen hiermit '
                      'Folgendes mit:',
                      style: const pw.TextStyle(fontSize: 11)),
                  pw.SizedBox(height: 16),

                  // 1. Sachverhalt
                  pw.Text('1. Sachverhalt',
                      style: pw.TextStyle(
                          fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 6),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                      borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(4)),
                    ),
                    child: pw.Text(sachverhalt,
                        style: const pw.TextStyle(fontSize: 10)),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text('Datum des Vorfalls: $vorfallStr',
                      style: pw.TextStyle(
                          fontSize: 10, fontStyle: pw.FontStyle.italic)),
                  pw.SizedBox(height: 16),

                  // 2. Verstoß
                  pw.Text('2. Festgestellter Verstoß',
                      style: pw.TextStyle(
                          fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 6),
                  pw.Text(
                      'Der oben geschilderte Sachverhalt stellt einen '
                      '$verstossTitel dar ($verstossParagraph).',
                      style: const pw.TextStyle(fontSize: 11)),
                  pw.SizedBox(height: 6),
                  pw.Text(verstossBeschreibung,
                      style: pw.TextStyle(
                          fontSize: 10,
                          fontStyle: pw.FontStyle.italic,
                          color: PdfColors.grey700)),
                  pw.SizedBox(height: 16),

                  // 3. Maßnahme
                  pw.Text('3. Ordnungsmaßnahme',
                      style: pw.TextStyle(
                          fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 6),
                  pw.Text(
                      'Aufgrund des oben dargestellten Sachverhalts verhängt '
                      'der Vorstand des ICD360S e.V. gegen Sie '
                      '$massnahmeText.',
                      style: const pw.TextStyle(fontSize: 11)),
                  pw.SizedBox(height: 16),

                  // 4. Anhörung (14 Tage)
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.amber50,
                      border: pw.Border.all(color: PdfColors.amber200),
                      borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(4)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('4. Recht auf Stellungnahme',
                            style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 6),
                        pw.Text(
                            'Gemäß §6 Abs. 6 Nr. 2 der Satzung haben Sie das Recht, '
                            'innerhalb von 14 Tagen nach Zugang dieses Schreibens '
                            'schriftlich Stellung zu nehmen.',
                            style: const pw.TextStyle(fontSize: 11)),
                        pw.SizedBox(height: 4),
                        pw.Text('Frist: $fristDatum',
                            style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text(
                            'Ihre Stellungnahme richten Sie bitte schriftlich an '
                            'den Vorstand des ICD360S e.V. an die oben genannte '
                            'Geschäftsadresse oder per E-Mail.',
                            style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 16),

                  // 5. Einspruch bei Ausschluss
                  if (massnahmeId == 'ausschluss') ...[
                    pw.Text('5. Einspruchsrecht',
                        style: pw.TextStyle(
                            fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 6),
                    pw.Text(
                        'Gemäß §6 Abs. 3a der Satzung können Sie gegen den '
                        'Ausschluss innerhalb eines Monats nach Zugang '
                        'dieses Bescheids schriftlich Einspruch einlegen. '
                        'Über den Einspruch entscheidet die nächste '
                        'Mitgliederversammlung endgültig.',
                        style: const pw.TextStyle(fontSize: 11)),
                    pw.SizedBox(height: 16),
                  ],

                  // 5. Zahlungsaufforderung bei Ordnungsgeld
                  if (massnahmeId == 'ordnungsgeld') ...[
                    pw.Text('5. Zahlungsaufforderung',
                        style: pw.TextStyle(
                            fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 6),
                    pw.Text(
                        'Das Ordnungsgeld in Höhe von '
                        '${ordnungsgeldBetrag ?? "50"} € ist innerhalb '
                        'von 30 Tagen nach Zugang dieses Schreibens auf das '
                        'Vereinskonto zu überweisen. Bei Nichtzahlung behält '
                        'sich der Vorstand weitere Maßnahmen vor.',
                        style: const pw.TextStyle(fontSize: 11)),
                    pw.SizedBox(height: 16),
                  ],

                  // Schluss
                  pw.Text(
                      'Wir bitten Sie, das beanstandete Verhalten künftig zu '
                      'unterlassen. Bei wiederholtem Verstoß behält sich der '
                      'Vorstand weitergehende Ordnungsmaßnahmen bis hin zum '
                      'Vereinsausschluss vor.',
                      style: const pw.TextStyle(fontSize: 11)),
                  pw.SizedBox(height: 20),
                  pw.Text('Mit freundlichen Grüßen',
                      style: const pw.TextStyle(fontSize: 11)),
                  pw.SizedBox(height: 30),

                  // Unterschrift
                  pw.Container(
                    width: 200,
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                          top: pw.BorderSide(
                              color: PdfColors.grey600, width: 0.5)),
                    ),
                    padding: const pw.EdgeInsets.only(top: 4),
                    child: pw.Text(
                        'Ionuț-Claudiu Duinea\n1. Vorsitzender, ICD360S e.V.',
                        style: const pw.TextStyle(fontSize: 9)),
                  ),
                  pw.SizedBox(height: 30),

                  // Footer
                  pw.Divider(color: PdfColors.grey400),
                  pw.SizedBox(height: 6),
                  pw.Text(
                      'Dieses Schreiben wurde maschinell erstellt und ist '
                      'auch ohne Unterschrift gültig.\n'
                      'ICD360S e.V. | Elsa-Brändström-Str. 13 | '
                      '89231 Neu-Ulm | Vereinsregister: AG Memmingen',
                      style: pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey600,
                          fontStyle: pw.FontStyle.italic),
                      textAlign: pw.TextAlign.center),
                ],
              ),
            ];
          },
        ),
      );

      final savedBytes = await pdf.save();
      final fileName =
          '${massnahmeId}_${mitgliedernummer}_${DateFormat('yyyy-MM-dd').format(datum)}.pdf';

      return (bytes: savedBytes, fileName: fileName);
    } catch (_) {
      return null;
    }
  }

  /// Save PDF to Downloads and show preview dialog
  static Future<void> saveAndPreview(
    BuildContext context,
    List<int> bytes,
    String fileName,
  ) async {
    final downloadsDir = await getDownloadsDirectory();
    if (downloadsDir == null) return;

    final file = File('${downloadsDir.path}/$fileName');
    await file.writeAsBytes(bytes);

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade700),
            const SizedBox(width: 12),
            Expanded(child: Text(tr('PDF erstellt', 'PDF creat'))),
          ],
        ),
        content: SizedBox(
          width: 600,
          height: 500,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.save, size: 16, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tr('Gespeichert: ${file.path}', 'Salvat: ${file.path}'),
                        style: TextStyle(
                            fontSize: 12, color: Colors.green.shade800),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: PdfPreview(
                  build: (format) async => Uint8List.fromList(bytes),
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  pdfFileName: fileName,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('Schließen', 'Închide')),
          ),
        ],
      ),
    );
  }

  /// Map existing Verwarnung typ to a Massnahme id
  static String typToMassnahmeId(String typ) {
    switch (typ) {
      case 'ermahnung':
        return 'verwarnung';
      case 'abmahnung':
        return 'verwarnung';
      case 'letzte_abmahnung':
        return 'verwarnung';
      default:
        return 'verwarnung';
    }
  }

  /// Map existing Verwarnung typ to the title used in the (German) PDF letter
  static String typToMassnahmeTitel(String typ) {
    switch (typ) {
      case 'ermahnung':
        return 'Ermahnung';
      case 'abmahnung':
        return 'Abmahnung';
      case 'letzte_abmahnung':
        return 'Letzte Abmahnung';
      default:
        return 'Schriftliche Verwarnung';
    }
  }

  /// Get Verstoss lists for external use
  static List<VerstossKategorie> get verstossKategorien => _verstossKategorien;
  static List<Massnahme> get massnahmen => _massnahmen;
}

class OrdnungsmassnahmenScreen extends StatefulWidget {
  final List<User> users;
  final VoidCallback onBack;

  const OrdnungsmassnahmenScreen({
    super.key,
    required this.users,
    required this.onBack,
  });

  @override
  State<OrdnungsmassnahmenScreen> createState() =>
      _OrdnungsmassnahmenScreenState();
}

class _OrdnungsmassnahmenScreenState extends State<OrdnungsmassnahmenScreen> {
  // Form state
  User? _selectedUser;
  VerstossKategorie? _selectedVerstoss;
  Massnahme? _selectedMassnahme;
  final _sachverhaltController = TextEditingController();
  final _ordnungsgeldController = TextEditingController(text: '50');
  final DateTime _datum = DateTime.now();
  DateTime? _vorfallDatum;
  bool _isGenerating = false;

  @override
  void dispose() {
    _sachverhaltController.dispose();
    _ordnungsgeldController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
                tooltip: tr('Zurück zur Übersicht',
                    'Înapoi la prezentarea generală'),
              ),
              const SizedBox(width: 8),
              Icon(Icons.gavel, size: 32, color: Colors.red.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tr('Ordnungsmaßnahmen', 'Măsuri disciplinare'),
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 56),
            child: Text(
              tr('Gemäß §6 Abs. 6 der Satzung des ICD360S e.V.',
                  'Conform §6 alin. 6 din statutul (Satzung) asociației ICD360S e.V.'),
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 20),

          // Content
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: Form
                Expanded(
                  flex: 5,
                  child: _buildForm(),
                ),
                const SizedBox(width: 20),
                // Right: Preview / Info
                Expanded(
                  flex: 3,
                  child: _buildPreviewPanel(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Card(
      elevation: 2,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step 1: Mitglied
            _buildSectionHeader(
              tr('1. Betroffenes Mitglied', '1. Membrul vizat'),
              Icons.person,
              Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildMitgliedSelector(),
            const SizedBox(height: 24),

            // Step 2: Verstoß-Kategorie
            _buildSectionHeader(
              tr('2. Art des Verstoßes', '2. Tipul încălcării'),
              Icons.category,
              Colors.orange,
            ),
            const SizedBox(height: 12),
            _buildVerstossSelector(),
            const SizedBox(height: 24),

            // Step 3: Sachverhalt
            _buildSectionHeader(
              tr('3. Sachverhalt / Beschreibung', '3. Situația de fapt / descriere'),
              Icons.edit_note,
              Colors.blueGrey,
            ),
            const SizedBox(height: 12),
            _buildSachverhaltInput(),
            const SizedBox(height: 24),

            // Step 4: Datum des Vorfalls
            _buildSectionHeader(
              tr('4. Datum des Vorfalls', '4. Data incidentului'),
              Icons.calendar_today,
              Colors.green,
            ),
            const SizedBox(height: 12),
            _buildVorfallDatumPicker(),
            const SizedBox(height: 24),

            // Step 5: Ordnungsmaßnahme
            _buildSectionHeader(
              tr('5. Ordnungsmaßnahme', '5. Măsură disciplinară'),
              Icons.gavel,
              Colors.red,
            ),
            const SizedBox(height: 12),
            _buildMassnahmeSelector(),

            // Ordnungsgeld amount
            if (_selectedMassnahme?.id == 'ordnungsgeld') ...[
              const SizedBox(height: 16),
              _buildOrdnungsgeldInput(),
            ],

            const SizedBox(height: 32),

            // Generate Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _canGenerate() ? _generatePdf : null,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.picture_as_pdf),
                label: Text(
                  _isGenerating
                      ? tr('PDF wird erstellt...', 'Se creează PDF-ul...')
                      : tr('Verwarnung als PDF erstellen',
                          'Creează avertismentul ca PDF'),
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  Widget _buildMitgliedSelector() {
    final members = widget.users
        .where((u) => u.status != 'geloescht')
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return DropdownButtonFormField<User>(
      initialValue: _selectedUser,
      decoration: InputDecoration(
        hintText: tr('Mitglied auswählen...', 'Selectați membrul...'),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      items: members.map((user) {
        return DropdownMenuItem(
          value: user,
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: _getRoleColor(user.role),
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${user.name} (${user.mitgliedernummer})',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: (user) => setState(() => _selectedUser = user),
    );
  }

  Widget _buildVerstossSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _verstossKategorien.map((v) {
        final selected = _selectedVerstoss?.id == v.id;
        return InkWell(
          onTap: () => setState(() => _selectedVerstoss = v),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? v.color.withValues(alpha: 0.15)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? v.color : Colors.grey.shade300,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(v.icon, size: 18, color: selected ? v.color : Colors.grey),
                const SizedBox(width: 6),
                Text(
                  v.anzeigeTitel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    color: selected ? v.color : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSachverhaltInput() {
    return TextField(
      controller: _sachverhaltController,
      maxLines: 5,
      decoration: InputDecoration(
        hintText: tr(
            'Beschreiben Sie den Vorfall detailliert...\n\n'
            'z.B.: Am [Datum] hat das Mitglied [Name] gegenüber '
            '[Person] vertrauliche Informationen weitergegeben...',
            // Der Text geht unverändert in das deutsche Schreiben an das
            // Mitglied — deshalb auf Rumänisch der Hinweis, deutsch zu
            // schreiben, und das Beispiel bleibt deutsch.
            'Descrieți incidentul în detaliu, în germană — textul apare '
            'neschimbat în scrisoarea oficială...\n\n'
            'de ex.: Am [Datum] hat das Mitglied [Name] gegenüber '
            '[Person] vertrauliche Informationen weitergegeben...'),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildVorfallDatumPicker() {
    final df = DateFormat('dd.MM.yyyy');
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _vorfallDatum ?? DateTime.now(),
          firstDate: DateTime(2025),
          lastDate: DateTime.now(),
          locale: LanguageService.instance.isRomanian
              ? const Locale('ro', 'RO')
              : const Locale('de', 'DE'),
        );
        if (picked != null) {
          setState(() => _vorfallDatum = picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today,
                size: 18, color: Colors.grey.shade600),
            const SizedBox(width: 10),
            Text(
              _vorfallDatum != null
                  ? df.format(_vorfallDatum!)
                  : tr('Datum auswählen...', 'Selectați data...'),
              style: TextStyle(
                fontSize: 14,
                color: _vorfallDatum != null
                    ? Colors.black
                    : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMassnahmeSelector() {
    return Column(
      children: _massnahmen.map((m) {
        final selected = _selectedMassnahme?.id == m.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () => setState(() => _selectedMassnahme = m),
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selected
                    ? m.color.withValues(alpha: 0.1)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? m.color : Colors.grey.shade300,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(m.icon,
                      size: 22,
                      color: selected ? m.color : Colors.grey.shade500),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.anzeigeTitel,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: selected
                                ? m.color
                                : Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          m.anzeigeBeschreibung,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check_circle, color: m.color, size: 22),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOrdnungsgeldInput() {
    return Row(
      children: [
        Text(tr('Betrag: ', 'Sumă: '),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        SizedBox(
          width: 100,
          child: TextField(
            controller: _ordnungsgeldController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              suffixText: '€',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text('(max. 100 €)',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildPreviewPanel() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.preview, size: 22, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(
                    tr('Vorschau', 'Previzualizare'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Selected info
              _buildPreviewRow(
                tr('Mitglied', 'Membru'),
                _selectedUser != null
                    ? '${_selectedUser!.name} (${_selectedUser!.mitgliedernummer})'
                    : '—',
              ),
              _buildPreviewRow(
                tr('Verstoß', 'Încălcare'),
                _selectedVerstoss?.anzeigeTitel ?? '—',
              ),
              _buildPreviewRow(
                tr('Rechtsgrundlage', 'Temei juridic'),
                _selectedVerstoss?.anzeigeParagraph ?? '—',
              ),
              _buildPreviewRow(
                tr('Vorfallsdatum', 'Data incidentului'),
                _vorfallDatum != null
                    ? DateFormat('dd.MM.yyyy').format(_vorfallDatum!)
                    : '—',
              ),
              _buildPreviewRow(
                tr('Maßnahme', 'Măsură'),
                _selectedMassnahme?.anzeigeTitel ?? '—',
              ),
              if (_selectedMassnahme?.id == 'ordnungsgeld')
                _buildPreviewRow(
                  tr('Ordnungsgeld', 'Amendă'),
                  '${_ordnungsgeldController.text} €',
                ),
              _buildPreviewRow(
                tr('Datum Schreiben', 'Data scrisorii'),
                DateFormat('dd.MM.yyyy').format(_datum),
              ),
              const SizedBox(height: 20),

              // Rechtliche Hinweise
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: Colors.amber.shade800),
                        const SizedBox(width: 6),
                        Text(
                          tr('Rechtliche Hinweise', 'Note juridice'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr(
                          '• Gemäß §6 Abs. 6 Nr. 2 der Satzung ist dem '
                          'Mitglied vor Verhängung einer Ordnungsmaßnahme '
                          'Gelegenheit zur schriftlichen Stellungnahme '
                          'innerhalb von 14 Tagen zu geben.',
                          '• Conform §6 alin. 6 pct. 2 din statut, înainte de '
                          'aplicarea unei măsuri disciplinare membrului trebuie '
                          'să i se acorde posibilitatea de a lua poziție în '
                          'scris în termen de 14 zile.'),
                      style: TextStyle(
                          fontSize: 11, color: Colors.amber.shade900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tr(
                          '• Gegen den Ausschluss kann das Mitglied '
                          'innerhalb eines Monats Einspruch einlegen '
                          '(§6 Abs. 3a Satzung).',
                          '• Membrul poate contesta excluderea în termen '
                          'de o lună (§6 alin. 3a din statut).'),
                      style: TextStyle(
                          fontSize: 11, color: Colors.amber.shade900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tr(
                          '• Die Maßnahme muss in Bezug zum Vereinszweck '
                          'und zur Ordnung des Vereins stehen.',
                          '• Măsura trebuie să aibă legătură cu scopul '
                          'și cu ordinea internă a asociației.'),
                      style: TextStyle(
                          fontSize: 11, color: Colors.amber.shade900),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Verstoss-Kategorien Info
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.list_alt,
                            size: 16, color: Colors.blue.shade800),
                        const SizedBox(width: 6),
                        Text(
                          tr('Stufenfolge', 'Gradarea măsurilor'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr(
                          '1. Schriftliche Verwarnung\n'
                          '2. Ordnungsgeld (bis 100 €)\n'
                          '3. Ausschluss aus dem Verein',
                          '1. Avertisment scris\n'
                          '2. Amendă (până la 100 €)\n'
                          '3. Excluderea din asociație'),
                      style: TextStyle(
                          fontSize: 11, color: Colors.blue.shade900),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    value != '—' ? FontWeight.bold : FontWeight.normal,
                color: value != '—' ? Colors.black : Colors.grey.shade400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _canGenerate() {
    if (_isGenerating) return false;
    if (_selectedUser == null) return false;
    if (_selectedVerstoss == null) return false;
    if (_selectedMassnahme == null) return false;
    if (_sachverhaltController.text.trim().isEmpty) return false;
    if (_vorfallDatum == null) return false;
    return true;
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'vorsitzer':
        return Colors.purple;
      case 'schatzmeister':
        return Colors.blue;
      case 'kassierer':
        return Colors.green;
      case 'mitgliedergrunder':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Future<void> _generatePdf() async {
    setState(() => _isGenerating = true);

    try {
      final user = _selectedUser!;
      final verstoss = _selectedVerstoss!;
      final massnahme = _selectedMassnahme!;
      final sachverhalt = _sachverhaltController.text.trim();

      // 1. Save to server via VerwarnungService
      final verwarnungService = VerwarnungService();
      final apiService = ApiService();
      verwarnungService.setToken(apiService.token);

      // Map massnahme to verwarnung typ
      String verwarnungTyp;
      switch (massnahme.id) {
        case 'verwarnung':
          verwarnungTyp = 'ermahnung';
        case 'ordnungsgeld':
          verwarnungTyp = 'abmahnung';
        case 'ausschluss':
          verwarnungTyp = 'letzte_abmahnung';
        default:
          verwarnungTyp = 'ermahnung';
      }

      await verwarnungService.createVerwarnung(
        userId: user.id,
        typ: verwarnungTyp,
        grund: '${verstoss.titel} (${verstoss.paragraph})',
        beschreibung: sachverhalt,
        datum: DateFormat('yyyy-MM-dd').format(_vorfallDatum!),
      );

      // 2. Generate PDF
      final result = await VerwarnungPdfGenerator.generate(
        userName: user.name,
        mitgliedernummer: user.mitgliedernummer,
        massnahmeId: massnahme.id,
        massnahmeTitel: massnahme.titel,
        verstossTitel: verstoss.titel,
        verstossParagraph: verstoss.paragraph,
        verstossBeschreibung: verstoss.beschreibung,
        sachverhalt: sachverhalt,
        vorfallDatum: _vorfallDatum!,
        ordnungsgeldBetrag: massnahme.id == 'ordnungsgeld'
            ? _ordnungsgeldController.text.trim()
            : null,
        schreibenDatum: _datum,
      );

      if (result != null && mounted) {
        await VerwarnungPdfGenerator.saveAndPreview(
          context,
          result.bytes,
          result.fileName,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                tr('Fehler beim Erstellen: $e', 'Eroare la creare: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }
}
