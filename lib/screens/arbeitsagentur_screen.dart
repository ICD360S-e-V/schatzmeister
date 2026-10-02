import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';

class ArbeitsagenturScreen extends StatefulWidget {
  final ApiService apiService;
  final VoidCallback onBack;

  const ArbeitsagenturScreen({
    super.key,
    required this.apiService,
    required this.onBack,
  });

  @override
  State<ArbeitsagenturScreen> createState() => _ArbeitsagenturScreenState();
}

class _ArbeitsagenturScreenState extends State<ArbeitsagenturScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                onPressed: widget.onBack,
                tooltip: tr('Zurück', 'Înapoi'),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.change_history, size: 32, color: Color(0xFFE30613)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('Bundesagentur für Arbeit', 'Bundesagentur für Arbeit (Agenția Federală de Muncă)'),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      tr('Mindestlohn · Zeitarbeit Tarife · Leistungen 2026', 'Salariu minim · Tarife muncă temporară · Prestații 2026'),
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Tabs
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.blue.shade700,
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey.shade700,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: [
                Tab(text: tr('Mindestlohn', 'Salariu minim')),
                Tab(text: tr('Zeitarbeit Tarife', 'Muncă temporară')),
                Tab(text: tr('Leistungen', 'Prestații')),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMindestlohnTab(),
                _buildZeitarbeitTab(),
                _buildLeistungenTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Tab 1: Mindestlohn ─────────────────────────────────────────────

  Widget _buildMindestlohnTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Big card with current Mindestlohn
          Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.euro, size: 48, color: Colors.green.shade700),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('Gesetzlicher Mindestlohn 2026', 'Salariul minim legal 2026'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tr('13,90 € brutto / Stunde', '13,90 € brut / oră'),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr('Gültig ab 01.01.2026 · +0,78 € gegenüber 2025 (13,12 €)', 'Valabil din 01.01.2026 · +0,78 € față de 2025 (13,12 €)'),
                          style: TextStyle(fontSize: 14, color: Colors.green.shade700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Info cards row
          Row(
            children: [
              Expanded(
                child: _infoCard(
                  icon: Icons.calendar_month,
                  title: tr('Monatslohn (Vollzeit)', 'Salariu lunar (normă întreagă)'),
                  value: tr('~2.411 € brutto', '~2.411 € brut'),
                  subtitle: tr('40 Std./Woche × 13,90 €', '40 ore/săpt. × 13,90 €'),
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _infoCard(
                  icon: Icons.money_off,
                  title: tr('Minijob-Grenze', 'Plafon minijob'),
                  value: tr('603,00 € / Monat', '603,00 € / lună'),
                  subtitle: tr('Angepasst an Mindestlohn', 'Ajustat la salariul minim'),
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _infoCard(
                  icon: Icons.people,
                  title: tr('Profitieren', 'Beneficiari'),
                  value: tr('> 6 Mio. Menschen', '> 6 mil. persoane'),
                  subtitle: tr('+190 € brutto/Monat', '+190 € brut/lună'),
                  color: Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Mindestlohn history table
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('Entwicklung des Mindestlohns', 'Evoluția salariului minim'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Table(
                    border: TableBorder.all(color: Colors.grey.shade300),
                    columnWidths: const {
                      0: FlexColumnWidth(2),
                      1: FlexColumnWidth(2),
                      2: FlexColumnWidth(1.5),
                    },
                    children: [
                      _tableHeaderRow([tr('Zeitraum', 'Perioadă'), tr('Stundenlohn', 'Salariu orar'), tr('Erhöhung', 'Creștere')]),
                      _tableRow([tr('Ab 01.01.2027', 'Din 01.01.2027'), '14,60 €', '+0,70 €'], highlight: true),
                      _tableRow([tr('Ab 01.01.2026', 'Din 01.01.2026'), '13,90 €', '+0,78 €'], highlight: true, current: true),
                      _tableRow([tr('Ab 01.01.2025', 'Din 01.01.2025'), '13,12 €', '+0,71 €']),
                      _tableRow([tr('Ab 01.01.2024', 'Din 01.01.2024'), '12,41 €', '+0,41 €']),
                      _tableRow([tr('Ab 01.01.2023', 'Din 01.01.2023'), '12,00 €', '+1,82 €']),
                      _tableRow([tr('Ab 01.10.2022', 'Din 01.10.2022'), '12,00 €', '+1,82 €']),
                      _tableRow([tr('Ab 01.07.2022', 'Din 01.07.2022'), '10,45 €', '+0,27 €']),
                      _tableRow([tr('Ab 01.01.2022', 'Din 01.01.2022'), '9,82 €', '+0,22 €']),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Next increase
          Card(
            color: Colors.blue.shade50,
            child: ListTile(
              leading: Icon(Icons.trending_up, color: Colors.blue.shade700, size: 32),
              title: Text(
                tr('Nächste Erhöhung: 01.01.2027', 'Următoarea creștere: 01.01.2027'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(tr('14,60 € brutto / Stunde (+0,70 €)', '14,60 € brut / oră (+0,70 €)')),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─── Tab 2: Zeitarbeit Tarife ───────────────────────────────────────

  Widget _buildZeitarbeitTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info banner
          Card(
            color: Colors.indigo.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.indigo.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('Einheitliches GVP/DGB-Tarifwerk ab 01.01.2026', 'Contract colectiv unitar GVP/DGB din 01.01.2026'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr(
                            'Die bisherigen BAP- und iGZ-Tarifverträge werden durch ein gemeinsames Tarifwerk ersetzt. '
                            'Ca. 560.000 Beschäftigte erhalten einheitliche Standards.',
                            'Contractele colective BAP și iGZ de până acum sunt înlocuite de un contract colectiv comun. '
                            'Aprox. 560.000 de angajați primesc standarde unitare.',
                          ),
                          style: TextStyle(fontSize: 13, color: Colors.indigo.shade700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Increase steps
          Row(
            children: [
              Expanded(
                child: _infoCard(
                  icon: Icons.calendar_today,
                  title: tr('Ab 01.01.2026', 'Din 01.01.2026'),
                  value: '+2,99 %',
                  subtitle: tr('1. Stufe', 'Etapa 1'),
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _infoCard(
                  icon: Icons.calendar_today,
                  title: tr('Ab 01.09.2026', 'Din 01.09.2026'),
                  value: '+2,50 %',
                  subtitle: tr('2. Stufe', 'Etapa 2'),
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _infoCard(
                  icon: Icons.calendar_today,
                  title: tr('Ab 01.04.2027', 'Din 01.04.2027'),
                  value: '+3,50 %',
                  subtitle: tr('3. Stufe', 'Etapa 3'),
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Entgelttabelle ab 01.01.2026
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.table_chart, color: Colors.indigo.shade700),
                      const SizedBox(width: 8),
                      Text(
                        tr('Entgelttabelle ab 01.01.2026', 'Grila salarială din 01.01.2026'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tr('Gültig bis 31.08.2026', 'Valabilă până la 31.08.2026'),
                          style: TextStyle(fontSize: 11, color: Colors.green.shade800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Table(
                    border: TableBorder.all(color: Colors.grey.shade300),
                    columnWidths: const {
                      0: FlexColumnWidth(2),
                      1: FlexColumnWidth(1.5),
                      2: FlexColumnWidth(2),
                      3: FlexColumnWidth(2),
                    },
                    children: [
                      _tableHeaderRow([tr('Entgeltgruppe', 'Grupă salarială'), tr('Stundenlohn', 'Salariu orar'), tr('+1,5% (>9 Mon.)', '+1,5% (>9 luni)'), tr('+3,0% (>12 Mon.)', '+3,0% (>12 luni)')]),
                      _tableRow([tr('EG 1 – Ungelernt', 'EG 1 – Necalificat'), '14,96 €', '15,18 €', '15,41 €']),
                      _tableRow([tr('EG 2a – Angelernt (einfach)', 'EG 2a – Semicalificat (simplu)'), '15,29 €', '15,52 €', '15,75 €']),
                      _tableRow([tr('EG 2b – Angelernt (erweitert)', 'EG 2b – Semicalificat (extins)'), '15,69 €', '15,93 €', '16,16 €']),
                      _tableRow([tr('EG 3 – Facharbeiter', 'EG 3 – Muncitor calificat'), '16,69 €', '16,94 €', '17,19 €']),
                      _tableRow([tr('EG 4 – Facharbeiter (qualif.)', 'EG 4 – Muncitor calificat (avansat)'), '17,65 €', '17,91 €', '18,18 €']),
                      _tableRow([tr('EG 5 – Spezialisten', 'EG 5 – Specialist'), '19,78 €', '20,08 €', '20,37 €']),
                      _tableRow([tr('EG 6 – Meister/Techniker', 'EG 6 – Maistru/Tehnician'), '21,97 €', '22,30 €', '22,63 €']),
                      _tableRow([tr('EG 7 – Akademiker', 'EG 7 – Absolvent universitar'), '25,56 €', '25,94 €', '26,33 €']),
                      _tableRow([tr('EG 8 – Akademiker (qualif.)', 'EG 8 – Absolvent universitar (avansat)'), '27,36 €', '27,77 €', '28,18 €']),
                      _tableRow([tr('EG 9 – Akademiker (Experte)', 'EG 9 – Absolvent universitar (expert)'), '28,70 €', '29,13 €', '29,56 €']),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr('Quelle: DGB/GVP-Tarifvertrag Zeitarbeit · Zuschläge nach Einsatzdauer: +1,5% ab 9 Mon., +3,0% ab 12 Mon.', 'Sursa: contractul colectiv DGB/GVP pentru munca temporară · Sporuri după durata misiunii: +1,5% de la 9 luni, +3,0% de la 12 luni'),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Entgeltgruppen explanation
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.help_outline, color: Colors.amber.shade700),
                      const SizedBox(width: 8),
                      Text(
                        tr('Entgeltgruppen – Einordnung', 'Grupe salariale – încadrare'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _egExplanation('EG 1', tr('Ungelernte Tätigkeiten ohne Vorkenntnisse (z.B. Helfer, Lager, Produktion)', 'Activități necalificate, fără cunoștințe prealabile (de ex. lucrător auxiliar, depozit, producție)')),
                  _egExplanation('EG 2a/2b', tr('Angelernte Tätigkeiten mit kurzer Einweisung (z.B. Maschinenführer, Kommissionierer)', 'Activități semicalificate, cu instruire scurtă (de ex. operator mașini, pregătire comenzi)')),
                  _egExplanation('EG 3', tr('Facharbeiter mit abgeschlossener Berufsausbildung (z.B. Elektriker, Schlosser)', 'Muncitori calificați, cu formare profesională încheiată (de ex. electrician, lăcătuș)')),
                  _egExplanation('EG 4', tr('Qualifizierte Facharbeiter mit Zusatzqualifikation', 'Muncitori calificați cu o calificare suplimentară')),
                  _egExplanation('EG 5', tr('Spezialisten mit besonderen Fachkenntnissen (z.B. CNC-Programmierer)', 'Specialiști cu cunoștințe tehnice deosebite (de ex. programator CNC)')),
                  _egExplanation('EG 6', tr('Meister, Techniker, Fachwirte', 'Maiștri, tehnicieni, specialiști economici (Fachwirt)')),
                  _egExplanation('EG 7', tr('Akademiker mit Hochschulabschluss', 'Absolvenți cu diplomă de studii superioare')),
                  _egExplanation('EG 8–9', tr('Hochqualifizierte Akademiker / Experten mit Berufserfahrung', 'Absolvenți universitari înalt calificați / experți cu experiență profesională')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Branchenzuschläge
          Card(
            color: Colors.amber.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.add_circle_outline, color: Colors.amber.shade800),
                      const SizedBox(width: 8),
                      Text(
                        tr('Branchenzuschläge (zusätzlich zum Grundentgelt)', 'Sporuri de ramură (pe lângă salariul de bază)'),
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr('In bestimmten Branchen erhalten Zeitarbeitnehmer zusätzliche Zuschläge auf den Tarifstundenlohn:', 'În anumite ramuri, lucrătorii temporari primesc sporuri suplimentare la salariul orar din contractul colectiv:'),
                    style: TextStyle(fontSize: 13, color: Colors.amber.shade900),
                  ),
                  const SizedBox(height: 8),
                  _brancheRow(tr('Metall & Elektro (IG Metall)', 'Metalurgie și electrotehnică (IG Metall)'), tr('+15% bis +65%', '+15% până la +65%')),
                  _brancheRow(tr('Chemie (IG BCE)', 'Chimie (IG BCE)'), tr('+10% bis +40%', '+10% până la +40%')),
                  _brancheRow(tr('Kunststoff', 'Mase plastice'), tr('+10% bis +24%', '+10% până la +24%')),
                  _brancheRow(tr('Textil & Bekleidung', 'Textile și confecții'), tr('+12% bis +21%', '+12% până la +21%')),
                  _brancheRow(tr('Kautschuk', 'Cauciuc'), tr('+10% bis +45%', '+10% până la +45%')),
                  _brancheRow(tr('Schienenverkehr (EVG)', 'Transport feroviar (EVG)'), tr('+10% bis +36%', '+10% până la +36%')),
                  const SizedBox(height: 8),
                  Text(
                    tr('Zuschläge steigen mit der Einsatzdauer beim selben Kundenbetrieb.', 'Sporurile cresc odată cu durata misiunii la aceeași firmă client.'),
                    style: TextStyle(fontSize: 11, color: Colors.amber.shade700, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─── Tab 3: Leistungen ──────────────────────────────────────────────

  Widget _buildLeistungenTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ALG I
          _leistungCard(
            icon: Icons.account_balance_wallet,
            title: tr('Arbeitslosengeld I (ALG I)', 'Ajutor de șomaj (Arbeitslosengeld I, ALG I)'),
            color: Colors.blue,
            items: [
              _kvRow(tr('Voraussetzung', 'Condiții'), tr('Mind. 12 Monate sozialversicherungspflichtig beschäftigt in den letzten 30 Monaten', 'Min. 12 luni de angajare cu asigurări sociale obligatorii în ultimele 30 de luni')),
              _kvRow(tr('Höhe', 'Cuantum'), tr('60% des letzten Netto-Entgelts (67% mit Kind)', '60% din ultimul salariu net (67% cu copil)')),
              _kvRow(tr('Höchstbetrag West', 'Sumă maximă Vest'), tr('~2.390 € / Monat', '~2.390 € / lună')),
              _kvRow(tr('Höchstbetrag Ost', 'Sumă maximă Est'), tr('~2.320 € / Monat', '~2.320 € / lună')),
              _kvRow(tr('Dauer', 'Durată'), tr('6–24 Monate (abhängig von Alter und Beschäftigungsdauer)', '6–24 luni (în funcție de vârstă și de durata angajării)')),
              _kvRow(tr('Antrag', 'Cerere'), tr('Bei der Agentur für Arbeit (spätestens 3 Monate vor Arbeitsende melden)', 'La Agentur für Arbeit (înregistrare cel târziu cu 3 luni înainte de încetarea angajării)')),
            ],
          ),
          const SizedBox(height: 12),

          // Bürgergeld
          _leistungCard(
            icon: Icons.home,
            title: tr('Bürgergeld (ab 07/2026: Grundsicherungsgeld)', 'Ajutor social (Bürgergeld; din 07/2026: Grundsicherungsgeld)'),
            color: Colors.green,
            items: [
              _kvRow(tr('Voraussetzung', 'Condiții'), tr('Hilfebedürftig, erwerbsfähig, 15–65 Jahre, gewöhnlicher Aufenthalt in DE', 'Aflat în nevoie, apt de muncă, 15–65 de ani, reședință obișnuită în DE')),
              _kvRow(tr('Regelsatz Alleinstehende', 'Cuantum de bază persoană singură'), tr('563 € / Monat', '563 € / lună')),
              _kvRow(tr('Regelsatz mit Partner', 'Cuantum de bază cu partener'), tr('506 € / Monat pro Person', '506 € / lună pe persoană')),
              _kvRow(tr('Kinder 14–17 J.', 'Copii 14–17 ani'), tr('471 € / Monat', '471 € / lună')),
              _kvRow(tr('Kinder 6–13 J.', 'Copii 6–13 ani'), tr('390 € / Monat', '390 € / lună')),
              _kvRow(tr('Kinder 0–5 J.', 'Copii 0–5 ani'), tr('357 € / Monat', '357 € / lună')),
              _kvRow(tr('Zusätzlich', 'În plus'), tr('Kosten für Unterkunft + Heizung (angemessen)', 'Costuri de locuință + încălzire (în limite rezonabile)')),
              _kvRow(tr('Reform 07/2026', 'Reforma 07/2026'), tr('Umbenennung in "Grundsicherungsgeld" – verschärfte Pflichten und Sanktionen', 'Redenumire în „Grundsicherungsgeld” – obligații și sancțiuni mai stricte')),
            ],
          ),
          const SizedBox(height: 12),

          // Kindergeld
          _leistungCard(
            icon: Icons.child_care,
            title: tr('Kindergeld', 'Alocație pentru copii (Kindergeld)'),
            color: Colors.pink,
            items: [
              _kvRow(tr('Höhe', 'Cuantum'), tr('255 € / Monat pro Kind (seit 01.01.2025)', '255 € / lună pe copil (din 01.01.2025)')),
              _kvRow(tr('Anspruch', 'Drept'), tr('Für alle Kinder bis 18 J. (bis 25 J. bei Ausbildung/Studium)', 'Pentru toți copiii până la 18 ani (până la 25 de ani în formare profesională/studii)')),
              _kvRow(tr('Antrag', 'Cerere'), tr('Bei der Familienkasse', 'La Familienkasse')),
            ],
          ),
          const SizedBox(height: 12),

          // Wohngeld
          _leistungCard(
            icon: Icons.apartment,
            title: tr('Wohngeld', 'Ajutor pentru locuință (Wohngeld)'),
            color: Colors.teal,
            items: [
              _kvRow(tr('Voraussetzung', 'Condiții'), tr('Geringes Einkommen, kein Bürgergeld-Bezug', 'Venit redus, fără Bürgergeld')),
              _kvRow(tr('Höhe', 'Cuantum'), tr('Abhängig von Einkommen, Miete, Haushaltsgröße und Wohnort', 'În funcție de venit, chirie, mărimea gospodăriei și localitate')),
              _kvRow(tr('Antrag', 'Cerere'), tr('Bei der Wohngeldstelle der Gemeinde/Stadt', 'La biroul Wohngeld al comunei/orașului')),
            ],
          ),
          const SizedBox(height: 12),

          // Weiterbildung
          _leistungCard(
            icon: Icons.school,
            title: tr('Förderung beruflicher Weiterbildung', 'Sprijin pentru formarea profesională continuă'),
            color: Colors.deepPurple,
            items: [
              _kvRow(tr('Bildungsgutschein', 'Voucher de formare (Bildungsgutschein)'), tr('Übernahme der Weiterbildungskosten durch die Agentur für Arbeit', 'Agentur für Arbeit preia costurile formării')),
              _kvRow(tr('Weiterbildungsgeld', 'Bonus de formare (Weiterbildungsgeld)'), tr('150 € / Monat zusätzlich bei qualifizierter Weiterbildung', '150 € / lună în plus la o formare calificantă')),
              _kvRow(tr('Umschulung', 'Recalificare'), tr('Bis zu 2 Jahre gefördert (100% Kostenübernahme)', 'Finanțată până la 2 ani (costuri acoperite 100%)')),
              _kvRow(tr('Qualifizierungsgeld', 'Indemnizație de calificare (Qualifizierungsgeld)'), tr('Für Beschäftigte, deren Arbeitsplatz durch Strukturwandel bedroht ist', 'Pentru angajații al căror loc de muncă este amenințat de schimbări structurale')),
            ],
          ),
          const SizedBox(height: 12),

          // Gründungszuschuss
          _leistungCard(
            icon: Icons.rocket_launch,
            title: tr('Gründungszuschuss', 'Subvenție pentru afacere proprie (Gründungszuschuss)'),
            color: Colors.amber,
            items: [
              _kvRow(tr('Voraussetzung', 'Condiții'), tr('Arbeitslos gemeldet + Rest-ALG-Anspruch mind. 150 Tage', 'Înregistrat ca șomer + drept rămas la ALG de min. 150 de zile')),
              _kvRow(tr('Phase 1 (6 Mon.)', 'Faza 1 (6 luni)'), tr('ALG I + 300 € / Monat', 'ALG I + 300 € / lună')),
              _kvRow(tr('Phase 2 (9 Mon.)', 'Faza 2 (9 luni)'), tr('300 € / Monat (Ermessenssache)', '300 € / lună (la discreția agenției)')),
              _kvRow(tr('Antrag', 'Cerere'), tr('Bei der Agentur für Arbeit mit Businessplan + Tragfähigkeitsbescheinigung', 'La Agentur für Arbeit, cu plan de afaceri + certificat de viabilitate (Tragfähigkeitsbescheinigung)')),
            ],
          ),
          const SizedBox(height: 12),

          // Eingliederungszuschuss
          _leistungCard(
            icon: Icons.handshake,
            title: tr('Eingliederungszuschuss (für Arbeitgeber)', 'Subvenție de integrare (Eingliederungszuschuss, pentru angajatori)'),
            color: Colors.cyan,
            items: [
              _kvRow(tr('Zweck', 'Scop'), tr('Zuschuss zum Arbeitsentgelt für Arbeitnehmer mit Vermittlungshemmnissen', 'Subvenție la salariu pentru angajați cu dificultăți de plasare')),
              _kvRow(tr('Höhe', 'Cuantum'), tr('Bis zu 50% des Arbeitsentgelts', 'Până la 50% din salariu')),
              _kvRow(tr('Dauer', 'Durată'), tr('Bis zu 12 Monate (für Ältere bis 36 Monate)', 'Până la 12 luni (pentru persoane mai în vârstă până la 36 de luni)')),
              _kvRow(tr('Antrag', 'Cerere'), tr('Arbeitgeber stellt Antrag bei der Agentur für Arbeit', 'Angajatorul depune cererea la Agentur für Arbeit')),
            ],
          ),
          const SizedBox(height: 12),

          // Kurzarbeitergeld
          _leistungCard(
            icon: Icons.timelapse,
            title: tr('Kurzarbeitergeld', 'Indemnizație pentru program redus (Kurzarbeitergeld)'),
            color: Colors.red,
            items: [
              _kvRow(tr('Voraussetzung', 'Condiții'), tr('Erheblicher Arbeitsausfall mit Entgeltausfall', 'Reducere considerabilă a timpului de lucru, cu pierdere de salariu')),
              _kvRow(tr('Höhe', 'Cuantum'), tr('60% des Netto-Entgeltausfalls (67% mit Kind)', '60% din salariul net pierdut (67% cu copil)')),
              _kvRow(tr('Dauer', 'Durată'), tr('Bis zu 12 Monate', 'Până la 12 luni')),
              _kvRow(tr('Antrag', 'Cerere'), tr('Arbeitgeber bei der Agentur für Arbeit', 'Angajatorul, la Agentur für Arbeit')),
            ],
          ),
          const SizedBox(height: 12),

          // Insolvenzgeld
          _leistungCard(
            icon: Icons.warning_amber,
            title: tr('Insolvenzgeld', 'Indemnizație de insolvență (Insolvenzgeld)'),
            color: Colors.brown,
            items: [
              _kvRow(tr('Voraussetzung', 'Condiții'), tr('Arbeitgeber ist insolvent', 'Angajatorul este insolvent')),
              _kvRow(tr('Höhe', 'Cuantum'), tr('Netto-Entgelt für die letzten 3 Monate vor Insolvenz', 'Salariul net pentru ultimele 3 luni dinaintea insolvenței')),
              _kvRow(tr('Antrag', 'Cerere'), tr('Innerhalb von 2 Monaten nach Insolvenzereignis', 'În termen de 2 luni de la data insolvenței')),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  TableRow _tableHeaderRow(List<String> cells) {
    return TableRow(
      decoration: BoxDecoration(color: Colors.grey.shade200),
      children: cells
          .map((c) => Padding(
                padding: const EdgeInsets.all(10),
                child: Text(c, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ))
          .toList(),
    );
  }

  TableRow _tableRow(List<String> cells, {bool highlight = false, bool current = false}) {
    return TableRow(
      decoration: BoxDecoration(
        color: current
            ? Colors.green.shade50
            : highlight
                ? Colors.blue.shade50
                : null,
      ),
      children: cells
          .map((c) => Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  c,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: current ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _egExplanation(String group, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.indigo.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              group,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.indigo.shade800),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(description, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _brancheRow(String branche, String zuschlag) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const SizedBox(width: 8),
          const Icon(Icons.circle, size: 6),
          const SizedBox(width: 8),
          Expanded(child: Text(branche, style: const TextStyle(fontSize: 13))),
          Text(zuschlag, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber.shade900)),
        ],
      ),
    );
  }

  Widget _leistungCard({
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> items,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const Divider(height: 20),
            ...items,
          ],
        ),
      ),
    );
  }

  Widget _kvRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(key, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
