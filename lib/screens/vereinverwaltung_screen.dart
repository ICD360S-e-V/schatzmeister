import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../l10n/app_localizations.dart';
import 'behoerden_screen.dart';
import 'stifter_helfen_screen.dart';
import 'google_nonprofit_screen.dart';
import 'microsoft_nonprofit_screen.dart';
import 'vr_bank_screen.dart';
import 'gls_bank_screen.dart';
import 'ordnungsmassnahmen_screen.dart';
import 'deutschepost_screen.dart';

class VereinverwaltungScreen extends StatefulWidget {
  final ApiService apiService;
  final List<User> users;
  final Color Function(String role) getRoleColor;
  final String Function(String role) getRoleText;

  const VereinverwaltungScreen({
    super.key,
    required this.apiService,
    required this.users,
    required this.getRoleColor,
    required this.getRoleText,
  });

  @override
  State<VereinverwaltungScreen> createState() => _VereinverwaltungScreenState();
}

class _VereinverwaltungScreenState extends State<VereinverwaltungScreen> {
  String _vereinSubview = 'overview';
  List<Map<String, dynamic>> _vereinData = [];
  bool _isLoading = true;

  // Platform Aufgaben counts
  int _stifterHelfenOpenAufgaben = 0;
  int _googleNonprofitOpenAufgaben = 0;
  int _microsoftNonprofitOpenAufgaben = 0;

  @override
  void initState() {
    super.initState();
    _loadVereinData();
    _loadStifterHelfenAufgaben();
    _loadGoogleNonprofitAufgaben();
    _loadMicrosoftNonprofitAufgaben();
  }

  Future<void> _loadVereinData() async {
    try {
      final result = await widget.apiService.getVereinverwaltung();
      if (result['success'] == true && mounted) {
        setState(() {
          _vereinData = List<Map<String, dynamic>>.from(result['data'] ?? []);
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStifterHelfenAufgaben() async {
    try {
      final result = await widget.apiService.getPlatformAufgaben('stifter-helfen');
      if (result['success'] == true && mounted) {
        final aufgaben = List<Map<String, dynamic>>.from(result['aufgaben'] ?? []);
        final open = aufgaben.where((a) => a['erledigt'] != true && a['erledigt'] != 1).length;
        setState(() => _stifterHelfenOpenAufgaben = open);
      }
    } catch (_) {}
  }

  Future<void> _loadGoogleNonprofitAufgaben() async {
    try {
      final result = await widget.apiService.getPlatformAufgaben('google-nonprofit');
      if (result['success'] == true && mounted) {
        final aufgaben = List<Map<String, dynamic>>.from(result['aufgaben'] ?? []);
        final open = aufgaben.where((a) => a['erledigt'] != true && a['erledigt'] != 1).length;
        setState(() => _googleNonprofitOpenAufgaben = open);
      }
    } catch (_) {}
  }

  Future<void> _loadMicrosoftNonprofitAufgaben() async {
    try {
      final result = await widget.apiService.getPlatformAufgaben('microsoft-nonprofit');
      if (result['success'] == true && mounted) {
        final aufgaben = List<Map<String, dynamic>>.from(result['aufgaben'] ?? []);
        final open = aufgaben.where((a) => a['erledigt'] != true && a['erledigt'] != 1).length;
        setState(() => _microsoftNonprofitOpenAufgaben = open);
      }
    } catch (_) {}
  }

  List<Map<String, dynamic>> _getByKategorie(String kategorie) {
    return _vereinData.where((e) => e['kategorie'] == kategorie).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_vereinSubview == 'behoerden') {
      return BehoerdenScreen(
        apiService: widget.apiService,
        onBack: () => setState(() => _vereinSubview = 'overview'),
      );
    } else if (_vereinSubview == 'partner') {
      return _buildPartnerDetailView();
    } else if (_vereinSubview == 'notar') {
      return _buildNotarDetailView();
    } else if (_vereinSubview == 'banken') {
      return _buildBankenDetailView();
    } else if (_vereinSubview == 'vorstand') {
      return _buildVorstandDetailView();
    } else if (_vereinSubview == 'deutschepost') {
      return DeutschePostScreen(
        apiService: widget.apiService,
        onBack: () => setState(() => _vereinSubview = 'partner'),
      );
    } else if (_vereinSubview == 'stifter-helfen') {
      return StifterHelfenScreen(
        apiService: widget.apiService,
        onBack: () {
          _loadStifterHelfenAufgaben();
          setState(() => _vereinSubview = 'it-beschaffung');
        },
      );
    } else if (_vereinSubview == 'google-nonprofit') {
      return GoogleNonprofitScreen(
        apiService: widget.apiService,
        onBack: () {
          _loadGoogleNonprofitAufgaben();
          setState(() => _vereinSubview = 'it-beschaffung');
        },
      );
    } else if (_vereinSubview == 'microsoft-nonprofit') {
      return MicrosoftNonprofitScreen(
        apiService: widget.apiService,
        onBack: () {
          _loadMicrosoftNonprofitAufgaben();
          setState(() => _vereinSubview = 'it-beschaffung');
        },
      );
    } else if (_vereinSubview == 'hetzner') {
      return _buildHetznerDetailView();
    } else if (_vereinSubview == 'inwx') {
      return _buildInwxDetailView();
    } else if (_vereinSubview == 'volksbank') {
      return VrBankScreen(
        onBack: () => setState(() => _vereinSubview = 'banken'),
      );
    } else if (_vereinSubview == 'gls') {
      return GlsBankScreen(
        onBack: () => setState(() => _vereinSubview = 'banken'),
      );
    } else if (_vereinSubview == 'it-beschaffung') {
      return _buildITBeschaffungDetailView();
    } else if (_vereinSubview == 'stifter-helfen') {
      return _buildStifterHelfenDetailView();
    } else if (_vereinSubview == 'ordnungsmassnahmen') {
      return OrdnungsmassnahmenScreen(
        users: widget.users,
        onBack: () => setState(() => _vereinSubview = 'overview'),
      );
    }

    final l = AppLocalizations.of(context);

    // Default overview
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.apartment, size: 32, color: Colors.blue.shade700),
              const SizedBox(width: 12),
              Text(
                l.vereinverwaltungTitle,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 3-column grid
          Expanded(
            child: Column(
              children: [
                // Row 1
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildBehoerdenCard()),
                      const SizedBox(width: 16),
                      Expanded(child: _buildPartnerCard()),
                      const SizedBox(width: 16),
                      Expanded(child: _buildNotarCard()),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Row 2
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildBankenCard()),
                      const SizedBox(width: 16),
                      Expanded(child: _buildVorstandCard()),
                      const SizedBox(width: 16),
                      Expanded(child: _buildOrdnungsmassnahmenCard()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== CARD BUILDERS ====================

  Widget _buildBehoerdenCard() {
    final l = AppLocalizations.of(context);
    return _buildClickableCard(
      icon: Icons.account_balance,
      title: l.authoritiesAndRegisters,
      color: Colors.blue,
      subtitle: l.authoritiesSubtitle,
      onTap: () => setState(() => _vereinSubview = 'behoerden'),
    );
  }

  Widget _buildPartnerCard() {
    final l = AppLocalizations.of(context);
    return _buildClickableCard(
      icon: Icons.handshake,
      title: l.partnersAndProviders,
      color: Colors.green,
      subtitle: l.partnersSubtitle,
      onTap: () => setState(() => _vereinSubview = 'partner'),
    );
  }

  Widget _buildNotarCard() {
    final l = AppLocalizations.of(context);
    return _buildClickableCard(
      icon: Icons.gavel,
      title: l.notarTitle,
      color: Colors.deepOrange,
      subtitle: l.notarSubtitle,
      onTap: () => setState(() => _vereinSubview = 'notar'),
    );
  }

  Widget _buildBankenCard() {
    final l = AppLocalizations.of(context);
    return _buildClickableCard(
      icon: Icons.account_balance,
      title: l.banksTitle,
      color: Colors.amber,
      subtitle: l.banksSubtitle,
      onTap: () => setState(() => _vereinSubview = 'banken'),
    );
  }

  Widget _buildVorstandCard() {
    final l = AppLocalizations.of(context);
    return _buildClickableCard(
      icon: Icons.people,
      title: l.boardTitle,
      color: Colors.purple,
      subtitle: l.boardSubtitle,
      onTap: () => setState(() => _vereinSubview = 'vorstand'),
    );
  }

  Widget _buildOrdnungsmassnahmenCard() {
    final l = AppLocalizations.of(context);
    return _buildClickableCard(
      icon: Icons.gavel,
      title: l.disciplinaryMeasures,
      color: Colors.red,
      subtitle: l.disciplinarySubtitle,
      onTap: () => setState(() => _vereinSubview = 'ordnungsmassnahmen'),
    );
  }

  // ==================== DETAIL VIEWS ====================

  Widget _buildPartnerDetailView() {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with back button
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _vereinSubview = 'overview'),
                tooltip: l.backToOverview,
              ),
              const SizedBox(width: 8),
              Icon(Icons.handshake, size: 32, color: Colors.green.shade700),
              const SizedBox(width: 12),
              Text(
                l.partnersAndProviders,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildDeutschePostCard()),
                const SizedBox(width: 16),
                Expanded(child: _buildHetznerCard()),
                const SizedBox(width: 16),
                Expanded(child: _buildInwxCard()),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildITBeschaffungCard()),
                const SizedBox(width: 16),
                const Expanded(child: SizedBox()), // Placeholder
                const SizedBox(width: 16),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeutschePostCard() {
    final l = AppLocalizations.of(context);
    return _buildClickableCard(
      icon: Icons.local_shipping,
      title: l.deutschePostTitle,
      color: Colors.yellow.shade700,
      subtitle: l.deutschePostSubtitle,
      onTap: () => setState(() => _vereinSubview = 'deutschepost'),
    );
  }

  Widget _buildHetznerCard() {
    final l = AppLocalizations.of(context);
    return _buildClickableCard(
      icon: Icons.dns,
      title: 'Hetzner',
      color: Colors.red,
      subtitle: l.hetznerSubtitle,
      onTap: () => setState(() => _vereinSubview = 'hetzner'),
    );
  }

  Widget _buildInwxCard() {
    final l = AppLocalizations.of(context);
    return _buildClickableCard(
      icon: Icons.language,
      title: 'INWX',
      color: Colors.blueGrey,
      subtitle: l.inwxSubtitle,
      onTap: () => setState(() => _vereinSubview = 'inwx'),
    );
  }

  Widget _buildITBeschaffungCard() {
    final l = AppLocalizations.of(context);
    return _buildClickableCard(
      icon: Icons.computer,
      title: l.itProcurementPlatform,
      color: Colors.deepPurple,
      subtitle: l.itProcurementSubtitle,
      onTap: () => setState(() => _vereinSubview = 'it-beschaffung'),
    );
  }

  Widget _buildNotarDetailView() {
    final l = AppLocalizations.of(context);
    final notarEntries = _getByKategorie('notar');

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _vereinSubview = 'overview'),
                tooltip: l.backToOverview,
              ),
              const SizedBox(width: 8),
              Icon(Icons.gavel, size: 32, color: Colors.deepOrange.shade700),
              const SizedBox(width: 12),
              Text(
                l.notarTitle,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : notarEntries.isEmpty
                    ? Center(child: Text(l.noNotarData))
                    : ListView.builder(
                        itemCount: notarEntries.length,
                        itemBuilder: (context, index) {
                          final n = notarEntries[index];
                          return _buildContactCard(
                            icon: Icons.gavel,
                            color: Colors.deepOrange,
                            name: n['name'] ?? '',
                            name2: n['name2'],
                            strasse: n['strasse'],
                            hausnummer: n['hausnummer'],
                            plz: n['plz'],
                            ort: n['ort'],
                            telefon: n['telefon'],
                            fax: n['fax'],
                            email: n['email'],
                            website: n['website'],
                            notizen: n['notizen'],
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankenDetailView() {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _vereinSubview = 'overview'),
                tooltip: l.backToOverview,
              ),
              const SizedBox(width: 8),
              Icon(Icons.account_balance, size: 32, color: Colors.amber.shade700),
              const SizedBox(width: 12),
              Text(
                l.banksTitle,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildVolksbankCard()),
                const SizedBox(width: 16),
                Expanded(child: _buildGlsBankCard()),
                const SizedBox(width: 16),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVolksbankCard() {
    final l = AppLocalizations.of(context);
    return _buildClickableCard(
      icon: Icons.account_balance,
      title: 'VR Bank',
      color: Colors.blue,
      subtitle: l.vrBankSubtitle,
      onTap: () => setState(() => _vereinSubview = 'volksbank'),
    );
  }

  Widget _buildGlsBankCard() {
    final l = AppLocalizations.of(context);
    return _buildClickableCard(
      icon: Icons.eco,
      title: 'GLS Bank',
      color: Colors.green,
      subtitle: l.glsBankSubtitle,
      onTap: () => setState(() => _vereinSubview = 'gls'),
    );
  }

  Widget _buildVorstandDetailView() {
    final l = AppLocalizations.of(context);
    final adminUsers = widget.users.where((u) =>
        ['vorsitzer', 'schatzmeister', 'kassierer', 'mitgliedergrunder'].contains(u.role)
    ).toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _vereinSubview = 'overview'),
                tooltip: l.backToOverview,
              ),
              const SizedBox(width: 8),
              Icon(Icons.people, size: 32, color: Colors.purple.shade700),
              const SizedBox(width: 12),
              Text(
                l.boardTitle,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: adminUsers.isEmpty
                ? Center(child: Text(l.noBoardMembers))
                : ListView.builder(
                    itemCount: adminUsers.length,
                    itemBuilder: (context, index) {
                      final user = adminUsers[index];
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: widget.getRoleColor(user.role),
                            child: Text(
                              user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${widget.getRoleText(user.role)} (${user.mitgliedernummer})'),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: user.isActive ? Colors.green.shade100 : Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              user.isActive ? l.active : user.status,
                              style: TextStyle(
                                fontSize: 12,
                                color: user.isActive ? Colors.green.shade800 : Colors.orange.shade800,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHetznerDetailView() {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _vereinSubview = 'partner'),
                tooltip: l.backToPartner,
              ),
              const SizedBox(width: 8),
              Icon(Icons.dns, size: 32, color: Colors.red.shade700),
              const SizedBox(width: 12),
              const Text(
                'Hetzner',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _buildInfoCard(
              icon: Icons.cloud,
              title: l.hetznerServices,
              color: Colors.red,
              items: [
                'Dedicated Server: 148.251.68.9 (Proxmox)',
                'Cloud Storage',
                'Backup Solutions',
                'Rechnungen & Verträge',
                'Support-Tickets',
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInwxDetailView() {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _vereinSubview = 'partner'),
                tooltip: l.backToPartner,
              ),
              const SizedBox(width: 8),
              Icon(Icons.language, size: 32, color: Colors.blueGrey.shade700),
              const SizedBox(width: 12),
              const Text(
                'INWX',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _buildInfoCard(
              icon: Icons.dns,
              title: l.inwxDomainServices,
              color: Colors.blueGrey,
              items: [
                'Domain: icd360s.de',
                'DNS-Verwaltung',
                'SSL-Zertifikate',
                'E-Mail-Weiterleitungen',
                'Nameserver-Einstellungen',
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildITBeschaffungDetailView() {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with back button
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _vereinSubview = 'partner'),
                tooltip: l.backToPartner,
              ),
              const SizedBox(width: 8),
              Icon(Icons.computer, size: 32, color: Colors.deepPurple.shade700),
              const SizedBox(width: 12),
              Text(
                l.itProcurementPlatform,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Stifter-helfen Card (clickable)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildStifterHelfenClickableCard()),
                const SizedBox(width: 16),
                Expanded(child: _buildGoogleNonprofitClickableCard()),
                const SizedBox(width: 16),
                Expanded(child: _buildMicrosoftNonprofitClickableCard()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStifterHelfenClickableCard() {
    final l = AppLocalizations.of(context);
    return _buildClickableCard(
      icon: Icons.volunteer_activism,
      title: 'Stifter-helfen',
      color: Colors.deepPurple,
      subtitle: 'IT for Nonprofits - Software-Spenden',
      onTap: () => setState(() => _vereinSubview = 'stifter-helfen'),
      badge: _stifterHelfenOpenAufgaben > 0
          ? l.openTasksLabel(_stifterHelfenOpenAufgaben)
          : null,
      badgeColor: _stifterHelfenOpenAufgaben > 0 ? Colors.orange : null,
    );
  }

  Widget _buildGoogleNonprofitClickableCard() {
    final l = AppLocalizations.of(context);
    return _buildClickableCard(
      icon: Icons.cloud,
      title: 'Google for Nonprofits',
      color: Colors.blue,
      subtitle: 'Workspace, Ad Grants, YouTube',
      onTap: () => setState(() => _vereinSubview = 'google-nonprofit'),
      badge: _googleNonprofitOpenAufgaben > 0
          ? l.openTasksLabel(_googleNonprofitOpenAufgaben)
          : null,
      badgeColor: _googleNonprofitOpenAufgaben > 0 ? Colors.orange : null,
    );
  }

  Widget _buildMicrosoftNonprofitClickableCard() {
    final l = AppLocalizations.of(context);
    return _buildClickableCard(
      icon: Icons.window,
      title: 'Microsoft for Nonprofits',
      color: Colors.orange,
      subtitle: 'Microsoft 365, Azure, Dynamics',
      onTap: () => setState(() => _vereinSubview = 'microsoft-nonprofit'),
      badge: _microsoftNonprofitOpenAufgaben > 0
          ? l.openTasksLabel(_microsoftNonprofitOpenAufgaben)
          : null,
      badgeColor: _microsoftNonprofitOpenAufgaben > 0 ? Colors.orange : null,
    );
  }

  Widget _buildStifterHelfenDetailView() {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _vereinSubview = 'it-beschaffung'),
                tooltip: l.backToITDesc,
              ),
              const SizedBox(width: 8),
              Icon(Icons.volunteer_activism, size: 32, color: Colors.deepPurple.shade700),
              const SizedBox(width: 12),
              const Text(
                'Stifter-helfen.de',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoCard(
                    icon: Icons.card_giftcard,
                    title: l.softwareDonations,
                    color: Colors.deepPurple,
                    items: [
                      'Microsoft 365 (bis zu 90% Rabatt)',
                      'Adobe Creative Cloud (65% Rabatt)',
                      'Dropbox Business',
                      'Zoom Pro/Business',
                      'Slack',
                      'Canva Pro',
                      'Asana Business',
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _launchURL('https://www.stifter-helfen.de'),
                    icon: const Icon(Icons.open_in_new),
                    label: Text(l.openStifterHelfen),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== HELPER WIDGETS ====================

  Widget _buildClickableCard({
    required IconData icon,
    required String title,
    required Color color,
    required String subtitle,
    required VoidCallback onTap,
    String? badge,
    Color? badgeColor,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 32, color: color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              if (badge != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? Colors.orange).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: (badgeColor ?? Colors.orange).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.task_alt, size: 14, color: badgeColor ?? Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        badge,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: badgeColor ?? Colors.orange),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required Color color,
    required List<String> items,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 32, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle, size: 16, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(item, style: const TextStyle(fontSize: 14)),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required Color color,
    required String name,
    String? name2,
    String? strasse,
    String? hausnummer,
    String? plz,
    String? ort,
    String? telefon,
    String? fax,
    String? email,
    String? website,
    String? notizen,
  }) {
    final address = [
      if (strasse != null) '$strasse${hausnummer != null ? ' $hausnummer' : ''}',
      if (plz != null || ort != null) '${plz ?? ''} ${ort ?? ''}'.trim(),
    ].where((s) => s.isNotEmpty).join(', ');

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 28, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      if (name2 != null && name2.isNotEmpty)
                        Text(name2, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (address.isNotEmpty)
              _buildContactRow(Icons.location_on, address),
            if (telefon != null && telefon.isNotEmpty)
              _buildContactRow(Icons.phone, telefon),
            if (fax != null && fax.isNotEmpty)
              _buildContactRow(Icons.fax, 'Fax: $fax'),
            if (email != null && email.isNotEmpty)
              _buildContactRow(Icons.email, email),
            if (website != null && website.isNotEmpty)
              InkWell(
                onTap: () => _launchURL(website),
                child: _buildContactRow(Icons.language, website, isLink: true),
              ),
            if (notizen != null && notizen.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notes, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(notizen, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String text, {bool isLink = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: isLink ? Colors.blue : null,
                decoration: isLink ? TextDecoration.underline : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
