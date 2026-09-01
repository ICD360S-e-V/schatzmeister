import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/verwarnung_service.dart';
import '../services/dokumente_service.dart';
import 'mitglieder_device.dart';
import '../services/termin_service.dart';
import '../models/user.dart';
import '../utils/role_helpers.dart';
import '../screens/ordnungsmassnahmen_screen.dart';
import '../l10n/app_localizations.dart';
import 'file_viewer_dialog.dart';

class UserDetailsDialog extends StatefulWidget {
  final User user;
  final ApiService apiService;
  final VoidCallback onUpdated;
  final String adminMitgliedernummer;

  const UserDetailsDialog({
    super.key,
    required this.user,
    required this.apiService,
    required this.onUpdated,
    required this.adminMitgliedernummer,
  });

  @override
  State<UserDetailsDialog> createState() => _UserDetailsDialogState();
}

class _UserDetailsDialogState extends State<UserDetailsDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _sessions = [];
  List<Map<String, dynamic>> _devices = [];

  // Verwarnungen
  final _verwarnungService = VerwarnungService();
  List<Verwarnung> _verwarnungen = [];
  VerwarnungStats? _verwarnungStats;
  bool _isLoadingVerwarnungen = false;
  bool _isSubmittingWarning = false;
  final _sachverhaltVerwarnungController = TextEditingController();
  VerstossKategorie? _selectedVerstossKat;
  Massnahme? _selectedMassnahmeTyp;
  final _ordnungsgeldBetragController = TextEditingController(text: '50');
  DateTime _selectedDatum = DateTime.now();

  // Dokumente
  final _dokumenteService = DokumenteService();
  List<MemberDokument> _dokumente = [];
  bool _isLoadingDokumente = false;
  bool _isUploadingDokument = false;

  // Edit controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'vorsitzer';

  // Verifizierung
  List<Map<String, dynamic>> _verifizierungStages = [];
  bool _isLoadingVerifizierung = false;
  bool _isUpdatingVerifizierung = false;
  String? _verifizierungFinanzielleSituation;
  Map<String, String?> _verifizierungAcceptances = {};

  // Befreiung
  List<Map<String, dynamic>> _befreiungen = [];
  bool _isBefreit = false;
  bool _isLoadingBefreiung = false;

  // Ermäßigung
  List<Map<String, dynamic>> _ermaessigungen = [];
  bool _isLoadingErmaessigung = false;

  // Notizen
  List<Map<String, dynamic>> _notizen = [];
  bool _isLoadingNotizen = false;
  final _notizController = TextEditingController();
  String _notizKategorie = 'allgemein';
  bool _notizWichtig = false;


  // Termine
  final _terminService = TerminService();
  List<Termin> _memberTermine = [];
  bool _isLoadingTermine = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 9, vsync: this);
    _nameController.text = widget.user.name;
    _emailController.text = widget.user.email;
    _selectedRole = widget.user.role;
    _verwarnungService.setToken(widget.apiService.token);
    _dokumenteService.setToken(widget.apiService.token);
    _terminService.setToken(widget.apiService.token);
    _loadUserDetails();
    _loadVerwarnungen();
    _loadDokumente();
    _loadVerifizierung();
    _loadBefreiungen();
    _loadErmaessigungen();
    _loadNotizen();
    _loadMemberTermine();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _sachverhaltVerwarnungController.dispose();
    _ordnungsgeldBetragController.dispose();
    _notizController.dispose();
    super.dispose();
  }

  Future<void> _loadUserDetails() async {
    try {
      final result = await widget.apiService.getUserDetails(widget.user.id);

      if (result['success'] == true && mounted) {
        setState(() {
          _sessions = List<Map<String, dynamic>>.from(result['sessions'] ?? []);
          _devices = List<Map<String, dynamic>>.from(result['devices'] ?? []);
          _isLoading = false;
        });
      } else {
        if (mounted) {
          final l = AppLocalizations.of(context);
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l.errorLoading(result['message'] ?? 'Unknown error')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final l = AppLocalizations.of(context);
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.connectionErrorWith2('$e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveChanges() async {
    String? newName = _nameController.text.trim() != widget.user.name ? _nameController.text.trim() : null;
    String? newEmail = _emailController.text.trim() != widget.user.email ? _emailController.text.trim() : null;
    String? newPassword = _passwordController.text.isNotEmpty ? _passwordController.text : null;
    String? newRole = _selectedRole != widget.user.role ? _selectedRole : null;

    final l = AppLocalizations.of(context);

    if (newName == null && newEmail == null && newPassword == null && newRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.noChanges)),
      );
      return;
    }

    try {
      final result = await widget.apiService.updateUser(
        userId: widget.user.id,
        name: newName,
        email: newEmail,
        password: newPassword,
        role: newRole,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.userUpdatedSuccess),
            backgroundColor: Colors.green,
          ),
        );
        widget.onUpdated();
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? l.errorUpdating),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.errorWith('$e')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _revokeSession(int sessionId) async {
    try {
      final result = await widget.apiService.revokeSession(sessionId);

      if (!mounted) return;

      final l = AppLocalizations.of(context);
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.sessionRevoked),
            backgroundColor: Colors.green,
          ),
        );
        _loadUserDetails(); // Reload sessions
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.errorWith(result['message'] ?? 'Unknown error')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.connectionErrorWith2('$e')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadVerwarnungen() async {
    setState(() => _isLoadingVerwarnungen = true);
    _verwarnungService.setToken(widget.apiService.token);
    final result = await _verwarnungService.getVerwarnungen(widget.user.id);
    if (mounted) {
      setState(() {
        if (result != null) {
          _verwarnungen = result.warnings;
          _verwarnungStats = result.stats;
        }
        _isLoadingVerwarnungen = false;
      });
    }
  }

  Future<void> _createVerwarnung() async {
    final l = AppLocalizations.of(context);
    if (_selectedVerstossKat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.pleaseSelectViolationCategory), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_selectedMassnahmeTyp == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.pleaseSelectMeasure), backgroundColor: Colors.orange),
      );
      return;
    }
    final sachverhalt = _sachverhaltVerwarnungController.text.trim();
    if (sachverhalt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.pleaseDescribeFacts), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSubmittingWarning = true);
    _verwarnungService.setToken(widget.apiService.token);

    // Map Massnahme id to legacy typ for backend
    String typ;
    switch (_selectedMassnahmeTyp!.id) {
      case 'verwarnung':
        typ = 'ermahnung';
        break;
      case 'ordnungsgeld':
        typ = 'abmahnung';
        break;
      case 'ausschluss':
        typ = 'letzte_abmahnung';
        break;
      default:
        typ = 'ermahnung';
    }

    final grund = '${_selectedVerstossKat!.titel} (${_selectedVerstossKat!.paragraph})';

    final result = await _verwarnungService.createVerwarnung(
      userId: widget.user.id,
      typ: typ,
      grund: grund,
      beschreibung: sachverhalt,
      datum: DateFormat('yyyy-MM-dd').format(_selectedDatum),
    );

    if (!mounted) return;

    setState(() => _isSubmittingWarning = false);

    if (result != null) {
      // Generate PDF
      final ordnungsgeld = _selectedMassnahmeTyp!.id == 'ordnungsgeld'
          ? _ordnungsgeldBetragController.text.trim()
          : null;

      final pdfResult = await VerwarnungPdfGenerator.generate(
        userName: widget.user.name,
        mitgliedernummer: widget.user.mitgliedernummer,
        massnahmeId: _selectedMassnahmeTyp!.id,
        massnahmeTitel: _selectedMassnahmeTyp!.titel,
        verstossTitel: _selectedVerstossKat!.titel,
        verstossParagraph: _selectedVerstossKat!.paragraph,
        verstossBeschreibung: _selectedVerstossKat!.beschreibung,
        sachverhalt: sachverhalt,
        vorfallDatum: _selectedDatum,
        ordnungsgeldBetrag: ordnungsgeld,
      );

      if (pdfResult != null && mounted) {
        await VerwarnungPdfGenerator.saveAndPreview(
          context,
          pdfResult.bytes,
          pdfResult.fileName,
        );
      }

      _sachverhaltVerwarnungController.clear();
      setState(() {
        _selectedVerstossKat = null;
        _selectedMassnahmeTyp = null;
        _ordnungsgeldBetragController.text = '50';
        _selectedDatum = DateTime.now();
      });
      if (mounted) {
        final l2 = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l2.measureCreatedFor(_selectedMassnahmeTyp?.titel ?? l2.disciplinaryMeasure, widget.user.name)),
            backgroundColor: Colors.green,
          ),
        );
      }
      _loadVerwarnungen();
    } else {
      if (mounted) {
        final l2 = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l2.errorCreatingWarning), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteVerwarnung(Verwarnung v) async {
    final l = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.red),
            const SizedBox(width: 8),
            Text(l.deleteWarningTitle),
          ],
        ),
        content: Text(l.deleteWarningConfirm(v.typDisplay, DateFormat('dd.MM.yyyy').format(v.datum))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l.delete),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _verwarnungService.setToken(widget.apiService.token);
      final success = await _verwarnungService.deleteVerwarnung(v.id);
      if (!mounted) return;
      final l2 = AppLocalizations.of(context);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l2.warningDeleted), backgroundColor: Colors.green),
        );
        _loadVerwarnungen();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l2.errorDeleting), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _generateVerwarnungPdf(Verwarnung v) async {
    final massnahmeId = VerwarnungPdfGenerator.typToMassnahmeId(v.typ);
    final massnahmeTitel = VerwarnungPdfGenerator.typToMassnahmeTitel(v.typ);

    // Try to find matching Verstoss from grund text
    String verstossTitel = v.grund;
    String verstossParagraph = '§6 Abs. 6 Satzung';
    String verstossBeschreibung = v.beschreibung ?? v.grund;

    for (final vk in VerwarnungPdfGenerator.verstossKategorien) {
      if (v.grund.contains(vk.titel) || v.grund.contains(vk.paragraph)) {
        verstossTitel = vk.titel;
        verstossParagraph = vk.paragraph;
        verstossBeschreibung = v.beschreibung ?? vk.beschreibung;
        break;
      }
    }

    final result = await VerwarnungPdfGenerator.generate(
      userName: widget.user.name,
      mitgliedernummer: widget.user.mitgliedernummer,
      massnahmeId: massnahmeId,
      massnahmeTitel: massnahmeTitel,
      verstossTitel: verstossTitel,
      verstossParagraph: verstossParagraph,
      verstossBeschreibung: verstossBeschreibung,
      sachverhalt: v.beschreibung ?? v.grund,
      vorfallDatum: v.datum,
    );

    if (result != null && mounted) {
      await VerwarnungPdfGenerator.saveAndPreview(
        context,
        result.bytes,
        result.fileName,
      );
    }
  }

  MaterialColor _getTypColor(String typ) {
    switch (typ) {
      case 'ermahnung':
        return Colors.amber;
      case 'abmahnung':
        return Colors.orange;
      case 'letzte_abmahnung':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypIcon(String typ) {
    switch (typ) {
      case 'ermahnung':
        return Icons.info_outline;
      case 'abmahnung':
        return Icons.warning_amber;
      case 'letzte_abmahnung':
        return Icons.gavel;
      default:
        return Icons.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final screenSize = MediaQuery.of(context).size;
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: screenSize.width - 48,
        height: screenSize.height - 48,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.user.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.user.mitgliedernummer,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Tabs
            Container(
              color: Colors.grey.shade200,
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.blue.shade700,
                unselectedLabelColor: Colors.grey.shade600,
                indicatorColor: Colors.blue.shade700,
                isScrollable: true,
                tabs: [
                  Tab(icon: const Icon(Icons.account_circle), text: l.accountTab),
                  const Tab(icon: Icon(Icons.devices), text: 'Geräte'),
                  Tab(icon: const Icon(Icons.warning_amber), text: l.warningsTab),
                  Tab(icon: const Icon(Icons.folder_open), text: l.documentsTab),
                  Tab(icon: const Icon(Icons.card_membership), text: l.membershipTab),
                  Tab(icon: const Icon(Icons.verified_user), text: l.verificationTab),
                  Tab(icon: const Icon(Icons.discount), text: l.discountTab),
                  Tab(icon: const Icon(Icons.sticky_note_2), text: l.notesTab),
                  Tab(icon: const Icon(Icons.calendar_month), text: l.appointmentsTab),
                ],
              ),
            ),
            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildKontoTab(),
                  MitgliederDeviceWidget(
                    sessions: _sessions,
                    devices: _devices,
                    isLoading: _isLoading,
                    onRevokeSession: (id) => _confirmRevokeSession(id),
                  ),
                  _buildVerwarnungenTab(),
                  _buildDokumenteTab(),
                  _buildMitgliedschaftTab(),
                  _buildVerifizierungTab(),
                  _buildErmaessigungTab(),
                  _buildNotizenTab(),
                  _buildTermineTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKontoTab() {
    final l = AppLocalizations.of(context);
    final user = widget.user;
    final dateFormat = DateFormat('dd.MM.yyyy, HH:mm');

    // Determine if account is deactivated
    final bool isDeactivated = user.isSuspended || user.isGesperrt || user.isDeleted ||
        user.isGekuendigt || user.isAusgeschlossen || user.isVerstorben;

    // Full name
    String fullName = user.name;
    if (user.vorname != null && user.nachname != null) {
      fullName = [user.vorname, user.vorname2, user.nachname]
          .where((s) => s != null && s.isNotEmpty)
          .join(' ');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header - Konto Status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDeactivated ? Colors.red.shade50 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDeactivated ? Colors.red.shade200 : Colors.green.shade200,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isDeactivated ? Icons.block : Icons.check_circle,
                  color: isDeactivated ? Colors.red : Colors.green,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  isDeactivated ? l.accountDeactivated : l.accountActive,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDeactivated ? Colors.red.shade700 : Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // --- Kontodaten Section ---
          Text(
            l.accountData,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),

          // Name (display + edit pencil)
          _kontoRow(
            icon: Icons.person,
            label: l.name,
            value: fullName,
            onEdit: () => _showEditNameDialog(),
          ),
          const Divider(height: 1),

          // E-Mail (display + edit pencil)
          _kontoRow(
            icon: Icons.email,
            label: l.email,
            value: user.email,
            onEdit: () => _showEditEmailDialog(),
          ),
          const Divider(height: 1),

          // Rolle (display + edit pencil)
          _kontoRow(
            icon: Icons.badge,
            label: l.role,
            value: getRoleText(user.role),
            valueColor: getRoleColor(user.role),
            onEdit: () => _showEditRoleDialog(),
          ),
          const Divider(height: 1),

          // Passwort (edit pencil)
          _kontoRow(
            icon: Icons.lock,
            label: l.password,
            value: '\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022',
            onEdit: () => _showEditPasswordDialog(),
          ),
          const SizedBox(height: 24),

          // --- Registrierung Section ---
          Text(
            l.registrationSection,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),

          // Registrierungsdatum
          _kontoRow(
            icon: Icons.calendar_today,
            label: l.registeredOn,
            value: user.createdAt != null
                ? dateFormat.format(user.createdAt!)
                : '–',
          ),
          const Divider(height: 1),

          // Letzter Login
          _kontoRow(
            icon: Icons.login,
            label: l.lastLogin,
            value: user.lastLogin != null
                ? dateFormat.format(user.lastLogin!)
                : '–',
          ),

          // --- Deaktivierung Section (only if deactivated) ---
          if (isDeactivated) ...[
            const SizedBox(height: 24),
            Text(
              l.deactivationSection,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 12),

            // Deaktivierungsdatum
            _kontoRow(
              icon: Icons.event_busy,
              label: l.deactivatedOn,
              value: user.deactivatedAt != null
                  ? dateFormat.format(user.deactivatedAt!)
                  : l.notRecorded,
              valueColor: Colors.red.shade700,
            ),
            const Divider(height: 1),

            // Grund
            _kontoRow(
              icon: Icons.info_outline,
              label: l.reason,
              value: user.deactivationReason ?? l.noReasonGiven,
              valueColor: Colors.red.shade700,
            ),

            // 30-day auto-deactivation info
            if (user.deactivationReason != null &&
                user.deactivationReason!.contains('30 Tage')) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.schedule, color: Colors.amber.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l.autoDeactivationInfo,
                        style: TextStyle(fontSize: 13, color: Colors.amber.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _kontoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    VoidCallback? onEdit,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
          if (onEdit != null)
            IconButton(
              icon: Icon(Icons.edit, size: 18, color: Colors.blue.shade600),
              onPressed: onEdit,
              tooltip: AppLocalizations.of(context).editFieldLabel(label),
              splashRadius: 18,
            ),
        ],
      ),
    );
  }

  Future<void> _showEditNameDialog() async {
    final l = AppLocalizations.of(context);
    _nameController.text = widget.user.name;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.editName),
        content: TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: l.name,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.person),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white),
            child: Text(l.save),
          ),
        ],
      ),
    );
    if (result == true) _saveChanges();
  }

  Future<void> _showEditEmailDialog() async {
    final l = AppLocalizations.of(context);
    _emailController.text = widget.user.email;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.editEmail),
        content: TextField(
          controller: _emailController,
          decoration: InputDecoration(
            labelText: l.email,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.email),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white),
            child: Text(l.save),
          ),
        ],
      ),
    );
    if (result == true) _saveChanges();
  }

  Future<void> _showEditRoleDialog() async {
    final l = AppLocalizations.of(context);
    String tempRole = _selectedRole;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l.editRole),
          content: DropdownButtonFormField<String>(
            initialValue: tempRole,
            decoration: InputDecoration(
              labelText: l.role,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.badge),
            ),
            items: [
              DropdownMenuItem(value: 'vorsitzer', child: Text(l.roleVorsitzer)),
              DropdownMenuItem(value: 'schatzmeister', child: Text(l.roleSchatzmeister)),
              DropdownMenuItem(value: 'kassierer', child: Text(l.roleKassierer)),
              DropdownMenuItem(value: 'mitgliedergrunder', child: Text(l.roleGruender)),
              DropdownMenuItem(value: 'mitglied', child: Text(l.membership)),
            ],
            onChanged: (value) {
              if (value != null) setDialogState(() => tempRole = value);
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
            ElevatedButton(
              onPressed: () {
                setState(() => _selectedRole = tempRole);
                Navigator.pop(ctx, true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white),
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );
    if (result == true) _saveChanges();
  }

  Future<void> _showEditPasswordDialog() async {
    final l = AppLocalizations.of(context);
    _passwordController.clear();
    bool obscure = true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(l.changePasswordTitle),
            content: TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: l.newPassword,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setDialogState(() => obscure = !obscure),
                ),
                hintText: l.minChars8,
              ),
              obscureText: obscure,
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
              ElevatedButton(
                onPressed: () {
                  if (_passwordController.text.length < 8) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l.passwordMin8Chars), backgroundColor: Colors.red),
                    );
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white),
                child: Text(l.save),
              ),
            ],
          );
        },
      ),
    );
    if (result == true) _saveChanges();
  }



  Widget _buildVerwarnungenTab() {
    final l = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats row
          if (_verwarnungStats != null && _verwarnungStats!.total > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  _buildStatChip(l.total, _verwarnungStats!.total, Colors.grey),
                  const SizedBox(width: 8),
                  if (_verwarnungStats!.ermahnung > 0)
                    _buildStatChip('Ermahnung', _verwarnungStats!.ermahnung, Colors.amber),
                  if (_verwarnungStats!.ermahnung > 0) const SizedBox(width: 8),
                  if (_verwarnungStats!.abmahnung > 0)
                    _buildStatChip('Abmahnung', _verwarnungStats!.abmahnung, Colors.orange),
                  if (_verwarnungStats!.abmahnung > 0) const SizedBox(width: 8),
                  if (_verwarnungStats!.letzteAbmahnung > 0)
                    _buildStatChip('Letzte', _verwarnungStats!.letzteAbmahnung, Colors.red),
                ],
              ),
            ),

          // Create warning form
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.gavel, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(l.newDisciplinaryMeasure, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 1. Verstoß-Kategorie
                  Text(l.violationLabel, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: VerwarnungPdfGenerator.verstossKategorien.map((vk) {
                      final selected = _selectedVerstossKat?.id == vk.id;
                      return ChoiceChip(
                        label: Text(vk.titel, style: const TextStyle(fontSize: 11)),
                        selected: selected,
                        onSelected: (_) => setState(() => _selectedVerstossKat = vk),
                        selectedColor: (vk.color as MaterialColor?)?.shade100 ?? vk.color.withValues(alpha: 0.2),
                        avatar: selected ? Icon(vk.icon, size: 14, color: vk.color) : null,
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                  if (_selectedVerstossKat != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(_selectedVerstossKat!.icon, size: 16, color: _selectedVerstossKat!.color),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_selectedVerstossKat!.paragraph} — ${_selectedVerstossKat!.beschreibung}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // 2. Sachverhalt
                  TextField(
                    controller: _sachverhaltVerwarnungController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: l.factsLabel,
                      alignLabelWithHint: true,
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 48),
                        child: Icon(Icons.description),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3. Maßnahme
                  Text(l.measureSectionLabel, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: VerwarnungPdfGenerator.massnahmen.map((m) {
                      final selected = _selectedMassnahmeTyp?.id == m.id;
                      return ChoiceChip(
                        label: Text(m.titel, style: const TextStyle(fontSize: 11)),
                        selected: selected,
                        onSelected: (_) => setState(() => _selectedMassnahmeTyp = m),
                        selectedColor: (m.color as MaterialColor?)?.shade100 ?? m.color.withValues(alpha: 0.2),
                        avatar: selected ? Icon(m.icon, size: 14, color: m.color) : null,
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),

                  // Ordnungsgeld amount field
                  if (_selectedMassnahmeTyp?.id == 'ordnungsgeld') ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: 180,
                      child: TextField(
                        controller: _ordnungsgeldBetragController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: l.amountMax100,
                          prefixIcon: const Icon(Icons.euro, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // 4. Date + Submit row
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDatum,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                            locale: const Locale('de', 'DE'),
                          );
                          if (picked != null) setState(() => _selectedDatum = picked);
                        },
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(DateFormat('dd.MM.yyyy').format(_selectedDatum)),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _isSubmittingWarning ? null : _createVerwarnung,
                        icon: _isSubmittingWarning
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.gavel),
                        label: Text(l.issueMeasurePdf),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Existing warnings list
          Row(
            children: [
              Icon(Icons.list_alt, size: 20, color: Colors.grey.shade700),
              const SizedBox(width: 8),
              Text(
                l.warningsCount(_verwarnungen.length),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const Spacer(),
              if (_isLoadingVerwarnungen)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 8),

          if (_verwarnungen.isEmpty && !_isLoadingVerwarnungen)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade600),
                    const SizedBox(width: 12),
                    Text(l.noWarnings),
                  ],
                ),
              ),
            )
          else
            ..._verwarnungen.map((v) {
              final color = _getTypColor(v.typ);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: color.shade300, width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(_getTypIcon(v.typ), color: color.shade800, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: color.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    v.typDisplay,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color.shade900),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat('dd.MM.yyyy').format(v.datum),
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(v.grund, style: const TextStyle(fontWeight: FontWeight.w600)),
                            if (v.beschreibung != null && v.beschreibung!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(v.beschreibung!, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              l.createdBy(v.createdByName),
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.picture_as_pdf, color: Colors.red.shade700, size: 20),
                        tooltip: l.createPdf,
                        onPressed: () => _generateVerwarnungPdf(v),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
                        tooltip: l.deleteWarning,
                        onPressed: () => _deleteVerwarnung(v),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  // ============= DOKUMENTE =============

  Future<void> _loadDokumente() async {
    setState(() => _isLoadingDokumente = true);
    _dokumenteService.setToken(widget.apiService.token);
    final result = await _dokumenteService.getDokumente(widget.user.id);
    if (mounted) {
      setState(() {
        _dokumente = result;
        _isLoadingDokumente = false;
      });
    }
  }

  Future<void> _uploadDokument({String kategorie = 'vereindokumente'}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'txt'],
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty) return;

    // Validate: max 10 files
    if (result.files.length > 10) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).max10FilesPerUpload), backgroundColor: Colors.orange),
      );
      return;
    }

    // Validate: max 100MB per file
    for (final f in result.files) {
      if (f.size > 100 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).fileTooLarge(f.name)), backgroundColor: Colors.orange),
        );
        return;
      }
      if (f.path == null) return;
    }

    if (!mounted) return;

    // Show upload dialog with category-specific fields
    final nameController = TextEditingController();
    final beschreibungController = TextEditingController();
    String? selectedDokumentTyp;
    DateTime? selectedAblaufDatum;

    // Pre-fill name for single file
    if (result.files.length == 1) {
      final n = result.files.first.name;
      nameController.text = n.contains('.') ? n.substring(0, n.lastIndexOf('.')) : n;
    } else {
      nameController.text = AppLocalizations.of(context).nDocumentsLabel(result.files.length);
    }

    // Document types per category
    final loc = AppLocalizations.of(context);
    final vereinTypen = {
      'beitrittsantrag': loc.docTypeApplicationForm,
      'aufnahmebestaetigung': loc.docTypeAdmissionConfirmation,
      'kuendigung': loc.docTypeCancellation,
      'sonstiges': loc.docTypeOther,
    };
    final behoerdeTypen = {
      'krankenkasse': loc.docTypeHealthInsurance,
      'finanzamt': loc.docTypeTaxOffice,
      'sozialversicherung': loc.docTypeSocialInsurance,
      'arbeitsamt': loc.docTypeEmploymentOffice,
      'sonstiges': loc.docTypeOther,
    };
    final typen = kategorie == 'vereindokumente' ? vereinTypen : behoerdeTypen;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(
                kategorie == 'vereindokumente' ? Icons.groups : Icons.account_balance,
                color: kategorie == 'vereindokumente' ? Colors.blue : Colors.teal,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(
                kategorie == 'vereindokumente' ? AppLocalizations.of(ctx).uploadAssociationDoc : AppLocalizations.of(ctx).uploadAuthorityDoc,
                style: const TextStyle(fontSize: 16),
              )),
            ],
          ),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // File list
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: result.files.map((f) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Icon(_getFileIcon(f.extension ?? ''), size: 20, color: _getFileColor(f.extension ?? '')),
                            const SizedBox(width: 8),
                            Expanded(child: Text(f.name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                            Text(_formatFilesize(f.size), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          ],
                        ),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Encrypted badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock, size: 14, color: Colors.green.shade700),
                        const SizedBox(width: 4),
                        Text(AppLocalizations.of(ctx).aes256Encrypted, style: TextStyle(fontSize: 11, color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (result.files.length == 1)
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(ctx).documentName,
                        prefixIcon: const Icon(Icons.description),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  if (result.files.length == 1) const SizedBox(height: 12),
                  // Document type dropdown
                  DropdownButtonFormField<String>(
                    key: ValueKey('doctyp_$selectedDokumentTyp'),
                    initialValue: selectedDokumentTyp,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(ctx).documentType,
                      prefixIcon: const Icon(Icons.category),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: typen.entries
                        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (val) => setDialogState(() => selectedDokumentTyp = val),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: beschreibungController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(ctx).descriptionOptional,
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 24),
                        child: Icon(Icons.notes),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  // Ablauf datum for Behörde documents
                  if (kategorie == 'behoerde') ...[
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime.now().add(const Duration(days: 365)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                          locale: const Locale('de', 'DE'),
                        );
                        if (picked != null) setDialogState(() => selectedAblaufDatum = picked);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(ctx).expiryDate,
                          prefixIcon: const Icon(Icons.event, color: Colors.red),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          suffixIcon: selectedAblaufDatum != null
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () => setDialogState(() => selectedAblaufDatum = null),
                                )
                              : null,
                        ),
                        child: Text(
                          selectedAblaufDatum != null
                              ? DateFormat('dd.MM.yyyy').format(selectedAblaufDatum!)
                              : AppLocalizations.of(ctx).noExpiryDate,
                          style: TextStyle(
                            color: selectedAblaufDatum != null ? Colors.black87 : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppLocalizations.of(ctx).expiryAutoDeleteInfo,
                      style: TextStyle(fontSize: 11, color: Colors.red.shade400, fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(ctx).cancel)),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.upload),
              label: Text(AppLocalizations.of(ctx).uploadFilesCount(result.files.length)),
              style: ElevatedButton.styleFrom(
                backgroundColor: kategorie == 'vereindokumente' ? Colors.blue.shade700 : Colors.teal.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isUploadingDokument = true);
    _dokumenteService.setToken(widget.apiService.token);

    final files = result.files.where((f) => f.path != null).map((f) => File(f.path!)).toList();
    final ablaufStr = selectedAblaufDatum != null ? DateFormat('yyyy-MM-dd').format(selectedAblaufDatum!) : null;

    if (files.length == 1) {
      final dokumentName = nameController.text.trim().isEmpty ? result.files.first.name : nameController.text.trim();
      final doc = await _dokumenteService.uploadDokument(
        userId: widget.user.id,
        dokumentName: dokumentName,
        file: files.first,
        beschreibung: beschreibungController.text.trim().isEmpty ? null : beschreibungController.text.trim(),
        kategorie: kategorie,
        dokumentTyp: selectedDokumentTyp,
        ablaufDatum: ablaufStr,
      );

      if (!mounted) return;
      setState(() => _isUploadingDokument = false);

      if (doc != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).documentUploaded(doc.dokumentName)), backgroundColor: Colors.green),
        );
        _loadDokumente();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).errorUploading2), backgroundColor: Colors.red),
        );
      }
    } else {
      final docs = await _dokumenteService.uploadMultipleDokumente(
        userId: widget.user.id,
        files: files,
        dokumentName: nameController.text.trim(),
        beschreibung: beschreibungController.text.trim().isEmpty ? null : beschreibungController.text.trim(),
        kategorie: kategorie,
        dokumentTyp: selectedDokumentTyp,
        ablaufDatum: ablaufStr,
      );

      if (!mounted) return;
      setState(() => _isUploadingDokument = false);

      if (docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).documentsUploaded(docs.length)), backgroundColor: Colors.green),
        );
        _loadDokumente();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).errorUploading2), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteDokument(MemberDokument doc) async {
    final l = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.red),
            const SizedBox(width: 8),
            Text(l.deleteDocumentTitle),
          ],
        ),
        content: Text(l.deleteDocumentConfirm(doc.dokumentName, doc.originalFilename)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l.delete),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _dokumenteService.setToken(widget.apiService.token);
      final success = await _dokumenteService.deleteDokument(doc.id);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).documentDeleted), backgroundColor: Colors.green),
        );
        _loadDokumente();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).errorDeleting), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _viewDokument(MemberDokument doc) async {
    final ext = doc.fileExtension.toLowerCase();
    final viewable = ['pdf', 'jpg', 'jpeg', 'png'];
    if (!viewable.contains(ext)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).previewOnlyPdfImages), backgroundColor: Colors.orange),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(AppLocalizations.of(ctx).fileLoading),
          ],
        ),
      ),
    );

    _dokumenteService.setToken(widget.apiService.token);
    final data = await _dokumenteService.downloadDokument(doc.id);
    if (!mounted) return;
    Navigator.pop(context); // Close loading dialog

    if (data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).errorLoadingFile), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      final bytes = base64Decode(data['data']);
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/${data['filename']}';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      await FileViewerDialog.show(context, filePath, data['filename']);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).errorDisplaying('$e')), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _downloadDokument(MemberDokument doc) async {
    _dokumenteService.setToken(widget.apiService.token);
    final data = await _dokumenteService.downloadDokument(doc.id);
    if (!mounted) return;

    if (data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).errorDownloading), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      final bytes = base64Decode(data['data']);
      final dir = await getDownloadsDirectory() ?? await getTemporaryDirectory();
      final filePath = '${dir.path}/${data['filename']}';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).savedFilename(data['filename'])),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: AppLocalizations.of(context).openFile,
            textColor: Colors.white,
            onPressed: () {
              Process.run('open', [filePath]);
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).errorSavingWith2('$e')), backgroundColor: Colors.red),
      );
    }
  }

  IconData _getFileIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
      case 'odt':
        return Icons.article;
      case 'xls':
      case 'xlsx':
      case 'ods':
        return Icons.table_chart;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      case 'txt':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return Colors.red.shade700;
      case 'doc':
      case 'docx':
      case 'odt':
        return Colors.blue.shade700;
      case 'xls':
      case 'xlsx':
      case 'ods':
        return Colors.green.shade700;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Colors.purple.shade700;
      case 'txt':
        return Colors.grey.shade700;
      default:
        return Colors.blueGrey.shade700;
    }
  }

  String _formatFilesize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _buildDokumenteTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Sub-tabs
          Container(
            color: Colors.grey.shade100,
            child: TabBar(
              labelColor: Colors.blue.shade800,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: Colors.blue.shade800,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.groups, size: 18),
                      const SizedBox(width: 6),
                      Text(AppLocalizations.of(context).associationDocuments),
                      const SizedBox(width: 4),
                      _buildDocCountBadge(_dokumente.where((d) => d.kategorie == 'vereindokumente').length),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.account_balance, size: 18),
                      const SizedBox(width: 6),
                      Text(AppLocalizations.of(context).authorityDocuments),
                      const SizedBox(width: 4),
                      _buildDocCountBadge(_dokumente.where((d) => d.kategorie == 'behoerde').length),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Sub-tab content
          Expanded(
            child: TabBarView(
              children: [
                _buildDokumenteSubTab('vereindokumente'),
                _buildDokumenteSubTab('behoerde'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocCountBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: count > 0 ? Colors.blue.shade100 : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: count > 0 ? Colors.blue.shade800 : Colors.grey.shade600),
      ),
    );
  }

  Widget _buildDokumenteSubTab(String kategorie) {
    final docs = _dokumente.where((d) => d.kategorie == kategorie).toList();
    final isVerein = kategorie == 'vereindokumente';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + Upload button
          Row(
            children: [
              Icon(
                isVerein ? Icons.groups : Icons.account_balance,
                size: 20,
                color: isVerein ? Colors.blue.shade700 : Colors.teal.shade700,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isVerein ? AppLocalizations.of(context).associationDocsCount(docs.length) : AppLocalizations.of(context).authorityDocsCount(docs.length),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              if (_isLoadingDokumente)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isUploadingDokument ? null : () => _uploadDokument(kategorie: kategorie),
                icon: _isUploadingDokument
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.upload_file, size: 16),
                label: Text(AppLocalizations.of(context).upload, style: const TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isVerein ? Colors.blue.shade700 : Colors.teal.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Info box
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isVerein ? Colors.blue.shade50 : Colors.teal.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isVerein ? Colors.blue.shade100 : Colors.teal.shade100),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: isVerein ? Colors.blue.shade700 : Colors.teal.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isVerein
                        ? AppLocalizations.of(context).associationDocInfo
                        : AppLocalizations.of(context).authorityDocInfo,
                    style: TextStyle(fontSize: 10, color: isVerein ? Colors.blue.shade700 : Colors.teal.shade700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Documents list
          if (docs.isEmpty && !_isLoadingDokumente)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.folder_off, color: Colors.grey.shade500),
                    const SizedBox(width: 12),
                    Text(isVerein ? AppLocalizations.of(context).noAssociationDocs : AppLocalizations.of(context).noAuthorityDocs),
                  ],
                ),
              ),
            )
          else
            ...docs.map((doc) => _buildDokumentCard(doc)),
        ],
      ),
    );
  }

  Widget _buildDokumentCard(MemberDokument doc) {
    final ext = doc.fileExtension;
    final color = _getFileColor(ext.toLowerCase());
    final isBehoerde = doc.kategorie == 'behoerde';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: doc.isExpired ? Colors.red.shade300 : (doc.isExpiringSoon ? Colors.orange.shade300 : color.withValues(alpha: 0.3)),
          width: doc.isExpired || doc.isExpiringSoon ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            // File icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                children: [
                  Icon(_getFileIcon(ext.toLowerCase()), color: color, size: 24),
                  if (doc.isEncrypted)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Icon(Icons.lock, size: 12, color: Colors.green.shade700),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // File info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(doc.dokumentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(ext, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
                      ),
                      const SizedBox(width: 6),
                      Text(doc.filesizeFormatted, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      const SizedBox(width: 6),
                      Text(DateFormat('dd.MM.yyyy').format(doc.createdAt), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      if (doc.dokumentTyp != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: isBehoerde ? Colors.teal.shade50 : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            _dokumentTypLabel(doc.dokumentTyp!),
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: isBehoerde ? Colors.teal.shade700 : Colors.blue.shade700),
                          ),
                        ),
                      ],
                    ],
                  ),
                  // Expiry info for Behörde docs
                  if (isBehoerde && doc.ablaufDatum != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          doc.isExpired ? Icons.error : (doc.isExpiringSoon ? Icons.warning : Icons.schedule),
                          size: 13,
                          color: doc.isExpired ? Colors.red : (doc.isExpiringSoon ? Colors.orange : Colors.grey),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          doc.isExpired
                              ? AppLocalizations.of(context).expiredOnDate(DateFormat('dd.MM.yyyy').format(doc.ablaufDatum!))
                              : doc.isExpiringSoon
                                  ? AppLocalizations.of(context).validUntilDays(DateFormat('dd.MM.yyyy').format(doc.ablaufDatum!), doc.daysUntilExpiry ?? 0)
                                  : AppLocalizations.of(context).validUntilDate(DateFormat('dd.MM.yyyy').format(doc.ablaufDatum!)),
                          style: TextStyle(
                            fontSize: 11,
                            color: doc.isExpired ? Colors.red : (doc.isExpiringSoon ? Colors.orange.shade700 : Colors.grey.shade600),
                            fontWeight: doc.isExpired || doc.isExpiringSoon ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (doc.beschreibung != null && doc.beschreibung!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(doc.beschreibung!, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                    ),
                  Text(
                    '${AppLocalizations.of(context).fromFieldLabel} ${doc.uploadedByName}',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            // Actions
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (['pdf', 'jpg', 'jpeg', 'png'].contains(doc.fileExtension.toLowerCase()))
                  IconButton(
                    icon: Icon(Icons.visibility, color: Colors.green.shade600, size: 18),
                    tooltip: AppLocalizations.of(context).preview,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                    onPressed: () => _viewDokument(doc),
                  ),
                IconButton(
                  icon: Icon(Icons.download, color: Colors.blue.shade600, size: 18),
                  tooltip: AppLocalizations.of(context).download,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                  onPressed: () => _downloadDokument(doc),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 18),
                  tooltip: AppLocalizations.of(context).delete,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                  onPressed: () => _deleteDokument(doc),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _dokumentTypLabel(String typ) {
    final loc = AppLocalizations.of(context);
    final labels = {
      'beitrittsantrag': loc.docTypeApplicationForm,
      'aufnahmebestaetigung': loc.docTypeAdmissionShort,
      'kuendigung': loc.docTypeCancellation,
      'krankenkasse': loc.docTypeHealthInsurance,
      'finanzamt': loc.docTypeTaxOffice,
      'sozialversicherung': loc.docTypeSocialInsuranceShort,
      'arbeitsamt': loc.docTypeEmploymentOffice,
      'sonstiges': loc.docTypeOther,
    };
    return labels[typ] ?? typ;
  }

  Widget _buildStatChip(String label, int count, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade200),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color.shade800),
      ),
    );
  }

  Future<void> _confirmRevokeSession(int sessionId) async {
    final l = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 8),
            Text(l.revokeSessionTitle),
          ],
        ),
        content: Text(l.revokeSessionInfo),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l.revoke),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _revokeSession(sessionId);
    }
  }

  Widget _buildMitgliedschaftTab() {
    final l = AppLocalizations.of(context);
    final user = widget.user;
    final dateFormat = DateFormat('dd.MM.yyyy');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status — editable
          _mitgliedschaftRow(
            icon: Icons.circle,
            iconColor: getStatusColor(user.status),
            label: l.status,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: getStatusColor(user.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: getStatusColor(user.status).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    getStatusText(user.status),
                    style: TextStyle(
                      color: getStatusColor(user.status),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _showStatusChangeDialog(),
                  icon: const Icon(Icons.edit, size: 16),
                  label: Text(l.changeStatusButton, style: const TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 24),

          // Mitgliedernummer
          _mitgliedschaftRow(
            icon: Icons.badge,
            iconColor: Colors.blue,
            label: l.memberNumber,
            child: Text(
              user.mitgliedernummer,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          const Divider(height: 24),

          // Rolle
          _mitgliedschaftRow(
            icon: Icons.admin_panel_settings,
            iconColor: getRoleColor(user.role),
            label: l.role,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: getRoleColor(user.role).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                getRoleText(user.role),
                style: TextStyle(
                  color: getRoleColor(user.role),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const Divider(height: 24),

          // Registriert am (App)
          _mitgliedschaftRow(
            icon: Icons.app_registration,
            iconColor: Colors.grey,
            label: l.registeredOn,
            child: Text(
              user.createdAt != null ? dateFormat.format(user.createdAt!) : l.unknown,
              style: const TextStyle(fontSize: 15),
            ),
          ),
          const Divider(height: 24),

          // Letzter Login
          _mitgliedschaftRow(
            icon: Icons.login,
            iconColor: Colors.grey,
            label: l.lastLogin,
            child: Text(
              user.lastLogin != null
                  ? DateFormat('dd.MM.yyyy HH:mm').format(user.lastLogin!)
                  : l.neverLoggedIn,
              style: const TextStyle(fontSize: 15),
            ),
          ),
          const Divider(height: 24),

          // Mitglied seit (auto-set on activation, editable for retroactive)
          _mitgliedschaftRow(
            icon: Icons.card_membership,
            iconColor: Colors.green,
            label: l.memberSince,
            child: Row(
              children: [
                Text(
                  user.mitgliedschaftDatum != null
                      ? dateFormat.format(user.mitgliedschaftDatum!)
                      : l.notYetActivated,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: user.mitgliedschaftDatum != null ? Colors.green.shade700 : Colors.grey,
                    fontStyle: user.mitgliedschaftDatum == null ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit_calendar, size: 20),
                  tooltip: l.changeDateRetroactive,
                  onPressed: () => _pickMitgliedschaftDatum(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ========== BEFREIUNG SECTION ==========
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isBefreit ? Colors.green.shade50 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _isBefreit ? Colors.green.shade300 : Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _isBefreit ? Icons.check_circle : Icons.info_outline,
                      color: _isBefreit ? Colors.green.shade700 : Colors.grey.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l.feeExemption,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: _isBefreit ? Colors.green.shade700 : Colors.grey.shade700,
                        ),
                      ),
                    ),
                    if (_isBefreit)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(l.exemptLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18),
                      tooltip: l.refresh,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                      onPressed: _loadBefreiungen,
                    ),
                    const SizedBox(width: 4),
                    ElevatedButton.icon(
                      onPressed: () => _showBefreiungUploadDialog(),
                      icon: const Icon(Icons.upload_file, size: 16),
                      label: Text(l.uploadCertificate, style: const TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                    ),
                  ],
                ),
                if (_isLoadingBefreiung) ...[
                  const SizedBox(height: 12),
                  const Center(child: CircularProgressIndicator()),
                ] else if (_befreiungen.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    l.noExemptionInfo,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  ..._befreiungen.map((bef) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildBefreiungCard(bef),
                  )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mitgliedschaftRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required Widget child,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 12),
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  Future<void> _showStatusChangeDialog() async {
    String selectedStatus = widget.user.status;

    final newStatus = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.swap_horiz, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.of(ctx).changeStatus),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.user.name} (${widget.user.mitgliedernummer})',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(AppLocalizations.of(ctx).currentStatusLabel, style: const TextStyle(fontSize: 13)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: getStatusColor(widget.user.status).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            getStatusText(widget.user.status),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: getStatusColor(widget.user.status),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(AppLocalizations.of(ctx).newStatusLabel, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    ...allStatuses.map((s) {
                      final value = s['value'] as String;
                      final label = s['label'] as String;
                      final desc = s['description'] as String;
                      final isSelected = selectedStatus == value;
                      final color = getStatusColor(value);
                      return InkWell(
                        onTap: () => setDialogState(() => selectedStatus = value),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          margin: const EdgeInsets.only(bottom: 2),
                          decoration: BoxDecoration(
                            color: isSelected ? color.withValues(alpha: 0.1) : null,
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected ? Border.all(color: color.withValues(alpha: 0.4)) : null,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                size: 20,
                                color: isSelected ? color : Colors.grey.shade400,
                              ),
                              const SizedBox(width: 10),
                              Icon(Icons.circle, size: 10, color: color),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      label,
                                      style: TextStyle(
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      desc,
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(AppLocalizations.of(ctx).cancel),
                ),
                ElevatedButton.icon(
                  onPressed: selectedStatus == widget.user.status
                      ? null
                      : () => Navigator.pop(ctx, selectedStatus),
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(AppLocalizations.of(ctx).save),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (newStatus == null || newStatus == widget.user.status) return;

    try {
      final result = await widget.apiService.updateUserStatus(widget.user.id, newStatus);
      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).statusChanged(getStatusText(newStatus))),
              backgroundColor: Colors.green,
            ),
          );
          widget.onUpdated();
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? AppLocalizations.of(context).error), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).errorWith('$e')), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickMitgliedschaftDatum() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.user.mitgliedschaftDatum ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      locale: const Locale('de', 'DE'),
    );

    if (picked == null || !mounted) return;

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(picked);
      final result = await widget.apiService.updateUser(
        userId: widget.user.id,
        mitgliedschaftDatum: dateStr,
      );

      if (result['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).membershipDateSaved),
            backgroundColor: Colors.green,
          ),
        );
        widget.onUpdated();
        if (mounted) Navigator.pop(context);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? AppLocalizations.of(context).error),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).errorWith('$e')), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day.$month.$year $hour:$minute';
  }

  // ============= VERIFIZIERUNG =============

  Future<void> _loadVerifizierung() async {
    setState(() => _isLoadingVerifizierung = true);
    try {
      final result = await widget.apiService.getVerifizierung(widget.user.id);
      if (mounted && result['success'] == true) {
        setState(() {
          _verifizierungStages = List<Map<String, dynamic>>.from(result['stages'] ?? []);
          _verifizierungFinanzielleSituation = result['finanzielle_situation'] as String?;
          final acceptances = result['document_acceptances'] as Map<String, dynamic>?;
          _verifizierungAcceptances = {
            'satzung': acceptances?['satzung'] as String?,
            'datenschutz': acceptances?['datenschutz'] as String?,
            'widerrufsbelehrung': acceptances?['widerrufsbelehrung'] as String?,
          };
          _isLoadingVerifizierung = false;
        });
      } else {
        if (mounted) setState(() => _isLoadingVerifizierung = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingVerifizierung = false);
    }
  }

  Future<void> _updateVerifizierungStatus(int stufe, String status, {String? notiz}) async {
    setState(() => _isUpdatingVerifizierung = true);
    try {
      final result = await widget.apiService.updateVerifizierung(
        userId: widget.user.id,
        stufe: stufe,
        status: status,
        notiz: notiz,
      );
      if (mounted) {
        setState(() => _isUpdatingVerifizierung = false);
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(status == 'geprueft' ? AppLocalizations.of(context).stageCheckedMsg(stufe) : status == 'abgelehnt' ? AppLocalizations.of(context).stageRejectedMsg(stufe) : AppLocalizations.of(context).stageResetMsg(stufe)),
              backgroundColor: status == 'geprueft' ? Colors.green : status == 'abgelehnt' ? Colors.red : Colors.grey,
            ),
          );
          _loadVerifizierung();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? AppLocalizations.of(context).error), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdatingVerifizierung = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).errorWith('$e')), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _stufeName(int stufe) {
    return AppLocalizations.of(context).stageNameExtended(stufe);
  }

  IconData _stufeIcon(int stufe) {
    switch (stufe) {
      case 1: return Icons.person;
      case 2: return Icons.groups;
      case 3: return Icons.account_balance_wallet;
      case 4: return Icons.payment;
      case 5: return Icons.calendar_today;
      case 6: return Icons.gavel;
      case 7: return Icons.privacy_tip;
      case 8: return Icons.assignment_return;
      default: return Icons.check_circle;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'geprueft': return Colors.green;
      case 'ausgefuellt': return Colors.orange;
      case 'abgelehnt': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _statusText(String status) {
    final l = AppLocalizations.of(context);
    switch (status) {
      case 'geprueft': return l.checkedStatus;
      case 'ausgefuellt': return l.filledIn;
      case 'abgelehnt': return l.rejectedStatus;
      default: return l.openStatus;
    }
  }

  Widget _buildVerifizierungTab() {
    final l = AppLocalizations.of(context);
    if (_isLoadingVerifizierung) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_verifizierungStages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(l.noVerificationData,
              style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loadVerifizierung,
              icon: const Icon(Icons.refresh),
              label: Text(l.reloadData),
            ),
          ],
        ),
      );
    }

    final geprueftCount = _verifizierungStages.where((s) => s['status'] == 'geprueft').length;
    final totalCount = _verifizierungStages.length;
    final allDone = totalCount > 0 && geprueftCount == totalCount;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: allDone ? Colors.green.shade50 : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: allDone ? Colors.green.shade200 : Colors.blue.shade200,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      allDone ? Icons.check_circle : Icons.pending,
                      color: allDone ? Colors.green.shade700 : Colors.blue.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l.stagesChecked(geprueftCount, totalCount),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: allDone ? Colors.green.shade700 : Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: totalCount > 0 ? geprueftCount / totalCount : 0,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      allDone ? Colors.green : Colors.blue,
                    ),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Stages
          ..._verifizierungStages.map((stage) {
            final stufe = stage['stufe'] as int;
            final status = stage['status'] as String;
            return _buildStufeCard(stufe, status, stage);
          }),
        ],
      ),
    );
  }

  Widget _buildStufeCard(int stufe, String status, Map<String, dynamic> stage) {
    final color = _statusColor(status);
    final user = widget.user;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_stufeIcon(stufe), color: color, size: 24),
        ),
        title: Row(
          children: [
            Text(
              AppLocalizations.of(context).stageLabel(stufe, _stufeName(stufe)),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _statusText(status),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
              ),
            ),
          ],
        ),
        subtitle: stage['geprueft_am'] != null
            ? Text(
                AppLocalizations.of(context).checkedOnBy(_formatDate(stage['geprueft_am']), stage['geprueft_von_name'] ?? AppLocalizations.of(context).unknown),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              )
            : null,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stage-specific content
                if (stufe == 1) _buildStufe1Content(user),
                if (stufe == 2) _buildStufe2Content(user),
                if (stufe == 3) _buildStufe3Content(user),
                if (stufe == 4) _buildStufe4Content(user),
                if (stufe == 5) _buildStufe5MitgliedschaftContent(),
                if (stufe == 6) _buildStufe6Content(),
                if (stufe == 7) _buildStufe7Content(),
                if (stufe == 8) _buildStufe8Content(),

                // Notiz
                if (stage['notiz'] != null && stage['notiz'].toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.yellow.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.yellow.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.note, size: 16, color: Colors.yellow.shade800),
                        const SizedBox(width: 8),
                        Expanded(child: Text(stage['notiz'], style: const TextStyle(fontSize: 12))),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (status != 'offen')
                      TextButton.icon(
                        onPressed: _isUpdatingVerifizierung ? null : () => _updateVerifizierungStatus(stufe, 'offen'),
                        icon: const Icon(Icons.restart_alt, size: 18),
                        label: Text(AppLocalizations.of(context).resetLabel),
                        style: TextButton.styleFrom(foregroundColor: Colors.grey),
                      ),
                    const SizedBox(width: 8),
                    if (status != 'abgelehnt')
                      OutlinedButton.icon(
                        onPressed: _isUpdatingVerifizierung ? null : () => _showAblehnungDialog(stufe),
                        icon: const Icon(Icons.close, size: 18),
                        label: Text(AppLocalizations.of(context).rejectLabel),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      ),
                    const SizedBox(width: 8),
                    if (status != 'geprueft')
                      ElevatedButton.icon(
                        onPressed: _isUpdatingVerifizierung ? null : () => _updateVerifizierungStatus(stufe, 'geprueft'),
                        icon: _isUpdatingVerifizierung
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check, size: 18),
                        label: Text(AppLocalizations.of(context).checkedStatus),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStufe1Content(User user) {
    final l = AppLocalizations.of(context);
    return Column(
      children: [
        _verifizierungDataRow(l.firstName, user.vorname),
        _verifizierungDataRow(l.lastName, user.nachname),
        _verifizierungDataRow(l.birthDate, user.geburtsdatum),
        _verifizierungDataRow(l.street, user.strasse),
        _verifizierungDataRow(l.houseNumber, user.hausnummer),
        _verifizierungDataRow(l.postalCode, user.plz),
        _verifizierungDataRow(l.city, user.ort),
        _verifizierungDataRow(l.phoneNumber, user.telefonMobil),
      ],
    );
  }

  Widget _verifizierungDataRow(String label, String? value) {
    final hasValue = value != null && value.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            hasValue ? Icons.check_circle_outline : Icons.cancel_outlined,
            size: 16,
            color: hasValue ? Colors.green : Colors.red.shade300,
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(
              hasValue ? value : AppLocalizations.of(context).notSpecified,
              style: TextStyle(
                fontSize: 13,
                color: hasValue ? Colors.black87 : Colors.red.shade300,
                fontStyle: hasValue ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStufe2Content(User user) {
    final loc = AppLocalizations.of(context);
    final mitgliedsartLabels = {
      'ordentliches_mitglied': loc.ordinaryMember,
      'foerdermitglied': loc.supportingMember,
      'ehrenmitglied': loc.honoraryMember,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (user.mitgliedsart != null && user.mitgliedsart!.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.groups, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  mitgliedsartLabels[user.mitgliedsart] ?? user.mitgliedsart!,
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).memberHasNotChosenType,
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Stufe 3: Finanzielle Situation
  Widget _buildStufe3Content(User user) {
    final loc = AppLocalizations.of(context);
    final finanzLabels = {
      'buergergeld': loc.citizenBenefit,
      'sozialamt': loc.socialWelfareOffice,
      'nein': loc.noSocialBenefits,
    };

    // Get finanzielle_situation from loaded verifizierung data
    final finSituation = _verifizierungFinanzielleSituation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (finSituation != null && finSituation.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: finSituation == 'nein' ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  finSituation == 'nein' ? Icons.check_circle : Icons.info_outline,
                  color: finSituation == 'nein' ? Colors.green.shade700 : Colors.orange.shade700,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  finanzLabels[finSituation] ?? finSituation,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: finSituation == 'nein' ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).memberHasNotSpecifiedFinancial,
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Stufe 4: Zahlungsmethode
  Widget _buildStufe4Content(User user) {
    final loc = AppLocalizations.of(context);
    final zahlungsLabels = {
      'ueberweisung': loc.bankTransfer,
      'sepa_lastschrift': loc.sepaDirectDebit,
      'dauerauftrag': loc.permanentOrder,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (user.zahlungsmethode != null && user.zahlungsmethode!.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.payment, color: Colors.green.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  zahlungsLabels[user.zahlungsmethode] ?? user.zahlungsmethode!,
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700),
                ),
              ],
            ),
          )
        else ...[
          Text(AppLocalizations.of(context).noPaymentMethod, style: TextStyle(color: Colors.red.shade400, fontStyle: FontStyle.italic)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).selectPaymentMethod,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: zahlungsLabels.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (value) async {
              if (value == null) return;
              await widget.apiService.updateUser(userId: widget.user.id, zahlungsmethode: value);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppLocalizations.of(context).paymentMethodSaved), backgroundColor: Colors.green),
                );
                widget.onUpdated();
              }
            },
          ),
        ],
      ],
    );
  }

  // Stufe 5: Mitgliedschaftsbeginn
  Widget _buildStufe5MitgliedschaftContent() {
    final finSituation = _verifizierungFinanzielleSituation;
    final isBeitragsfrei = finSituation == 'buergergeld' || finSituation == 'sozialamt';

    // Find mitgliedschaftsbeginn data from stages or user data
    // The data comes from the API response
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).memberChosenStartDate,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        if (isBeitragsfrei) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.green.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).feeExemptRetroactive,
                    style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // Stufe 6: Satzung
  Widget _buildStufe6Content() {
    final l = AppLocalizations.of(context);
    return _buildRedirectStufe(
      title: l.statuteLabel2,
      description: l.statuteDesc,
      url: 'https://icd360sev.icd360s.de/satzung',
      buttonLabel: l.openStatute,
      icon: Icons.gavel,
      acceptanceDate: _verifizierungAcceptances['satzung'],
    );
  }

  // Stufe 7: Datenschutz
  Widget _buildStufe7Content() {
    final l = AppLocalizations.of(context);
    return _buildRedirectStufe(
      title: l.privacyLabel,
      description: l.privacyDesc,
      url: 'https://icd360sev.icd360s.de/datenschutz',
      buttonLabel: l.openPrivacy,
      icon: Icons.privacy_tip,
      acceptanceDate: _verifizierungAcceptances['datenschutz'],
    );
  }

  // Stufe 8: Widerrufsbelehrung
  Widget _buildStufe8Content() {
    final l = AppLocalizations.of(context);
    return _buildRedirectStufe(
      title: l.withdrawalLabelFull,
      description: l.withdrawalDesc,
      url: 'https://icd360sev.icd360s.de/widerrufsbelehrung',
      buttonLabel: l.openWithdrawal,
      icon: Icons.assignment_return,
      acceptanceDate: _verifizierungAcceptances['widerrufsbelehrung'],
    );
  }

  Widget _buildRedirectStufe({
    required String title,
    required String description,
    required String url,
    required String buttonLabel,
    required IconData icon,
    String? acceptanceDate,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (acceptanceDate != null && acceptanceDate.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).acceptedAtRegistrationDate(_formatDate(acceptanceDate)),
                    style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          )
        else
          Text(description, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () async {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          icon: Icon(icon, size: 18),
          label: Text(buttonLabel),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.blue.shade700),
        ),
      ],
    );
  }

  Future<void> _showAblehnungDialog(int stufe) async {
    final l = AppLocalizations.of(context);
    final notizController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.cancel, color: Colors.red),
            const SizedBox(width: 8),
            Text(l.rejectStage(stufe)),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: notizController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: l.rejectionReasonOptional,
              alignLabelWithHint: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.close),
            label: Text(l.rejectLabel),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final notiz = notizController.text.trim().isEmpty ? null : notizController.text.trim();
      _updateVerifizierungStatus(stufe, 'abgelehnt', notiz: notiz);
    }
  }

  // ========== BEFREIUNG ==========

  Future<void> _loadBefreiungen() async {
    setState(() => _isLoadingBefreiung = true);
    try {
      final result = await widget.apiService.getBefreiungen(widget.user.id);
      if (mounted && result['success'] == true) {
        setState(() {
          _befreiungen = List<Map<String, dynamic>>.from(result['befreiungen'] ?? []);
          _isBefreit = result['is_befreit'] == true;
          _isLoadingBefreiung = false;
        });
      } else {
        if (mounted) setState(() => _isLoadingBefreiung = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingBefreiung = false);
    }
  }

  Widget _buildBefreiungCard(Map<String, dynamic> bef) {
    final status = bef['status'] as String? ?? 'eingereicht';
    final behoerde = bef['behoerde'] as String? ?? '';
    final gueltigVon = bef['gueltig_von'] as String?;
    final gueltigBis = bef['gueltig_bis'] as String?;
    final bescheidDatum = bef['bescheid_datum'] as String?;
    final notiz = bef['notiz'] as String?;
    final geprueftAm = bef['geprueft_am'] as String?;
    final geprueftVonName = bef['geprueft_von_name'] as String?;
    final originalFilename = bef['original_filename'] as String?;
    final filesize = bef['filesize'];
    final id = bef['id'] is int ? bef['id'] as int : int.tryParse(bef['id'].toString()) ?? 0;

    Color statusColor;
    IconData statusIcon;
    String statusText;
    switch (status) {
      case 'genehmigt':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = AppLocalizations.of(context).approvedStatus;
        break;
      case 'abgelehnt':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = AppLocalizations.of(context).rejectedStatus2;
        break;
      case 'abgelaufen':
        statusColor = Colors.orange;
        statusIcon = Icons.timer_off;
        statusText = AppLocalizations.of(context).expiredStatus;
        break;
      default:
        statusColor = Colors.blue;
        statusIcon = Icons.hourglass_top;
        statusText = AppLocalizations.of(context).submittedStatus;
    }

    final behoerdeLabel = behoerde == 'jobcenter' ? 'Jobcenter' : AppLocalizations.of(context).socialWelfareOffice;
    final behoerdeColor = behoerde == 'jobcenter' ? Colors.indigo : Colors.teal;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: statusColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Behörde + Status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: behoerdeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: behoerdeColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.account_balance, size: 14, color: behoerdeColor),
                      const SizedBox(width: 4),
                      Text(behoerdeLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: behoerdeColor)),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(statusText, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Dates
            Row(
              children: [
                Expanded(
                  child: _befreiungInfoRow(Icons.date_range, AppLocalizations.of(context).validFromLabel, gueltigVon != null ? _formatDate(gueltigVon) : '-'),
                ),
                Expanded(
                  child: _befreiungInfoRow(Icons.event, AppLocalizations.of(context).validUntilLabel, gueltigBis != null ? _formatDate(gueltigBis) : '-'),
                ),
              ],
            ),
            if (bescheidDatum != null) ...[
              const SizedBox(height: 4),
              _befreiungInfoRow(Icons.description, AppLocalizations.of(context).certificateFrom, _formatDate(bescheidDatum)),
            ],

            // File info
            if (originalFilename != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      originalFilename.toLowerCase().endsWith('.pdf') ? Icons.picture_as_pdf : Icons.image,
                      size: 18,
                      color: originalFilename.toLowerCase().endsWith('.pdf') ? Colors.red : Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(originalFilename, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                          if (filesize != null)
                            Text(_formatFileSize(filesize), style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.visibility, size: 18, color: Colors.green.shade600),
                      tooltip: AppLocalizations.of(context).preview,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                      onPressed: () => _viewBefreiungDokument(id, originalFilename),
                    ),
                  ],
                ),
              ),
            ],

            // Notiz
            if (notiz != null && notiz.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.yellow.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.yellow.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.note, size: 14, color: Colors.yellow.shade800),
                    const SizedBox(width: 6),
                    Expanded(child: Text(notiz, style: const TextStyle(fontSize: 11))),
                  ],
                ),
              ),
            ],

            // Geprüft info
            if (geprueftAm != null) ...[
              const SizedBox(height: 6),
              Text(
                AppLocalizations.of(context).checkedOnBy(_formatDate(geprueftAm), geprueftVonName ?? AppLocalizations.of(context).unknown),
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
              ),
            ],

            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Delete
                TextButton.icon(
                  onPressed: () => _deleteBefreiung(id),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: Text(AppLocalizations.of(context).delete, style: const TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: Colors.red.shade400),
                ),
                const Spacer(),
                if (status != 'genehmigt' && status != 'abgelaufen')
                  TextButton.icon(
                    onPressed: () => _showBefreiungAblehnungDialog(id),
                    icon: const Icon(Icons.close, size: 16),
                    label: Text(AppLocalizations.of(context).rejectLabel, style: const TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                if (status != 'genehmigt' && status != 'abgelaufen') ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _updateBefreiungStatus(id, 'genehmigt'),
                    icon: const Icon(Icons.check, size: 16),
                    label: Text(AppLocalizations.of(context).approveLabel, style: const TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                  ),
                ],
                if (status == 'abgelehnt' || status == 'abgelaufen')
                  TextButton.icon(
                    onPressed: () => _updateBefreiungStatus(id, 'eingereicht'),
                    icon: const Icon(Icons.restart_alt, size: 16),
                    label: Text(AppLocalizations.of(context).resetLabel, style: const TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(foregroundColor: Colors.grey),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _befreiungInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text('$label: ', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }

  String _formatFileSize(dynamic size) {
    final bytes = size is int ? size : int.tryParse(size.toString()) ?? 0;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _viewBefreiungDokument(int id, String filename) async {
    final ext = filename.toLowerCase().split('.').last;
    final viewable = ['pdf', 'jpg', 'jpeg', 'png'];
    if (!viewable.contains(ext)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).previewOnlyPdfImages), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await widget.apiService.downloadBefreiung(id);
      if (!mounted) return;
      Navigator.pop(context); // close loading

      if (result['success'] == true) {
        final bytes = base64Decode(result['data']);
        final dir = await getTemporaryDirectory();
        final filePath = '${dir.path}/${result['filename']}';
        await File(filePath).writeAsBytes(bytes);
        if (mounted) {
          await FileViewerDialog.show(context, filePath, result['filename']);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? AppLocalizations.of(context).errorDownloading2), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).errorWith('$e')), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateBefreiungStatus(int id, String status, {String? notiz}) async {
    try {
      final result = await widget.apiService.updateBefreiung(id: id, status: status, notiz: notiz);
      if (mounted) {
        if (result['success'] == true) {
          final labels = {'genehmigt': AppLocalizations.of(context).exemptionApproved, 'abgelehnt': AppLocalizations.of(context).exemptionRejected, 'eingereicht': AppLocalizations.of(context).statusResetLabel};
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(labels[status] ?? AppLocalizations.of(context).statusUpdated),
              backgroundColor: status == 'genehmigt' ? Colors.green : status == 'abgelehnt' ? Colors.red : Colors.grey,
            ),
          );
          _loadBefreiungen();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? AppLocalizations.of(context).error), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).errorWith('$e')), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteBefreiung(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.delete_forever, color: Colors.red),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(context).deleteExemptionTitle),
          ],
        ),
        content: Text(AppLocalizations.of(context).deleteExemptionConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(ctx).cancel)),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete),
            label: Text(AppLocalizations.of(ctx).delete),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final result = await widget.apiService.deleteBefreiung(id);
        if (mounted) {
          if (result['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context).exemptionDeleted), backgroundColor: Colors.green),
            );
            _loadBefreiungen();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(result['message'] ?? AppLocalizations.of(context).error), backgroundColor: Colors.red),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).errorWith('$e')), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _showBefreiungAblehnungDialog(int id) async {
    final notizController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.cancel, color: Colors.red),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(ctx).rejectExemptionTitle),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: notizController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(ctx).rejectionReasonOptional,
              alignLabelWithHint: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(ctx).cancel)),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.close),
            label: Text(AppLocalizations.of(ctx).rejectLabel),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final notiz = notizController.text.trim().isEmpty ? null : notizController.text.trim();
      _updateBefreiungStatus(id, 'abgelehnt', notiz: notiz);
    }
  }

  Future<void> _showBefreiungUploadDialog() async {
    String selectedBehoerde = 'jobcenter';
    DateTime? bescheidDatum;
    DateTime? gueltigVon;
    DateTime? gueltigBis;
    String? selectedFilePath;
    String? selectedFileName;
    final notizController = TextEditingController();
    final dateFormat = DateFormat('dd.MM.yyyy');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.upload_file, color: Colors.teal),
              const SizedBox(width: 8),
              Text(AppLocalizations.of(ctx).approvalCertificate),
            ],
          ),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Behörde
                  Text(AppLocalizations.of(ctx).authorityRequired, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: selectedBehoerde,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: [
                      const DropdownMenuItem(value: 'jobcenter', child: Text('Jobcenter')),
                      DropdownMenuItem(value: 'sozialamt', child: Text(AppLocalizations.of(ctx).socialWelfareOffice)),
                    ],
                    onChanged: (val) => setDialogState(() => selectedBehoerde = val ?? 'jobcenter'),
                  ),
                  const SizedBox(height: 12),

                  // Bescheid Datum
                  Text(AppLocalizations.of(ctx).certificateDateLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: bescheidDatum ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        locale: const Locale('de'),
                      );
                      if (picked != null) setDialogState(() => bescheidDatum = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Text(bescheidDatum != null ? dateFormat.format(bescheidDatum!) : AppLocalizations.of(ctx).selectDatePlaceholder)),
                          const Icon(Icons.calendar_today, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Gültig von
                  Text(AppLocalizations.of(ctx).validFromRequired, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: gueltigVon ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        locale: const Locale('de'),
                      );
                      if (picked != null) setDialogState(() => gueltigVon = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: gueltigVon == null ? Colors.red.shade300 : Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Text(gueltigVon != null ? dateFormat.format(gueltigVon!) : AppLocalizations.of(ctx).selectStartDate)),
                          const Icon(Icons.calendar_today, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Gültig bis
                  Text(AppLocalizations.of(ctx).validUntilRequired, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: gueltigBis ?? (gueltigVon != null ? gueltigVon!.add(const Duration(days: 365)) : DateTime.now().add(const Duration(days: 365))),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                        locale: const Locale('de'),
                      );
                      if (picked != null) setDialogState(() => gueltigBis = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: gueltigBis == null ? Colors.red.shade300 : Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Text(gueltigBis != null ? dateFormat.format(gueltigBis!) : AppLocalizations.of(ctx).selectEndDate)),
                          const Icon(Icons.calendar_today, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // File picker
                  Text(AppLocalizations.of(ctx).approvalCertificateRequired, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                        dialogTitle: AppLocalizations.of(ctx).selectApprovalCertificate,
                      );
                      if (result != null && result.files.single.path != null) {
                        setDialogState(() {
                          selectedFilePath = result.files.single.path;
                          selectedFileName = result.files.single.name;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: selectedFilePath == null ? Colors.red.shade300 : Colors.green.shade400,
                          style: selectedFilePath == null ? BorderStyle.solid : BorderStyle.solid,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: selectedFilePath != null ? Colors.green.shade50 : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selectedFilePath != null ? Icons.check_circle : Icons.attach_file,
                            size: 18,
                            color: selectedFilePath != null ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedFileName ?? AppLocalizations.of(ctx).selectFileLabel,
                              style: TextStyle(
                                fontSize: 13,
                                color: selectedFilePath != null ? Colors.green.shade700 : Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Notiz
                  Text(AppLocalizations.of(ctx).noteFieldLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: notizController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(ctx).optionalNote,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(ctx).cancel)),
            ElevatedButton.icon(
              onPressed: (gueltigVon == null || gueltigBis == null || selectedFilePath == null)
                  ? null
                  : () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.upload),
              label: Text(AppLocalizations.of(ctx).upload),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && gueltigVon != null && gueltigBis != null && selectedFilePath != null) {
      // Show loading
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
      }

      try {
        final result = await widget.apiService.uploadBefreiung(
          userId: widget.user.id,
          behoerde: selectedBehoerde,
          gueltigVon: DateFormat('yyyy-MM-dd').format(gueltigVon!),
          gueltigBis: DateFormat('yyyy-MM-dd').format(gueltigBis!),
          bescheidDatum: bescheidDatum != null ? DateFormat('yyyy-MM-dd').format(bescheidDatum!) : null,
          notiz: notizController.text.trim().isEmpty ? null : notizController.text.trim(),
          filePath: selectedFilePath!,
          fileName: selectedFileName!,
        );

        if (mounted) {
          Navigator.pop(context); // close loading
          if (result['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context).certificateUploaded), backgroundColor: Colors.green),
            );
            _loadBefreiungen();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(result['message'] ?? AppLocalizations.of(context).errorUploading2), backgroundColor: Colors.red),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).errorWith('$e')), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // ══════════════════════════════════════════════════════════════
  // ERMÄSSIGUNG TAB
  // ══════════════════════════════════════════════════════════════

  Map<String, String> _getAntragTypLabels() {
    final loc = AppLocalizations.of(context);
    return {
      'arbeitslosengeld': loc.assistUnemploymentBenefit,
      'buergergeld': loc.assistCitizenBenefit,
      'sozialhilfe': loc.assistSocialWelfare,
      'grundsicherung': loc.assistBasicSecurity,
      'wohngeld': loc.assistHousingBenefit,
      'bafog': loc.assistBafog,
      'ausbildungsbeihilfe': loc.assistTrainingAllowance,
      'kinderzuschlag': loc.assistChildSupplement,
      'rente': loc.assistPension,
      'sonstiges': loc.assistOther,
    };
  }

  static const Map<String, Color> _antragTypColors = {
    'arbeitslosengeld': Colors.indigo,
    'buergergeld': Colors.teal,
    'sozialhilfe': Colors.purple,
    'grundsicherung': Colors.brown,
    'wohngeld': Colors.cyan,
    'bafog': Colors.deepOrange,
    'ausbildungsbeihilfe': Colors.pink,
    'kinderzuschlag': Colors.green,
    'rente': Colors.blueGrey,
    'sonstiges': Colors.grey,
  };

  Future<void> _loadErmaessigungen() async {
    setState(() => _isLoadingErmaessigung = true);
    try {
      final result = await widget.apiService.getErmaessigungsantraege(userId: widget.user.id);
      if (mounted && result['success'] == true) {
        setState(() {
          _ermaessigungen = List<Map<String, dynamic>>.from(result['antraege'] ?? []);
          _isLoadingErmaessigung = false;
        });
      } else {
        if (mounted) setState(() => _isLoadingErmaessigung = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingErmaessigung = false);
    }
  }

  Widget _buildErmaessigungTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.deepPurple.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.discount, color: Colors.deepPurple.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context).discountApplications,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.deepPurple.shade700,
                        ),
                      ),
                    ),
                    if (_ermaessigungen.where((a) => a['status'] == 'eingereicht').isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          AppLocalizations.of(context).openCountLabel(_ermaessigungen.where((a) => a['status'] == 'eingereicht').length),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
                        ),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18),
                      tooltip: AppLocalizations.of(context).refresh,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                      onPressed: _loadErmaessigungen,
                    ),
                  ],
                ),
                if (_isLoadingErmaessigung) ...[
                  const SizedBox(height: 12),
                  const Center(child: CircularProgressIndicator()),
                ] else if (_ermaessigungen.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context).noDiscountApplications,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  ..._ermaessigungen.map((antrag) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildErmaessigungCard(antrag),
                  )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErmaessigungCard(Map<String, dynamic> antrag) {
    final status = antrag['status'] as String? ?? 'eingereicht';
    final antragTyp = antrag['antrag_typ'] as String? ?? 'sonstiges';
    final gueltigVon = antrag['gueltig_von'] as String?;
    final gueltigBis = antrag['gueltig_bis'] as String?;
    final eingereichtAm = antrag['eingereicht_am'] as String?;
    final notiz = antrag['notiz'] as String?;
    final ablehnungsgrund = antrag['ablehnungsgrund'] as String?;
    final geprueftAm = antrag['geprueft_am'] as String?;
    final geprueftVonName = antrag['geprueft_von_name'] as String?;
    final originalFilename = antrag['original_filename'] as String?;
    final filesize = antrag['filesize'];
    final tageOffen = antrag['tage_offen'] is int ? antrag['tage_offen'] as int : int.tryParse(antrag['tage_offen']?.toString() ?? '0') ?? 0;
    final id = antrag['id'] is int ? antrag['id'] as int : int.tryParse(antrag['id'].toString()) ?? 0;

    // Checklist state
    final checkDokument = antrag['check_dokument_lesbar'] == true || antrag['check_dokument_lesbar'] == 1;
    final checkLeistungsart = antrag['check_leistungsart_erkennbar'] == true || antrag['check_leistungsart_erkennbar'] == 1;
    final checkAktuell = antrag['check_aktuell_12monate'] == true || antrag['check_aktuell_12monate'] == 1;
    final alleGeprueft = checkDokument && checkLeistungsart && checkAktuell;

    Color statusColor;
    IconData statusIcon;
    String statusText;
    switch (status) {
      case 'genehmigt':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = AppLocalizations.of(context).approvedStatus;
        break;
      case 'abgelehnt':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = AppLocalizations.of(context).rejectedStatus2;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_top;
        statusText = AppLocalizations.of(context).submittedStatus;
    }

    final typLabel = _getAntragTypLabels()[antragTyp] ?? antragTyp;
    final typColor = _antragTypColors[antragTyp] ?? Colors.grey;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: statusColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Leistungsart + Status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: typColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: typColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.description, size: 14, color: typColor),
                      const SizedBox(width: 4),
                      Text(typLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: typColor)),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(statusText, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Dates & tage offen
            Row(
              children: [
                if (eingereichtAm != null)
                  Expanded(
                    child: _befreiungInfoRow(Icons.upload, 'Eingereicht', _formatDate(eingereichtAm)),
                  ),
                if (status == 'eingereicht')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: tageOffen >= 12 ? Colors.red.shade50 : tageOffen >= 7 ? Colors.orange.shade50 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      AppLocalizations.of(context).daysOpen(tageOffen),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: tageOffen >= 12 ? Colors.red : tageOffen >= 7 ? Colors.orange.shade800 : Colors.grey.shade700,
                      ),
                    ),
                  ),
              ],
            ),
            if (gueltigVon != null || gueltigBis != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  if (gueltigVon != null)
                    Expanded(child: _befreiungInfoRow(Icons.date_range, AppLocalizations.of(context).validFromLabel, _formatDate(gueltigVon))),
                  if (gueltigBis != null)
                    Expanded(child: _befreiungInfoRow(Icons.event, AppLocalizations.of(context).validUntilLabel, _formatDate(gueltigBis))),
                ],
              ),
            ],

            // File info
            if (originalFilename != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      originalFilename.toLowerCase().endsWith('.pdf') ? Icons.picture_as_pdf : Icons.image,
                      size: 18,
                      color: originalFilename.toLowerCase().endsWith('.pdf') ? Colors.red : Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(originalFilename, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                          if (filesize != null)
                            Text(_formatFileSize(filesize), style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.visibility, size: 18, color: Colors.green.shade600),
                      tooltip: 'Vorschau',
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                      onPressed: () => _viewErmaessigungDokument(id, originalFilename),
                    ),
                  ],
                ),
              ),
            ],

            // Checklist (only for eingereicht status)
            if (status == 'eingereicht') ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLocalizations.of(context).checkSectionLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                    const SizedBox(height: 4),
                    _buildCheckItem(AppLocalizations.of(context).documentReadable, checkDokument, (val) {
                      _updateErmaessigungCheck(id, checkDokumentLesbar: val);
                    }),
                    _buildCheckItem(AppLocalizations.of(context).benefitTypeRecognizable, checkLeistungsart, (val) {
                      _updateErmaessigungCheck(id, checkLeistungsartErkennbar: val);
                    }),
                    _buildCheckItem(AppLocalizations.of(context).currentWithin12Months, checkAktuell, (val) {
                      _updateErmaessigungCheck(id, checkAktuell12Monate: val);
                    }),
                  ],
                ),
              ),
            ],

            // Show checklist status for processed items
            if (status != 'eingereicht') ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(checkDokument ? Icons.check_box : Icons.check_box_outline_blank, size: 14, color: checkDokument ? Colors.green : Colors.grey),
                  const SizedBox(width: 4),
                  Text(AppLocalizations.of(context).readableShort, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                  const SizedBox(width: 8),
                  Icon(checkLeistungsart ? Icons.check_box : Icons.check_box_outline_blank, size: 14, color: checkLeistungsart ? Colors.green : Colors.grey),
                  const SizedBox(width: 4),
                  Text(AppLocalizations.of(context).benefitTypeShort, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                  const SizedBox(width: 8),
                  Icon(checkAktuell ? Icons.check_box : Icons.check_box_outline_blank, size: 14, color: checkAktuell ? Colors.green : Colors.grey),
                  const SizedBox(width: 4),
                  Text(AppLocalizations.of(context).currentShortLabel, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                ],
              ),
            ],

            // Ablehnungsgrund
            if (ablehnungsgrund != null && ablehnungsgrund.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Colors.red.shade700),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppLocalizations.of(context).rejectionReasonHeading, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                          const SizedBox(height: 2),
                          Text(ablehnungsgrund, style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Notiz
            if (notiz != null && notiz.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.yellow.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.yellow.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.note, size: 14, color: Colors.yellow.shade800),
                    const SizedBox(width: 6),
                    Expanded(child: Text(notiz, style: const TextStyle(fontSize: 11))),
                  ],
                ),
              ),
            ],

            // Geprüft info
            if (geprueftAm != null) ...[
              const SizedBox(height: 6),
              Text(
                AppLocalizations.of(context).checkedOnBy(_formatDate(geprueftAm), geprueftVonName ?? AppLocalizations.of(context).unknown),
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
              ),
            ],

            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Delete
                TextButton.icon(
                  onPressed: () => _deleteErmaessigung(id),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: Text(AppLocalizations.of(context).delete, style: const TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: Colors.red.shade400),
                ),
                const Spacer(),
                if (status == 'eingereicht') ...[
                  TextButton.icon(
                    onPressed: () => _showErmaessigungAblehnungDialog(id),
                    icon: const Icon(Icons.close, size: 16),
                    label: Text(AppLocalizations.of(context).rejectLabel, style: const TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: alleGeprueft ? () => _updateErmaessigungStatus(id, 'genehmigt') : null,
                    icon: const Icon(Icons.check, size: 16),
                    label: Text(AppLocalizations.of(context).approveLabel, style: const TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                  ),
                ],
                if (status == 'abgelehnt')
                  TextButton.icon(
                    onPressed: () => _updateErmaessigungStatus(id, 'eingereicht'),
                    icon: const Icon(Icons.restart_alt, size: 16),
                    label: Text(AppLocalizations.of(context).resetLabel, style: const TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(foregroundColor: Colors.grey),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckItem(String label, bool checked, ValueChanged<bool> onChanged) {
    return InkWell(
      onTap: () => onChanged(!checked),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(
              checked ? Icons.check_box : Icons.check_box_outline_blank,
              size: 20,
              color: checked ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 12, color: checked ? Colors.green.shade700 : Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }

  Future<void> _updateErmaessigungCheck(int id, {bool? checkDokumentLesbar, bool? checkLeistungsartErkennbar, bool? checkAktuell12Monate}) async {
    try {
      final result = await widget.apiService.updateErmaessigung(
        id: id,
        checkDokumentLesbar: checkDokumentLesbar,
        checkLeistungsartErkennbar: checkLeistungsartErkennbar,
        checkAktuell12Monate: checkAktuell12Monate,
      );
      if (mounted && result['success'] == true) {
        _loadErmaessigungen();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).errorWith('$e')), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateErmaessigungStatus(int id, String status) async {
    try {
      final result = await widget.apiService.updateErmaessigung(id: id, status: status);
      if (mounted) {
        if (result['success'] == true) {
          final labels = {'genehmigt': AppLocalizations.of(context).discountApproved, 'abgelehnt': AppLocalizations.of(context).discountRejected, 'eingereicht': AppLocalizations.of(context).statusResetLabel};
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(labels[status] ?? AppLocalizations.of(context).statusUpdated),
              backgroundColor: status == 'genehmigt' ? Colors.green : status == 'abgelehnt' ? Colors.red : Colors.grey,
            ),
          );
          _loadErmaessigungen();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? AppLocalizations.of(context).error), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).errorWith('$e')), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteErmaessigung(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.delete_forever, color: Colors.red),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(ctx).deleteApplicationTitle),
          ],
        ),
        content: Text(AppLocalizations.of(ctx).deleteApplicationConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(ctx).cancel)),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete),
            label: Text(AppLocalizations.of(ctx).delete),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final result = await widget.apiService.deleteErmaessigung(id);
        if (mounted) {
          if (result['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context).applicationDeleted), backgroundColor: Colors.green),
            );
            _loadErmaessigungen();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(result['message'] ?? AppLocalizations.of(context).error), backgroundColor: Colors.red),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).errorWith('$e')), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _viewErmaessigungDokument(int id, String filename) async {
    final ext = filename.toLowerCase().split('.').last;
    final viewable = ['pdf', 'jpg', 'jpeg', 'png'];
    if (!viewable.contains(ext)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).previewOnlyPdfImages), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await widget.apiService.downloadErmaessigung(id);
      if (!mounted) return;
      Navigator.pop(context);

      if (result['success'] == true) {
        final bytes = base64Decode(result['data']);
        final dir = await getTemporaryDirectory();
        final filePath = '${dir.path}/${result['filename']}';
        await File(filePath).writeAsBytes(bytes);
        if (mounted) {
          await FileViewerDialog.show(context, filePath, result['filename']);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? AppLocalizations.of(context).errorDownloading2), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).errorWith('$e')), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showErmaessigungAblehnungDialog(int id) async {
    final grundController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.cancel, color: Colors.red),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(ctx).rejectDiscountTitle),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(ctx).rejectionReasonRequired,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: grundController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(ctx).rejectionReasonField,
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(ctx).cancel)),
          ElevatedButton.icon(
            onPressed: () {
              if (grundController.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(AppLocalizations.of(ctx).rejectionReasonMandatory), backgroundColor: Colors.orange),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            icon: const Icon(Icons.close),
            label: Text(AppLocalizations.of(ctx).rejectLabel),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          ),
        ],
      ),
    );

    if (confirmed == true && grundController.text.trim().isNotEmpty) {
      try {
        final result = await widget.apiService.updateErmaessigung(
          id: id,
          status: 'abgelehnt',
          ablehnungsgrund: grundController.text.trim(),
        );
        if (mounted) {
          if (result['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context).discountRejected), backgroundColor: Colors.red),
            );
            _loadErmaessigungen();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(result['message'] ?? AppLocalizations.of(context).error), backgroundColor: Colors.red),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).errorWith('$e')), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // ══════════════════════════════════════════════════════════════
  // NOTIZEN TAB
  // ══════════════════════════════════════════════════════════════

  Future<void> _loadNotizen() async {
    setState(() => _isLoadingNotizen = true);
    try {
      final result = await widget.apiService.getNotizen(widget.user.id);
      if (mounted && result['success'] == true) {
        setState(() {
          _notizen = List<Map<String, dynamic>>.from(result['notizen'] ?? []);
          _isLoadingNotizen = false;
        });
      } else {
        if (mounted) setState(() => _isLoadingNotizen = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingNotizen = false);
    }
  }

  Future<void> _createNotiz() async {
    final text = _notizController.text.trim();
    debugPrint('[NOTIZ] _createNotiz called, text="$text", kategorie=$_notizKategorie, wichtig=$_notizWichtig');
    if (text.isEmpty) {
      debugPrint('[NOTIZ] Text is empty, returning');
      return;
    }

    try {
      debugPrint('[NOTIZ] Sending to API: userId=${widget.user.id}');
      final result = await widget.apiService.createNotiz(
        userId: widget.user.id,
        notiz: text,
        kategorie: _notizKategorie,
        wichtig: _notizWichtig,
      );
      debugPrint('[NOTIZ] API response: $result');
      if (mounted) {
        if (result['success'] == true) {
          _notizController.clear();
          setState(() {
            _notizKategorie = 'allgemein';
            _notizWichtig = false;
          });
          _loadNotizen();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).noteSaved), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? AppLocalizations.of(context).error), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      debugPrint('[NOTIZ] Exception: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).errorWith('$e')), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteNotiz(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx).deleteNoteTitle),
        content: Text(AppLocalizations.of(ctx).deleteNoteConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(ctx).cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text(AppLocalizations.of(ctx).delete),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final result = await widget.apiService.deleteNotiz(id);
      if (mounted) {
        if (result['success'] == true) {
          _loadNotizen();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).noteDeleted), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).errorWith('$e')), backgroundColor: Colors.red),
        );
      }
    }
  }

  Map<String, String> _getKategorieLabels() {
    final loc = AppLocalizations.of(context);
    return {
      'allgemein': loc.categoryGeneral,
      'verhalten': loc.categoryBehavior,
      'zahlung': loc.categoryPayment,
      'kommunikation': loc.categoryCommunication,
      'sonstiges': loc.categoryOtherNotes,
    };
  }

  static const _kategorieColors = {
    'allgemein': Colors.blueGrey,
    'verhalten': Colors.orange,
    'zahlung': Colors.green,
    'kommunikation': Colors.blue,
    'sonstiges': Colors.purple,
  };

  static const _kategorieIcons = {
    'allgemein': Icons.notes,
    'verhalten': Icons.person_outline,
    'zahlung': Icons.euro,
    'kommunikation': Icons.chat_bubble_outline,
    'sonstiges': Icons.more_horiz,
  };

  Widget _buildNotizenTab() {
    final df = DateFormat('dd.MM.yyyy HH:mm', 'de_DE');

    return Column(
      children: [
        // Create new note
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            border: Border(bottom: BorderSide(color: Colors.amber.shade200)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context).newNote, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              TextField(
                controller: _notizController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context).internalNoteHint,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(12),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  // Kategorie dropdown
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _notizKategorie,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).categoryLabel,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        isDense: true,
                      ),
                      items: _getKategorieLabels().entries.map((e) {
                        return DropdownMenuItem(
                          value: e.key,
                          child: Row(
                            children: [
                              Icon(_kategorieIcons[e.key], size: 16, color: _kategorieColors[e.key]),
                              const SizedBox(width: 6),
                              Text(e.value, style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _notizKategorie = v ?? 'allgemein'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Wichtig toggle
                  FilterChip(
                    label: Text(AppLocalizations.of(context).importantLabel, style: const TextStyle(fontSize: 12)),
                    selected: _notizWichtig,
                    onSelected: (v) => setState(() => _notizWichtig = v),
                    selectedColor: Colors.red.shade100,
                    avatar: Icon(
                      _notizWichtig ? Icons.star : Icons.star_border,
                      size: 16,
                      color: _notizWichtig ? Colors.red.shade700 : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Submit button
                  ElevatedButton.icon(
                    onPressed: _createNotiz,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(AppLocalizations.of(context).add),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Notes list
        Expanded(
          child: _isLoadingNotizen
              ? const Center(child: CircularProgressIndicator())
              : _notizen.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sticky_note_2_outlined, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 8),
                          Text(AppLocalizations.of(context).noNotesAvailable, style: TextStyle(color: Colors.grey.shade500)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _notizen.length,
                      itemBuilder: (ctx, i) {
                        final notiz = _notizen[i];
                        final kategorie = notiz['kategorie']?.toString() ?? 'allgemein';
                        final isWichtig = notiz['wichtig'] == true;
                        final color = _kategorieColors[kategorie] ?? Colors.blueGrey;
                        final icon = _kategorieIcons[kategorie] ?? Icons.notes;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: isWichtig ? 2 : 0.5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: isWichtig
                                ? BorderSide(color: Colors.red.shade300, width: 1.5)
                                : BorderSide(color: Colors.grey.shade200),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header row
                                Row(
                                  children: [
                                    if (isWichtig) ...[
                                      Icon(Icons.star, size: 16, color: Colors.red.shade600),
                                      const SizedBox(width: 4),
                                    ],
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(icon, size: 13, color: color),
                                          const SizedBox(width: 4),
                                          Text(
                                            _getKategorieLabels()[kategorie] ?? kategorie,
                                            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      notiz['created_at'] != null
                                          ? df.format(DateTime.tryParse(notiz['created_at']) ?? DateTime.now())
                                          : '',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                    ),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () => _deleteNotiz(notiz['id'] is int ? notiz['id'] : int.parse(notiz['id'].toString())),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Icon(Icons.delete_outline, size: 16, color: Colors.red.shade300),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Note text
                                SelectableText(
                                  notiz['notiz']?.toString() ?? '',
                                  style: const TextStyle(fontSize: 13, height: 1.4),
                                ),
                                const SizedBox(height: 6),
                                // Author
                                Text(
                                  AppLocalizations.of(context).fromAuthor(notiz['erstellt_von_name'] ?? AppLocalizations.of(context).unknown, notiz['erstellt_von_nummer'] ?? ''),
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
        // Footer with count
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border(top: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(context).notesCountInfo(_notizen.length),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Zaehl-Plakette im Kopf des Termine-Reiters.
  ///
  /// ⚠️ Der Name stammt aus dem Tickets-Reiter, der am 01.09.2026 entfernt
  /// wurde — der Termine-Reiter benutzt sie mit.
  Widget _buildTicketStatChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('$label: $count', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }

  // ==================== TERMINE TAB ====================

  Future<void> _loadMemberTermine() async {
    setState(() => _isLoadingTermine = true);
    try {
      final result = await _terminService.getAllTermine(participantId: widget.user.id);
      if (mounted && result['success'] == true) {
        final termineList = result['termine'] as List? ?? [];
        setState(() {
          _memberTermine = termineList.map((t) => Termin.fromJson(t)).toList();
          _isLoadingTermine = false;
        });
      } else {
        if (mounted) setState(() => _isLoadingTermine = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingTermine = false);
    }
  }

  Widget _buildTermineTab() {
    final df = DateFormat('dd.MM.yyyy HH:mm', 'de_DE');
    final dateOnly = DateFormat('dd.MM.yyyy', 'de_DE');
    final timeOnly = DateFormat('HH:mm', 'de_DE');

    if (_isLoadingTermine) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_memberTermine.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context).noAppointmentsAvailable, style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    // Split into upcoming and past
    final now = DateTime.now();
    final upcoming = _memberTermine.where((t) => t.terminDate.isAfter(now)).toList();
    final past = _memberTermine.where((t) => !t.terminDate.isAfter(now)).toList();

    return Column(
      children: [
        // Stats bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            border: Border(bottom: BorderSide(color: Colors.purple.shade200)),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_month, size: 18, color: Colors.purple.shade700),
              const SizedBox(width: 8),
              Text(AppLocalizations.of(context).appointmentsCount(_memberTermine.length), style: TextStyle(fontWeight: FontWeight.w600, color: Colors.purple.shade700)),
              const Spacer(),
              _buildTicketStatChip(AppLocalizations.of(context).upcomingShort, upcoming.length, Colors.blue),
              const SizedBox(width: 8),
              _buildTicketStatChip(AppLocalizations.of(context).pastShort, past.length, Colors.grey),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: _loadMemberTermine,
                tooltip: AppLocalizations.of(context).refresh,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
        // Termine list
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (upcoming.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(AppLocalizations.of(context).upcomingAppointments, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.blue.shade700)),
                ),
                ...upcoming.map((t) => _buildTerminCard(t, df, dateOnly, timeOnly)),
                const SizedBox(height: 16),
              ],
              if (past.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(AppLocalizations.of(context).pastAppointments, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey.shade600)),
                ),
                ...past.map((t) => _buildTerminCard(t, df, dateOnly, timeOnly, isPast: true)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTerminCard(Termin termin, DateFormat df, DateFormat dateOnly, DateFormat timeOnly, {bool isPast = false}) {
    final catColor = termin.categoryColor;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isPast ? 0 : 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: isPast ? Colors.grey.shade200 : catColor.withValues(alpha: 0.3)),
      ),
      color: isPast ? Colors.grey.shade50 : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Category + Status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(termin.categoryDisplay, style: TextStyle(fontSize: 11, color: catColor, fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                if (termin.status == 'cancelled')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(AppLocalizations.of(context).cancelledStatus, style: TextStyle(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Title
            Text(termin.title, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: isPast ? Colors.grey.shade600 : null)),
            if (termin.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(termin.description, style: TextStyle(fontSize: 12, color: Colors.grey.shade600), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 8),
            // Date + Time + Location
            Row(
              children: [
                Icon(Icons.calendar_today, size: 13, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(dateOnly.format(termin.terminDate), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                const SizedBox(width: 12),
                Icon(Icons.access_time, size: 13, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text('${timeOnly.format(termin.terminDate)} - ${timeOnly.format(termin.terminEndTime)}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                if (termin.location.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.location_on, size: 13, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Flexible(child: Text(termin.location, style: TextStyle(fontSize: 11, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis)),
                ],
              ],
            ),
            // Participants + linked ticket
            if (termin.totalParticipants != null || termin.ticketSubject != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  if (termin.totalParticipants != null) ...[
                    Icon(Icons.group, size: 13, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(AppLocalizations.of(context).confirmedOfTotal(termin.confirmedCount ?? 0, termin.totalParticipants ?? 0), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                  if (termin.ticketSubject != null) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.confirmation_number, size: 13, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Flexible(child: Text(termin.ticketSubject!, style: TextStyle(fontSize: 11, color: Colors.grey.shade500), overflow: TextOverflow.ellipsis)),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
