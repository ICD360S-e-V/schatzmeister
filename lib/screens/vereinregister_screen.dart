import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../l10n/app_localizations.dart';

class VereinregisterScreen extends StatefulWidget {
  final ApiService apiService;
  final VoidCallback onBack;

  const VereinregisterScreen({
    super.key,
    required this.apiService,
    required this.onBack,
  });

  @override
  State<VereinregisterScreen> createState() => _VereinregisterScreenState();
}

class _VereinregisterScreenState extends State<VereinregisterScreen> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;

  // Vereineinstellungen data (from DB)
  Map<String, dynamic> _vereineinstellungen = {};
  bool _vereineinstellungenLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadVereineinstellungen();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final result = await widget.apiService.getVereinverwaltung(kategorie: 'behoerde');
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

  Future<void> _loadVereineinstellungen() async {
    setState(() => _vereineinstellungenLoading = true);
    try {
      final result = await widget.apiService.getVereineinstellungen();
      if (result['success'] == true && mounted) {
        setState(() {
          _vereineinstellungen = Map<String, dynamic>.from(result['data'] ?? {});
          _vereineinstellungenLoading = false;
        });
      } else if (mounted) {
        setState(() => _vereineinstellungenLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _vereineinstellungenLoading = false);
    }
  }

  Future<void> _saveVereineinstellungen(Map<String, dynamic> data) async {
    final result = await widget.apiService.updateVereineinstellungen(data);
    if (result['success'] == true && mounted) {
      setState(() {
        _vereineinstellungen = Map<String, dynamic>.from(result['data'] ?? {});
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).vereinSettingsSaved), backgroundColor: Colors.green),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? AppLocalizations.of(context).errorSaving), backgroundColor: Colors.red),
      );
    }
  }

  void _showSettingsDialog() {
    final l = AppLocalizations.of(context);
    final d = _vereineinstellungen;
    final nameCtrl = TextEditingController(text: (d['vereinsname'] ?? '').toString());
    final adresseCtrl = TextEditingController(text: (d['adresse'] ?? '').toString());
    final telefonFixCtrl = TextEditingController(text: (d['telefon_fix'] ?? '').toString());
    final faxCtrl = TextEditingController(text: (d['fax'] ?? '').toString());
    final mobilCtrl = TextEditingController(text: (d['mobil'] ?? '').toString());
    final emailCtrl = TextEditingController(text: (d['email'] ?? '').toString());
    final gruendungsdatumCtrl = TextEditingController(text: (d['gruendungsdatum'] ?? '').toString());
    final registernummerCtrl = TextEditingController(text: (d['registernummer'] ?? '').toString());
    final registergerichtCtrl = TextEditingController(text: (d['registergericht'] ?? '').toString());

    final links = <Widget>[
      TextField(
        controller: nameCtrl,
        decoration: InputDecoration(
          labelText: l.vereinsname,
          prefixIcon: const Icon(Icons.business),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          hintText: tr('z.B. ICD360S e.V.', 'de ex. ICD360S e.V.'),
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: adresseCtrl,
        decoration: InputDecoration(
          labelText: l.addressRequired,
          prefixIcon: const Icon(Icons.location_on),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          hintText: tr('Straße Nr., PLZ Ort', 'Stradă nr., cod poștal, localitate'),
        ),
        maxLines: 2,
      ),
      const SizedBox(height: 14),
      TextField(
        controller: gruendungsdatumCtrl,
        decoration: InputDecoration(
          labelText: l.foundingDate,
          prefixIcon: const Icon(Icons.calendar_month),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          hintText: tr('z.B. 01.01.2025', 'de ex. 01.01.2025'),
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: registernummerCtrl,
        decoration: InputDecoration(
          labelText: l.registerNumber,
          prefixIcon: const Icon(Icons.numbers),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          hintText: tr('z.B. VR 201335', 'de ex. VR 201335'),
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: registergerichtCtrl,
        decoration: InputDecoration(
          labelText: l.registerCourt,
          prefixIcon: const Icon(Icons.account_balance),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          hintText: tr('z.B. Amtsgericht Memmingen, Bayern',
              'de ex. Amtsgericht Memmingen, Bayern'),
        ),
      ),
    ];
    final rechts = <Widget>[
      TextField(
        controller: emailCtrl,
        decoration: InputDecoration(
          labelText: l.email,
          prefixIcon: const Icon(Icons.email),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: telefonFixCtrl,
        decoration: InputDecoration(
          labelText: l.landlinePhone,
          prefixIcon: const Icon(Icons.phone),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: faxCtrl,
        decoration: InputDecoration(
          labelText: l.faxLabel,
          prefixIcon: const Icon(Icons.fax),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: mobilCtrl,
        decoration: InputDecoration(
          labelText: l.mobilePhone,
          prefixIcon: const Icon(Icons.phone_android),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        // Dialoge liegen über der ganzen App, nicht neben der Seitenleiste:
        // hier zählt die Fensterbreite. (LayoutBuilder geht in AlertDialog
        // nicht, der misst seinen Inhalt mit IntrinsicWidth.) Auf dem Telefon
        // eine Spalte statt zwei — sonst bleiben den Feldern kaum 80 dp.
        final telefon = MediaQuery.sizeOf(ctx).width < 600;
        return AlertDialog(
          insetPadding: telefon ? const EdgeInsets.symmetric(horizontal: 16, vertical: 24) : null,
          title: Row(
            children: [
              Icon(Icons.settings, color: Colors.indigo.shade700),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  l.vereinSettingsTitle,
                  style: telefon ? const TextStyle(fontSize: 20) : null,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 700,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Divider(),
                  const SizedBox(height: 8),
                  if (telefon)
                    Column(children: [...links, const SizedBox(height: 14), ...rechts])
                  else
                    // Two-column layout
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left column
                        Expanded(child: Column(children: links)),
                        const SizedBox(width: 16),
                        // Right column
                        Expanded(child: Column(children: rechts)),
                      ],
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.cancel),
            ),
            ElevatedButton.icon(
              onPressed: () {
                _saveVereineinstellungen({
                  'vereinsname': nameCtrl.text,
                  'adresse': adresseCtrl.text,
                  'telefon_fix': telefonFixCtrl.text,
                  'fax': faxCtrl.text,
                  'mobil': mobilCtrl.text,
                  'email': emailCtrl.text,
                  'gruendungsdatum': gruendungsdatumCtrl.text,
                  'registernummer': registernummerCtrl.text,
                  'registergericht': registergerichtCtrl.text,
                });
                Navigator.pop(ctx);
              },
              icon: const Icon(Icons.save, size: 18),
              label: Text(l.save),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  // Get values from DB (no fallback - values are stored in vereineinstellungen table)
  String get _vereinsname =>
      (_vereineinstellungen['vereinsname'] ?? '').toString().trim();

  String get _registernummer =>
      (_vereineinstellungen['registernummer'] ?? '').toString().trim();

  String get _registergericht =>
      (_vereineinstellungen['registergericht'] ?? '').toString().trim();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Telefon: Breite, die der Bildschirm wirklich bekommt (LayoutBuilder).
    return LayoutBuilder(
      builder: (context, constraints) {
        final telefon = constraints.maxWidth < 600;
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
                    tooltip: l.back,
                  ),
                  const SizedBox(width: 8),
                  if (!telefon) ...[
                    Icon(Icons.article, size: 32, color: Colors.indigo.shade700),
                    const SizedBox(width: 12),
                  ],
                  // Registernummer rechts außen; passt sie nicht mehr neben
                  // den Titel, steht sie darunter.
                  Expanded(
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        Text(
                          l.vereinregisterTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: telefon ? 20 : 24, fontWeight: FontWeight.bold),
                        ),
                        if (_data != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.indigo.shade200),
                            ),
                            child: Text(
                              _registernummer,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo.shade700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: telefon ? 16 : 24),
              // Content
              Expanded(
                child: _isLoading || _vereineinstellungenLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _data == null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.article, size: 48, color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                Text(
                                  l.noVereinregisterData,
                                  textAlign: telefon ? TextAlign.center : null, // bricht nur dort um
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                                ),
                              ],
                            ),
                          )
                        : _buildContent(telefon),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(bool telefon) {
    final l = AppLocalizations.of(context);
    final d = _data!;
    final ve = _vereineinstellungen;
    final hasVereinData = ve.isNotEmpty && (ve['vereinsname'] ?? '').toString().trim().isNotEmpty;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Amtsgericht Card
          Card(
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
                          color: Colors.indigo.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.account_balance, color: Colors.indigo, size: 24),
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
                  // Registration info
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.indigo.shade100),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.verified, color: Colors.indigo, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          _vereinsname,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${l.registerNumber}: $_registernummer',
                          style: TextStyle(fontSize: 15, color: Colors.indigo.shade700, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _registergericht,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Address
                  _buildInfoRow(Icons.location_on, l.address, '${d['strasse']} ${d['hausnummer']}, ${d['plz']} ${d['ort']}', gestapelt: telefon),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.phone, l.phone, d['telefon'] ?? '-', gestapelt: telefon),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.fax, l.faxLabel, d['fax'] ?? '-', gestapelt: telefon),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.email, l.email, d['email'] ?? '-', gestapelt: telefon),
                  const SizedBox(height: 16),
                  // Action button
                  if (d['website'] != null)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: Text(l.openWebsite),
                        onPressed: () => _openUrl(d['website']),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Vereinsdaten Card (from Vereineinstellungen)
          if (hasVereinData) ...[
            const SizedBox(height: 20),
            Card(
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
                          child: const Icon(Icons.business, color: Colors.teal, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l.vereinsdatenTitle,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.edit, size: 20, color: Colors.teal.shade700),
                          onPressed: _showSettingsDialog,
                          tooltip: l.edit,
                        ),
                      ],
                    ),
                    const Divider(height: 28),
                    // Vereinsdaten fields
                    if ((ve['vereinsname'] ?? '').toString().trim().isNotEmpty)
                      _buildInfoRow(Icons.business, l.name, ve['vereinsname'].toString(), gestapelt: telefon),
                    if ((ve['adresse'] ?? '').toString().trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildInfoRow(Icons.location_on, l.address, ve['adresse'].toString(), gestapelt: telefon),
                    ],
                    if ((ve['telefon_fix'] ?? '').toString().trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildInfoRow(Icons.phone, l.phone, ve['telefon_fix'].toString(), gestapelt: telefon),
                    ],
                    if ((ve['fax'] ?? '').toString().trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildInfoRow(Icons.fax, l.faxLabel, ve['fax'].toString(), gestapelt: telefon),
                    ],
                    if ((ve['mobil'] ?? '').toString().trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildInfoRow(Icons.phone_android, l.mobilePhone, ve['mobil'].toString(), gestapelt: telefon),
                    ],
                    if ((ve['email'] ?? '').toString().trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildInfoRow(Icons.email, l.email, ve['email'].toString(), gestapelt: telefon),
                    ],
                    if ((ve['gruendungsdatum'] ?? '').toString().trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildInfoRow(Icons.calendar_month, l.foundingLabel, ve['gruendungsdatum'].toString(), gestapelt: telefon),
                    ],
                  ],
                ),
              ),
            ),
          ],

          // Hint if no Vereinsdaten
          if (!hasVereinData) ...[
            const SizedBox(height: 20),
            Card(
              color: Colors.grey.shade50,
              child: InkWell(
                onTap: _showSettingsDialog,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline, size: 32, color: Colors.grey.shade400),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.addVereinsdaten,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l.enterVereinsdaten,
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool gestapelt = false}) {
    // Telefon: Bezeichnung über dem Wert statt in einer 70-dp-Spalte daneben —
    // sonst brächen lange Werte (E-Mail-Adressen) auf 320 dp mitten im Wort.
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
          width: 70,
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
