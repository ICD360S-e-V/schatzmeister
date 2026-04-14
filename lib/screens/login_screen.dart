import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';
import '../services/diagnostic_service.dart';
import '../services/logger_service.dart';
import '../widgets/diagnostic_consent_dialog.dart';
import '../widgets/eastern.dart';
import '../widgets/login_tab.dart';
import '../widgets/responsive_layout.dart';
import 'dashboard_screen.dart';

final _log = LoggerService();

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _apiService = ApiService();
  final _secureStorage = const FlutterSecureStorage();
  final _mitgliedernummerController = TextEditingController();

  bool _isLoading = false;
  bool _isInitializing = true;
  String? _loginErrorMessage;

  // Approval polling
  Timer? _pollingTimer;
  Timer? _countdownTimer;
  String? _requestToken;
  int _remainingSeconds = 300; // 5 minutes
  bool _isWaiting = false;

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    _mitgliedernummerController.dispose();
    super.dispose();
  }

  /// Auto-login: check if we have a saved Schatzmeister-Nummer with approved device
  Future<void> _checkAutoLogin() async {
    final savedMnr = await _secureStorage.read(key: 'approval_mitgliedernummer');

    // Show diagnostic consent first
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      await checkAndShowDiagnosticConsent(context);
      DiagnosticService().setScreen('login');

      if (savedMnr != null && savedMnr.isNotEmpty && mounted) {
        _mitgliedernummerController.text = savedMnr;
        _requestLogin();
      } else {
        if (mounted) setState(() => _isInitializing = false);
      }
    });
  }

  /// Request login (passwordless) - either auto-approved or waiting for Vorsitzer
  Future<void> _requestLogin() async {
    final mnr = _mitgliedernummerController.text.trim().toUpperCase();
    if (mnr.isEmpty) return;

    setState(() {
      _isLoading = true;
      _loginErrorMessage = null;
    });

    try {
      final result = await _apiService.requestLoginApproval(mnr);
      _log.info('Login request result: ${result['success']}, auto_approved=${result['auto_approved']}', tag: 'AUTH');

      if (result['success'] == true) {
        if (result['auto_approved'] == true) {
          // Known device → auto-login
          await _secureStorage.write(key: 'approval_mitgliedernummer', value: mnr);
          if (mounted) _navigateToDashboard(result['user']);
        } else {
          // New device → wait for Vorsitzer approval
          _requestToken = result['request_token'] as String?;
          await _secureStorage.write(key: 'approval_mitgliedernummer', value: mnr);
          if (mounted) {
            setState(() {
              _isLoading = false;
              _isWaiting = true;
              _isInitializing = false;
              _remainingSeconds = 300;
            });
            _startPolling();
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isInitializing = false;
            _loginErrorMessage = result['message'] ?? 'Login fehlgeschlagen';
          });
        }
      }
    } catch (e) {
      _log.error('Login request error: $e', tag: 'AUTH');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isInitializing = false;
          _loginErrorMessage = 'Verbindungsfehler: $e';
        });
      }
    }
  }

  /// Start polling for approval status every 3 seconds
  void _startPolling() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();

    // Countdown timer
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() => _remainingSeconds--);
      if (_remainingSeconds <= 0) {
        _cancelWaiting('Anfrage abgelaufen. Bitte erneut versuchen.');
      }
    });

    // Polling timer
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted || _requestToken == null) { timer.cancel(); return; }

      try {
        final result = await _apiService.checkApprovalStatus(_requestToken!);
        if (!mounted) return;

        final status = result['status'] as String?;

        if (status == 'approved' && result['success'] == true) {
          _pollingTimer?.cancel();
          _countdownTimer?.cancel();
          _navigateToDashboard(result['user']);
        } else if (status == 'rejected') {
          _cancelWaiting('Anmeldung vom Vorsitzenden abgelehnt.');
        } else if (status == 'expired') {
          _cancelWaiting('Anfrage abgelaufen. Bitte erneut versuchen.');
        }
      } catch (e) {
        _log.error('Polling error: $e', tag: 'AUTH');
      }
    });
  }

  void _cancelWaiting(String message) {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    if (mounted) {
      setState(() {
        _isWaiting = false;
        _requestToken = null;
        _loginErrorMessage = message;
      });
    }
  }

  void _navigateToDashboard(Map<String, dynamic> user) {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => DashboardScreen(
          userName: user['name'] ?? '',
          currentMitgliedernummer: user['mitgliedernummer'] ?? '',
          currentEmail: user['email'] ?? '',
          currentRole: user['role'] ?? 'schatzmeister',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Loading / auto-login splash
    if (_isInitializing || (_isLoading && !_isWaiting)) {
      return Scaffold(
        backgroundColor: const Color(0xFF1a1a2e),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shield, size: 64, color: Color(0xFF4a90d9)),
              const SizedBox(height: 24),
              const Text('ICD360S e.V', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 8),
              const Text('Schatzmeister', style: TextStyle(fontSize: 16, color: Colors.white70)),
              const SizedBox(height: 24),
              const CircularProgressIndicator(color: Color(0xFF4a90d9)),
            ],
          ),
        ),
      );
    }

    // Waiting for approval dialog
    if (_isWaiting) {
      return Scaffold(
        backgroundColor: const Color(0xFF1a1a2e),
        body: Center(
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(32),
            constraints: const BoxConstraints(maxWidth: 420),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.hourglass_top, size: 56, color: Color(0xFF4a90d9)),
                const SizedBox(height: 20),
                const Text(
                  'Warten auf Genehmigung',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Der Vorsitzende wurde benachrichtigt.\nBitte warten Sie auf die Genehmigung.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.4),
                ),
                const SizedBox(height: 24),
                // Countdown
                Text(
                  '${_remainingSeconds ~/ 60}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(0xFF4a90d9)),
                ),
                const SizedBox(height: 8),
                Text('Verbleibende Zeit', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                const SizedBox(height: 20),
                // Progress indicator
                LinearProgressIndicator(
                  value: _remainingSeconds / 300,
                  backgroundColor: Colors.grey.shade200,
                  color: const Color(0xFF4a90d9),
                ),
                const SizedBox(height: 24),
                // Cancel button
                TextButton.icon(
                  onPressed: () => _cancelWaiting('Abgebrochen.'),
                  icon: const Icon(Icons.close, color: Colors.red),
                  label: const Text('Abbrechen', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Login form
    final isMobile = ResponsiveLayout.isMobile(context);

    return Scaffold(
      body: SeasonalBackground(
        child: isMobile
            ? _buildMobileLoginLayout()
            : Row(
                children: [
                  Expanded(flex: 5, child: _buildBrandingPanel()),
                  Expanded(flex: 4, child: _buildLoginFormPanel()),
                ],
              ),
      ),
    );
  }

  Widget _buildMobileLoginLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield, size: 36, color: Color(0xFF4a90d9)),
                  ),
                  const SizedBox(height: 12),
                  const Text('ICD360S e.V', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  const Text('SCHATZMEISTER', style: TextStyle(fontSize: 13, color: Colors.white60, letterSpacing: 2)),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
                ),
                child: LoginTab(
                  mitgliedernummerController: _mitgliedernummerController,
                  isLoading: _isLoading,
                  errorMessage: _loginErrorMessage,
                  onLogin: _requestLogin,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandingPanel() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield, size: 80, color: Color(0xFF4a90d9)),
            SizedBox(height: 24),
            Text('ICD360S e.V', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
            SizedBox(height: 8),
            Text('SCHATZMEISTER PORTAL', style: TextStyle(fontSize: 14, color: Colors.white60, letterSpacing: 4)),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginFormPanel() {
    return Container(
      color: Colors.white,
      child: Center(
        child: SizedBox(
          width: 400,
          child: LoginTab(
            mitgliedernummerController: _mitgliedernummerController,
            isLoading: _isLoading,
            errorMessage: _loginErrorMessage,
            onLogin: _requestLogin,
          ),
        ),
      ),
    );
  }
}
