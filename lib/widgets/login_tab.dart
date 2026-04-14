import 'package:flutter/material.dart';

/// Passwordless login tab - only Schatzmeister-Nummer field + Anmelden button
class LoginTab extends StatefulWidget {
  final TextEditingController mitgliedernummerController;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onLogin;

  const LoginTab({
    super.key,
    required this.mitgliedernummerController,
    required this.isLoading,
    this.errorMessage,
    required this.onLogin,
  });

  @override
  State<LoginTab> createState() => _LoginTabState();
}

class _LoginTabState extends State<LoginTab> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Shield icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF4a90d9).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield, size: 48, color: Color(0xFF4a90d9)),
            ),
            const SizedBox(height: 24),

            // Error message
            if (widget.errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(widget.errorMessage!, style: TextStyle(color: Colors.red.shade700)),
                    ),
                  ],
                ),
              ),

            // Schatzmeister-Nummer field
            TextFormField(
              controller: widget.mitgliedernummerController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Schatzmeister-Nummer',
                hintText: 'S_____',
                prefixIcon: const Icon(Icons.badge),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Bitte Schatzmeister-Nummer eingeben';
                }
                final v = value.trim().toUpperCase();
                if (!RegExp(r'^S\d{5}$').hasMatch(v)) {
                  return 'Format: S + 5 Ziffern (z.B. S42759)';
                }
                return null;
              },
              onFieldSubmitted: (_) => _handleLogin(),
            ),
            const SizedBox(height: 20),

            // Anmelden button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: widget.isLoading ? null : _handleLogin,
                icon: widget.isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.key),
                label: Text(widget.isLoading ? 'Bitte warten...' : 'Anmelden', style: const TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4a90d9),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Info box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Bekanntes Gerät: sofortige Anmeldung.\nNeues Gerät: Genehmigung vom Vorsitzenden erforderlich.',
                      style: TextStyle(fontSize: 13, color: Colors.blue.shade700, height: 1.4),
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

  void _handleLogin() {
    if (_formKey.currentState != null && !_formKey.currentState!.validate()) return;
    widget.onLogin();
  }
}
