import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:archive/archive.dart' as archive;
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../services/logger_service.dart';

final _log = LoggerService();

/// Archive screen for storing encrypted WhatsApp conversations and other records
class ArchivScreen extends StatefulWidget {
  final ApiService apiService;
  final List<User> users;

  const ArchivScreen({super.key, required this.apiService, required this.users});

  @override
  State<ArchivScreen> createState() => _ArchivScreenState();
}

class _ArchivScreenState extends State<ArchivScreen> {
  List<Map<String, dynamic>> _archives = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadArchives();
  }

  Future<void> _loadArchives() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await widget.apiService.getArchives();

      if (result['success'] == true) {
        final list = result['archives'] as List? ?? [];
        setState(() {
          _archives = list.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = result['message']?.toString() ?? tr('Fehler beim Laden', 'Eroare la încărcare');
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = tr('Verbindungsfehler: $e', 'Eroare de conexiune: $e');
        _isLoading = false;
      });
      _log.error('Archiv: Load failed: $e', tag: 'ARCHIV');
    }
  }

  Future<void> _uploadArchive() async {
    // Show dialog to get metadata first
    final metadata = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => _UploadDialog(users: widget.users),
    );

    if (metadata == null) return;

    // Pick files
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['txt', 'pdf', 'jpg', 'jpeg', 'png', 'zip'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      for (final file in result.files) {
        if (file.bytes == null) continue;

        final base64Data = base64Encode(file.bytes!);

        final uploadResult = await widget.apiService.uploadArchive(
          personName: metadata['person_name'] ?? '',
          mitgliedernummer: metadata['mitgliedernummer'],
          titel: metadata['titel'] ?? '',
          beschreibung: metadata['beschreibung'] ?? '',
          kategorie: metadata['kategorie'] ?? 'whatsapp',
          originalFilename: file.name,
          filesize: file.size,
          data: base64Data,
        );

        if (uploadResult['success'] != true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(tr('Fehler: ${uploadResult['message']}', 'Eroare: ${uploadResult['message']}')),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }

      await _loadArchives();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('${result.files.length} Datei(en) erfolgreich archiviert',
                'Fișiere arhivate cu succes: ${result.files.length}')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _log.error('Archiv: Upload failed: $e', tag: 'ARCHIV');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Upload fehlgeschlagen: $e', 'Încărcare eșuată: $e')), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _viewArchive(Map<String, dynamic> archive) async {
    try {
      final result = await widget.apiService.downloadArchive(
        int.parse(archive['id'].toString()),
      );

      if (result['success'] == true && result['data'] != null) {
        final bytes = Uint8List.fromList(base64Decode(result['data']));
        final filename = result['filename']?.toString() ?? 'archiv_download';

        // Show in-memory viewer — file NEVER touches disk
        if (mounted) {
          await showDialog(
            context: context,
            builder: (ctx) => _SecureFileViewer(
              filename: filename,
              bytes: bytes,
              titel: archive['titel']?.toString() ?? filename,
            ),
          );
        }
        // After dialog closes, bytes are garbage collected — nothing on disk
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('Anzeige fehlgeschlagen: ${result['message']}', 'Afișare eșuată: ${result['message']}')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      _log.error('Archiv: View failed: $e', tag: 'ARCHIV');
    }
  }

  Future<void> _downloadArchive(Map<String, dynamic> archive) async {
    try {
      final result = await widget.apiService.downloadArchive(
        int.parse(archive['id'].toString()),
      );

      if (result['success'] == true && result['data'] != null) {
        final bytes = base64Decode(result['data']);
        final filename = result['filename']?.toString() ?? 'archiv_download';

        final savePath = await FilePicker.platform.saveFile(
          dialogTitle: tr('Archiv speichern', 'Salvează arhiva'),
          fileName: filename,
        );

        if (savePath != null) {
          final file = File(savePath);
          await file.writeAsBytes(bytes);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(tr('Datei gespeichert', 'Fișier salvat')), backgroundColor: Colors.green),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('Download fehlgeschlagen: ${result['message']}', 'Descărcare eșuată: ${result['message']}')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      _log.error('Archiv: Download failed: $e', tag: 'ARCHIV');
    }
  }

  Future<void> _deleteArchive(Map<String, dynamic> archive) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Archiv löschen', 'Șterge arhiva')),
        content: Text(tr('Möchten Sie "${archive['titel']}" wirklich löschen?\n\nDiese Aktion kann nicht rückgängig gemacht werden.',
            'Sigur doriți să ștergeți „${archive['titel']}”?\n\nAceastă acțiune nu poate fi anulată.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Abbrechen', 'Anulare'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('Löschen', 'Șterge'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final result = await widget.apiService.deleteArchive(
        int.parse(archive['id'].toString()),
      );

      if (result['success'] == true) {
        await _loadArchives();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('Archiv gelöscht', 'Arhivă ștearsă')), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      _log.error('Archiv: Delete failed: $e', tag: 'ARCHIV');
    }
  }

  List<Map<String, dynamic>> get _filteredArchives {
    if (_searchQuery.isEmpty) return _archives;
    final q = _searchQuery.toLowerCase();
    return _archives.where((a) {
      return (a['person_name']?.toString().toLowerCase().contains(q) ?? false) ||
          (a['mitgliedernummer']?.toString().toLowerCase().contains(q) ?? false) ||
          (a['titel']?.toString().toLowerCase().contains(q) ?? false) ||
          (a['beschreibung']?.toString().toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Entschieden wird nach der Breite, die der Bildschirm wirklich bekommt
    // (auf dem Schreibtisch nimmt die Seitenleiste ihren Teil), nicht nach
    // MediaQuery. Unter 600 dp: Telefon.
    return LayoutBuilder(
      builder: (context, constraints) => _aufbau(schmal: constraints.maxWidth < 600),
    );
  }

  Widget _aufbau({required bool schmal}) {
    final df = DateFormat('dd.MM.yyyy HH:mm', 'de_DE');
    final titel = Row(
      children: [
        Icon(Icons.archive, color: Colors.indigo.shade700, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('Archiv', 'Arhivă'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Text(
                tr('Verschlüsselte Aufbewahrung von WhatsApp-Chats und Dokumenten',
                    'Păstrare criptată a conversațiilor WhatsApp și a documentelor'),
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
    final hochladen = ElevatedButton.icon(
      onPressed: _uploadArchive,
      icon: const Icon(Icons.upload_file),
      label: Text(tr('Hochladen', 'Încarcă')),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
    );

    // Content: Laden, Fehler oder leer — sonst die Liste.
    final Widget? zustand = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _loadArchives, child: Text(tr('Erneut versuchen', 'Încearcă din nou'))),
                  ],
                ),
              )
            : _filteredArchives.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.archive_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? tr('Noch keine Archive vorhanden', 'Încă nu există arhive')
                              : tr('Keine Ergebnisse', 'Niciun rezultat'),
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
                        ),
                        if (_searchQuery.isEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            tr('Laden Sie WhatsApp-Chats oder Dokumente hoch', 'Încărcați conversații WhatsApp sau documente'),
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                          ),
                        ],
                      ],
                    ),
                  )
                : null;
    Widget karte(BuildContext context, int index) =>
        _buildArchiveCard(_filteredArchives[index], df, schmal: schmal);

    final kopf = <Widget>[
      // Header — auf dem Telefon steht „Hochladen“ unter dem Titel:
      // daneben blieben der Unterzeile keine 80 dp, und
      // „conversațiilor“ brach mitten im Wort.
      if (schmal) ...[
        titel,
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: hochladen),
      ] else
        Row(
          children: [
            Expanded(child: titel),
            hochladen,
          ],
        ),
      const SizedBox(height: 16),

      // Stats bar
      _buildStatsBar(schmal: schmal),
      const SizedBox(height: 16),

      // Search
      TextField(
        decoration: InputDecoration(
          hintText: tr('Suchen nach Person, Titel...', 'Căutare după persoană, titlu...'),
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onChanged: (v) => setState(() => _searchQuery = v),
      ),
      const SizedBox(height: 16),
    ];

    if (schmal) {
      // Telefon: Kopf, Kennzahlen und Suche rollen mit der Liste. Fest
      // stehend ließen sie auf 320×640 dp kaum Platz für eine Karte.
      return CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverList.list(children: kopf),
          ),
          if (zustand != null)
            SliverFillRemaining(hasScrollBody: false, child: zustand)
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverList.builder(
                itemCount: _filteredArchives.length,
                itemBuilder: karte,
              ),
            ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...kopf,

          // Content
          Expanded(
            child: zustand ??
                ListView.builder(
                  itemCount: _filteredArchives.length,
                  itemBuilder: karte,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar({required bool schmal}) {
    final total = _archives.length;
    final whatsapp = _archives.where((a) => a['kategorie'] == 'whatsapp').length;
    final dokumente = _archives.where((a) => a['kategorie'] == 'dokument').length;
    final sonstige = total - whatsapp - dokumente;
    final totalSize = _archives.fold<int>(0, (sum, a) => sum + (int.tryParse(a['filesize']?.toString() ?? '0') ?? 0));

    if (schmal) {
      // Fünf Kennzahlen nebeneinander ließen auf dem Telefon je ~50 dp:
      // „Verschlüsselt“ und „Dokumente“ brachen mitten im Wort. Hier drei
      // je Zeile, darunter die übrigen zwei.
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.indigo.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.indigo.shade100),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final breite = (constraints.maxWidth - 2 * 8) / 3;
            Widget feld(IconData icon, String value, String label) =>
                SizedBox(width: breite, child: _statInhalt(icon, value, label));
            return Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 12,
              children: [
                feld(Icons.archive, '$total', tr('Gesamt', 'Total')),
                feld(Icons.chat, '$whatsapp', 'WhatsApp'),
                feld(Icons.description, '$dokumente', tr('Dokumente', 'Documente')),
                feld(Icons.folder, '$sonstige', tr('Sonstiges', 'Altele')),
                feld(Icons.lock, _formatSize(totalSize), tr('Verschlüsselt', 'Criptat')),
              ],
            );
          },
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.shade100),
      ),
      child: Row(
        children: [
          _statItem(Icons.archive, '$total', tr('Gesamt', 'Total')),
          _statDivider(),
          _statItem(Icons.chat, '$whatsapp', 'WhatsApp'),
          _statDivider(),
          _statItem(Icons.description, '$dokumente', tr('Dokumente', 'Documente')),
          _statDivider(),
          _statItem(Icons.folder, '$sonstige', tr('Sonstiges', 'Altele')),
          _statDivider(),
          _statItem(Icons.lock, _formatSize(totalSize), tr('Verschlüsselt', 'Criptat')),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String value, String label) {
    return Expanded(
      child: _statInhalt(icon, value, label),
    );
  }

  Widget _statInhalt(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.indigo.shade700, size: 20),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade700)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _statDivider() {
    return Container(width: 1, height: 40, color: Colors.indigo.shade100);
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _buildArchiveCard(Map<String, dynamic> archive, DateFormat df, {required bool schmal}) {
    final kategorie = archive['kategorie']?.toString() ?? 'sonstiges';
    final isEncrypted = archive['is_encrypted'] == 1 || archive['is_encrypted'] == true;

    IconData catIcon;
    Color catColor;
    switch (kategorie) {
      case 'whatsapp':
        catIcon = Icons.chat;
        catColor = Colors.green.shade700;
        break;
      case 'dokument':
        catIcon = Icons.description;
        catColor = Colors.blue.shade700;
        break;
      default:
        catIcon = Icons.folder;
        catColor = Colors.orange.shade700;
    }

    DateTime? createdAt;
    try {
      createdAt = DateTime.parse(archive['created_at']?.toString() ?? '');
    } catch (_) {}

    // Category icon
    final symbol = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: catColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        children: [
          Center(child: Icon(catIcon, color: catColor, size: 24)),
          if (isEncrypted)
            Positioned(
              right: 0,
              bottom: 0,
              child: Icon(Icons.lock, size: 12, color: Colors.green.shade700),
            ),
        ],
      ),
    );
    final titel = Text(
      archive['titel']?.toString() ?? tr('Kein Titel', 'Fără titlu'),
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      overflow: TextOverflow.ellipsis,
      maxLines: schmal ? 2 : null,
    );
    final katChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: catColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        kategorie == 'whatsapp'
            ? 'WhatsApp'
            : kategorie == 'dokument'
                ? tr('Dokument', 'Document')
                : tr('Sonstiges', 'Altele'),
        style: TextStyle(fontSize: 11, color: catColor, fontWeight: FontWeight.w500),
      ),
    );
    final hatNummer = archive['mitgliedernummer'] != null && archive['mitgliedernummer'].toString().isNotEmpty;
    // Name und Dateiname sind Flexible: mit langen Werten lief die Zeile auf
    // dem Tablet (800 dp) um 167 dp hinaus. Passt alles, ändert das nichts.
    final person = [
      Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          archive['person_name']?.toString() ?? '-',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      if (hatNummer) ...[
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            archive['mitgliedernummer'].toString(),
            style: TextStyle(fontSize: 11, color: Colors.blue.shade700, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ];
    final datei = [
      Icon(Icons.attach_file, size: 14, color: Colors.grey.shade600),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          archive['original_filename']?.toString() ?? '-',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      const SizedBox(width: 8),
      Text(
        _formatSize(int.tryParse(archive['filesize']?.toString() ?? '0') ?? 0),
        style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
      ),
    ];
    final beschreibung = archive['beschreibung'] != null && archive['beschreibung'].toString().isNotEmpty
        ? Text(
            archive['beschreibung'].toString(),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          )
        : null;
    final datum = Text(
      createdAt != null ? df.format(createdAt) : '-',
      style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
    );
    final knoepfe = [
      IconButton(
        icon: const Icon(Icons.visibility, size: 20),
        tooltip: tr('Anzeigen (nur im Speicher)', 'Afișează (doar în memorie)'),
        onPressed: () => _viewArchive(archive),
        color: Colors.green.shade700,
      ),
      IconButton(
        icon: const Icon(Icons.download, size: 20),
        tooltip: tr('Herunterladen', 'Descarcă'),
        onPressed: () => _downloadArchive(archive),
        color: Colors.indigo,
      ),
      IconButton(
        icon: const Icon(Icons.delete_outline, size: 20),
        tooltip: tr('Löschen', 'Șterge'),
        onPressed: () => _deleteArchive(archive),
        color: Colors.red.shade400,
      ),
    ];

    if (schmal) {
      // Telefon: Person und Datei je in eigener Zeile, die Knöpfe unten
      // neben dem Datum. In einer Zeile mit Mitgliedsnummer, Dateiname und
      // Größe lief die Karte auf 320 dp um über 600 dp hinaus.
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    symbol,
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [titel, const SizedBox(height: 4), katChip],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(children: person),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(children: datei),
              ),
              if (beschreibung != null) ...[
                const SizedBox(height: 4),
                beschreibung,
              ],
              Row(
                children: [
                  Expanded(child: datum),
                  ...knoepfe,
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            symbol,
            const SizedBox(width: 14),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: titel),
                      katChip,
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      ...person,
                      const SizedBox(width: 16),
                      ...datei,
                    ],
                  ),
                  if (beschreibung != null) ...[
                    const SizedBox(height: 4),
                    beschreibung,
                  ],
                  const SizedBox(height: 6),
                  datum,
                ],
              ),
            ),
            // Actions
            Column(
              children: knoepfe,
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// UPLOAD DIALOG
// ══════════════════════════════════════════════════════════════

class _UploadDialog extends StatefulWidget {
  final List<User> users;

  const _UploadDialog({required this.users});

  @override
  State<_UploadDialog> createState() => _UploadDialogState();
}

class _UploadDialogState extends State<_UploadDialog> {
  final _titelCtrl = TextEditingController();
  final _beschreibungCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  String _kategorie = 'whatsapp';
  User? _selectedUser;
  List<User> _filteredUsers = [];

  @override
  void initState() {
    super.initState();
    _filteredUsers = widget.users;
  }

  @override
  void dispose() {
    _titelCtrl.dispose();
    _beschreibungCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filterUsers(String query) {
    final q = query.toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredUsers = widget.users;
      } else {
        _filteredUsers = widget.users.where((u) {
          return u.name.toLowerCase().contains(q) ||
              u.mitgliedernummer.toLowerCase().contains(q) ||
              u.email.toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Telefon: 16 statt 40 dp Rand. Mit 40 dp blieben dem Formular auf
    // 320 dp nur 192 dp — Titel und Kategorie liefen hinaus, und von den
    // Namen in der Mitgliederliste blieben drei Buchstaben.
    final schmal = MediaQuery.sizeOf(context).width < 600;
    return AlertDialog(
      insetPadding: schmal ? const EdgeInsets.symmetric(horizontal: 16, vertical: 24) : null,
      title: Row(
        children: [
          Icon(Icons.upload_file, color: Colors.indigo.shade700),
          const SizedBox(width: 8),
          Expanded(child: Text(tr('Archiv hochladen', 'Încarcă arhivă'))),
        ],
      ),
      content: SizedBox(
        width: 480,
        height: 520,
        // Rollbar: auf 320×640 dp ist der Dialog niedriger als die 520 dp
        // des Formulars, unten lief es um 154 dp hinaus.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Info box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock, color: Colors.green.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tr('Dateien werden AES-256 verschlüsselt auf dem Server gespeichert.',
                            'Fișierele sunt stocate pe server, criptate cu AES-256.'),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Member selector
              Align(
                alignment: Alignment.centerLeft,
                child: Text(tr('Mitglied auswählen *', 'Selectați membrul *'),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: tr('Suchen nach Name, Nummer...', 'Căutare după nume, număr...'),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  isDense: true,
                ),
                onChanged: _filterUsers,
              ),
              const SizedBox(height: 6),
              Container(
                height: 130,
                decoration: BoxDecoration(
                  border: Border.all(color: _selectedUser == null ? Colors.grey.shade300 : Colors.indigo.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: _filteredUsers.length,
                  itemBuilder: (ctx, i) {
                    final user = _filteredUsers[i];
                    final isSelected = _selectedUser?.id == user.id;
                    return InkWell(
                      onTap: () => setState(() => _selectedUser = user),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        color: isSelected ? Colors.indigo.shade50 : null,
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                              size: 18,
                              color: isSelected ? Colors.indigo.shade700 : Colors.grey.shade400,
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                user.mitgliedernummer,
                                style: TextStyle(fontSize: 11, color: Colors.blue.shade700, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                user.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              user.role,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (_selectedUser != null) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${_selectedUser!.name} (${_selectedUser!.mitgliedernummer})',
                    style: TextStyle(fontSize: 12, color: Colors.indigo.shade700, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
              const SizedBox(height: 12),

              TextField(
                controller: _titelCtrl,
                decoration: InputDecoration(
                  labelText: tr('Titel *', 'Titlu *'),
                  hintText: tr('z.B. WhatsApp Chat mit Max Mustermann', 'de ex. Chat WhatsApp cu Ion Popescu'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.title),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _kategorie,
                decoration: InputDecoration(
                  labelText: tr('Kategorie', 'Categorie'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.category),
                ),
                items: [
                  DropdownMenuItem(value: 'whatsapp', child: Text(tr('WhatsApp Chat', 'Chat WhatsApp'))),
                  DropdownMenuItem(value: 'dokument', child: Text(tr('Dokument', 'Document'))),
                  DropdownMenuItem(value: 'sonstiges', child: Text(tr('Sonstiges', 'Altele'))),
                ],
                onChanged: (v) => setState(() => _kategorie = v ?? 'whatsapp'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _beschreibungCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: tr('Beschreibung', 'Descriere'),
                  hintText: tr('Warum wird dieses Archiv aufbewahrt?', 'De ce este păstrată această arhivă?'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.notes),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('Abbrechen', 'Anulare')),
        ),
        ElevatedButton.icon(
          onPressed: () {
            if (_selectedUser == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(tr('Bitte wählen Sie ein Mitglied aus', 'Vă rugăm selectați un membru')),
                    backgroundColor: Colors.red),
              );
              return;
            }
            if (_titelCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(tr('Titel ist erforderlich', 'Titlul este obligatoriu')),
                    backgroundColor: Colors.red),
              );
              return;
            }
            Navigator.pop(context, {
              'person_name': _selectedUser!.name,
              'mitgliedernummer': _selectedUser!.mitgliedernummer,
              'titel': _titelCtrl.text.trim(),
              'beschreibung': _beschreibungCtrl.text.trim(),
              'kategorie': _kategorie,
            });
          },
          icon: const Icon(Icons.check),
          label: Text(tr('Weiter — Dateien auswählen', 'Continuă — selectați fișierele')),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo.shade700,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SECURE IN-MEMORY FILE VIEWER — file NEVER touches disk
// ══════════════════════════════════════════════════════════════

class _SecureFileViewer extends StatefulWidget {
  final String filename;
  final Uint8List bytes;
  final String titel;

  const _SecureFileViewer({
    required this.filename,
    required this.bytes,
    required this.titel,
  });

  @override
  State<_SecureFileViewer> createState() => _SecureFileViewerState();
}

class _SecureFileViewerState extends State<_SecureFileViewer> {
  String get _ext => _activeFilename.split('.').last.toLowerCase();

  bool get _isImage => ['jpg', 'jpeg', 'png', 'bmp', 'gif', 'webp'].contains(_ext);
  bool get _isTxt => ['txt', 'html', 'htm', 'css', 'js', 'json', 'xml', 'csv', 'log', 'md'].contains(_ext);
  bool get _isPdf => _ext == 'pdf';
  bool get _isZip => ['zip'].contains(widget.filename.split('.').last.toLowerCase());

  // ZIP navigation state
  List<archive.ArchiveFile>? _zipFiles;
  archive.ArchiveFile? _selectedZipFile;
  Uint8List? _selectedFileBytes;
  String _activeFilename = '';
  String _zipSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _activeFilename = widget.filename;
    if (_isZip) {
      _extractZip();
    }
  }

  void _extractZip() {
    try {
      final decoded = archive.ZipDecoder().decodeBytes(widget.bytes);
      setState(() {
        _zipFiles = decoded.files.where((f) => !f.isFile || f.size > 0).toList()
          ..sort((a, b) {
            // Folders first, then by name
            if (a.isFile != b.isFile) return a.isFile ? 1 : -1;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
      });
    } catch (e) {
      debugPrint('ZIP extract error: $e');
    }
  }

  void _openZipFile(archive.ArchiveFile file) {
    if (!file.isFile) return;
    setState(() {
      _selectedZipFile = file;
      _selectedFileBytes = Uint8List.fromList(file.content as List<int>);
      _activeFilename = file.name.split('/').last;
    });
  }

  void _backToZipList() {
    setState(() {
      _selectedZipFile = null;
      _selectedFileBytes = null;
      _activeFilename = widget.filename;
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayTitle = _selectedZipFile != null
        ? _selectedZipFile!.name.split('/').last
        : widget.titel;
    final displaySubtitle = _selectedZipFile != null
        ? '${widget.filename} → ${_selectedZipFile!.name}'
        : tr('${widget.filename} — Nur im Speicher (nicht auf der Festplatte)',
            '${widget.filename} — doar în memorie (nu pe disc)');

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 900,
        height: 650,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.indigo.shade700,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  if (_selectedZipFile != null) ...[
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                      onPressed: _backToZipList,
                      tooltip: tr('Zurück zur Dateiliste', 'Înapoi la lista de fișiere'),
                    ),
                  ] else
                    const Icon(Icons.lock, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayTitle,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          displaySubtitle,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.shade600,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text('AES-256', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                    tooltip: tr('Schließen (Daten werden aus dem Speicher gelöscht)', 'Închide (datele sunt șterse din memorie)'),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: _buildContent(),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      tr('Diese Datei existiert nur im Arbeitsspeicher. Beim Schließen wird sie vollständig gelöscht.',
                          'Acest fișier există doar în memoria RAM. La închidere este șters complet.'),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    // ZIP file: show file list or selected file content
    if (_isZip && _selectedZipFile == null) {
      return _buildZipViewer();
    }

    // Use selected file bytes if viewing a ZIP entry
    final viewBytes = _selectedFileBytes ?? widget.bytes;

    if (_isTxt) {
      return _buildTextViewer(viewBytes);
    } else if (_isImage) {
      return _buildImageViewer(viewBytes);
    } else if (_isPdf) {
      return _buildPdfViewer(viewBytes);
    } else {
      return _buildUnsupportedViewer();
    }
  }

  Widget _buildZipViewer() {
    if (_zipFiles == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _zipSearchQuery.isEmpty
        ? _zipFiles!
        : _zipFiles!.where((f) => f.name.toLowerCase().contains(_zipSearchQuery.toLowerCase())).toList();

    final files = filtered.where((f) => f.isFile).toList();
    final totalSize = files.fold<int>(0, (sum, f) => sum + f.size);

    return Column(
      children: [
        // Search + stats bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey.shade50,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final symbol = Icon(Icons.folder_zip, color: Colors.orange.shade700, size: 20);
              final anzahl = Text(
                tr('${files.length} Dateien — ${_formatSize(totalSize)}',
                    'Fișiere: ${files.length} — ${_formatSize(totalSize)}'),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
              );
              final suche = TextField(
                onChanged: (v) => setState(() => _zipSearchQuery = v),
                decoration: InputDecoration(
                  hintText: tr('Datei suchen...', 'Caută fișier...'),
                  hintStyle: const TextStyle(fontSize: 12),
                  prefixIcon: const Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 12),
              );
              // Telefon: das 250 dp breite Suchfeld steht unter der Anzahl —
              // daneben lief die Leiste im Betrachter hinaus.
              if (constraints.maxWidth < 500) {
                return Column(
                  children: [
                    Row(
                      children: [
                        symbol,
                        const SizedBox(width: 8),
                        Expanded(child: anzahl),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(height: 34, child: suche),
                  ],
                );
              }
              return Row(
                children: [
                  symbol,
                  const SizedBox(width: 8),
                  anzahl,
                  const Spacer(),
                  SizedBox(
                    width: 250,
                    height: 34,
                    child: suche,
                  ),
                ],
              );
            },
          ),
        ),
        const Divider(height: 1),
        // File list — mit eigenem Material: sonst zeichnete der weiße Kasten
        // des Betrachters über die Tintenwelle der Einträge (Flutter meldet
        // das als Fehler).
        Expanded(
          child: Material(
            type: MaterialType.transparency,
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (ctx, i) {
                final file = filtered[i];
                final name = file.name;
                final ext = name.split('.').last.toLowerCase();
                final isDir = !file.isFile;
                final icon = isDir
                    ? Icons.folder
                    : _fileIcon(ext);
                final color = isDir
                    ? Colors.amber.shade700
                    : _fileColor(ext);

                return ListTile(
                  dense: true,
                  leading: Icon(icon, size: 22, color: color),
                  title: Text(
                    name.split('/').last.isEmpty ? name : name.split('/').last,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isDir ? FontWeight.w600 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: isDir
                      ? null
                      : Text(
                          _formatSize(file.size),
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                  trailing: file.isFile
                      ? Icon(Icons.open_in_new, size: 16, color: Colors.grey.shade400)
                      : null,
                  onTap: file.isFile ? () => _openZipFile(file) : null,
                  hoverColor: Colors.indigo.shade50,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  IconData _fileIcon(String ext) {
    if (['jpg', 'jpeg', 'png', 'bmp', 'gif', 'webp'].contains(ext)) return Icons.image;
    if (ext == 'pdf') return Icons.picture_as_pdf;
    if (['txt', 'log', 'md', 'csv'].contains(ext)) return Icons.description;
    if (['html', 'htm'].contains(ext)) return Icons.code;
    if (['mp4', 'avi', 'mov', 'mkv'].contains(ext)) return Icons.videocam;
    if (['mp3', 'wav', 'ogg', 'opus', 'm4a'].contains(ext)) return Icons.audiotrack;
    if (['doc', 'docx'].contains(ext)) return Icons.article;
    if (['xls', 'xlsx'].contains(ext)) return Icons.table_chart;
    if (['zip', 'rar', '7z'].contains(ext)) return Icons.folder_zip;
    return Icons.insert_drive_file;
  }

  Color _fileColor(String ext) {
    if (['jpg', 'jpeg', 'png', 'bmp', 'gif', 'webp'].contains(ext)) return Colors.green.shade700;
    if (ext == 'pdf') return Colors.red.shade700;
    if (['txt', 'log', 'md', 'csv'].contains(ext)) return Colors.blue.shade700;
    if (['html', 'htm'].contains(ext)) return Colors.orange.shade700;
    if (['mp4', 'avi', 'mov', 'mkv'].contains(ext)) return Colors.purple.shade700;
    if (['mp3', 'wav', 'ogg', 'opus', 'm4a'].contains(ext)) return Colors.pink.shade700;
    return Colors.grey.shade600;
  }

  Widget _buildTextViewer(Uint8List viewBytes) {
    String text;
    try {
      text = utf8.decode(viewBytes);
    } catch (_) {
      text = latin1.decode(viewBytes);
    }

    return Container(
      color: Colors.grey.shade50,
      child: SelectionArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageViewer(Uint8List viewBytes) {
    return Container(
      color: Colors.grey.shade200,
      child: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.memory(
            viewBytes,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildPdfViewer(Uint8List viewBytes) {
    return PdfViewer.data(viewBytes, sourceName: _activeFilename);
  }

  Widget _buildUnsupportedViewer() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            tr('Vorschau für .$_ext nicht verfügbar', 'Previzualizare indisponibilă pentru .$_ext'),
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            tr('Dateityp: $_ext | Größe: ${_formatSize(_selectedFileBytes?.length ?? widget.bytes.length)}',
                'Tip fișier: $_ext | Dimensiune: ${_formatSize(_selectedFileBytes?.length ?? widget.bytes.length)}'),
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
          Text(
            tr('Die Datei ist im Speicher entschlüsselt, kann aber nicht angezeigt werden.',
                'Fișierul este decriptat în memorie, dar nu poate fi afișat.'),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
