import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../services/logger_service.dart';
import 'arbeitsagentur_screen.dart';

final _log = LoggerService();

class NetzwerkScreen extends StatefulWidget {
  const NetzwerkScreen({super.key});

  @override
  State<NetzwerkScreen> createState() => _NetzwerkScreenState();
}

class _NetzwerkScreenState extends State<NetzwerkScreen> {
  final _apiService = ApiService();

  // Sub-view selectat: null = main, altfel detalii modul
  String? _subview;

  // Date generice per modul (încărcate din DB)
  final Map<String, List<Map<String, dynamic>>> _moduleData = {};
  final Map<String, List<Map<String, dynamic>>> _moduleStats = {};
  final Map<String, bool> _moduleLoading = {};
  final Map<String, String?> _moduleFilter = {};

  /// Încarcă datele unui modul din API
  Future<void> _loadModuleData(String moduleKey, {String? filter}) async {
    setState(() {
      _moduleLoading[moduleKey] = true;
      _moduleFilter[moduleKey] = filter;
    });

    try {
      Map<String, dynamic> result;
      switch (moduleKey) {
        case 'behoerden':
          result = await _apiService.getBehoerden(kategorie: filter);
          break;
        case 'krankenhaeuser':
          result = await _apiService.getKrankenhaeuser(typ: filter);
          break;
        case 'praxen':
          result = await _apiService.getPraxen(kategorie: filter);
          break;
        case 'drogerie':
          result = await _apiService.getDrogerien(typ: filter);
          break;
        case 'maerkte':
          result = await _apiService.getMaerkte(typ: filter);
          break;
        case 'krankenkasse':
          result = await _apiService.getKrankenkassen(typ: filter);
          break;
        default:
          result = {'success': false, 'message': 'Unbekanntes Modul'};
      }

      if (result['success'] == true) {
        // Numele listei principale din răspunsul API
        final dataKey = _getApiDataKey(moduleKey);
        setState(() {
          _moduleData[moduleKey] = List<Map<String, dynamic>>.from(result[dataKey] ?? []);
          _moduleStats[moduleKey] = List<Map<String, dynamic>>.from(result['stats'] ?? []);
          _moduleLoading[moduleKey] = false;
        });
        _log.debug('${_moduleData[moduleKey]!.length} Einträge geladen: $moduleKey', tag: 'STADT');
      } else {
        setState(() => _moduleLoading[moduleKey] = false);
        _log.error('Fehler $moduleKey: ${result['message']}', tag: 'STADT');
      }
    } catch (e) {
      setState(() => _moduleLoading[moduleKey] = false);
      _log.error('API Fehler $moduleKey: $e', tag: 'STADT');
    }
  }

  /// Numele cheii de date din răspunsul API
  String _getApiDataKey(String moduleKey) {
    switch (moduleKey) {
      case 'krankenkasse': return 'krankenkassen';
      default: return moduleKey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_subview == 'arbeitsagentur') {
      return ArbeitsagenturScreen(
        apiService: _apiService,
        onBack: () => setState(() => _subview = 'behoerden'),
      );
    }
    if (_subview != null) {
      return _buildModuleDetailView(_subview!);
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.location_city, size: 32, color: Colors.indigo.shade700),
              const SizedBox(width: 12),
              Text(
                tr('Netzwerk', 'Rețea'),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Rândul 1: 3 carduri (Behörden, Krankenhäuser, Praxen)
          Expanded(
            flex: 1,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildMainCard(
                    key: 'behoerden',
                    icon: Icons.account_balance,
                    title: tr('Behörden', 'Autorități'),
                    subtitle: tr('Ämter, Verwaltung, Bürgerservice',
                        'Oficii, administrație, servicii pentru cetățeni'),
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMainCard(
                    key: 'krankenhaeuser',
                    icon: Icons.local_hospital,
                    title: tr('Krankenhäuser', 'Spitale'),
                    subtitle: tr('Kliniken, Notaufnahme, Stationen',
                        'Clinici, urgențe, secții'),
                    color: Colors.red.shade700,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMainCard(
                    key: 'praxen',
                    icon: Icons.medical_services,
                    title: tr('Praxen', 'Cabinete medicale'),
                    subtitle: tr('Ärzte, Zahnärzte, Fachärzte',
                        'Medici, stomatologi, medici specialiști'),
                    color: Colors.teal.shade700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Rândul 2: 3 carduri (Drogerie, Märkte, Krankenkasse)
          Expanded(
            flex: 1,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildMainCard(
                    key: 'drogerie',
                    icon: Icons.local_pharmacy,
                    title: tr('Drogerie', 'Drogherie'),
                    subtitle: tr('Apotheken, Drogerien, Gesundheit',
                        'Farmacii, drogherii, sănătate'),
                    color: Colors.pink.shade700,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMainCard(
                    key: 'maerkte',
                    icon: Icons.store,
                    title: tr('Märkte', 'Magazine'),
                    subtitle: tr('Supermärkte, Wochenmärkte, Einzelhandel',
                        'Supermarketuri, piețe săptămânale, comerț cu amănuntul'),
                    color: Colors.orange.shade700,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMainCard(
                    key: 'krankenkasse',
                    icon: Icons.health_and_safety,
                    title: tr('Krankenkasse', 'Casa de sănătate'),
                    subtitle: tr('Gesetzliche, Private Krankenversicherung',
                        'Asigurare de sănătate publică, privată'),
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Card clickabil pentru fiecare modul pe pagina principală
  Widget _buildMainCard({
    required String key,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _subview = key),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  // Zeilen begrenzt: auf dem Telefon stehen drei Karten
                  // nebeneinander, längere (rumänische) Texte liefen unten hinaus.
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: Colors.grey.shade400, size: 16),
                ],
              ),
              const Divider(height: 24),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 40, color: Colors.grey.shade300),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Detail view generic pentru fiecare modul - încarcă date din DB
  Widget _buildModuleDetailView(String moduleKey) {
    // Behörden: doar carduri speciale (Arbeitsagentur etc.), fără date din DB
    if (moduleKey == 'behoerden') {
      return _buildBehoerdenDetailView();
    }

    final config = _moduleConfigs[moduleKey]!;
    final data = _moduleData[moduleKey] ?? [];
    final stats = _moduleStats[moduleKey] ?? [];
    final isLoading = _moduleLoading[moduleKey] ?? false;
    final currentFilter = _moduleFilter[moduleKey];

    // Încarcă datele la prima deschidere
    if (data.isEmpty && !isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadModuleData(moduleKey));
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header cu buton back
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _subview = null;
                  _moduleFilter[moduleKey] = null;
                }),
                tooltip: tr('Zurück', 'Înapoi'),
              ),
              const SizedBox(width: 8),
              Icon(config.icon, size: 32, color: config.color),
              const SizedBox(width: 12),
              Text(
                config.title,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              // Total badge
              if (!isLoading && data.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: config.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    tr('${data.length} Einträge', '${data.length} intrări'),
                    style: TextStyle(
                      color: config.color,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Filter chips pe categorii/tipuri
          if (!isLoading && stats.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildFilterChip(moduleKey, null, tr('Alle', 'Toate'), Icons.list, config.color, currentFilter),
                  const SizedBox(width: 8),
                  ...stats.map((stat) {
                    final filterKey = stat[config.filterField] as String? ?? '';
                    final label = stat[config.filterLabelField] ?? filterKey;
                    final count = stat['anzahl'] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildFilterChip(
                        moduleKey, filterKey, '$label ($count)',
                        Icons.label, config.color, currentFilter,
                      ),
                    );
                  }),
                ],
              ),
            ),
          const SizedBox(height: 16),
          // Conținut principal
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : data.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(config.icon, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              tr('Keine Einträge gefunden', 'Nu s-au găsit intrări'),
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : _buildDataGrid(moduleKey, data, config),
          ),
        ],
      ),
    );
  }

  /// Behörden detail view — doar carduri speciale (fără date din DB)
  Widget _buildBehoerdenDetailView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _subview = null),
                tooltip: tr('Zurück', 'Înapoi'),
              ),
              const SizedBox(width: 8),
              Icon(Icons.account_balance, size: 32, color: Colors.blue.shade700),
              const SizedBox(width: 12),
              Text(
                tr('Behörden', 'Autorități'),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Arbeitsagentur card (Logo: roter Punkt mit Dreieck)
          _buildSpecialBehoerdenCard(
            icon: Icons.change_history,
            title: 'Bundesagentur für Arbeit',
            subtitle: tr('Mindestlohn · Zeitarbeit Tarife · Leistungen 2026',
                'Salariu minim · tarife muncă temporară · prestații 2026'),
            color: const Color(0xFFE30613), // BA corporate red
            onTap: () => setState(() => _subview = 'arbeitsagentur'),
          ),
        ],
      ),
    );
  }

  /// Card special clickabil (Arbeitsagentur etc.) în detail view
  Widget _buildSpecialBehoerdenCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey.shade400, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// Filter chip generic
  Widget _buildFilterChip(
    String moduleKey, String? filterValue, String label,
    IconData icon, Color color, String? currentFilter,
  ) {
    final isSelected = currentFilter == filterValue;
    return FilterChip(
      selected: isSelected,
      label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : null)),
      selectedColor: color,
      checkmarkColor: Colors.white,
      onSelected: (_) => _loadModuleData(moduleKey, filter: filterValue),
    );
  }

  /// Grid de carduri generic (3 per rând, scrollabil)
  Widget _buildDataGrid(String moduleKey, List<Map<String, dynamic>> data, _ModuleConfig config) {
    // Grupare pe categorie/tip dacă nu e filtrat
    final currentFilter = _moduleFilter[moduleKey];
    if (currentFilter == null && data.length > 6) {
      return _buildGroupedGrid(moduleKey, data, config);
    }

    return SingleChildScrollView(
      child: _buildSimpleGrid(data, config),
    );
  }

  /// Grid grupat pe categorie/tip
  Widget _buildGroupedGrid(String moduleKey, List<Map<String, dynamic>> data, _ModuleConfig config) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in data) {
      final group = item[config.filterField] as String? ?? 'Sonstige';
      grouped.putIfAbsent(group, () => []).add(item);
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: grouped.entries.map((entry) {
          // 'Sonstige' bleibt Gruppierungsschlüssel; übersetzt wird nur die Anzeige.
          final groupLabel = entry.value.first[config.filterLabelField] as String? ??
              (entry.key == 'Sonstige' ? tr('Sonstige', 'Altele') : entry.key);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Grup header
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.label, size: 18, color: config.color),
                    const SizedBox(width: 8),
                    Text(
                      '$groupLabel (${entry.value.length})',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: config.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Divider(color: config.color.withValues(alpha: 0.3))),
                  ],
                ),
              ),
              _buildSimpleGrid(entry.value, config),
              const SizedBox(height: 12),
            ],
          );
        }).toList(),
      ),
    );
  }

  /// Grid simplu de carduri (3 per rând)
  Widget _buildSimpleGrid(List<Map<String, dynamic>> items, _ModuleConfig config) {
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += 3) {
      final rowItems = items.sublist(i, i + 3 > items.length ? items.length : i + 3);
      rows.add(
        SizedBox(
          height: 110,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...rowItems.map((item) => Expanded(child: _buildItemCard(item, config))),
              for (var j = rowItems.length; j < 3; j++)
                const Expanded(child: SizedBox()),
            ],
          ),
        ),
      );
      if (i + 3 < items.length) rows.add(const SizedBox(height: 8));
    }
    return Column(children: rows);
  }

  /// Card individual generic
  Widget _buildItemCard(Map<String, dynamic> item, _ModuleConfig config) {
    final name = item['name'] as String? ?? item['fachrichtung'] as String? ?? item['umgangsname'] as String? ?? '';
    final subtitle = item['beschreibung'] as String? ?? item['standort'] as String? ?? '';
    final website = item['website'] as String? ?? '';
    final extra = _getExtraInfo(item, config.key);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nume
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: config.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(config.icon, color: config.color, size: 14),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Subtitle / extra info
            if (extra.isNotEmpty)
              Text(
                extra,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            if (subtitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  subtitle,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            if (website.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  website.replaceAll('https://', '').replaceAll('http://', ''),
                  style: TextStyle(fontSize: 9, color: Colors.blue.shade300),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Info extra per modul
  String _getExtraInfo(Map<String, dynamic> item, String moduleKey) {
    switch (moduleKey) {
      case 'krankenhaeuser':
        return item['typ_label'] as String? ?? '';
      case 'praxen':
        return item['umgangsname'] as String? ?? '';
      case 'drogerie':
      case 'maerkte':
        final filialen = item['filialen_anzahl'];
        return filialen != null ? tr('$filialen Filialen', '$filialen filiale') : '';
      case 'krankenkasse':
        final zusatz = item['zusatzbeitrag'];
        final bw = item['bundesweit'] == 1 || item['bundesweit'] == true;
        final parts = <String>[];
        if (zusatz != null) parts.add('$zusatz%');
        if (bw) parts.add(tr('bundesweit', 'la nivel național'));
        return parts.join(' · ');
      default:
        return '';
    }
  }

  /// Configurație pentru fiecare modul
  ///
  /// Getter statt `static final`: die Titel kommen aus tr() und müssen bei
  /// jedem Aufbau in der aktuell gewählten Sprache entstehen.
  static Map<String, _ModuleConfig> get _moduleConfigs => {
    'behoerden': _ModuleConfig(
      key: 'behoerden',
      icon: Icons.account_balance,
      title: tr('Behörden', 'Autorități'),
      color: Colors.blue.shade700,
      filterField: 'kategorie',
      filterLabelField: 'kategorie',
    ),
    'krankenhaeuser': _ModuleConfig(
      key: 'krankenhaeuser',
      icon: Icons.local_hospital,
      title: tr('Krankenhäuser', 'Spitale'),
      color: Colors.red.shade700,
      filterField: 'typ',
      filterLabelField: 'typ_label',
    ),
    'praxen': _ModuleConfig(
      key: 'praxen',
      icon: Icons.medical_services,
      title: tr('Praxen', 'Cabinete medicale'),
      color: Colors.teal.shade700,
      filterField: 'kategorie',
      filterLabelField: 'kategorie',
    ),
    'drogerie': _ModuleConfig(
      key: 'drogerie',
      icon: Icons.local_pharmacy,
      title: tr('Drogerie', 'Drogherie'),
      color: Colors.pink.shade700,
      filterField: 'typ',
      filterLabelField: 'typ_label',
    ),
    'maerkte': _ModuleConfig(
      key: 'maerkte',
      icon: Icons.store,
      title: tr('Märkte', 'Magazine'),
      color: Colors.orange.shade700,
      filterField: 'typ',
      filterLabelField: 'typ_label',
    ),
    'krankenkasse': _ModuleConfig(
      key: 'krankenkasse',
      icon: Icons.health_and_safety,
      title: tr('Krankenkassen', 'Asigurări de sănătate'),
      color: Colors.green.shade700,
      filterField: 'typ',
      filterLabelField: 'typ_label',
    ),
  };
}

class _ModuleConfig {
  final String key;
  final IconData icon;
  final String title;
  final Color color;
  final String filterField;
  final String filterLabelField;

  const _ModuleConfig({
    required this.key,
    required this.icon,
    required this.title,
    required this.color,
    required this.filterField,
    required this.filterLabelField,
  });
}
