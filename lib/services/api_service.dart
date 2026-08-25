import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'device_key_service.dart';
import 'http_client_factory.dart';
import 'logger_service.dart';
import '../utils/role_helpers.dart';

class ApiService {
  static const String baseUrl = 'https://icd360sev.icd360s.de/api';

  // ✅ SECURITY FIX (2026-02-10): Removed hardcoded API key
  // All requests now use dynamic Device Key only (no legacy fallback)
  // Hardcoded keys can be extracted via reverse engineering - CRITICAL vulnerability!

  String? _token;
  String? _refreshToken;
  late http.Client _client;
  final DeviceKeyService _deviceKeyService = DeviceKeyService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal() {
    // ✅ SECURITY: Certificate pinning (ISRG Root X1 / Let's Encrypt only)
    // In release: only accepts certificates signed by Let's Encrypt
    // In debug: pinning disabled for development
    final httpClient = HttpClientFactory.createPinnedHttpClient();
    _client = IOClient(httpClient);
  }

  /// Inițializează API service - TREBUIE apelat la pornirea aplicației
  Future<bool> initialize() async {
    // Inițializează device key
    final deviceKeyInitialized = await _deviceKeyService.initialize();
    if (!deviceKeyInitialized) {
      return false;
    }
    // Încarcă token-urile
    await loadTokens();
    // Nach einem Neustart liegt der gespeicherte access_token womöglich seit
    // Stunden herum. Einmal erneuern, bevor der erste Aufruf ins 401 läuft.
    if (_refreshToken != null) {
      await ensureFreshToken();
    }
    return true;
  }

  /// ✅ SECURITY FIX (2026-02-10): Tokens stored in FlutterSecureStorage (encrypted)
  /// Previous implementation used SharedPreferences (plain text) - CRITICAL vulnerability!
  Future<void> loadTokens() async {
    try {
      _token = await _secureStorage.read(key: 'access_token');
      _refreshToken = await _secureStorage.read(key: 'refresh_token');
    } catch (e) {
      LoggerService().error('Failed to load tokens from secure storage: $e', tag: 'API');
      _token = null;
      _refreshToken = null;
    }
  }

  Future<void> saveTokens(String token, String refreshToken) async {
    try {
      await _secureStorage.write(key: 'access_token', value: token);
      await _secureStorage.write(key: 'refresh_token', value: refreshToken);
      _token = token;
      _refreshToken = refreshToken;
    } catch (e) {
      LoggerService().error('Failed to save tokens to secure storage: $e', tag: 'API');
      // Fallback: keep tokens in memory only
      _token = token;
      _refreshToken = refreshToken;
    }
    _startTokenRefreshTimer();
  }

  // ══════════════════════════════════════════════════════════════════
  //  TOKEN-ERNEUERUNG
  //
  // ⚠️ Der refresh_token wurde bis 2026-08-25 zwar gespeichert, aber NIE
  // benutzt. Der access_token gilt eine Stunde (ACCESS_TOKEN_EXPIRY in
  // config.php); danach antwortete jeder JWT-Endpunkt mit 401, im Chat
  // sichtbar als „Authentication required". Die App hielt sich weiter für
  // angemeldet — sie war es nicht mehr.
  // ══════════════════════════════════════════════════════════════════

  Timer? _tokenRefreshTimer;
  bool _isRefreshing = false;

  /// Erneuert 10 Minuten vor Ablauf, nicht erst danach: ein Aufruf, der
  /// genau in die Lücke fällt, bekäme sonst ein 401 zu sehen.
  void _startTokenRefreshTimer() {
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = Timer.periodic(const Duration(minutes: 50), (_) async {
      LoggerService().info('Turnusmäßige Token-Erneuerung', tag: 'AUTH');
      await ensureFreshToken();
    });
  }

  /// Besorgt einen gültigen access_token — auf welchem Weg auch immer.
  ///
  /// Zuerst der refresh_token. Schlägt der fehl, der device_key: refresh.php
  /// gibt KEINEN neuen refresh_token aus, der alte läuft also nach 30 Tagen
  /// hart ab. Ohne den zweiten Weg wäre danach nur noch ein neuer
  /// Aktivierungscode geblieben.
  Future<bool> ensureFreshToken() async {
    if (_isRefreshing) return false;
    _isRefreshing = true;
    try {
      if (_refreshToken != null && await _postRefresh()) return true;

      LoggerService().warning(
          'refresh_token abgelehnt — versuche es über den Geräteschlüssel',
          tag: 'AUTH');
      return await _reissueFromDeviceKey();
    } finally {
      _isRefreshing = false;
    }
  }

  Future<bool> _postRefresh() async {
    try {
      final deviceKey = _deviceKeyService.deviceKey;
      final response = await _client.post(
        Uri.parse('$baseUrl/auth/refresh.php'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'ICD360S-Schatzmeister/1.0',
          if (deviceKey != null) 'X-Device-Key': deviceKey,
        },
        body: jsonEncode({'refresh_token': _refreshToken}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return false;
      final data = jsonDecode(response.body);
      final neu = data['token'] as String?;
      if (data['success'] != true || neu == null) return false;

      // ⚠️ refresh.php liefert nur einen neuen access_token. Den alten
      // refresh_token behalten — sonst stünde nach dem ersten Durchlauf
      // keiner mehr da.
      await saveTokens(neu, _refreshToken!);
      LoggerService().info('access_token erneuert', tag: 'AUTH');
      return true;
    } catch (e) {
      LoggerService().warning('Token-Erneuerung nicht erreichbar: $e', tag: 'AUTH');
      return false;
    }
  }

  /// Neues Paar aus dem Geräteschlüssel. Gleiche Vertrauensstufe wie jeder
  /// andere Aufruf — der Geräteschlüssel authentifiziert sie ohnehin alle.
  Future<bool> _reissueFromDeviceKey() async {
    final deviceKey = _deviceKeyService.deviceKey;
    if (deviceKey == null) return false;
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/auth/device_token.php'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'ICD360S-Schatzmeister/1.0',
          'X-Device-Key': deviceKey,
        },
        body: '{}',
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return false;
      final data = jsonDecode(response.body);
      if (data['success'] == true &&
          data['token'] != null &&
          data['refresh_token'] != null) {
        await saveTokens(data['token'] as String, data['refresh_token'] as String);
        LoggerService().info('Tokens über den Geräteschlüssel neu ausgestellt', tag: 'AUTH');
        return true;
      }
      return false;
    } catch (e) {
      LoggerService().warning('Geräteschlüssel-Ausstellung nicht erreichbar: $e', tag: 'AUTH');
      return false;
    }
  }

  Future<void> clearTokens() async {
    try {
      await _secureStorage.delete(key: 'access_token');
      await _secureStorage.delete(key: 'refresh_token');
    } catch (e) {
      LoggerService().error('Failed to clear tokens from secure storage: $e', tag: 'API');
    }
    _token = null;
    _refreshToken = null;
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = null;
  }

  bool get isLoggedIn => _token != null;
  String? get token => _token;
  String? get refreshToken => _refreshToken;

  /// Headers pentru request-uri - folosește Device Key dinamic
  /// ✅ SECURITY FIX: Removed legacy API key fallback (all devices must be registered)
  Map<String, String> get _headers {
    final deviceKey = _deviceKeyService.deviceKey;
    if (deviceKey == null) {
      throw Exception('Device not registered. Please restart the app to register device.');
    }
    return {
      'Content-Type': 'application/json',
      'User-Agent': 'ICD360S-Schatzmeister/1.0',
      'X-Device-Key': deviceKey,
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }

  // Login (Vorsitzer Portal - Admin roles only)
  Future<Map<String, dynamic>> login(String mitgliedernummer, String password) async {
    final deviceKey = _deviceKeyService.deviceKey;
    if (deviceKey == null) {
      return {
        'success': false,
        'message': 'Device not registered. Please restart the app.',
      };
    }

    // ✅ SECURITY FIX: Sanitize input to prevent SQL injection
    final sanitizedMitgliedernummer = sanitizeMitgliedernummer(mitgliedernummer);

    if (!isValidMitgliedernummer(sanitizedMitgliedernummer)) {
      return {
        'success': false,
        'message': 'Ungültige Benutzernummer Format.',
      };
    }

    final response = await _client.post(
      Uri.parse('$baseUrl/auth/login_schatzmeister.php'),
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'ICD360S-Schatzmeister/1.0',
        'X-Device-Key': deviceKey,
      },
      body: jsonEncode({
        'mitgliedernummer': sanitizedMitgliedernummer,
        'password': password,
        'device_language': Platform.localeName,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      await saveTokens(data['token'], data['refresh_token']);
    }

    return data;
  }

  /// Passwordless login - request approval from Vorsitzer
  Future<Map<String, dynamic>> requestLoginApproval(String schatzmeisterNummer) async {
    final deviceKey = _deviceKeyService.deviceKey;
    final deviceId = _deviceKeyService.deviceId;
    if (deviceKey == null) {
      return {'success': false, 'message': 'Device not registered. Please restart the app.'};
    }

    final response = await _client.post(
      Uri.parse('$baseUrl/auth/login_request_schatzmeister.php'),
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'ICD360S-Schatzmeister/1.0',
        'X-Device-Key': deviceKey,
      },
      body: jsonEncode({
        'mitgliedernummer': schatzmeisterNummer,
        'device_id': deviceId,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true && data['data'] != null) {
      final d = data['data'];
      if (d['auto_approved'] == true && d['token'] != null) {
        await saveTokens(d['token'], d['refresh_token']);
      }
      return {'success': true, ...d};
    }

    return {
      'success': data['success'] ?? false,
      'message': data['message'] ?? 'Login request failed',
      if (data['data'] != null) ...data['data'],
    };
  }

  // ═══════════════════════════════════════════════════════════════════
  //  GERÄTEAKTIVIERUNG PER 16-STELLIGEM CODE
  //
  //  Eigenes Namespace: /api/schatzmeister/auth/. Der Vorsitzer-Endpunkt
  //  /api/auth/activate_code.php lehnt diese Rolle ausdrücklich ab, und
  //  /api/auth/recover_device_key.php liefert Klarnamen zurück — beides
  //  Gründe, hier nicht mitzubenutzen.
  // ═══════════════════════════════════════════════════════════════════

  /// Öffentlicher Bootstrap-Aufruf (kein Device-Key nötig): löst den vom
  /// Vorsitzenden ausgestellten Code ein und meldet dieses Gerät an.
  /// Liefert token + refresh_token + device_key zum lokalen Speichern.
  Future<Map<String, dynamic>> activateSchatzmeisterCode({
    required String mitgliedernummer,
    required String code,
    required String deviceId,
    Map<String, dynamic>? deviceInfo,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/schatzmeister/auth/activate_code.php'),
        headers: const {
          'Content-Type': 'application/json',
          'User-Agent': 'ICD360S-Schatzmeister/1.0',
        },
        body: jsonEncode({
          'mitgliedernummer': mitgliedernummer,
          'code': code,
          'device_id': deviceId,
          'device_info': deviceInfo ?? {},
        }),
      ).timeout(const Duration(seconds: 20));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true && data['data'] != null) {
        final d = data['data'];
        await saveTokens(d['token'], d['refresh_token']);
        return {'success': true, ...d};
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Aktivierung fehlgeschlagen',
      };
    } on FormatException {
      return {'success': false, 'message': 'Ungültige Serverantwort'};
    } catch (e) {
      return {'success': false, 'message': 'Aktivierung fehlgeschlagen: $e'};
    }
  }

  /// Versucht, einen bestehenden device_key über den Hardware-Fingerprint
  /// zurückzuholen. Greift nach einer Neuinstallation, bei der der lokale
  /// Speicher gelöscht wurde, die device_id aber gleich geblieben ist —
  /// erspart dem Schatzmeister einen neuen Aktivierungscode.
  Future<Map<String, dynamic>> recoverSchatzmeisterDeviceKey(String deviceId) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/schatzmeister/auth/recover_device_key.php'),
        headers: _headers,
        body: jsonEncode({'device_id': deviceId}),
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } on FormatException {
      return {'success': false, 'message': 'Ungültige Serverantwort'};
    } catch (e) {
      return {'success': false, 'message': 'Wiederherstellung fehlgeschlagen: $e'};
    }
  }

  /// Poll approval status for pending login request
  Future<Map<String, dynamic>> checkApprovalStatus(String requestToken) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/auth/check_approval.php'),
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'ICD360S-Schatzmeister/1.0',
      },
      body: jsonEncode({'request_token': requestToken}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true && data['data'] != null) {
      final d = data['data'];
      if (d['status'] == 'approved' && d['token'] != null) {
        await saveTokens(d['token'], d['refresh_token']);
      }
      return {'success': true, ...d};
    }

    return {
      'success': data['success'] ?? false,
      'message': data['message'] ?? 'Check failed',
      if (data['data'] != null) ...data['data'],
    };
  }

  // Logout a specific device (before login, for max devices scenario)
  Future<Map<String, dynamic>> logoutDevice(String mitgliedernummer, String password, int sessionId) async {
    final deviceKey = _deviceKeyService.deviceKey;
    if (deviceKey == null) {
      return {
        'success': false,
        'message': 'Device not registered.',
      };
    }

    final response = await _client.post(
      Uri.parse('$baseUrl/auth/logout_device.php'),
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'ICD360S-Schatzmeister/1.0',
        'X-Device-Key': deviceKey,
      },
      body: jsonEncode({
        'mitgliedernummer': mitgliedernummer,
        'password': password,
        'session_id': sessionId,
      }),
    );

    return jsonDecode(response.body);
  }

  // Get board members only (name, role, status - no personal data)
  Future<Map<String, dynamic>> getBoardMembers() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/vereinverwaltung/board_members.php'),
      headers: _headers,
    );

    return jsonDecode(response.body);
  }

  // Update user status
  Future<Map<String, dynamic>> updateUserStatus(int userId, String status) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/admin/user_status.php'),
      headers: _headers,
      body: jsonEncode({
        'user_id': userId,
        'status': status,
      }),
    );

    return jsonDecode(response.body);
  }

  // Delete user
  Future<Map<String, dynamic>> deleteUser(int userId) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/admin/user_delete.php'),
      headers: _headers,
      body: jsonEncode({
        'user_id': userId,
      }),
    );

    return jsonDecode(response.body);
  }

  // Get user details with sessions and devices (admin only)
  Future<Map<String, dynamic>> getUserDetails(int userId) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/admin/user_details.php'),
      headers: _headers,
      body: jsonEncode({
        'user_id': userId,
      }),
    );

    return jsonDecode(response.body);
  }

  // Update user (admin only)
  Future<Map<String, dynamic>> updateUser({
    required int userId,
    String? email,
    String? password,
    String? name,
    String? role,
    String? mitgliedschaftDatum,
    String? vorname2,
    String? bundesland,
    String? land,
    String? mitgliedsart,
    String? zahlungsmethode,
    int? zahlungstag,
    String? geburtsdatum,
    String? geburtsort,
    String? staatsangehoerigkeit,
    String? muttersprache,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/admin/user_update.php'),
      headers: _headers,
      body: jsonEncode({
        'user_id': userId,
        if (email != null) 'email': email,
        if (password != null) 'password': password,
        if (name != null) 'name': name,
        if (role != null) 'role': role,
        if (mitgliedschaftDatum != null) 'mitgliedschaft_datum': mitgliedschaftDatum,
        if (vorname2 != null) 'vorname2': vorname2,
        if (bundesland != null) 'bundesland': bundesland,
        if (land != null) 'land': land,
        if (mitgliedsart != null) 'mitgliedsart': mitgliedsart,
        if (zahlungsmethode != null) 'zahlungsmethode': zahlungsmethode,
        if (zahlungstag != null) 'zahlungstag': zahlungstag,
        if (geburtsdatum != null) 'geburtsdatum': geburtsdatum,
        if (geburtsort != null) 'geburtsort': geburtsort,
        if (staatsangehoerigkeit != null) 'staatsangehoerigkeit': staatsangehoerigkeit,
        if (muttersprache != null) 'muttersprache': muttersprache,
      }),
    );

    return jsonDecode(response.body);
  }

  // Admin register new member (status: neu)
  Future<Map<String, dynamic>> adminRegisterMember({
    required String name,
    required String email,
    required String password,
    String role = 'mitglied',
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/schatzmeister/admin_register.php'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'role': role,
      }),
    );

    return jsonDecode(response.body);
  }

  // Revoke session (admin only)
  Future<Map<String, dynamic>> revokeSession(int sessionId) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/admin/session_revoke.php'),
      headers: _headers,
      body: jsonEncode({
        'session_id': sessionId,
      }),
    );

    return jsonDecode(response.body);
  }

  // Get my sessions (member - self-service)
  Future<Map<String, dynamic>> getMySessions() async {
    LoggerService().debug('getMySessions: Sending request...', tag: 'API');
    final response = await _client.get(
      Uri.parse('$baseUrl/auth/my_sessions.php'),
      headers: _headers,
    );

    LoggerService().debug('getMySessions: Response status=${response.statusCode}', tag: 'API');
    LoggerService().debug('getMySessions: Response body length=${response.body.length}', tag: 'API');
    LoggerService().debug('getMySessions: Response body=${response.body}', tag: 'API');

    if (response.body.isEmpty) {
      LoggerService().error('getMySessions: Empty response body!', tag: 'API');
      return {'success': false, 'message': 'Empty response from server', 'sessions': []};
    }

    return jsonDecode(response.body);
  }

  // Revoke my session (member - self-service)
  Future<Map<String, dynamic>> revokeMySession(int sessionId) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/auth/revoke_my_session.php'),
      headers: _headers,
      body: jsonEncode({
        'session_id': sessionId,
      }),
    );

    return jsonDecode(response.body);
  }

  // Change password
  Future<Map<String, dynamic>> changePassword(String mitgliedernummer, String currentPassword, String newPassword) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/auth/change_password.php'),
      headers: _headers,
      body: jsonEncode({
        'mitgliedernummer': mitgliedernummer,
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );

    return jsonDecode(response.body);
  }

  // Change email
  Future<Map<String, dynamic>> changeEmail(String mitgliedernummer, String newEmail, String password) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/auth/change_email.php'),
      headers: _headers,
      body: jsonEncode({
        'mitgliedernummer': mitgliedernummer,
        'password': password,
        'new_email': newEmail,
      }),
    );

    return jsonDecode(response.body);
  }

  // Recover Password
  Future<Map<String, dynamic>> recoverPassword(String mitgliedernummer, String recoveryCode, String newPassword) async {
    final deviceKey = _deviceKeyService.deviceKey;
    if (deviceKey == null) {
      return {
        'success': false,
        'message': 'Device not registered.',
      };
    }

    final response = await _client.post(
      Uri.parse('$baseUrl/auth/recover.php'),
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'ICD360S-Schatzmeister/1.0',
        'X-Device-Key': deviceKey,
      },
      body: jsonEncode({
        'mitgliedernummer': mitgliedernummer,
        'recovery_code': recoveryCode,
        'new_password': newPassword,
      }),
    );

    return jsonDecode(response.body);
  }

  // Register
  Future<Map<String, dynamic>> register(String email, String password, String name, String recoveryCode) async {
    final deviceKey = _deviceKeyService.deviceKey;
    if (deviceKey == null) {
      return {
        'success': false,
        'message': 'Device not registered.',
      };
    }

    // ✅ SECURITY FIX: Sanitize email input
    final sanitizedEmail = sanitizeEmail(email);

    if (!isValidEmail(sanitizedEmail)) {
      return {
        'success': false,
        'message': 'Ungültige E-Mail-Adresse.',
      };
    }

    final response = await _client.post(
      Uri.parse('$baseUrl/auth/register.php'),
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'ICD360S-Schatzmeister/1.0',
        'X-Device-Key': deviceKey,
      },
      body: jsonEncode({
        'email': sanitizedEmail,
        'password': password,
        'name': name,
        'recovery_code': recoveryCode,
        'device_language': Platform.localeName,
      }),
    );

    return jsonDecode(response.body);
  }

  // Send heartbeat to update last_seen (with optional network info)
  Future<Map<String, dynamic>> sendHeartbeat(
    String mitgliedernummer, {
    String? connectionType,
    int? latencyMs,
    String? networkQuality,
  }) async {
    final body = <String, dynamic>{
      'mitgliedernummer': mitgliedernummer,
    };
    if (connectionType != null) body['connection_type'] = connectionType;
    if (latencyMs != null) body['latency_ms'] = latencyMs;
    if (networkQuality != null) body['network_quality'] = networkQuality;

    final response = await _client.post(
      Uri.parse('$baseUrl/auth/heartbeat.php'),
      headers: _headers,
      body: jsonEncode(body),
    );

    return jsonDecode(response.body);
  }

  // Get support online status (with network info)
  Future<Map<String, dynamic>> getSupportStatus() async {
    final response = await _client.post(
      Uri.parse('$baseUrl/chat/support_status.php'),
      headers: _headers,
      body: jsonEncode({}),
    );

    return jsonDecode(response.body);
  }

  // Get Profile (personal data + beitrag status)
  Future<Map<String, dynamic>> getProfile(String mitgliedernummer) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/auth/get_profile.php'),
      headers: _headers,
      body: jsonEncode({
        'mitgliedernummer': mitgliedernummer,
      }),
    );

    return jsonDecode(response.body);
  }

  // Get Account Status (trial days remaining for 'neu' accounts)
  Future<Map<String, dynamic>> getAccountStatus(String mitgliedernummer) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/auth/account_status.php'),
      headers: _headers,
      body: jsonEncode({
        'mitgliedernummer': mitgliedernummer,
      }),
    );

    return jsonDecode(response.body);
  }

  // Update Profile (personal data)
  Future<Map<String, dynamic>> updateProfile({
    required String mitgliedernummer,
    String? vorname,
    String? nachname,
    String? strasse,
    String? hausnummer,
    String? plz,
    String? ort,
    String? telefonMobil,
    String? geburtsdatum,
    List<String>? languages,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/auth/update_profile.php'),
      headers: _headers,
      body: jsonEncode({
        'mitgliedernummer': mitgliedernummer,
        'vorname': vorname,
        'nachname': nachname,
        'strasse': strasse,
        'hausnummer': hausnummer,
        'plz': plz,
        'ort': ort,
        'telefon_mobil': telefonMobil,
        'geburtsdatum': geburtsdatum,
        if (languages != null) 'languages': languages,
      }),
    );

    return jsonDecode(response.body);
  }

  // Logout
  Future<void> logout() async {
    await clearTokens();
  }

  // ============= CHAT API =============

  // Start a new chat conversation
  Future<Map<String, dynamic>> startChat(String mitgliedernummer, {String subject = 'Support'}) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/chat/start.php'),
      headers: _headers,
      body: jsonEncode({
        'mitgliedernummer': mitgliedernummer,
        'subject': subject,
      }),
    );

    return jsonDecode(response.body);
  }

  // Admin: Start a chat conversation with a member
  Future<Map<String, dynamic>> adminStartChat(String adminMitgliedernummer, String memberMitgliedernummer) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/chat/admin_start.php'),
      headers: _headers,
      body: jsonEncode({
        'admin_mitgliedernummer': adminMitgliedernummer,
        'member_mitgliedernummer': memberMitgliedernummer,
      }),
    );

    return jsonDecode(response.body);
  }

  // Send a chat message
  /// 🆕 URGENT NOTIFICATIONS (2026-02-11): Added urgent parameter for full-screen alerts
  Future<Map<String, dynamic>> sendChatMessage(
    int conversationId,
    String mitgliedernummer,
    String message, {
    bool urgent = false,  // 🆕 Urgent flag for full-screen notifications
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/chat/send.php'),
      headers: _headers,
      body: jsonEncode({
        'conversation_id': conversationId,
        'mitgliedernummer': mitgliedernummer,
        'message': message,
        'urgent': urgent,  // 🆕 Send urgent flag to backend
      }),
    );

    return jsonDecode(response.body);
  }

  // Get chat messages
  Future<Map<String, dynamic>> getChatMessages(int conversationId, String mitgliedernummer, {int? lastMessageId}) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/chat/messages.php'),
      headers: _headers,
      body: jsonEncode({
        'conversation_id': conversationId,
        'mitgliedernummer': mitgliedernummer,
        if (lastMessageId != null) 'last_message_id': lastMessageId,
      }),
    );

    return jsonDecode(response.body);
  }

  // Get all conversations (for admin) or user's conversations
  Future<Map<String, dynamic>> getChatConversations(String mitgliedernummer, {String? status}) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/chat/conversations.php'),
      headers: _headers,
      body: jsonEncode({
        'mitgliedernummer': mitgliedernummer,
        if (status != null) 'status': status,
      }),
    );

    return jsonDecode(response.body);
  }

  // Close a chat conversation (admin only)
  Future<Map<String, dynamic>> closeChatConversation(int conversationId, String mitgliedernummer) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/chat/close.php'),
      headers: _headers,
      body: jsonEncode({
        'conversation_id': conversationId,
        'mitgliedernummer': mitgliedernummer,
      }),
    );

    return jsonDecode(response.body);
  }

  // Mute or unmute a chat conversation (admin only)
  Future<Map<String, dynamic>> muteConversation(int conversationId, String mitgliedernummer, String duration) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/chat/mute.php'),
      headers: _headers,
      body: jsonEncode({
        'conversation_id': conversationId,
        'mitgliedernummer': mitgliedernummer,
        'duration': duration,
      }),
    );

    return jsonDecode(response.body);
  }

  // Upload chat attachments (max 10 files, 100MB total)
  Future<Map<String, dynamic>> uploadChatAttachments({
    required int conversationId,
    required String mitgliedernummer,
    required List<File> files,
    String? message,
  }) async {
    try {
      final deviceKey = _deviceKeyService.deviceKey;
      if (deviceKey == null) {
        return {'success': false, 'message': 'Device not registered'};
      }

      // Create multipart request
      final uri = Uri.parse('$baseUrl/chat/upload.php');
      final request = http.MultipartRequest('POST', uri);

      // Add headers
      request.headers['User-Agent'] = 'ICD360S-Schatzmeister/1.0';
      request.headers['X-Device-Key'] = deviceKey;

      // Add fields
      request.fields['conversation_id'] = conversationId.toString();
      request.fields['mitgliedernummer'] = mitgliedernummer;
      if (message != null && message.isNotEmpty) {
        request.fields['message'] = message;
      }

      // Add files
      for (final file in files) {
        request.files.add(await http.MultipartFile.fromPath(
          'files[]',
          file.path,
        ));
      }

      // Send request using our custom IOClient
      final streamedResponse = await _client.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Upload failed: $e'};
    }
  }

  // Download chat attachment
  Future<Map<String, dynamic>> downloadChatAttachment({
    required int attachmentId,
    required String mitgliedernummer,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/chat/download.php'),
        headers: _headers,
        body: jsonEncode({
          'attachment_id': attachmentId,
          'mitgliedernummer': mitgliedernummer,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Download failed: $e'};
    }
  }

  // Mark messages as read/delivered (WhatsApp-style read receipts)
  Future<Map<String, dynamic>> markMessagesRead({
    required int conversationId,
    required String mitgliedernummer,
    required String status, // 'delivered' or 'read'
    List<int>? messageIds,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/chat/mark_read.php'),
        headers: _headers,
        body: jsonEncode({
          'conversation_id': conversationId,
          'mitgliedernummer': mitgliedernummer,
          'status': status,
          if (messageIds != null) 'message_ids': messageIds,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Mark read failed: $e'};
    }
  }

  // ============= VEREINVERWALTUNG API =============

  // Get Vereinverwaltung data (partners, notary, etc.)
  Future<Map<String, dynamic>> getVereinverwaltung({String? kategorie}) async {
    try {
      String url = '$baseUrl/vereinverwaltung/get.php';
      if (kategorie != null) {
        url += '?kategorie=$kategorie';
      }

      final response = await _client.get(
        Uri.parse(url),
        headers: _headers,
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to load data: $e'};
    }
  }

  // Get platform credentials (encrypted in DB)
  Future<Map<String, dynamic>> getPlatformCredentials(String platform) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/platform/get_credentials.php'),
        headers: _headers,
        body: jsonEncode({'platform': platform}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to load credentials: $e'};
    }
  }

  // Save platform credentials (encrypted in DB)
  Future<Map<String, dynamic>> savePlatformCredentials({
    required String platform,
    required String email,
    required String password,
    String? website,
  }) async {
    try {
      final body = {
        'platform': platform,
        'email': email,
        'password': password,
      };
      if (website != null) body['website'] = website;
      final response = await _client.post(
        Uri.parse('$baseUrl/platform/save_credentials.php'),
        headers: _headers,
        body: jsonEncode(body),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to save credentials: $e'};
    }
  }

  // List platform Aufgaben
  Future<Map<String, dynamic>> getPlatformAufgaben(String platform) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/platform/aufgaben_list.php'),
        headers: _headers,
        body: jsonEncode({'platform': platform}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to load Aufgaben: $e'};
    }
  }

  // Create platform Aufgabe
  Future<Map<String, dynamic>> createPlatformAufgabe({
    required String platform,
    required String titel,
    required String faelligAm,
    String? beschreibung,
  }) async {
    try {
      final body = {
        'platform': platform,
        'titel': titel,
        'faellig_am': faelligAm,
      };
      if (beschreibung != null) body['beschreibung'] = beschreibung;
      final response = await _client.post(
        Uri.parse('$baseUrl/platform/aufgaben_create.php'),
        headers: _headers,
        body: jsonEncode(body),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to create Aufgabe: $e'};
    }
  }

  // Update platform Aufgabe
  Future<Map<String, dynamic>> updatePlatformAufgabe(Map<String, dynamic> data) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/platform/aufgaben_update.php'),
        headers: _headers,
        body: jsonEncode(data),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to update Aufgabe: $e'};
    }
  }

  // Delete platform Aufgabe
  Future<Map<String, dynamic>> deletePlatformAufgabe(int id) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/platform/aufgaben_delete.php'),
        headers: _headers,
        body: jsonEncode({'id': id}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to delete Aufgabe: $e'};
    }
  }

  // ============= PLATFORM NOTIZEN API =============

  Future<Map<String, dynamic>> getPlatformNotizen(String platform) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/platform/notizen_list.php'),
        headers: _headers,
        body: jsonEncode({'platform': platform}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to load Notizen: $e'};
    }
  }

  Future<Map<String, dynamic>> createPlatformNotiz({
    required String platform,
    required String inhalt,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/platform/notizen_create.php'),
        headers: _headers,
        body: jsonEncode({
          'platform': platform,
          'inhalt': inhalt,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to create Notiz: $e'};
    }
  }

  Future<Map<String, dynamic>> deletePlatformNotiz(int id) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/platform/notizen_delete.php'),
        headers: _headers,
        body: jsonEncode({'id': id}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to delete Notiz: $e'};
    }
  }

  // ============= POSTCARD KARTEN API =============

  Future<Map<String, dynamic>> getPostcardKarten() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/platform/postcard_list.php'),
        headers: _headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to load Postcards: $e'};
    }
  }

  Future<Map<String, dynamic>> createPostcardKarte({
    required String kartennummer,
    String? pin,
    String? bezeichnung,
    double tageslimit = 10.0,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/platform/postcard_create.php'),
        headers: _headers,
        body: jsonEncode({
          'kartennummer': kartennummer,
          if (pin != null) 'pin': pin,
          if (bezeichnung != null) 'bezeichnung': bezeichnung,
          'tageslimit': tageslimit,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to create Postcard: $e'};
    }
  }

  Future<Map<String, dynamic>> updatePostcardKarte({
    required int id,
    String? kartennummer,
    String? pin,
    String? bezeichnung,
    double? tageslimit,
    bool? aktiv,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/platform/postcard_update.php'),
        headers: _headers,
        body: jsonEncode({
          'id': id,
          if (kartennummer != null) 'kartennummer': kartennummer,
          if (pin != null) 'pin': pin,
          if (bezeichnung != null) 'bezeichnung': bezeichnung,
          if (tageslimit != null) 'tageslimit': tageslimit,
          if (aktiv != null) 'aktiv': aktiv,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to update Postcard: $e'};
    }
  }

  Future<Map<String, dynamic>> deletePostcardKarte(int id) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/platform/postcard_delete.php'),
        headers: _headers,
        body: jsonEncode({'id': id}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to delete Postcard: $e'};
    }
  }

  // ============= POSTCARD ACCOUNT API =============

  Future<Map<String, dynamic>> getPostcardAccount() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/platform/postcard_account_get.php'),
        headers: _headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to load account: $e'};
    }
  }

  Future<Map<String, dynamic>> savePostcardAccount({
    required String website,
    required String username,
    required String password,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/platform/postcard_account_save.php'),
        headers: _headers,
        body: jsonEncode({
          'website': website,
          'username': username,
          'password': password,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to save account: $e'};
    }
  }

  // Update Vereinverwaltung entry
  Future<Map<String, dynamic>> updateVereinverwaltung(Map<String, dynamic> data) async {
    try {
      final response = await _client.put(
        Uri.parse('$baseUrl/vereinverwaltung/update.php'),
        headers: _headers,
        body: jsonEncode(data),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to update: $e'};
    }
  }

  /// Reaktion auf eine Chat-Nachricht setzen oder entfernen (leerer String
  /// = entfernen). Der Server erzwingt die Eigentumsregel: auf eigene
  /// Nachrichten darf nicht reagiert werden.
  ///
  /// Die erlaubten Schlüssel stehen in `MessageEmotion` (lib/utils/
  /// message_emotion.dart) und müssen mit der Whitelist `$allowed` in
  /// api/chat/react.php übereinstimmen — sonst antwortet der Server 400.
  Future<Map<String, dynamic>> reactToMessage({
    required int conversationId,
    required int messageId,
    required String mitgliedernummer,
    required String reaction,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/chat/react.php'),
        headers: _headers,
        body: jsonEncode({
          'conversation_id': conversationId,
          'message_id': messageId,
          'mitgliedernummer': mitgliedernummer,
          'reaction': reaction,
        }),
      ).timeout(const Duration(seconds: 15));

      return jsonDecode(response.body);
    } on FormatException {
      return {'success': false, 'message': 'Ungültige Serverantwort'};
    } catch (e) {
      return {'success': false, 'message': 'Reaktion fehlgeschlagen: $e'};
    }
  }

  // ==================== EIGENE UNTERSCHRIFTEN ====================
  //
  // Ruft den MITGLIEDER-Endpunkt, nicht den der Vorstandsansicht. Das ist kein
  // Versehen: `vorstand/signatur_manage.php` verwaltet die Unterschriften
  // ANDERER und ist auf `vorsitzer` beschränkt; hier geht es um die eigenen.
  //
  // Serverseitig war nichts zu tun: `member/signatur_manage.php` hängt über
  // requireAuth() an der IDENTITÄT, nicht an einer Rolle, und jede Abfrage
  // dort trägt `user_id = ?` mit. Der Schatzmeister ist dort ein Nutzer wie
  // jeder andere — mit eigener Handynummer, an die der Code geht.
  //
  // _headers trägt Bearer-Token UND Geräteschlüssel, der Aufruf authentifiziert
  // also den Menschen, der gerade angemeldet ist.

  /// Aktionen: `list`, `tan_anfordern`, `signieren`, `ablehnen`.
  Future<Map<String, dynamic>> eigeneSignatur(
    String action, [
    Map<String, dynamic> felder = const {},
  ]) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/member/signatur_manage.php'),
            headers: _headers,
            body: jsonEncode({'action': action, ...felder}),
          )
          .timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);
      if (data is! Map) {
        return {'success': false, 'message': 'Unerwartete Antwort vom Server'};
      }
      return Map<String, dynamic>.from(data);
    } on FormatException {
      return {'success': false, 'message': 'Ungültige Antwort vom Server'};
    } catch (e) {
      // Der Aufrufer soll einen Satz zum Anzeigen bekommen, keine Ausnahme:
      // dieser Bildschirm läuft auch mal ohne Netz.
      return {'success': false, 'message': 'Netzwerkfehler: $e'};
    }
  }

  /// Das PDF einer EIGENEN Unterschrift.
  ///
  /// `welche`: 'original' vor dem Unterschreiben, 'signiert' danach.
  /// Kommt JSON statt PDF zurück, gibt es die Fassung noch nicht — bei
  /// 'signiert' also der Normalfall, solange das Siegel aussteht oder noch auf
  /// den zweiten Unterzeichner gewartet wird.
  Future<Uint8List?> eigeneSignaturPdf(int signaturId,
      {String welche = 'original'}) async {
    try {
      final r = await _client
          .get(
            Uri.parse('$baseUrl/member/signatur_pdf.php'
                '?id=$signaturId&which=$welche'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 60));

      if (r.statusCode != 200 ||
          (r.headers['content-type'] ?? '').contains('json')) {
        return null;
      }
      return r.bodyBytes;
    } catch (e) {
      return null;
    }
  }

  // ============= VEREINEINSTELLUNGEN API =============

  // Get Vereineinstellungen (single row with all association settings)
  Future<Map<String, dynamic>> getVereineinstellungen() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/schatzmeister/finanzen/einstellungen.php'),
        headers: _headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to load Vereineinstellungen: $e'};
    }
  }

  // Vereinsstammdaten sind für den Schatzmeister schreibgeschützt.
  //
  // Das Schatzmeister-Namespace bietet für einstellungen.php bewusst nur GET
  // an (der Server antwortet auf POST mit 405). Ändern darf diese Daten nur
  // der Vorsitzende. Wir schicken die Anfrage gar nicht erst los, damit die
  // UI sofort eine verständliche Meldung bekommt statt eines rohen 405.
  Future<Map<String, dynamic>> updateVereineinstellungen(Map<String, dynamic> data) async {
    return {
      'success': false,
      'read_only': true,
      'message': 'Vereinsstammdaten können nur vom Vorsitzenden geändert werden.',
    };
  }

  // ============= FINANZAMT DOKUMENTE API =============

  // List finanzamt documents
  Future<Map<String, dynamic>> getFinanzamtDokumente() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/admin/finanzamt/dokumente.php'),
        headers: _headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to load documents: $e'};
    }
  }

  // Upload finanzamt document
  Future<Map<String, dynamic>> uploadFinanzamtDokument({
    required String filePath,
    required String fileName,
    String kategorie = 'sonstiges',
    String beschreibung = '',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/admin/finanzamt/dokumente.php');
      final request = http.MultipartRequest('POST', uri);

      for (final entry in _headers.entries) {
        request.headers[entry.key] = entry.value;
      }
      request.headers.remove('Content-Type');

      request.fields['kategorie'] = kategorie;
      request.fields['beschreibung'] = beschreibung;
      request.files.add(await http.MultipartFile.fromPath('file', filePath, filename: fileName));

      final streamedResponse = await _client.send(request);
      final response = await http.Response.fromStream(streamedResponse);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to upload: $e'};
    }
  }

  // Delete finanzamt document
  Future<Map<String, dynamic>> deleteFinanzamtDokument(int id) async {
    try {
      final request = http.Request('DELETE', Uri.parse('$baseUrl/admin/finanzamt/dokumente.php'));
      request.headers.addAll(_headers);
      request.body = jsonEncode({'id': id});

      final streamedResponse = await _client.send(request);
      final response = await http.Response.fromStream(streamedResponse);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to delete: $e'};
    }
  }

  // Download finanzamt document (returns bytes)
  Future<http.Response?> downloadFinanzamtDokument(int id) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/admin/finanzamt/download.php?id=$id'),
        headers: _headers,
      );
      if (response.statusCode == 200) return response;
      return null;
    } catch (_) {
      return null;
    }
  }

  // ============= NOTAR API =============

  // Get Notar Rechnungen (Invoices)
  Future<Map<String, dynamic>> getNotarRechnungen({int? notarId}) async {
    try {
      String url = '$baseUrl/notar/rechnungen.php';
      if (notarId != null) {
        url += '?notar_id=$notarId';
      }
      final response = await _client.get(Uri.parse(url), headers: _headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to load: $e'};
    }
  }

  // Create Notar Rechnung
  Future<Map<String, dynamic>> createNotarRechnung(Map<String, dynamic> data) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/notar/rechnungen.php'),
        headers: _headers,
        body: jsonEncode(data),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to create: $e'};
    }
  }

  // Update Notar Rechnung
  Future<Map<String, dynamic>> updateNotarRechnung(Map<String, dynamic> data) async {
    try {
      final response = await _client.put(
        Uri.parse('$baseUrl/notar/rechnungen.php'),
        headers: _headers,
        body: jsonEncode(data),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to update: $e'};
    }
  }

  // Delete Notar Rechnung
  Future<Map<String, dynamic>> deleteNotarRechnung(int id) async {
    try {
      final response = await _client.delete(
        Uri.parse('$baseUrl/notar/rechnungen.php?id=$id'),
        headers: _headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to delete: $e'};
    }
  }

  // Get Notar Besuche (Visits)
  Future<Map<String, dynamic>> getNotarBesuche({int? notarId}) async {
    try {
      String url = '$baseUrl/notar/besuche.php';
      if (notarId != null) {
        url += '?notar_id=$notarId';
      }
      final response = await _client.get(Uri.parse(url), headers: _headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to load: $e'};
    }
  }

  // Create Notar Besuch
  Future<Map<String, dynamic>> createNotarBesuch(Map<String, dynamic> data) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/notar/besuche.php'),
        headers: _headers,
        body: jsonEncode(data),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to create: $e'};
    }
  }

  // Update Notar Besuch
  Future<Map<String, dynamic>> updateNotarBesuch(Map<String, dynamic> data) async {
    try {
      final response = await _client.put(
        Uri.parse('$baseUrl/notar/besuche.php'),
        headers: _headers,
        body: jsonEncode(data),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to update: $e'};
    }
  }

  // Delete Notar Besuch
  Future<Map<String, dynamic>> deleteNotarBesuch(int id) async {
    try {
      final response = await _client.delete(
        Uri.parse('$baseUrl/notar/besuche.php?id=$id'),
        headers: _headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to delete: $e'};
    }
  }

  // Get Notar Dokumente
  Future<Map<String, dynamic>> getNotarDokumente({int? notarId, String? typ}) async {
    try {
      String url = '$baseUrl/notar/dokumente.php';
      List<String> params = [];
      if (notarId != null) params.add('notar_id=$notarId');
      if (typ != null) params.add('typ=$typ');
      if (params.isNotEmpty) url += '?${params.join('&')}';
      final response = await _client.get(Uri.parse(url), headers: _headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to load: $e'};
    }
  }

  // Create Notar Dokument
  Future<Map<String, dynamic>> createNotarDokument(Map<String, dynamic> data) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/notar/dokumente.php'),
        headers: _headers,
        body: jsonEncode(data),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to create: $e'};
    }
  }

  // Update Notar Dokument
  Future<Map<String, dynamic>> updateNotarDokument(Map<String, dynamic> data) async {
    try {
      final response = await _client.put(
        Uri.parse('$baseUrl/notar/dokumente.php'),
        headers: _headers,
        body: jsonEncode(data),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to update: $e'};
    }
  }

  // Delete Notar Dokument
  Future<Map<String, dynamic>> deleteNotarDokument(int id) async {
    try {
      final response = await _client.delete(
        Uri.parse('$baseUrl/notar/dokumente.php?id=$id'),
        headers: _headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to delete: $e'};
    }
  }

  // Get Notar Zahlungen (Payments)
  Future<Map<String, dynamic>> getNotarZahlungen({int? notarId, int? rechnungId}) async {
    try {
      String url = '$baseUrl/notar/zahlungen.php';
      List<String> params = [];
      if (notarId != null) params.add('notar_id=$notarId');
      if (rechnungId != null) params.add('rechnung_id=$rechnungId');
      if (params.isNotEmpty) url += '?${params.join('&')}';
      final response = await _client.get(Uri.parse(url), headers: _headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to load: $e'};
    }
  }

  // Create Notar Zahlung
  Future<Map<String, dynamic>> createNotarZahlung(Map<String, dynamic> data) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/notar/zahlungen.php'),
        headers: _headers,
        body: jsonEncode(data),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to create: $e'};
    }
  }

  // Update Notar Zahlung
  Future<Map<String, dynamic>> updateNotarZahlung(Map<String, dynamic> data) async {
    try {
      final response = await _client.put(
        Uri.parse('$baseUrl/notar/zahlungen.php'),
        headers: _headers,
        body: jsonEncode(data),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to update: $e'};
    }
  }

  // Delete Notar Zahlung
  Future<Map<String, dynamic>> deleteNotarZahlung(int id) async {
    try {
      final response = await _client.delete(
        Uri.parse('$baseUrl/notar/zahlungen.php?id=$id'),
        headers: _headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to delete: $e'};
    }
  }

  // Get Notar Aufgaben (Tasks)
  Future<Map<String, dynamic>> getNotarAufgaben({int? notarId}) async {
    try {
      String url = '$baseUrl/notar/aufgaben.php';
      if (notarId != null) {
        url += '?notar_id=$notarId';
      }
      final response = await _client.get(Uri.parse(url), headers: _headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to load: $e'};
    }
  }

  // Create Notar Aufgabe
  Future<Map<String, dynamic>> createNotarAufgabe(Map<String, dynamic> data) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/notar/aufgaben.php'),
        headers: _headers,
        body: jsonEncode(data),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to create: $e'};
    }
  }

  // Update Notar Aufgabe
  Future<Map<String, dynamic>> updateNotarAufgabe(Map<String, dynamic> data) async {
    try {
      final response = await _client.put(
        Uri.parse('$baseUrl/notar/aufgaben.php'),
        headers: _headers,
        body: jsonEncode(data),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to update: $e'};
    }
  }

  // Delete Notar Aufgabe
  Future<Map<String, dynamic>> deleteNotarAufgabe(int id) async {
    try {
      final response = await _client.delete(
        Uri.parse('$baseUrl/notar/aufgaben.php?id=$id'),
        headers: _headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to delete: $e'};
    }
  }

  // ============= CHAT SCHEDULED MESSAGES API =============

  Future<Map<String, dynamic>> getScheduledMessages() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/chat/scheduled_messages.php'),
        headers: _headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to load scheduled messages: $e'};
    }
  }

  Future<Map<String, dynamic>> createScheduledMessage({
    required String sendTime,
    required String message,
    String category = 'mahlzeit',
    String daysOfWeek = '1,2,3,4,5,6,7',
    String? createdBy,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/chat/scheduled_messages.php'),
        headers: _headers,
        body: jsonEncode({
          'send_time': sendTime,
          'message': message,
          'category': category,
          'days_of_week': daysOfWeek,
          if (createdBy != null) 'created_by': createdBy,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to create scheduled message: $e'};
    }
  }

  Future<Map<String, dynamic>> updateScheduledMessage({
    required int id,
    String? sendTime,
    String? message,
    String? category,
    String? daysOfWeek,
    bool? isActive,
  }) async {
    try {
      final response = await _client.put(
        Uri.parse('$baseUrl/chat/scheduled_messages.php'),
        headers: _headers,
        body: jsonEncode({
          'id': id,
          if (sendTime != null) 'send_time': sendTime,
          if (message != null) 'message': message,
          if (category != null) 'category': category,
          if (daysOfWeek != null) 'days_of_week': daysOfWeek,
          if (isActive != null) 'is_active': isActive ? 1 : 0,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to update scheduled message: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteScheduledMessage(int id) async {
    try {
      final response = await _client.delete(
        Uri.parse('$baseUrl/chat/scheduled_messages.php?id=$id'),
        headers: _headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to delete scheduled message: $e'};
    }
  }

  // ============= PER-CONVERSATION SCHEDULED MESSAGES =============

  // Get scheduled messages for a conversation (with enabled/disabled status)
  Future<Map<String, dynamic>> getConversationScheduled(int conversationId) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/chat/conversation_scheduled.php?conversation_id=$conversationId'),
        headers: _headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to load conversation scheduled: $e'};
    }
  }

  // Toggle a scheduled message for a conversation
  Future<Map<String, dynamic>> toggleConversationScheduled(int conversationId, int scheduledMessageId, bool enable) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/chat/conversation_scheduled.php'),
        headers: _headers,
        body: jsonEncode({
          'conversation_id': conversationId,
          'scheduled_message_id': scheduledMessageId,
          'enable': enable,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to toggle scheduled message: $e'};
    }
  }

  // ============= DHL TRACKING API =============

  // Get saved tracking shipments
  Future<Map<String, dynamic>> getDhlShipments() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/tracking/dhl.php?action=list'),
        headers: _headers,
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to load shipments: $e'};
    }
  }

  // Track a shipment via DHL API
  Future<Map<String, dynamic>> trackDhlShipment(String trackingNumber) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/tracking/dhl.php?action=track&number=${Uri.encodeComponent(trackingNumber)}'),
        headers: _headers,
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to track shipment: $e'};
    }
  }

  // Save a new shipment to track
  Future<Map<String, dynamic>> addDhlShipment(String trackingNumber, {String? beschreibung, String? createdBy}) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/tracking/dhl.php'),
        headers: _headers,
        body: jsonEncode({
          'tracking_number': trackingNumber,
          if (beschreibung != null) 'beschreibung': beschreibung,
          if (createdBy != null) 'created_by': createdBy,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to add shipment: $e'};
    }
  }

  // Delete a saved shipment
  Future<Map<String, dynamic>> deleteDhlShipment(int id) async {
    try {
      final response = await _client.delete(
        Uri.parse('$baseUrl/tracking/dhl.php?id=$id'),
        headers: _headers,
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to delete shipment: $e'};
    }
  }

  // ============= DHL SETTINGS API =============

  Future<Map<String, dynamic>> getDhlSettings() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/tracking/dhl_settings.php'),
        headers: _headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to load DHL settings: $e'};
    }
  }

  Future<Map<String, dynamic>> saveDhlSettings({required String email, required String password, String? updatedBy}) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/tracking/dhl_settings.php'),
        headers: _headers,
        body: jsonEncode({
          'email': email,
          'password': password,
          if (updatedBy != null) 'updated_by': updatedBy,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to save DHL settings: $e'};
    }
  }

  // ============= DHL FILIALFINDER API =============

  Future<Map<String, dynamic>> findDhlLocations({String? plz, String? ort, int limit = 20}) async {
    try {
      final params = <String, String>{};
      if (plz != null && plz.isNotEmpty) params['plz'] = plz;
      if (ort != null && ort.isNotEmpty) params['ort'] = ort;
      params['limit'] = limit.toString();

      final uri = Uri.parse('$baseUrl/tracking/filialfinder.php').replace(queryParameters: params);
      final response = await _client.get(uri, headers: _headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Filialfinder Fehler: $e'};
    }
  }

  // ============= ADMIN STATUS MESSAGE API =============

  // Get active admin status message (banner)
  Future<Map<String, dynamic>> getAdminStatusMessage() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/admin/status_message.php'),
        headers: _headers,
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to load status message: $e'};
    }
  }

  // Set or update admin status message
  Future<Map<String, dynamic>> setAdminStatusMessage(String message, {String? createdBy}) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/admin/status_message.php'),
        headers: _headers,
        body: jsonEncode({
          'message': message,
          if (createdBy != null) 'created_by': createdBy,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to set status message: $e'};
    }
  }

  // Clear (deactivate) admin status message
  Future<Map<String, dynamic>> clearAdminStatusMessage() async {
    try {
      final response = await _client.delete(
        Uri.parse('$baseUrl/admin/status_message.php'),
        headers: _headers,
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to clear status message: $e'};
    }
  }

  // ============= LOGS API =============

  // Push client logs to server
  Future<Map<String, dynamic>> pushLogs({
    required String mitgliedernummer,
    required String deviceId,
    required String machineName,
    required String platform,
    required List<Map<String, dynamic>> logs,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/logs/store.php'),
        headers: _headers,
        body: jsonEncode({
          'mitgliedernummer': mitgliedernummer,
          'device_id': deviceId,
          'machine_name': machineName,
          'platform': platform,
          'logs': logs,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Push logs failed: $e'};
    }
  }

  // ============= CHANGELOG API =============

  // Get changelog (protected endpoint - Vorsitzer Portal)
  Future<Map<String, dynamic>> getChangelog() async {
    final log = LoggerService();
    try {
      log.info('Fetching changelog from API', tag: 'CHANGELOG');

      final response = await _client.get(
        Uri.parse('$baseUrl/changelog_schatzmeister.php'),
        headers: _headers,
      );

      log.info('Changelog API Response Status: ${response.statusCode}', tag: 'CHANGELOG');
      log.debug('Changelog API Response Body: ${response.body}', tag: 'CHANGELOG');

      final decoded = jsonDecode(response.body);
      log.info('Changelog decoded successfully', tag: 'CHANGELOG');

      return decoded;
    } catch (e) {
      log.error('Changelog API Error: $e', tag: 'CHANGELOG');
      return {'success': false, 'message': 'Failed to load changelog: $e'};
    }
  }

  // Krankenkassen lista din DB
  Future<Map<String, dynamic>> getKrankenkassen({String? typ}) async {
    final uri = typ != null
        ? Uri.parse('$baseUrl/stadtverwaltung/krankenkassen.php?typ=$typ')
        : Uri.parse('$baseUrl/stadtverwaltung/krankenkassen.php');

    final response = await _client.get(uri, headers: _headers);
    return jsonDecode(response.body);
  }

  // Behörden lista din DB
  Future<Map<String, dynamic>> getBehoerden({String? kategorie}) async {
    final uri = kategorie != null
        ? Uri.parse('$baseUrl/stadtverwaltung/behoerden.php?kategorie=$kategorie')
        : Uri.parse('$baseUrl/stadtverwaltung/behoerden.php');
    final response = await _client.get(uri, headers: _headers);
    return jsonDecode(response.body);
  }

  // Krankenhäuser lista din DB
  Future<Map<String, dynamic>> getKrankenhaeuser({String? typ}) async {
    final uri = typ != null
        ? Uri.parse('$baseUrl/stadtverwaltung/krankenhaeuser.php?typ=$typ')
        : Uri.parse('$baseUrl/stadtverwaltung/krankenhaeuser.php');
    final response = await _client.get(uri, headers: _headers);
    return jsonDecode(response.body);
  }

  // Praxen lista din DB
  Future<Map<String, dynamic>> getPraxen({String? kategorie}) async {
    final uri = kategorie != null
        ? Uri.parse('$baseUrl/stadtverwaltung/praxen.php?kategorie=$kategorie')
        : Uri.parse('$baseUrl/stadtverwaltung/praxen.php');
    final response = await _client.get(uri, headers: _headers);
    return jsonDecode(response.body);
  }

  // Drogerien lista din DB
  Future<Map<String, dynamic>> getDrogerien({String? typ}) async {
    final uri = typ != null
        ? Uri.parse('$baseUrl/stadtverwaltung/drogerien.php?typ=$typ')
        : Uri.parse('$baseUrl/stadtverwaltung/drogerien.php');
    final response = await _client.get(uri, headers: _headers);
    return jsonDecode(response.body);
  }

  // Märkte lista din DB
  Future<Map<String, dynamic>> getMaerkte({String? typ}) async {
    final uri = typ != null
        ? Uri.parse('$baseUrl/stadtverwaltung/maerkte.php?typ=$typ')
        : Uri.parse('$baseUrl/stadtverwaltung/maerkte.php');
    final response = await _client.get(uri, headers: _headers);
    return jsonDecode(response.body);
  }

  // Get verification stages for a user
  Future<Map<String, dynamic>> getVerifizierung(int userId) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/admin/verifizierung_list.php'),
      headers: _headers,
      body: jsonEncode({'user_id': userId}),
    );
    return jsonDecode(response.body);
  }

  // ========== FINANZVERWALTUNG ==========

  // Bank-Transaktionen abrufen
  Future<Map<String, dynamic>> getBankTransaktionen({int? monat, int? jahr, String? typ}) async {
    final params = <String, String>{};
    if (monat != null) params['monat'] = monat.toString();
    if (jahr != null) params['jahr'] = jahr.toString();
    if (typ != null) params['typ'] = typ;
    final query = params.isNotEmpty ? '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}' : '';
    final response = await _client.get(
      Uri.parse('$baseUrl/schatzmeister/finanzen/transaktionen.php$query'),
      headers: _headers,
    );
    return jsonDecode(response.body);
  }

  // Neue Bank-Transaktion erstellen
  Future<Map<String, dynamic>> createBankTransaktion({
    required String datum,
    required double betrag,
    required String typ,
    String? kategorie,
    String? beschreibung,
    String? empfaengerAbsender,
    String? referenz,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/schatzmeister/finanzen/transaktionen.php'),
      headers: _headers,
      body: jsonEncode({
        'datum': datum,
        'betrag': betrag,
        'typ': typ,
        if (kategorie != null) 'kategorie': kategorie,
        if (beschreibung != null) 'beschreibung': beschreibung,
        if (empfaengerAbsender != null) 'empfaenger_absender': empfaengerAbsender,
        if (referenz != null) 'referenz': referenz,
      }),
    );
    return jsonDecode(response.body);
  }

  // Bank-Transaktion löschen
  Future<Map<String, dynamic>> deleteBankTransaktion(int id) async {
    final request = http.Request('DELETE', Uri.parse('$baseUrl/schatzmeister/finanzen/transaktionen.php'));
    request.headers.addAll(_headers);
    request.body = jsonEncode({'id': id});
    final streamed = await _client.send(request);
    final body = await streamed.stream.bytesToString();
    return jsonDecode(body);
  }

  // Beitragszahlungen abrufen (für einen Monat/Jahr)
  Future<Map<String, dynamic>> getBeitragszahlungen({int? monat, int? jahr}) async {
    final params = <String, String>{};
    if (monat != null) params['monat'] = monat.toString();
    if (jahr != null) params['jahr'] = jahr.toString();
    final query = params.isNotEmpty ? '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}' : '';
    final response = await _client.get(
      Uri.parse('$baseUrl/schatzmeister/finanzen/beitragszahlungen.php$query'),
      headers: _headers,
    );
    return jsonDecode(response.body);
  }

  // Beitragszahlung erstellen/aktualisieren
  Future<Map<String, dynamic>> updateBeitragszahlung({
    required String mitgliedernummer,
    required int monat,
    required int jahr,
    required double betrag,
    required String status,
    String? zahlungsdatum,
    String? zahlungsmethode,
    String? notiz,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/schatzmeister/finanzen/beitragszahlungen.php'),
      headers: _headers,
      body: jsonEncode({
        'mitgliedernummer': mitgliedernummer,
        'monat': monat,
        'jahr': jahr,
        'betrag': betrag,
        'status': status,
        if (zahlungsdatum != null) 'zahlungsdatum': zahlungsdatum,
        if (zahlungsmethode != null) 'zahlungsmethode': zahlungsmethode,
        if (notiz != null) 'notiz': notiz,
      }),
    );
    return jsonDecode(response.body);
  }

  // Spenden abrufen
  Future<Map<String, dynamic>> getSpenden({int? jahr}) async {
    final params = <String, String>{};
    if (jahr != null) params['jahr'] = jahr.toString();
    final query = params.isNotEmpty ? '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}' : '';
    final response = await _client.get(
      Uri.parse('$baseUrl/schatzmeister/finanzen/spenden.php$query'),
      headers: _headers,
    );
    return jsonDecode(response.body);
  }

  // Spende erstellen
  Future<Map<String, dynamic>> createSpende({
    required String datum,
    required double betrag,
    required String spenderName,
    String? spenderAdresse,
    String? spenderMitgliedernummer,
    String? zweck,
    bool quittungAusgestellt = false,
    String? notiz,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/schatzmeister/finanzen/spenden.php'),
      headers: _headers,
      body: jsonEncode({
        'datum': datum,
        'betrag': betrag,
        'spender_name': spenderName,
        if (spenderAdresse != null) 'spender_adresse': spenderAdresse,
        if (spenderMitgliedernummer != null) 'spender_mitgliedernummer': spenderMitgliedernummer,
        if (zweck != null) 'zweck': zweck,
        'quittung_ausgestellt': quittungAusgestellt ? 1 : 0,
        if (notiz != null) 'notiz': notiz,
      }),
    );
    return jsonDecode(response.body);
  }

  // Spende löschen
  Future<Map<String, dynamic>> deleteSpende(int id) async {
    final request = http.Request('DELETE', Uri.parse('$baseUrl/schatzmeister/finanzen/spenden.php'));
    request.headers.addAll(_headers);
    request.body = jsonEncode({'id': id});
    final streamed = await _client.send(request);
    final body = await streamed.stream.bytesToString();
    return jsonDecode(body);
  }

  // Update a verification stage
  Future<Map<String, dynamic>> updateVerifizierung({
    required int userId,
    required int stufe,
    required String status,
    String? notiz,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/admin/verifizierung_update.php'),
      headers: _headers,
      body: jsonEncode({
        'user_id': userId,
        'stufe': stufe,
        'status': status,
        if (notiz != null) 'notiz': notiz,
      }),
    );
    return jsonDecode(response.body);
  }

  // ========== BEFREIUNG ==========

  // List befreiung entries for a user
  Future<Map<String, dynamic>> getBefreiungen(int userId) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/schatzmeister/befreiung_list.php'),
      headers: _headers,
      body: jsonEncode({'user_id': userId}),
    );
    return jsonDecode(response.body);
  }

  // Upload befreiung document (multipart)
  Future<Map<String, dynamic>> uploadBefreiung({
    required int userId,
    required String behoerde,
    required String gueltigVon,
    required String gueltigBis,
    String? bescheidDatum,
    String? notiz,
    required String filePath,
    required String fileName,
  }) async {
    final uri = Uri.parse('$baseUrl/schatzmeister/befreiung_upload.php');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_headers);
    request.fields['user_id'] = userId.toString();
    request.fields['behoerde'] = behoerde;
    request.fields['gueltig_von'] = gueltigVon;
    request.fields['gueltig_bis'] = gueltigBis;
    if (bescheidDatum != null) request.fields['bescheid_datum'] = bescheidDatum;
    if (notiz != null) request.fields['notiz'] = notiz;
    request.files.add(await http.MultipartFile.fromPath('file', filePath, filename: fileName));
    final streamed = await _client.send(request);
    final body = await streamed.stream.bytesToString();
    return jsonDecode(body);
  }

  // Update befreiung status (genehmigt/abgelehnt/eingereicht)
  Future<Map<String, dynamic>> updateBefreiung({
    required int id,
    required String status,
    String? notiz,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/schatzmeister/befreiung_update.php'),
      headers: _headers,
      body: jsonEncode({
        'id': id,
        'status': status,
        if (notiz != null) 'notiz': notiz,
      }),
    );
    return jsonDecode(response.body);
  }

  // Delete befreiung entry
  Future<Map<String, dynamic>> deleteBefreiung(int id) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/schatzmeister/befreiung_delete.php'),
      headers: _headers,
      body: jsonEncode({'id': id}),
    );
    return jsonDecode(response.body);
  }

  // Download befreiung document (returns base64 data)
  Future<Map<String, dynamic>> downloadBefreiung(int id) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/schatzmeister/befreiung_download.php'),
      headers: _headers,
      body: jsonEncode({'id': id}),
    );
    return jsonDecode(response.body);
  }

  // ══════════════════════════════════════════════════════════════
  // ERMÄSSIGUNG (fee reduction applications)
  // ══════════════════════════════════════════════════════════════

  // List Ermäßigungsanträge (optional filter by user_id)
  Future<Map<String, dynamic>> getErmaessigungsantraege({int? userId}) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/schatzmeister/ermaessigung_list.php'),
      headers: _headers,
      body: jsonEncode({if (userId != null) 'user_id': userId}),
    );
    return jsonDecode(response.body);
  }

  // Update Ermäßigungsantrag (status, checklist, rejection reason)
  Future<Map<String, dynamic>> updateErmaessigung({
    required int id,
    String? status,
    bool? checkDokumentLesbar,
    bool? checkLeistungsartErkennbar,
    bool? checkAktuell12Monate,
    String? ablehnungsgrund,
    String? notiz,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/schatzmeister/ermaessigung_update.php'),
      headers: _headers,
      body: jsonEncode({
        'id': id,
        if (status != null) 'status': status,
        if (checkDokumentLesbar != null) 'check_dokument_lesbar': checkDokumentLesbar,
        if (checkLeistungsartErkennbar != null) 'check_leistungsart_erkennbar': checkLeistungsartErkennbar,
        if (checkAktuell12Monate != null) 'check_aktuell_12monate': checkAktuell12Monate,
        if (ablehnungsgrund != null) 'ablehnungsgrund': ablehnungsgrund,
        if (notiz != null) 'notiz': notiz,
      }),
    );
    return jsonDecode(response.body);
  }

  // Delete Ermäßigungsantrag
  Future<Map<String, dynamic>> deleteErmaessigung(int id) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/schatzmeister/ermaessigung_delete.php'),
      headers: _headers,
      body: jsonEncode({'id': id}),
    );
    return jsonDecode(response.body);
  }

  // Download Ermäßigung document (returns base64 data)
  Future<Map<String, dynamic>> downloadErmaessigung(int id) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/schatzmeister/ermaessigung_download.php'),
      headers: _headers,
      body: jsonEncode({'id': id}),
    );
    return jsonDecode(response.body);
  }

  // ══════════════════════════════════════════════════════════════
  // NOTIZEN (internal notes per member)
  // ══════════════════════════════════════════════════════════════

  // List notes for a user
  Future<Map<String, dynamic>> getNotizen(int userId) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/schatzmeister/notizen_list.php'),
      headers: _headers,
      body: jsonEncode({'user_id': userId}),
    );
    return jsonDecode(response.body);
  }

  // Create a note for a user
  Future<Map<String, dynamic>> createNotiz({
    required int userId,
    required String notiz,
    String kategorie = 'allgemein',
    bool wichtig = false,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/schatzmeister/notizen_create.php'),
      headers: _headers,
      body: jsonEncode({
        'user_id': userId,
        'notiz': notiz,
        'kategorie': kategorie,
        'wichtig': wichtig,
      }),
    );
    return jsonDecode(response.body);
  }

  // Delete a note
  Future<Map<String, dynamic>> deleteNotiz(int id) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/schatzmeister/notizen_delete.php'),
      headers: _headers,
      body: jsonEncode({'id': id}),
    );
    return jsonDecode(response.body);
  }

  // ══════════════════════════════════════════════════════════════
  // ARCHIV (Encrypted archive storage)
  // ══════════════════════════════════════════════════════════════

  // Get all archives
  Future<Map<String, dynamic>> getArchives() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/schatzmeister/archiv_list.php'),
      headers: _headers,
    );
    return jsonDecode(response.body);
  }

  // Upload archive file (encrypted on server)
  Future<Map<String, dynamic>> uploadArchive({
    required String personName,
    String? mitgliedernummer,
    required String titel,
    required String beschreibung,
    required String kategorie,
    required String originalFilename,
    required int filesize,
    required String data,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/schatzmeister/archiv_upload.php'),
      headers: _headers,
      body: jsonEncode({
        'person_name': personName,
        if (mitgliedernummer != null) 'mitgliedernummer': mitgliedernummer,
        'titel': titel,
        'beschreibung': beschreibung,
        'kategorie': kategorie,
        'original_filename': originalFilename,
        'filesize': filesize,
        'data': data,
      }),
    );
    return jsonDecode(response.body);
  }

  // Download archive file (decrypted, returns base64)
  Future<Map<String, dynamic>> downloadArchive(int id) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/schatzmeister/archiv_download.php'),
      headers: _headers,
      body: jsonEncode({'id': id}),
    );
    return jsonDecode(response.body);
  }

  // Delete archive entry + encrypted file
  Future<Map<String, dynamic>> deleteArchive(int id) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/schatzmeister/archiv_delete.php'),
      headers: _headers,
      body: jsonEncode({'id': id}),
    );
    return jsonDecode(response.body);
  }
}
