import 'dart:io';
import 'dart:typed_data';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:signature/signature.dart';

import '../services/api_service.dart';
import '../services/language_service.dart';

/// Dokumente, die der SCHATZMEISTER SELBST unterschreiben soll.
///
/// Der Vorsitzende stellt ein Dokument ein, der Schatzmeister unterschreibt es
/// hier — Kassenbericht, Bankvollmacht, alles mit zwei Unterschriften.
///
/// Serverseitig war dafür nichts zu bauen, und zwar an BEIDEN Enden:
///   • `member/signatur_manage.php` hängt an der Identität aus dem Token, nicht
///     an einer Rolle. Der Schatzmeister ist dort ein Nutzer wie jeder andere.
///   • `vorstand/signatur_manage.php` (`anfordern`) prüft beim Unterzeichner
///     nur, DASS es ihn gibt — `SELECT 1 FROM users WHERE id = ?`, keine
///     Rollenprüfung. Und `admin/users.php` listet alle Rollen, der
///     Schatzmeister steht also in der Auswahl des Vorsitzenden.
///
/// Belegt ist das auch in den Daten: von den bereits geleisteten Unterschriften
/// tragen 10 die Rolle `vorsitzer` und 2 `mitgliedergrunder` — der Ablauf wird
/// längst von mehr als nur `mitglied` benutzt.
///
/// Übernommen aus der Vorsitzer-App (`eigene_unterschriften_screen.dart`,
/// origin/main). Deren `F.h(...)`-Farbhelfer sind durch die direkten
/// Material-Abstufungen ersetzt: die schalten auf Dunkelmodus um, den es in
/// dieser App nicht gibt — `app_farben.dart` mitzunehmen hieße, ein ganzes
/// Farbsystem für zwei Aufrufe einzuschleppen. Ein Unterschied ist bewusst: dort hängt der Einstieg ohne
/// Zählerabzeichen in der Leiste, weil der Vorsitzende die Unterschrift selbst
/// angefordert hat und ohnehin weiß, dass sie ansteht. Für den Schatzmeister
/// gilt das nicht — er bekommt sie geschickt. Deshalb zählt der Einstieg hier.
class EigeneUnterschriftenScreen extends StatefulWidget {
  final ApiService apiService;

  const EigeneUnterschriftenScreen({super.key, required this.apiService});

  @override
  State<EigeneUnterschriftenScreen> createState() =>
      _EigeneUnterschriftenScreenState();
}

class _EigeneUnterschriftenScreenState
    extends State<EigeneUnterschriftenScreen> {
  List<Map<String, dynamic>> _vorgaenge = [];
  bool _laedt = true;
  String? _fehler;

  @override
  void initState() {
    super.initState();
    _laden();
  }

  Future<void> _laden() async {
    setState(() {
      _laedt = true;
      _fehler = null;
    });

    final antwort = await widget.apiService.eigeneSignatur('list');
    if (!mounted) return;

    if (antwort['success'] != true) {
      setState(() {
        _laedt = false;
        _fehler = antwort['message']?.toString() ??
            tr('Laden fehlgeschlagen', 'Încărcare eșuată');
      });
      return;
    }

    final roh = antwort['signaturen'];
    setState(() {
      _laedt = false;
      _vorgaenge = roh is List
          ? roh.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Meine Unterschriften', 'Semnăturile mele')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: tr('Neu laden', 'Reîncarcă'),
            onPressed: _laedt ? null : _laden,
          ),
        ],
      ),
      body: _laedt
          ? const Center(child: CircularProgressIndicator())
          : _fehler != null
              ? _fehlerAnsicht()
              : _vorgaenge.isEmpty
                  ? _leer()
                  : RefreshIndicator(
                      onRefresh: _laden,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _vorgaenge.length,
                        itemBuilder: (_, i) => _kachel(_vorgaenge[i]),
                      ),
                    ),
    );
  }

  Widget _fehlerAnsicht() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(_fehler!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: _laden,
                  child: Text(tr('Erneut versuchen', 'Încearcă din nou'))),
            ],
          ),
        ),
      );

  Widget _leer() => ListView(
        padding: const EdgeInsets.all(32),
        children: [
          const SizedBox(height: 80),
          Icon(Icons.draw_outlined, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            tr('Zurzeit liegt nichts zu Ihrer Unterschrift vor.',
                'Momentan nu aveți nimic de semnat.'),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      );

  Widget _kachel(Map<String, dynamic> v) {
    final status = (v['status'] ?? 'offen').toString();
    final offen = status == 'offen';
    // Unterschrieben, aber das Dokument wartet noch auf den zweiten
    // Unterzeichner. Ohne eigenen Zustand sähe das aus wie „fertig" — und der
    // Vorsitzende suchte einen Download, den es noch nicht geben kann.
    final wartet = v['wartet_auf_mitunterzeichner'] == true;

    final (farbe, symbol, text) = switch (status) {
      'signiert' when wartet => (
          Colors.blue.shade700,
          Icons.hourglass_top,
          tr('Von Ihnen unterschrieben · warten auf die zweite Unterschrift',
              'Semnat de dumneavoastră · se așteaptă a doua semnătură'),
        ),
      'signiert' => (Colors.green.shade700, Icons.verified,
          tr('Von Ihnen unterschrieben', 'Semnat de dumneavoastră')),
      'abgelehnt' => (Colors.red.shade700, Icons.cancel,
          tr('Von Ihnen abgelehnt', 'Refuzat de dumneavoastră')),
      'widerrufen' => (Colors.grey.shade600, Icons.undo, tr('Zurückgezogen', 'Retras')),
      'abgelaufen' => (Colors.grey.shade600, Icons.schedule,
          tr('Frist abgelaufen', 'Termen expirat')),
      _ => (Colors.orange.shade800, Icons.edit_document,
          tr('Wartet auf Ihre Unterschrift', 'Așteaptă semnătura dumneavoastră')),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: farbe.withValues(alpha: 0.15),
          child: Icon(symbol, color: farbe),
        ),
        title: Text((v['dokument_titel'] ?? '').toString(),
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(text, style: TextStyle(color: farbe, fontSize: 12)),
        trailing: offen ? const Icon(Icons.chevron_right) : null,
        onTap: offen ? () => _oeffnen(v) : null,
      ),
    );
  }

  Future<void> _oeffnen(Map<String, dynamic> v) async {
    final fertig = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EigeneUnterschriftLeistenScreen(
          apiService: widget.apiService,
          signaturId: (v['id'] as num).toInt(),
          titel: (v['dokument_titel'] ?? '').toString(),
          seiten: (v['pdf_seiten'] as num?)?.toInt(),
        ),
      ),
    );
    if (fertig == true) _laden();
  }
}

// ═══════════════════════════════════════════════════════════════════════════

/// Der eigentliche Vorgang: lesen, unterschreiben, mit Code bestätigen.
class EigeneUnterschriftLeistenScreen extends StatefulWidget {
  final ApiService apiService;
  final int signaturId;
  final String titel;
  final int? seiten;

  const EigeneUnterschriftLeistenScreen({
    super.key,
    required this.apiService,
    required this.signaturId,
    required this.titel,
    this.seiten,
  });

  @override
  State<EigeneUnterschriftLeistenScreen> createState() =>
      _EigeneUnterschriftLeistenScreenState();
}

class _EigeneUnterschriftLeistenScreenState
    extends State<EigeneUnterschriftLeistenScreen> {
  final _unterschrift = SignatureController(
    penStrokeWidth: 2.5,
    penColor: Colors.black,
  );
  final _tanFeld = TextEditingController();

  int _schritt = 0;
  bool _sendet = false;
  String? _fehler;
  String? _codeGesendetAn;
  int _letzteGeseheneSeite = 1;

  /// Erst weiterblättern lassen, wenn das Dokument bis zum Ende gesehen wurde.
  /// Wer unterschreibt, soll gelesen haben können — das ist der Sinn der
  /// ganzen Übung, nicht Förmelei.
  bool get _durchgeblaettert =>
      widget.seiten == null || _letzteGeseheneSeite >= widget.seiten!;

  @override
  void dispose() {
    _unterschrift.dispose();
    _tanFeld.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titel, style: const TextStyle(fontSize: 16)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: (_schritt + 1) / 3),
        ),
      ),
      body: switch (_schritt) {
        0 => _lesen(),
        1 => _malen(),
        _ => _bestaetigen(),
      },
    );
  }

  // ── Schritt 1: lesen ──

  Widget _lesen() => Column(
        children: [
          Expanded(
            child: _EigenesPdf(
              apiService: widget.apiService,
              signaturId: widget.signaturId,
              onSeite: (s) {
                if (s > _letzteGeseheneSeite) {
                  setState(() => _letzteGeseheneSeite = s);
                }
              },
            ),
          ),
          _fussleiste(
            hinweis: _durchgeblaettert
                ? null
                : tr(
                    'Bitte lesen Sie das Dokument bis zur letzten Seite '
                        '($_letzteGeseheneSeite von ${widget.seiten}).',
                    'Vă rugăm citiți documentul până la ultima pagină '
                        '($_letzteGeseheneSeite din ${widget.seiten}).'),
            weiter: _durchgeblaettert ? () => setState(() => _schritt = 1) : null,
            weiterText: tr('Weiter zur Unterschrift', 'Continuă la semnătură'),
          ),
        ],
      );

  // ── Schritt 2: unterschreiben ──

  Widget _malen() => Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    tr('Bitte unterschreiben Sie im weißen Feld.',
                        'Vă rugăm semnați în câmpul alb.'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Signature(
                        controller: _unterschrift,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _unterschrift.clear(),
                      icon: const Icon(Icons.clear, size: 18),
                      label: Text(tr('Löschen', 'Șterge')),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _fussleiste(
            zurueck: () => setState(() => _schritt = 0),
            weiter: () {
              if (_unterschrift.isEmpty) {
                _meldung(
                    tr('Bitte unterschreiben Sie zuerst.', 'Vă rugăm semnați mai întâi.'),
                    fehler: true);
                return;
              }
              setState(() => _schritt = 2);
            },
            weiterText: tr('Weiter zum Code', 'Continuă la cod'),
          ),
        ],
      );

  // ── Schritt 3: Code ──

  Widget _bestaetigen() => Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    tr(
                        'Zur Bestätigung schicken wir Ihnen einen Code per SMS an '
                        'Ihre hinterlegte Mobilnummer.',
                        'Pentru confirmare vă trimitem un cod prin SMS '
                        'la numărul de mobil înregistrat.'),
                  ),
                  const SizedBox(height: 16),
                  if (_codeGesendetAn == null)
                    FilledButton.icon(
                      onPressed: _sendet ? null : _tanAnfordern,
                      icon: const Icon(Icons.sms),
                      label: Text(tr('Code anfordern', 'Solicită cod')),
                    )
                  else ...[
                    Text(
                        tr('Code gesendet an $_codeGesendetAn',
                            'Cod trimis la $_codeGesendetAn'),
                        style: TextStyle(color: Colors.green.shade700)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _tanFeld,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: InputDecoration(
                        labelText: tr('Code aus der SMS', 'Codul din SMS'),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        // Der Knopf hängt am Inhalt, also muss der Aufbau
                        // laufen, wenn sich der Inhalt ändert. Genau das fehlte
                        // in der Mitglieder-App und der Knopf blieb tot.
                        setState(() {});
                      },
                    ),
                    TextButton(
                      onPressed: _sendet ? null : _tanAnfordern,
                      child: Text(tr('Neuen Code anfordern', 'Solicită un cod nou')),
                    ),
                  ],
                  if (_fehler != null) ...[
                    const SizedBox(height: 12),
                    Text(_fehler!, style: TextStyle(color: Colors.red.shade700)),
                  ],
                  const SizedBox(height: 24),
                  TextButton.icon(
                    onPressed: _sendet ? null : _ablehnen,
                    icon: const Icon(Icons.cancel_outlined),
                    label: Text(tr('Unterschrift ablehnen', 'Refuză semnătura')),
                    style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                  ),
                ],
              ),
            ),
          ),
          _fussleiste(
            zurueck: () => setState(() => _schritt = 1),
            weiter: (_codeGesendetAn != null && _tanFeld.text.trim().length >= 4 && !_sendet)
                ? _signieren
                : null,
            weiterText: tr('Rechtsverbindlich unterschreiben', 'Semnează cu valoare juridică'),
          ),
        ],
      );

  // ── Fußleiste ──

  Widget _fussleiste({
    String? hinweis,
    VoidCallback? zurueck,
    VoidCallback? weiter,
    required String weiterText,
  }) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey.shade300)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              if (hinweis != null) ...[
                Text(hinweis,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  if (zurueck != null)
                    TextButton(
                        onPressed: zurueck, child: Text(tr('Zurück', 'Înapoi'))),
                  // Der Weiter-Knopf nimmt den Rest der Zeile und darf
                  // umbrechen: „Rechtsverbindlich unterschreiben“ lief neben
                  // „Zurück“ auf 320 dp um 33 dp hinaus. Passt er, steht er
                  // rechts wie bisher.
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: weiter,
                        child: _sendet
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(weiterText, textAlign: TextAlign.center),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  // ── Aktionen ──

  Future<void> _tanAnfordern() async {
    setState(() {
      _sendet = true;
      _fehler = null;
    });

    final antwort = await widget.apiService
        .eigeneSignatur('tan_anfordern', {'signatur_id': widget.signaturId});

    if (!mounted) return;
    setState(() => _sendet = false);

    if (antwort['success'] == true) {
      setState(() => _codeGesendetAn = antwort['gesendet_an']?.toString());
      return;
    }

    // 'keine_rufnummer' ausdrücklich benennen: ein Knopf, der nichts tut, sieht
    // aus wie ein Fehler in der App, obwohl schlicht keine Nummer hinterlegt ist.
    setState(() {
      _fehler = antwort['grund'] == 'keine_rufnummer'
          ? tr(
              'Für Ihr Konto ist keine Mobilnummer hinterlegt. '
                  'Ohne Nummer kann kein Code verschickt werden.',
              'Pentru contul dumneavoastră nu este înregistrat niciun număr de mobil. '
                  'Fără număr nu se poate trimite niciun cod.')
          : (antwort['message']?.toString() ??
              tr('Code konnte nicht gesendet werden.', 'Codul nu a putut fi trimis.'));
    });
  }

  Future<void> _signieren() async {
    final svg = _unterschrift.toRawSVG();
    if (svg == null || svg.isEmpty) {
      setState(() => _schritt = 1);
      _meldung(tr('Die Unterschrift ist leer.', 'Semnătura este goală.'), fehler: true);
      return;
    }

    setState(() {
      _sendet = true;
      _fehler = null;
    });

    final antwort = await widget.apiService.eigeneSignatur('signieren', {
      'signatur_id': widget.signaturId,
      'signature_svg': svg,
      'tan': _tanFeld.text.trim(),
      'signed_at_local': DateTime.now().toIso8601String(),
      'device_hostname': await _geraetename(),
    });

    if (!mounted) return;
    setState(() => _sendet = false);

    if (antwort['success'] == true) {
      _meldung(tr('Unterschrift gespeichert.', 'Semnătură salvată.'), erfolg: true);
      if (mounted) Navigator.pop(context, true);
      return;
    }

    setState(() {
      _fehler = switch (antwort['grund']?.toString()) {
        'tan_falsch' => tr('Der Code stimmt nicht.', 'Codul nu este corect.'),
        'tan_abgelaufen' => tr('Der Code ist abgelaufen. Bitte fordern Sie einen neuen an.',
            'Codul a expirat. Vă rugăm solicitați unul nou.'),
        'zu_viele_versuche' =>
          tr('Zu viele Fehlversuche. Bitte fordern Sie einen neuen Code an.',
              'Prea multe încercări eșuate. Vă rugăm solicitați un cod nou.'),
        _ => antwort['message']?.toString() ??
            tr('Unterschrift fehlgeschlagen.', 'Semnarea a eșuat.'),
      };
    });
  }

  Future<void> _ablehnen() async {
    final grundFeld = TextEditingController();

    final bestaetigt = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Unterschrift ablehnen', 'Refuză semnătura')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr(
                  'Das Dokument wird dann nicht unterschrieben. Bei einer Vollmacht '
                  'gilt die Ablehnung für das ganze Dokument — auch wenn die andere '
                  'Person schon unterschrieben hat.',
                  'Documentul nu va fi semnat. În cazul unei împuterniciri (Vollmacht) '
                  'refuzul se aplică întregului document — chiar dacă cealaltă '
                  'persoană a semnat deja.'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: grundFeld,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: tr('Begründung (freiwillig)', 'Motivare (opțional)'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('Abbrechen', 'Anulare'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('Ablehnen', 'Refuză')),
          ),
        ],
      ),
    );

    if (bestaetigt != true || !mounted) return;

    final antwort = await widget.apiService.eigeneSignatur('ablehnen', {
      'signatur_id': widget.signaturId,
      'grund': grundFeld.text.trim(),
    });
    if (!mounted) return;

    if (antwort['success'] == true) {
      _meldung(tr('Abgelehnt.', 'Refuzat.'), erfolg: true);
      Navigator.pop(context, true);
    } else {
      _meldung(
          antwort['message']?.toString() ??
              tr('Ablehnen fehlgeschlagen.', 'Refuzul a eșuat.'),
          fehler: true);
    }
  }

  /// Gerätename fürs Beweisbündel. Fehlt er, bleibt das Feld leer — daran darf
  /// eine gültige Unterschrift nicht scheitern.
  Future<String?> _geraetename() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        return _zusammen([a.manufacturer, a.model, 'Android ${a.version.release}']);
      }
      if (Platform.isIOS) {
        final i = await info.iosInfo;
        return _zusammen([i.name, i.model, '${i.systemName} ${i.systemVersion}']);
      }
      if (Platform.isMacOS) {
        final m = await info.macOsInfo;
        return _zusammen([m.computerName, m.model, 'macOS ${m.osRelease}']);
      }
      if (Platform.isWindows) {
        final w = await info.windowsInfo;
        return _zusammen([w.computerName, w.productName]);
      }
      if (Platform.isLinux) {
        final l = await info.linuxInfo;
        return _zusammen([Platform.localHostname, l.prettyName]);
      }
    } catch (_) {
      // bewusst still
    }
    return null;
  }

  static String? _zusammen(List<String?> teile) {
    final gefiltert = teile
        .map((t) => (t ?? '').trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (gefiltert.isEmpty) return null;
    final text = gefiltert.join(' · ');
    return text.length > 120 ? text.substring(0, 120) : text;
  }

  void _meldung(String text, {bool fehler = false, bool erfolg = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: fehler
            ? Colors.red.shade700
            : erfolg
                ? Colors.green.shade700
                : null,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════

/// Lädt das PDF über den eigenen Client und zeigt es aus dem Speicher.
///
/// Nicht über `PdfViewer.uri`: der Betrachter lädt dann selbst, mit eigener
/// Zertifikatsprüfung — unter Windows scheitert das an der neuen Wurzel und
/// sieht nur wie „Failed to open PDF" aus.
class _EigenesPdf extends StatefulWidget {
  final ApiService apiService;
  final int signaturId;
  final void Function(int seite) onSeite;

  const _EigenesPdf({
    required this.apiService,
    required this.signaturId,
    required this.onSeite,
  });

  @override
  State<_EigenesPdf> createState() => _EigenesPdfState();
}

class _EigenesPdfState extends State<_EigenesPdf> {
  Uint8List? _daten;
  bool _laedt = true;

  @override
  void initState() {
    super.initState();
    _laden();
  }

  Future<void> _laden() async {
    final bytes = await widget.apiService.eigeneSignaturPdf(widget.signaturId);
    if (!mounted) return;
    setState(() {
      _daten = bytes;
      _laedt = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_laedt) return const Center(child: CircularProgressIndicator());
    if (_daten == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                  tr('Das Dokument konnte nicht geladen werden.',
                      'Documentul nu a putut fi încărcat.'),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  setState(() => _laedt = true);
                  _laden();
                },
                child: Text(tr('Erneut versuchen', 'Încearcă din nou')),
              ),
            ],
          ),
        ),
      );
    }

    return PdfViewer.data(
      _daten!,
      sourceName: 'unterschrift_${widget.signaturId}.pdf',
      params: PdfViewerParams(
        onPageChanged: (seite) {
          if (seite != null) widget.onSeite(seite);
        },
      ),
    );
  }
}
