import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';

class FinanzamtScreen extends StatefulWidget {
  final ApiService apiService;
  final VoidCallback onBack;

  const FinanzamtScreen({
    super.key,
    required this.apiService,
    required this.onBack,
  });

  @override
  State<FinanzamtScreen> createState() => _FinanzamtScreenState();
}

class _FinanzamtScreenState extends State<FinanzamtScreen> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;


  // Zuständiger (Vorsitzer - automatic)
  String? _zustaendigerName;
  String? _zustaendigerNummer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadZustaendiger();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final result = await widget.apiService.getVereinverwaltung(kategorie: 'finanzamt');
      if (mounted && result['success'] == true) {
        final data = result['data'] as List?;
        if (data != null && data.isNotEmpty) {
          setState(() {
            _data = data[0];
            _isLoading = false;
          });
          return;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadZustaendiger() async {
    try {
      final result = await widget.apiService.getBoardMembers();
      if (mounted && result['success'] == true) {
        final users = List<Map<String, dynamic>>.from(result['data']?['users'] ?? []);
        final vorsitzer = users.where((u) => u['role'] == 'vorsitzer' && u['status'] == 'active').toList();
        if (vorsitzer.isNotEmpty) {
          final v = vorsitzer.first;
          setState(() {
            _zustaendigerName = '${v['vorname'] ?? v['name'] ?? ''} ${v['nachname'] ?? ''}'.trim();
            _zustaendigerNummer = v['mitgliedernummer'] ?? '';
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // Entscheidend ist die Breite, die der Bildschirm wirklich bekommt
    // (auf dem Schreibtisch nimmt die Seitenleiste Platz weg).
    return LayoutBuilder(
      builder: (context, constraints) {
        final telefon = constraints.maxWidth < 600;
        final schmal = constraints.maxWidth < 900;
        return Padding(
          padding: EdgeInsets.all(telefon ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header — auf dem Telefon ohne Zierbild und mit 20er Titel
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: widget.onBack,
                    tooltip: tr('Zurück', 'Înapoi'),
                  ),
                  const SizedBox(width: 8),
                  if (!telefon) ...[
                    Icon(Icons.receipt_long, size: 32, color: Colors.teal.shade700),
                    const SizedBox(width: 12),
                  ],
                  Flexible(
                    child: Text(
                      tr('Finanzamt', 'Finanzamt (fisc)'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: telefon ? 20 : 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              SizedBox(height: telefon ? 16 : 24),
              // Content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _data == null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.receipt_long, size: 48, color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                Text(
                                  tr('Keine Finanzamt-Daten vorhanden', 'Nu există date despre Finanzamt'),
                                  textAlign: telefon ? TextAlign.center : null, // bricht nur dort um
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                                ),
                              ],
                            ),
                          )
                        : _buildContent(schmal: schmal, telefon: telefon),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent({required bool schmal, required bool telefon}) {
    final d = _data!;
    final notizen = (d['notizen'] ?? '') as String;

    // Parse notizen for structured data
    String? steuernummer;
    String? gemeinnuetzigkeit;
    String? oeffnungszeiten;
    String? serviceCenter;
    for (final line in notizen.split('\n')) {
      if (line.startsWith('Steuernummer:')) steuernummer = line.substring('Steuernummer:'.length).trim();
      if (line.startsWith('Gemeinnützigkeit:')) gemeinnuetzigkeit = line.substring('Gemeinnützigkeit:'.length).trim();
      if (line.startsWith('Öffnungszeiten:')) oeffnungszeiten = line.substring('Öffnungszeiten:'.length).trim();
      if (line.startsWith('Service-Center:')) serviceCenter = line.substring('Service-Center:'.length).trim();
    }

    final websiteKnopf = d['website'] == null
        ? null
        : OutlinedButton.icon(
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(tr('Website öffnen', 'Deschide site-ul')),
            onPressed: () => _openUrl(d['website']),
          );
    final mailKnopf = d['email'] == null
        ? null
        : OutlinedButton.icon(
            icon: const Icon(Icons.email, size: 16),
            label: Text(tr('E-Mail senden', 'Trimite e-mail')),
            onPressed: () => _openUrl('mailto:${d['email']}'),
          );

    // Finanzamt contact card
    final kontakt = Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.account_balance, color: Colors.teal, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d['name'] ?? '',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      if (d['name2'] != null)
                        Text(
                          d['name2'],
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            // Address & Contact
            _buildInfoRow(Icons.location_on, tr('Adresse', 'Adresă'), '${d['strasse']} ${d['hausnummer']}, ${d['plz']} ${d['ort']}', gestapelt: telefon),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.phone, 'Telefon', d['telefon'] ?? '-', gestapelt: telefon),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.fax, 'Fax', d['fax'] ?? '-', gestapelt: telefon),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.email, tr('E-Mail', 'E-mail'), d['email'] ?? '-', gestapelt: telefon),
            if (oeffnungszeiten != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(Icons.access_time, tr('Öffnungszeiten', 'Program'), oeffnungszeiten, gestapelt: telefon),
            ],
            if (serviceCenter != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(Icons.support_agent, tr('Service-Center', 'Centru de servicii'), serviceCenter, gestapelt: telefon),
            ],
            // Unten angeschlagen nur, solange die Karte die volle Höhe hat.
            if (schmal) const SizedBox(height: 16) else const Spacer(),
            // Action buttons — auf dem Telefon untereinander in voller Breite,
            // nebeneinander bräche die Beschriftung zweizeilig um.
            if (telefon)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (websiteKnopf != null) websiteKnopf,
                  if (websiteKnopf != null && mailKnopf != null) const SizedBox(height: 8),
                  if (mailKnopf != null) mailKnopf,
                ],
              )
            else
              Row(
                children: [
                  if (websiteKnopf != null)
                    Expanded(child: websiteKnopf),
                  const SizedBox(width: 8),
                  if (mailKnopf != null)
                    Expanded(child: mailKnopf),
                ],
              ),
          ],
        ),
      ),
    );

    // Right: Steuernummer & Gemeinnützigkeit + Zuständiger
    final verein = Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.verified, color: Colors.teal, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'ICD360S e.V.',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            // Steuernummer
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.teal.shade100),
              ),
              child: Column(
                children: [
                  Icon(Icons.tag, color: Colors.teal.shade700, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    tr('Steuernummer', 'Număr fiscal (Steuernummer)'),
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    steuernummer ?? tr('(wird ergänzt)', '(se va completa)'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Gemeinnützigkeit
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: gemeinnuetzigkeit == 'anerkannt' ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: gemeinnuetzigkeit == 'anerkannt' ? Colors.green.shade200 : Colors.orange.shade200,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    gemeinnuetzigkeit == 'anerkannt' ? Icons.check_circle : Icons.pending,
                    color: gemeinnuetzigkeit == 'anerkannt' ? Colors.green.shade700 : Colors.orange.shade700,
                    size: 28,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr('Gemeinnützigkeit', 'Utilitate publică (Gemeinnützigkeit)'),
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    // 'anerkannt' ist der Wert aus den Notizen, auf den oben
                    // auch die Farbe prüft — nur die Anzeige wird übersetzt.
                    gemeinnuetzigkeit == 'anerkannt'
                        ? tr('anerkannt', 'recunoscută')
                        : gemeinnuetzigkeit ?? tr('(wird ergänzt)', '(se va completa)'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: gemeinnuetzigkeit == 'anerkannt' ? Colors.green.shade700 : Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Zuständiger
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                children: [
                  Icon(Icons.person, color: Colors.blue.shade700, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    tr('Zuständig für Dosar', 'Responsabil de dosar'),
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _zustaendigerName ?? tr('(wird geladen...)', '(se încarcă...)'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tr('Vorsitzer${_zustaendigerNummer != null ? ' ($_zustaendigerNummer)' : ''}',
                        'Președinte${_zustaendigerNummer != null ? ' ($_zustaendigerNummer)' : ''}'),
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade400),
                  ),
                ],
              ),
            ),
            if (schmal) const SizedBox(height: 16) else const Spacer(),
            // Info text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr('Zuständiges Finanzamt für ICD360S e.V. im Landkreis Neu-Ulm, Bayern.',
                          'Finanzamt competent pentru ICD360S e.V. în districtul Neu-Ulm, Bavaria.'),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (schmal) {
      // Unter 900 dp untereinander in natürlicher Höhe, die Seite scrollt —
      // statt Spalten nebeneinander, die auf dem Telefon kaum 60 dp
      // breit wären.
      return ListView(
        children: [
          kontakt,
          const SizedBox(height: 16),
          verein,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: Finanzamt Info
        Expanded(
          flex: 2,
          child: Column(
            children: [
              // Finanzamt contact card
              Expanded(child: kontakt),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Right: Steuernummer & Gemeinnützigkeit + Zuständiger
        Expanded(
          flex: 1,
          child: verein,
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool gestapelt = false}) {
    // Telefon: Bezeichnung über dem Wert statt in einer 110-dp-Spalte daneben —
    // sonst blieben dem Wert auf 320 dp kaum 100 dp.
    if (gestapelt) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
