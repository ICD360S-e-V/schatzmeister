import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/device_key_service.dart';
import '../services/diagnostic_service.dart';
import '../services/logger_service.dart';
import '../services/update_service.dart';
import '../widgets/diagnostic_consent_dialog.dart';
import 'dashboard_screen.dart';

/// Geräteaktivierung für das Schatzmeister-Portal.
///
/// Zwei Schritte: Schatzmeister-Nummer → 16-stelliger Einmalcode
/// (4 Felder à 4 Zeichen). Der Code wird vom Vorsitzenden ausgestellt.
/// Nach erfolgreicher Aktivierung liegen device_key + JWT lokal, und die
/// App meldet sich ab dann bei jedem Start automatisch an.
///
/// Das Gegenstück auf dem Server ist /api/schatzmeister/auth/ — ein eigenes
/// Namespace. Der Vorsitzer-Endpunkt lehnt diese Rolle ausdrücklich ab.
///
/// Datenschutz: der Server liefert hier bewusst weder Name noch E-Mail
/// zurück. Angezeigt und gespeichert wird nur die Schatzmeister-Nummer.
class LoginWithCodeScreen extends StatefulWidget {
  const LoginWithCodeScreen({super.key});

  @override
  State<LoginWithCodeScreen> createState() => _LoginWithCodeScreenState();
}

class _LoginWithCodeScreenState extends State<LoginWithCodeScreen> {
  static final _log = LoggerService();

  /// Verwechslungsfreies Alphabet — identisch zum Server (kein 0/O, kein 1/I).
  static const _allowedChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  final _apiService = ApiService();
  final _deviceKeyService = DeviceKeyService();

  final _nummerC = TextEditingController();
  final List<TextEditingController> _blockC =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _blockFocus = List.generate(4, (_) => FocusNode());

  int _step = 0; // 0 = Nummer, 1 = Code
  bool _loading = false;
  bool _checkingAutoLogin = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    // Die Diagnose-Einwilligung hing bisher am alten Passwort-Login. Mit dem
    // Wechsel auf die Aktivierung wäre sie ersatzlos entfallen — samt dem
    // Start des DiagnosticService, den main.dart ausdrücklich hier erwartet
    // („Diagnostic service will be started from LoginScreen after user
    // consent"). Sie läuft deshalb jetzt hier, vor allem anderen.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await checkAndShowDiagnosticConsent(context);
      DiagnosticService().setScreen('aktivierung');
    });

    _checkExistingActivation();
  }

  @override
  void dispose() {
    _nummerC.dispose();
    for (final c in _blockC) {
      c.dispose();
    }
    for (final f in _blockFocus) {
      f.dispose();
    }
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════
  // Start: bereits aktiviert?
  // ═══════════════════════════════════════════════════════

  Future<void> _checkExistingActivation() async {
    try {
      // Bewusst KEIN _deviceKeyService.initialize(): das validiert beim Server
      // und löscht den Key bei JEDEM Fehlschlag — eine gültige Aktivierung
      // würde bei einem Netzaussetzer verloren gehen. Jeder API-Aufruf
      // validiert den device_key ohnehin serverseitig.
      final prefs = await SharedPreferences.getInstance();
      final nummer = prefs.getString('mitgliedernummer') ?? '';
      final autoLogin = prefs.getBool('auto_login') ?? false;

      // ── Weg A: lokale Zugangsdaten vorhanden → sofort anmelden ──
      if (nummer.isNotEmpty && autoLogin) {
        final storedKey = await _deviceKeyService.loadStoredDeviceKey();
        if (storedKey != null && storedKey.isNotEmpty) {
          final storedId = await _deviceKeyService.loadStoredDeviceId() ?? '';
          _log.info('Device key vorhanden ($nummer) — Auto-Login', tag: 'AUTH');
          await _completeLogin(storedKey, storedId, nummer);
          return;
        }
      }

      // ── Weg B: lokaler Speicher leer → Wiederherstellung per Fingerprint ──
      // Greift nach Neuinstallation, wenn die Hardware dieselbe geblieben ist.
      // Erspart dem Schatzmeister einen neuen Aktivierungscode.
      try {
        final deviceId = await _deviceKeyService.getOrGenerateDeviceId();
        final recovery =
            await _apiService.recoverSchatzmeisterDeviceKey(deviceId);

        final recoveredKey = recovery['device_key'] as String?;
        if (recovery['success'] == true &&
            recoveredKey != null &&
            recoveredKey.isNotEmpty) {
          final mgnr = (recovery['mitgliedernummer'] ?? '').toString();
          _log.info('Gerät per Fingerprint wiederhergestellt ($mgnr)',
              tag: 'AUTH');

          await _deviceKeyService.setActivatedCredentials(recoveredKey, deviceId);
          await prefs.setString('mitgliedernummer', mgnr);
          await prefs.setBool('auto_login', true);
          await _completeLogin(recoveredKey, deviceId, mgnr);
          return;
        }
        _log.debug('Keine Geräte-Wiederherstellung — Code erforderlich',
            tag: 'AUTH');
      } catch (e) {
        _log.warning('Wiederherstellung fehlgeschlagen: $e', tag: 'AUTH');
      }

      // ── Weg C: manuelle Eingabe ──
      if (mounted) setState(() => _checkingAutoLogin = false);
    } catch (e) {
      _log.error('checkExistingActivation fehlgeschlagen: $e', tag: 'AUTH');
      if (mounted) setState(() => _checkingAutoLogin = false);
    }
  }

  /// Gemeinsamer Abschluss: Zugangsdaten setzen, API initialisieren,
  /// zum Dashboard wechseln.
  Future<void> _completeLogin(String key, String devId, String nummer) async {
    if (devId.isNotEmpty) {
      await _deviceKeyService.setActivatedCredentials(key, devId);
    }
    await _apiService.initialize();
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DashboardScreen(
          // Name und E-Mail liefert das Schatzmeister-API absichtlich nicht.
          // Die Oberfläche identifiziert über die Nummer.
          userName: nummer,
          currentMitgliedernummer: nummer,
          currentEmail: '',
          currentRole: 'schatzmeister',
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // Aufbau
  // ═══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_checkingAutoLogin) {
      return Scaffold(
        backgroundColor: Colors.teal.shade50,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.teal.shade50,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                elevation: 8,
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: _step == 0 ? _buildNummerStep() : _buildCodeStep(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Schritt 1: Schatzmeister-Nummer ──
  Widget _buildNummerStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.vpn_key, size: 64, color: Colors.teal.shade400),
        const SizedBox(height: 16),
        Text(
          'Gerät aktivieren',
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.teal.shade900),
        ),
        const SizedBox(height: 6),
        Text(
          'Schritt 1 von 2 — Schatzmeister-Nummer eingeben',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _nummerC,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
            LengthLimitingTextInputFormatter(20),
            TextInputFormatter.withFunction((_, n) => TextEditingValue(
                  text: n.text.toUpperCase(),
                  selection: n.selection,
                )),
          ],
          decoration: InputDecoration(
            labelText: 'Schatzmeister-Nummer',
            hintText: 'z. B. S12345',
            prefixIcon: const Icon(Icons.badge),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          style: const TextStyle(fontSize: 16, letterSpacing: 2),
          onSubmitted: (_) => _goToCodeStep(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _errorBanner(_error!),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Weiter'),
            onPressed: _loading ? null : _goToCodeStep,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: Colors.teal.shade700,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Dieses Portal ist ausschließlich für den Schatzmeister. '
          'Noch keinen Code? Bitte beim Vorsitzenden anfordern.',
          style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _goToCodeStep() {
    final nummer = _nummerC.text.trim();

    if (nummer.length < 4) {
      setState(() => _error = 'Bitte eine gültige Nummer eingeben');
      return;
    }
    // Schatzmeister-Nummern beginnen mit "S". Früh abfangen spart einen
    // Fehlversuch gegen das Rate-Limit des Servers (5 pro 15 Minuten).
    if (!nummer.startsWith('S')) {
      setState(() => _error =
          'Dieses Portal ist nur für Schatzmeister (S-Nummern) zugänglich.');
      return;
    }

    setState(() {
      _step = 1;
      _error = null;
    });
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _blockFocus[0].requestFocus());
  }

  // ── Schritt 2: 4 × 4 Zeichen ──
  Widget _buildCodeStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.pin, size: 64, color: Colors.teal.shade400),
        const SizedBox(height: 16),
        Text(
          'Aktivierungscode',
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.teal.shade900),
        ),
        const SizedBox(height: 6),
        Text(
          'Schritt 2 von 2 — 16-stelligen Code eingeben',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Nummer: ${_nummerC.text.trim()}',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < 4; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text('–',
                      style: TextStyle(
                          fontSize: 22, color: Colors.grey.shade400)),
                ),
              _codeBox(i),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Tipp: Sie können den vollständigen Code (mit oder ohne Bindestriche) '
          'in ein beliebiges Feld einfügen.',
          style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade500,
              fontStyle: FontStyle.italic),
          textAlign: TextAlign.center,
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _errorBanner(_error!),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            icon: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_circle),
            label: Text(_loading ? 'Aktiviere…' : 'Gerät aktivieren'),
            onPressed: _loading ? null : _submit,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: Colors.green.shade700,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          icon: const Icon(Icons.arrow_back, size: 16),
          label: const Text('Nummer ändern', style: TextStyle(fontSize: 12)),
          onPressed: _loading
              ? null
              : () {
                  for (final c in _blockC) {
                    c.clear();
                  }
                  setState(() {
                    _step = 0;
                    _error = null;
                  });
                },
        ),
      ],
    );
  }

  Widget _codeBox(int i) {
    return SizedBox(
      width: 78,
      height: 58,
      child: TextField(
        controller: _blockC[i],
        focusNode: _blockFocus[i],
        maxLength: 4,
        textAlign: TextAlign.center,
        textCapitalization: TextCapitalization.characters,
        style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
            fontFamily: 'monospace'),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade400, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.teal.shade700, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.allow(
              RegExp('[$_allowedChars]', caseSensitive: false)),
          TextInputFormatter.withFunction((_, n) => TextEditingValue(
                text: n.text.toUpperCase(),
                selection: n.selection,
              )),
        ],
        onChanged: (v) {
          // Vollständigen Code in ein beliebiges Feld einfügen → aufteilen
          if (v.length > 4) {
            _distributePaste(v);
            return;
          }
          if (v.length == 4 && i < 3) {
            _blockFocus[i + 1].requestFocus();
          }
        },
        onSubmitted: (_) {
          if (i < 3) {
            _blockFocus[i + 1].requestFocus();
          } else {
            _submit();
          }
        },
      ),
    );
  }

  void _distributePaste(String raw) {
    final clean =
        raw.toUpperCase().replaceAll(RegExp('[^$_allowedChars]'), '');
    if (clean.length < 4) return;

    for (int i = 0; i < 4; i++) {
      final start = i * 4;
      if (start >= clean.length) {
        _blockC[i].text = '';
        continue;
      }
      final end = (start + 4) > clean.length ? clean.length : start + 4;
      _blockC[i].text = clean.substring(start, end);
    }

    if (clean.length >= 16) {
      _blockFocus[3].unfocus();
      _submit();
    } else {
      _blockFocus[(clean.length ~/ 4).clamp(0, 3)].requestFocus();
    }
  }

  // ═══════════════════════════════════════════════════════
  // Absenden
  // ═══════════════════════════════════════════════════════

  Future<void> _submit() async {
    final code = _blockC.map((c) => c.text.trim()).join();
    if (code.length != 16) {
      setState(() => _error = 'Der Code muss genau 16 Zeichen enthalten');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Bevorzugt eine bereits gespeicherte device_id, sonst der STABILE
      // Hardware-Fingerprint — damit die serverseitige Wiederherstellung
      // später ohne neuen Code funktioniert.
      final deviceId = _deviceKeyService.deviceId ??
          await _deviceKeyService.loadStoredDeviceId() ??
          await _deviceKeyService.getOrGenerateDeviceId();

      final result = await _apiService.activateSchatzmeisterCode(
        mitgliedernummer: _nummerC.text.trim(),
        code: code,
        deviceId: deviceId,
        deviceInfo: {
          'name': _deviceName(),
          'platform': _platformString(),
          'type': _deviceType(),
          'app_version': UpdateService.currentVersion,
        },
      );

      if (result['success'] != true) {
        setState(() {
          _error = (result['message'] ?? 'Aktivierung fehlgeschlagen').toString();
          _loading = false;
        });
        return;
      }

      final deviceKey = result['device_key']?.toString();
      if (deviceKey == null || deviceKey.isEmpty) {
        setState(() {
          _error = 'Ungültige Server-Antwort (device_key fehlt)';
          _loading = false;
        });
        return;
      }

      // Die Tokens hat activateSchatzmeisterCode() bereits gespeichert.
      await _deviceKeyService.setActivatedCredentials(deviceKey, deviceId);

      final user = (result['user'] as Map?) ?? {};
      final nummer = (user['mitgliedernummer'] ?? _nummerC.text.trim()).toString();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('mitgliedernummer', nummer);
      await prefs.setBool('remember_me', true);
      await prefs.setBool('auto_login', true);

      _log.info('Gerät für $nummer aktiviert', tag: 'AUTH');

      await _completeLogin(deviceKey, deviceId, nummer);
    } catch (e) {
      _log.error('Aktivierungsfehler: $e', tag: 'AUTH');
      if (mounted) {
        setState(() {
          _error = 'Netzwerkfehler: $e';
          _loading = false;
        });
      }
    }
  }

  // ═══════════════════════════════════════════════════════
  // Hilfsmittel
  // ═══════════════════════════════════════════════════════

  Widget _errorBanner(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(children: [
        Icon(Icons.error_outline, size: 16, color: Colors.red.shade700),
        const SizedBox(width: 8),
        Expanded(
          child: Text(msg,
              style: TextStyle(fontSize: 12, color: Colors.red.shade900)),
        ),
      ]),
    );
  }

  String _platformString() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  String _deviceType() {
    if (Platform.isAndroid || Platform.isIOS) return 'phone';
    return 'desktop';
  }

  String _deviceName() {
    if (Platform.isMacOS) return 'Mac';
    if (Platform.isWindows) return 'PC';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isIOS) return 'iPhone';
    if (Platform.isAndroid) return 'Android';
    return 'Gerät';
  }
}
