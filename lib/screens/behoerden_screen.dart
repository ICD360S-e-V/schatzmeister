import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import 'finanzamt_screen.dart';
import 'handelsregister_screen.dart';
import 'vereinregister_screen.dart';

class BehoerdenScreen extends StatefulWidget {
  final ApiService apiService;
  final VoidCallback onBack;

  const BehoerdenScreen({
    super.key,
    required this.apiService,
    required this.onBack,
  });

  @override
  State<BehoerdenScreen> createState() => _BehoerdenScreenState();
}

class _BehoerdenScreenState extends State<BehoerdenScreen> {
  String? _subview; // null = cards, 'vereinregister', 'finanzamt', 'handelsregister'

  @override
  Widget build(BuildContext context) {
    if (_subview == 'vereinregister') {
      return VereinregisterScreen(
        apiService: widget.apiService,
        onBack: () => setState(() => _subview = null),
      );
    }
    if (_subview == 'handelsregister') {
      return HandelsregisterScreen(
        apiService: widget.apiService,
        onBack: () => setState(() => _subview = null),
      );
    }
    if (_subview == 'finanzamt') {
      return FinanzamtScreen(
        apiService: widget.apiService,
        onBack: () => setState(() => _subview = null),
      );
    }

    // Erst ab 900 dp (Schreibtisch) stehen die drei Karten nebeneinander und
    // füllen die Höhe — wie bisher. Schmaler passen sie nicht nebeneinander
    // (auf dem Telefon gut 60 dp je Karte, schon auf 800 dp bricht
    // „Handelsregister" mitten im Wort um): dort stehen sie untereinander, in
    // natürlicher Höhe, und die Seite scrollt.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return _buildSchmal(telefon: constraints.maxWidth < 600);
        }
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              // Cards row
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildVereinregisterCard()),
                    const SizedBox(width: 16),
                    Expanded(child: _buildFinanzamtCard()),
                    const SizedBox(width: 16),
                    Expanded(child: _buildHandelsregisterCard()),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Telefon und Tablet: Karten untereinander, volle Breite, die Seite scrollt.
  Widget _buildSchmal({required bool telefon}) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(telefon ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          SizedBox(height: telefon ? 16 : 24),
          _buildVereinregisterCard(fuellen: false),
          const SizedBox(height: 8),
          _buildFinanzamtCard(fuellen: false),
          const SizedBox(height: 8),
          _buildHandelsregisterCard(fuellen: false),
        ],
      ),
    );
  }

  // Header with back button
  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
          tooltip: tr('Zurück', 'Înapoi'),
        ),
        const SizedBox(width: 8),
        Icon(Icons.account_balance, size: 32, color: Colors.blue.shade700),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            tr('Behörden', 'Autorități'),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildVereinregisterCard({bool fuellen = true}) {
    return _buildClickableCard(
      icon: Icons.article,
      // Titel und Untertitel nicht länger als auf Deutsch: auf dem
      // Schreibtisch stehen drei Karten nebeneinander und füllen die Höhe,
      // jede zusätzliche Zeile kostet dort Platz.
      title: 'Vereinregister',
      color: Colors.indigo,
      subtitle: 'Amtsgericht Memmingen\nVR 201335 - ICD360S e.V.',
      onTap: () => setState(() => _subview = 'vereinregister'),
      fuellen: fuellen,
    );
  }

  Widget _buildHandelsregisterCard({bool fuellen = true}) {
    return _buildClickableCard(
      icon: Icons.search,
      title: 'Handelsregister',
      color: Colors.green,
      subtitle: tr('Firmen & Vereine suchen\nhandelsregister.de',
          'Caută firme și asociații\nhandelsregister.de'),
      onTap: () => setState(() => _subview = 'handelsregister'),
      fuellen: fuellen,
    );
  }

  Widget _buildFinanzamtCard({bool fuellen = true}) {
    return _buildClickableCard(
      icon: Icons.receipt_long,
      title: 'Finanzamt',
      color: Colors.teal,
      subtitle: tr('Finanzamt Neu-Ulm\nSteuernummer, Gemeinnützigkeit',
          'Finanzamt Neu-Ulm\nNumăr fiscal, statut nonprofit'),
      onTap: () => setState(() => _subview = 'finanzamt'),
      fuellen: fuellen,
    );
  }

  /// [fuellen]: die Karte füllt die Höhe der Zeile (Schreibtisch); sonst
  /// natürliche Höhe (Telefon/Tablet, untereinander in einer scrollenden Seite).
  Widget _buildClickableCard({
    required IconData icon,
    required String title,
    required Color color,
    required String subtitle,
    required VoidCallback onTap,
    bool fuellen = true,
  }) {
    final inhalt = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: color.withValues(alpha: 0.3)),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: fuellen ? MainAxisSize.max : MainAxisSize.min,
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
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: Colors.grey.shade400, size: 16),
                ],
              ),
              const Divider(height: 24),
              if (fuellen) Expanded(child: inhalt) else inhalt,
            ],
          ),
        ),
      ),
    );
  }

}
