import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'api_service.dart';
import 'http_client_factory.dart';
import 'logger_service.dart';
import 'notification_service.dart';

final _log = LoggerService();

/// Self-hosted push notification service via ntfy (no Google dependency)
/// Subscribes to a user-specific topic and shows local notifications
/// when messages arrive (even when WebSocket is dead on Android)
///
/// Security: ntfy topics require authentication (anonymous access blocked)
/// Token is fetched from server via JWT-protected endpoint, NOT hardcoded
class NtfyService {
  static final NtfyService _instance = NtfyService._internal();
  factory NtfyService() => _instance;
  NtfyService._internal();

  static const String _ntfyBaseUrl = 'https://icd360sev.icd360s.de/ntfy';
  static const String _topicPrefix = 'schatzmeister_';
  static const String _ntfyTokenUrl = 'https://icd360sev.icd360s.de/api/auth/ntfy_token.php';

  String? _mitgliedernummer;
  String? _ntfyToken;
  bool _isListening = false;
  http.Client? _client;
  StreamSubscription? _subscription;

  /// Start listening for push notifications on user's topic
  void start(String mitgliedernummer) {
    if (_isListening && _mitgliedernummer == mitgliedernummer) return;

    stop(); // Clean up previous subscription

    _mitgliedernummer = mitgliedernummer;
    _isListening = true;
    _log.info('NtfyService: Starting for $mitgliedernummer', tag: 'NTFY');
    _fetchTokenAndConnect();
  }

  /// Stop listening
  void stop() {
    _isListening = false;
    _subscription?.cancel();
    _subscription = null;
    _client?.close();
    _client = null;
    _log.info('NtfyService: Stopped', tag: 'NTFY');
  }

  /// Fetch ntfy token from server (JWT-protected) then connect
  Future<void> _fetchTokenAndConnect() async {
    if (!_isListening) return;

    try {
      final jwtToken = ApiService().token;
      if (jwtToken == null) {
        _log.error('NtfyService: No JWT token, cannot fetch ntfy token', tag: 'NTFY');
        _scheduleReconnect();
        return;
      }

      final pinnedClient = IOClient(HttpClientFactory.createPinnedHttpClient());
      final response = await pinnedClient.get(
        Uri.parse(_ntfyTokenUrl),
        headers: {
          'Authorization': 'Bearer $jwtToken',
        },
      ).timeout(const Duration(seconds: 10));
      pinnedClient.close();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['ntfy_token'] != null) {
          _ntfyToken = data['ntfy_token'] as String;
          _log.info('NtfyService: Token fetched successfully', tag: 'NTFY');
          _connect();
          return;
        }
      }

      _log.error('NtfyService: Failed to fetch token (HTTP ${response.statusCode})', tag: 'NTFY');
      _scheduleReconnect();
    } catch (e) {
      _log.error('NtfyService: Token fetch error: $e', tag: 'NTFY');
      _scheduleReconnect();
    }
  }

  /// Connect to ntfy topic via SSE (Server-Sent Events / JSON stream)
  void _connect() async {
    if (!_isListening || _mitgliedernummer == null || _ntfyToken == null) return;

    final topic = '$_topicPrefix${_mitgliedernummer!.toLowerCase()}';
    final url = '$_ntfyBaseUrl/$topic/json';

    _log.info('NtfyService: Connecting to $url', tag: 'NTFY');

    try {
      final pinnedHttpClient = HttpClientFactory.createPinnedHttpClient(
        idleTimeout: const Duration(minutes: 30),
      );
      _client = IOClient(pinnedHttpClient);
      final request = http.Request('GET', Uri.parse(url));
      request.headers['Accept'] = 'application/x-ndjson';
      request.headers['Authorization'] = 'Bearer $_ntfyToken';

      final response = await _client!.send(request);

      if (response.statusCode == 401 || response.statusCode == 403) {
        _log.error('NtfyService: Auth failed (${response.statusCode}), refetching token...', tag: 'NTFY');
        _ntfyToken = null;
        _subscription?.cancel();
        _client?.close();
        _client = null;
        if (_isListening) {
          Future.delayed(const Duration(seconds: 2), () {
            if (_isListening) _fetchTokenAndConnect();
          });
        }
        return;
      }

      if (response.statusCode != 200) {
        _log.error('NtfyService: HTTP ${response.statusCode}', tag: 'NTFY');
        _scheduleReconnect();
        return;
      }

      _log.info('NtfyService: Connected, listening...', tag: 'NTFY');

      _subscription = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          if (line.trim().isEmpty) return;
          _handleMessage(line);
        },
        onError: (error) {
          _log.error('NtfyService: Stream error: $error', tag: 'NTFY');
          _scheduleReconnect();
        },
        onDone: () {
          _log.info('NtfyService: Stream closed', tag: 'NTFY');
          _scheduleReconnect();
        },
        cancelOnError: false,
      );
    } catch (e) {
      _log.error('NtfyService: Connection error: $e', tag: 'NTFY');
      _scheduleReconnect();
    }
  }

  /// Handle incoming ntfy message
  void _handleMessage(String line) {
    try {
      final data = jsonDecode(line);

      // Skip keepalive/open events
      if (data['event'] != 'message') return;

      final title = data['title'] ?? 'Benachrichtigung';
      final message = data['message'] ?? '';

      _log.info('NtfyService: Received: $title - $message', tag: 'NTFY');

      // Show local notification
      NotificationService().show(
        title: title,
        body: message,
      );
    } catch (e) {
      _log.error('NtfyService: Parse error: $e', tag: 'NTFY');
    }
  }

  /// Reconnect after delay
  void _scheduleReconnect() {
    _subscription?.cancel();
    _subscription = null;
    _client?.close();
    _client = null;

    if (!_isListening) return;

    _log.info('NtfyService: Reconnecting in 5s...', tag: 'NTFY');
    Future.delayed(const Duration(seconds: 5), () {
      if (_isListening) {
        // If token is missing, refetch; otherwise just reconnect
        if (_ntfyToken == null) {
          _fetchTokenAndConnect();
        } else {
          _connect();
        }
      }
    });
  }
}
