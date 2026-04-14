import 'package:flutter/material.dart';
import '../services/api_service.dart';
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

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with back button
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
                tooltip: 'Zurück',
              ),
              const SizedBox(width: 8),
              Icon(Icons.account_balance, size: 32, color: Colors.blue.shade700),
              const SizedBox(width: 12),
              const Text(
                'Behörden',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
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
  }

  Widget _buildVereinregisterCard() {
    return _buildClickableCard(
      icon: Icons.article,
      title: 'Vereinregister',
      color: Colors.indigo,
      subtitle: 'Amtsgericht Memmingen\nVR 201335 - ICD360S e.V.',
      onTap: () => setState(() => _subview = 'vereinregister'),
    );
  }

  Widget _buildHandelsregisterCard() {
    return _buildClickableCard(
      icon: Icons.search,
      title: 'Handelsregister',
      color: Colors.green,
      subtitle: 'Firmen & Vereine suchen\nhandelsregister.de',
      onTap: () => setState(() => _subview = 'handelsregister'),
    );
  }

  Widget _buildFinanzamtCard() {
    return _buildClickableCard(
      icon: Icons.receipt_long,
      title: 'Finanzamt',
      color: Colors.teal,
      subtitle: 'Finanzamt Neu-Ulm\nSteuernummer, Gemeinnützigkeit',
      onTap: () => setState(() => _subview = 'finanzamt'),
    );
  }

  Widget _buildClickableCard({
    required IconData icon,
    required String title,
    required Color color,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
              Expanded(
                child: Center(
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
