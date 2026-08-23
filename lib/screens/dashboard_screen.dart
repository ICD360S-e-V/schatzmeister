import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';
import '../services/chat_service.dart';
import '../services/heartbeat_service.dart';
import '../services/diagnostic_service.dart';
import '../services/tray_service.dart';
import '../services/ticket_service.dart';
import '../services/ticket_notification_service.dart';
import '../services/notification_service.dart';
import '../services/weather_service.dart';
import '../services/ntfy_service.dart';
import '../models/user.dart';
import '../widgets/live_chat_dialog.dart';
import '../widgets/update_dialog.dart';
import '../widgets/incoming_call_dialog.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/legal_footer.dart';
import 'archiv_screen.dart';
import 'dienste_screen.dart';
import 'eigene_unterschriften_screen.dart';
import 'routinenaufgaben_screen.dart';
import 'statistik_screen.dart';
import 'login_with_code_screen.dart';
import '../services/termin_service.dart';
import '../widgets/profile_dialog.dart';
import '../widgets/dashboard_sidebar.dart';
import '../widgets/eastern.dart';
import '../utils/role_helpers.dart';
import 'vereinverwaltung_screen.dart';
import 'finanzverwaltung_screen.dart';

final _log = LoggerService();

class DashboardScreen extends StatefulWidget {
  final String userName;
  final String currentMitgliedernummer;
  final String currentEmail;
  final String currentRole;

  const DashboardScreen({
    super.key,
    required this.userName,
    required this.currentMitgliedernummer,
    required this.currentEmail,
    required this.currentRole,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  final _apiService = ApiService();
  final _chatService = ChatService();
  late final _heartbeatService = HeartbeatService(_apiService);
  final _ticketNotificationService = TicketNotificationService();
  List<User> _users = [];
  late String _currentEmail;

  // Sidebar navigation
  int _selectedMenuIndex = 0;

  // Unread chat messages counter
  int _unreadChatCount = 0;
  int _offeneUnterschriften = 0;
  StreamSubscription<ChatMessage>? _messageSubscription;
  StreamSubscription<CallOfferEvent>? _callOfferSubscription;
  StreamSubscription<TicketNotificationEvent>? _ticketNotificationSubscription;
  StreamSubscription<String>? _notificationClickSubscription;

  // Pending incoming call (when AdminChatDialog is not open)
  CallOfferEvent? _pendingCall;
  bool _isAdminChatOpen = false;

  // Auto-refresh timer for tickets
  Timer? _ticketRefreshTimer;

  // Payment reminder
  Timer? _paymentReminderTimer;
  bool _paymentReminderShownToday = false;

  // Weather
  final _weatherService = WeatherService();
  WeatherData? _weatherData;
  List<WeatherAlert> _weatherAlerts = [];


  // Background conversation IDs for receiving messages
  List<int> _backgroundConversationIds = [];

  // Ticket & Termin (read-only for Schatzmeister)
  final _ticketService = TicketService();
  final _terminService = TerminService();
  List<Ticket> _myTickets = [];
  bool _isLoadingMyTickets = false;
  List<Map<String, dynamic>> _myTermine = [];
  bool _isLoadingMyTermine = false;

  // Weekly time tracking

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Start periodic log upload to server (every 30s)
    _log.startUpload(widget.currentMitgliedernummer);

    _currentEmail = widget.currentEmail;
    // Set token for TerminService (singleton needs auth token for API calls)
    _terminService.setToken(_apiService.token);
    _loadBoardMembers();
    _loadMyTickets();
    _loadMyTermine();
    _loadOffeneUnterschriften();
    _connectWebSocket();
    _setupMessageListener();
    _setupTicketNotificationListener();
    _setupNotificationClickListener();
    _startTicketAutoRefresh();
    // Start heartbeat to update last_seen in real-time
    _heartbeatService.start(widget.currentMitgliedernummer);
    // Start ticket notification polling - WebSocket not working reliably
    _ticketNotificationService.start(widget.currentMitgliedernummer);
    // Set user info for diagnostic service (battery_level, battery_state)
    DiagnosticService().setUser(widget.currentMitgliedernummer, widget.currentRole);
    // Start ntfy push notifications (self-hosted, no Google dependency)
    NtfyService().start(widget.currentMitgliedernummer);
    // Check for updates and push logs after widget is built
    // Start weather service (uses city from user profile)
    _startWeatherService();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await checkAndShowUpdateDialog(context);
      // Push logs to server after login
      _log.pushToServer(widget.currentMitgliedernummer);
      // Check payment reminder
      _checkPaymentReminder();
      // Android: Request battery optimization exemption
      if (Platform.isAndroid) {
        _requestBatteryOptimization();
      }
    });
    // Check payment reminder every hour
    _paymentReminderTimer = Timer.periodic(const Duration(hours: 1), (_) => _checkPaymentReminder());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _ticketRefreshTimer?.cancel();
      _paymentReminderTimer?.cancel();
      _log.debug('App paused - UI timers stopped', tag: 'SYS');
    } else if (state == AppLifecycleState.resumed) {
      _startTicketAutoRefresh();
      _paymentReminderTimer = Timer.periodic(const Duration(hours: 1), (_) => _checkPaymentReminder());
      _loadMyTickets();
      _loadMyTermine();
      _log.debug('App resumed - UI timers restarted', tag: 'SYS');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _log.stopUpload(); // Stop periodic log upload
    _messageSubscription?.cancel();
    _callOfferSubscription?.cancel();
    _ticketNotificationSubscription?.cancel();
    _notificationClickSubscription?.cancel();
    _ticketRefreshTimer?.cancel();
    _heartbeatService.stop();
    _ticketNotificationService.stop();
    _paymentReminderTimer?.cancel();
    _weatherService.stop();
    NtfyService().stop();
    super.dispose();
  }

  /// Android: Request battery optimization exemption so WebSocket stays alive
  static const _batteryChannel = MethodChannel('de.icd360sev.schatzmeister/battery');

  Future<void> _requestBatteryOptimization() async {
    try {
      final isDisabled = await _batteryChannel.invokeMethod<bool>('isBatteryOptimizationDisabled');
      if (isDisabled != true && mounted) {
        await _batteryChannel.invokeMethod('requestDisableBatteryOptimization');
      }
    } catch (e) {
      _log.error('Battery optimization request failed: $e', tag: 'SYS');
    }
  }

  void _setupMessageListener() {
    // Listen for new messages at dashboard level for badge updates
    _messageSubscription = _chatService.messageStream.listen((message) {
      if (mounted) {
        setState(() {
          _unreadChatCount++;
        });
        _log.info('New message received, unread count: $_unreadChatCount', tag: 'DASH');
      }
    });

    // Listen for incoming calls at dashboard level
    _callOfferSubscription = _chatService.callOfferStream.listen((event) {
      if (mounted && !_isAdminChatOpen) {
        _handleIncomingCall(event);
      }
    });
  }

  void _handleIncomingCall(CallOfferEvent event) {
    _log.info('Incoming call from ${event.callerName} (conv: ${event.conversationId})', tag: 'DASH');
    _pendingCall = event;

    // Show incoming call dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => IncomingCallDialog(
        callerName: event.callerName,
        onAccept: () {
          Navigator.of(ctx).pop();
          // Open AdminChatDialog with pending call
          _showAdminChatDialogWithCall();
        },
        onReject: () {
          Navigator.of(ctx).pop();
          // Reject the call
          _chatService.sendCallReject(event.conversationId, 'rejected');
          _pendingCall = null;
        },
      ),
    );
  }

  void _setupTicketNotificationListener() {
    // Listen for ticket notifications via WebSocket
    _ticketNotificationSubscription = _chatService.ticketNotificationStream.listen((event) {
      _log.info('Ticket notification received: ${event.title}', tag: 'TICKET');

      // Auto-refresh ticket list when notification arrives
      if (mounted) {
        _loadMyTickets();
      }
    });
  }

  void _setupNotificationClickListener() {
    _notificationClickSubscription = NotificationService().onNotificationClicked.listen((payload) {
      if (!mounted) return;
      _log.info('Notification clicked with payload: $payload', tag: 'DASH');

      // Parse payload format: 'type:data'
      final parts = payload.split(':');
      final type = parts.isNotEmpty ? parts[0] : '';

      if (type == 'chat' && !_isAdminChatOpen) {
        _showAdminChatDialog();
      }
    });
  }

  void _startTicketAutoRefresh() {
    // Auto-refresh tickets every 30 seconds (fallback if WebSocket fails)
    _ticketRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && _selectedMenuIndex == 2) {
        // Only refresh if we're on Ticketverwaltung tab
        _log.debug('Auto-refreshing tickets...', tag: 'TICKET');
        _loadMyTickets();
      }
    });
  }

  Future<void> _connectWebSocket() async {
    // Connect to WebSocket for background notifications
    final connected = await _chatService.connect(widget.currentMitgliedernummer, userName: widget.userName);
    _log.info('WebSocket connected at login: $connected', tag: 'DASH');
    // Clear tray unread count when user is active
    TrayService().clearUnread();

    // Auto-join all conversations to receive messages even when chat dialog is closed
    if (connected) {
      await _joinBackgroundConversations();
    }
  }

  Future<void> _joinBackgroundConversations() async {
    try {
      // Get all conversations for admin
      final result = await _apiService.getChatConversations(widget.currentMitgliedernummer);
      if (result['success'] == true) {
        final conversations = List<Map<String, dynamic>>.from(result['conversations'] ?? []);
        _backgroundConversationIds = [];
        int totalUnread = 0;
        final myUserId = _chatService.currentUserId;
        for (final conv in conversations) {
          final status = conv['status'] ?? 'open';
          if (status == 'open') {
            // Only join own conversations (where we are the member)
            final memberId = conv['member_id'];
            if (memberId != null && myUserId != null && memberId != myUserId) {
              continue; // Skip conversations of other members
            }
            final convId = conv['id'];
            final id = convId is int ? convId : int.tryParse(convId.toString());
            if (id != null) {
              _backgroundConversationIds.add(id);
              _chatService.joinConversation(id);

              // Check for unread messages and send push notification
              final unreadCount = conv['unread_count'] ?? 0;
              if (unreadCount > 0) {
                totalUnread += unreadCount as int;
                final unknownLabel = mounted ? AppLocalizations.of(context).unknown : 'Unknown';
                final memberName = conv['member_name'] ?? unknownLabel;
                final lastMessage = conv['last_message'] ?? '';
                final msgPreview = lastMessage.length > 80
                    ? '${lastMessage.substring(0, 80)}...'
                    : lastMessage;

                final unreadMsg = mounted
                    ? AppLocalizations.of(context).unreadMessages(unreadCount)
                    : '$unreadCount unread';
                NotificationService().showChatMessage(
                  senderName: memberName,
                  message: unreadCount == 1
                      ? msgPreview
                      : '$unreadMsg: $msgPreview',
                  conversationId: id,
                );
              }
            }
          }
        }
        if (totalUnread > 0 && mounted) {
          setState(() {
            _unreadChatCount = totalUnread;
          });
        }
        _log.info('Background joined ${_backgroundConversationIds.length} conversations, $totalUnread unread', tag: 'DASH');
      }
    } catch (e) {
      _log.error('Failed to join background conversations: $e', tag: 'DASH');
    }
  }

  Future<void> _checkPaymentReminder() async {
    if (_paymentReminderShownToday) return;
    try {
      final result = await _apiService.getProfile(widget.currentMitgliedernummer);
      if (result['success'] != true) return;
      final zahlungstag = result['zahlungstag'] != null
          ? int.tryParse(result['zahlungstag'].toString())
          : null;
      if (zahlungstag == null) return;
      final now = DateTime.now();
      if (now.day == zahlungstag) {
        _paymentReminderShownToday = true;
        if (!mounted) return;
        final zahlungsmethode = result['zahlungsmethode']?.toString() ?? 'ueberweisung';
        final l = AppLocalizations.of(context);
        final methodLabel = {
          'ueberweisung': l.transfer,
          'sepa_lastschrift': l.sepaDirectDebit,
          'dauerauftrag': l.standingOrder,
        }[zahlungsmethode] ?? zahlungsmethode;
        await NotificationService().show(
          title: l.paymentReminder,
          body: l.paymentReminderBody(zahlungstag, methodLabel),
          payload: 'payment',
        );
        _log.info('Payment reminder shown for day $zahlungstag', tag: 'DASH');
      }
    } catch (e) {
      _log.error('Payment reminder check failed: $e', tag: 'DASH');
    }
  }

  Future<void> _startWeatherService() async {
    try {
      final result = await _apiService.getProfile(widget.currentMitgliedernummer);
      if (result['success'] == true) {
        final ort = result['ort']?.toString() ?? '';

        // Setup callbacks
        _weatherService.onWeatherUpdate = (weather) {
          if (mounted) setState(() => _weatherData = weather);
        };
        _weatherService.onAlertsUpdate = (alerts) {
          if (mounted) setState(() => _weatherAlerts = alerts);
        };
        // Start weather service
        if (ort.isNotEmpty) {
          await _weatherService.start(ort);
        }
      }
    } catch (e) {
      _log.error('Weather: Failed to start: $e', tag: 'WEATHER');
    }
  }

  void _showWeatherDialog() {
    final weather = _weatherData;
    if (weather == null) return;

    final df = DateFormat('HH:mm', 'de_DE');
    final dfDay = DateFormat('E dd.MM.', 'de_DE');
    final dfDayShort = DateFormat('E', 'de_DE');
    final now = DateTime.now();

    // Filter hourly forecast: next 24 hours
    final next24h = _weatherService.hourlyForecast
        .where((h) => h.time.isAfter(now) && h.time.isBefore(now.add(const Duration(hours: 25))))
        .toList();

    // Filter daily forecast: next 3 days
    final next3Days = _weatherService.dailyForecast.take(3).toList();

    // Full week (7 days)
    final weekForecast = _weatherService.dailyForecast.toList();

    final isMobileWeather = ResponsiveLayout.isMobile(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogWidth = isMobileWeather ? screenWidth * 0.95 : 520.0;
    final dialogHeight = isMobileWeather ? screenHeight * 0.85 : 580.0;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: EdgeInsets.all(isMobileWeather ? 8 : 40),
        child: SizedBox(
          width: dialogWidth,
          height: dialogHeight,
          child: DefaultTabController(
            length: 4,
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(weather.icon, style: const TextStyle(fontSize: 32)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(AppLocalizations.of(context).weatherIn(weather.city), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                Text(
                                  '${weather.description} • ${weather.temperature.toStringAsFixed(1)}°C',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 20),
                            tooltip: AppLocalizations.of(context).refresh,
                            onPressed: () async {
                              await _weatherService.refresh();
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) _showWeatherDialog();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TabBar(
                        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        unselectedLabelStyle: const TextStyle(fontSize: 12),
                        indicatorSize: TabBarIndicatorSize.tab,
                        tabs: [
                          Tab(text: AppLocalizations.of(context).weatherCurrentTab),
                          Tab(text: AppLocalizations.of(context).hourlyTab),
                          Tab(text: AppLocalizations.of(context).threeDays),
                          Tab(text: AppLocalizations.of(context).weatherWeekTab),
                        ],
                      ),
                    ],
                  ),
                ),
                // Tab content
                Expanded(
                  child: TabBarView(
                    children: [
                      // === TAB 1: Aktuell ===
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Current conditions
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _weatherDetailColumn(AppLocalizations.of(context).temperature, '${weather.temperature.toStringAsFixed(1)}°C', Icons.thermostat),
                                  _weatherDetailColumn(AppLocalizations.of(context).wind, '${weather.windSpeed.toStringAsFixed(0)} km/h', Icons.air),
                                  _weatherDetailColumn(AppLocalizations.of(context).humidity, '${weather.humidity}%', Icons.water_drop),
                                ],
                              ),
                            ),
                            // DWD Alerts
                            if (_weatherAlerts.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  const Icon(Icons.warning_amber, color: Colors.red, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    AppLocalizations.of(context).dwdWarnings(_weatherAlerts.length),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ..._weatherAlerts.map((alert) => _buildAlertCard(alert)),
                            ] else ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
                                    const SizedBox(width: 8),
                                    Text(AppLocalizations.of(context).noWeatherAlerts, style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Text(
                              AppLocalizations.of(context).weatherDataSource,
                              style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),

                      // === TAB 2: Stündlich (next 24h) ===
                      next24h.isEmpty
                          ? Center(child: Text(AppLocalizations.of(context).noHourlyData))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: next24h.length,
                              itemBuilder: (_, i) {
                                final h = next24h[i];
                                final isNow = i == 0;
                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isNow ? Colors.blue.shade50 : (i.isEven ? Colors.grey.shade50 : null),
                                    borderRadius: BorderRadius.circular(6),
                                    border: isNow ? Border.all(color: Colors.blue.shade200) : null,
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 45,
                                        child: Text(
                                          df.format(h.time),
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isNow ? FontWeight.bold : FontWeight.normal,
                                            color: isNow ? Colors.blue.shade800 : null,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(h.icon, style: const TextStyle(fontSize: 18)),
                                      const SizedBox(width: 10),
                                      SizedBox(
                                        width: 50,
                                        child: Text(
                                          '${h.temperature.toStringAsFixed(1)}°',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: h.temperature < 0 ? Colors.blue.shade800 : Colors.orange.shade800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(Icons.air, size: 14, color: Colors.grey.shade500),
                                      const SizedBox(width: 2),
                                      SizedBox(
                                        width: 55,
                                        child: Text(
                                          '${h.windSpeed.toStringAsFixed(0)} km/h',
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                        ),
                                      ),
                                      if (h.precipitation > 0) ...[
                                        Icon(Icons.water_drop, size: 14, color: Colors.blue.shade400),
                                        const SizedBox(width: 2),
                                        Text(
                                          '${h.precipitation.toStringAsFixed(1)} mm',
                                          style: TextStyle(fontSize: 11, color: Colors.blue.shade600),
                                        ),
                                      ],
                                      const Spacer(),
                                      SizedBox(
                                        width: 90,
                                        child: Text(
                                          h.description,
                                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),

                      // === TAB 3: 3 Tage ===
                      next3Days.isEmpty
                          ? Center(child: Text(AppLocalizations.of(context).noForecast))
                          : SingleChildScrollView(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: next3Days.map((d) => _buildDayForecastCard(d, dfDay)).toList(),
                              ),
                            ),

                      // === TAB 4: Woche ===
                      weekForecast.isEmpty
                          ? Center(child: Text(AppLocalizations.of(context).noForecast))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: weekForecast.length,
                              itemBuilder: (_, i) {
                                final d = weekForecast[i];
                                final isToday = d.date.day == now.day && d.date.month == now.month;
                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isToday ? Colors.blue.shade50 : (i.isEven ? Colors.grey.shade50 : null),
                                    borderRadius: BorderRadius.circular(8),
                                    border: isToday ? Border.all(color: Colors.blue.shade200) : null,
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 35,
                                        child: Text(
                                          isToday ? AppLocalizations.of(context).todayShort : dfDayShort.format(d.date),
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(d.icon, style: const TextStyle(fontSize: 20)),
                                      const SizedBox(width: 10),
                                      // Temperature range bar
                                      Text(
                                        '${d.tempMin.toStringAsFixed(0)}°',
                                        style: TextStyle(fontSize: 13, color: Colors.blue.shade700),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: _buildTempRangeBar(d.tempMin, d.tempMax, weekForecast),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${d.tempMax.toStringAsFixed(0)}°',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
                                      ),
                                      const SizedBox(width: 10),
                                      if (d.precipitationSum > 0) ...[
                                        Icon(Icons.water_drop, size: 14, color: Colors.blue.shade400),
                                        Text(
                                          d.precipitationSum.toStringAsFixed(1),
                                          style: TextStyle(fontSize: 11, color: Colors.blue.shade600),
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      Icon(Icons.air, size: 14, color: Colors.grey.shade400),
                                      const SizedBox(width: 2),
                                      SizedBox(
                                        width: 30,
                                        child: Text(
                                          d.windSpeedMax.toStringAsFixed(0),
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlertCard(WeatherAlert alert) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _alertColor(alert.severity).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _alertColor(alert.severity).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _alertColor(alert.severity),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  alert.severityLabel,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(alert.event, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(alert.headline, style: const TextStyle(fontSize: 11)),
          if (alert.onset != null || alert.expires != null) ...[
            const SizedBox(height: 4),
            Text(
              [
                if (alert.onset != null) '${AppLocalizations.of(context).from}: ${alert.onset!.day}.${alert.onset!.month}.${alert.onset!.year} ${alert.onset!.hour}:${alert.onset!.minute.toString().padLeft(2, '0')}',
                if (alert.expires != null) '${AppLocalizations.of(context).to}: ${alert.expires!.day}.${alert.expires!.month}.${alert.expires!.year} ${alert.expires!.hour}:${alert.expires!.minute.toString().padLeft(2, '0')}',
              ].join(' • '),
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDayForecastCard(DailyForecast day, DateFormat dfDay) {
    final now = DateTime.now();
    final isToday = day.date.day == now.day && day.date.month == now.month;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: isToday ? 2 : 0.5,
      color: isToday ? Colors.blue.shade50 : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: isToday ? BorderSide(color: Colors.blue.shade200) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(day.icon, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isToday ? AppLocalizations.of(context).today : dfDay.format(day.date),
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isToday ? Colors.blue.shade800 : null),
                      ),
                      Text(day.description, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${day.tempMax.toStringAsFixed(0)}°C',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
                    ),
                    Text(
                      '${day.tempMin.toStringAsFixed(0)}°C',
                      style: TextStyle(fontSize: 13, color: Colors.blue.shade700),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _weatherSmallInfo(Icons.air, '${day.windSpeedMax.toStringAsFixed(0)} km/h'),
                _weatherSmallInfo(Icons.water_drop, '${day.precipitationSum.toStringAsFixed(1)} mm'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTempRangeBar(double tempMin, double tempMax, List<DailyForecast> all) {
    // Calculate range across all days for normalization
    double globalMin = all.fold(double.infinity, (v, d) => d.tempMin < v ? d.tempMin : v);
    double globalMax = all.fold(-double.infinity, (v, d) => d.tempMax > v ? d.tempMax : v);
    final range = globalMax - globalMin;
    if (range <= 0) return const SizedBox();

    final leftFraction = (tempMin - globalMin) / range;
    final widthFraction = (tempMax - tempMin) / range;

    return LayoutBuilder(
      builder: (_, constraints) {
        final totalWidth = constraints.maxWidth;
        return Stack(
          children: [
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Positioned(
              left: leftFraction * totalWidth,
              child: Container(
                width: (widthFraction * totalWidth).clamp(4, totalWidth),
                height: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade300, Colors.orange.shade400],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _weatherSmallInfo(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
      ],
    );
  }

  Widget _weatherDetailColumn(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.blue.shade700),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue.shade800)),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
      ],
    );
  }

  Color _alertColor(String severity) {
    switch (severity) {
      case 'extreme': return Colors.red.shade800;
      case 'severe': return Colors.orange.shade700;
      case 'moderate': return Colors.amber.shade700;
      default: return Colors.yellow.shade700;
    }
  }

  // ── News Dialog ────────────────────────────────────────────


  Future<void> _loadBoardMembers() async {
    try {
      final result = await _apiService.getBoardMembers();

      if (result['success'] == true) {
        final usersList = result['users'] as List;
        setState(() {
          _users = usersList.map((u) => User.fromJson(u)).toList();
        });
      }
    } catch (_) {
      // Silently handle loading errors
    }
  }

  /// Wie viele Dokumente auf die Unterschrift des Schatzmeisters warten.
  ///
  /// Die Vorsitzer-App zählt das bewusst NICHT — dort hat der Vorsitzende die
  /// Unterschrift selbst angefordert und weiß, dass sie ansteht. Hier ist es
  /// umgekehrt: die Anforderung kommt von außen, und ohne Zähler würde sie
  /// schlicht übersehen. Gezählt wird beim Laden des Dashboards mit, kein
  /// eigener Takt.
  Future<void> _loadOffeneUnterschriften() async {
    try {
      final antwort = await _apiService.eigeneSignatur('list');
      if (!mounted || antwort['success'] != true) return;

      final liste = (antwort['signaturen'] as List?) ?? const [];
      final offen = liste
          .where((e) => e is Map && (e['status'] ?? 'offen') == 'offen')
          .length;

      setState(() => _offeneUnterschriften = offen);
    } catch (_) {
      // Ein fehlgeschlagener Zähler darf das Dashboard nicht aufhalten.
    }
  }

  Future<void> _loadMyTickets() async {
    setState(() => _isLoadingMyTickets = true);
    try {
      final tickets = await _ticketService.getTickets(widget.currentMitgliedernummer);
      if (mounted) {
        setState(() {
          _myTickets = tickets;
          _isLoadingMyTickets = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMyTickets = false);
    }
  }

  Future<void> _loadMyTermine() async {
    setState(() => _isLoadingMyTermine = true);
    try {
      final result = await _terminService.getMyTermine(filter: 'all');
      if (mounted && result['success'] == true) {
        setState(() {
          _myTermine = List<Map<String, dynamic>>.from(result['termine'] ?? []);
          _isLoadingMyTermine = false;
        });
      } else if (mounted) {
        setState(() => _isLoadingMyTermine = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMyTermine = false);
    }
  }

  Future<void> _logout() async {
    // Clear API tokens
    await _apiService.logout();

    // Clear auto-login flag and saved credentials
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_login', false);

    // Clear encrypted credentials + approval data
    const secureStorage = FlutterSecureStorage();
    await secureStorage.delete(key: 'mitgliedernummer');
    await secureStorage.delete(key: 'password');
    await secureStorage.delete(key: 'approval_token');
    await secureStorage.delete(key: 'approval_mitgliedernummer');

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginWithCodeScreen()),
      );
    }
  }

  void _showProfileDialog() {
    final currentUser = _users.where((u) => u.mitgliedernummer == widget.currentMitgliedernummer).firstOrNull;
    showDialog(
      context: context,
      builder: (context) => ProfileDialog(
        userName: widget.userName,
        mitgliedernummer: widget.currentMitgliedernummer,
        email: _currentEmail,
        role: widget.currentRole,
        userId: currentUser?.id,
        apiService: _apiService,
        onEmailChanged: (newEmail) {
          setState(() {
            _currentEmail = newEmail;
          });
        },
      ),
    );
  }

  void _showAdminChatDialog() {
    _showAdminChatDialogInternal(null);
  }

  void _showAdminChatDialogWithCall() {
    _showAdminChatDialogInternal(_pendingCall);
  }

  void _showAdminChatDialogInternal(CallOfferEvent? pendingCall) {
    // Clear unread count when opening chat
    setState(() {
      _unreadChatCount = 0;
      _isAdminChatOpen = true;
    });
    // Also clear tray unread count
    TrayService().clearUnread();

    showDialog(
      context: context,
      builder: (context) => LiveChatDialog(
        mitgliedernummer: widget.currentMitgliedernummer,
        userName: widget.userName,
        pendingCall: pendingCall,
      ),
    ).then((_) {
      // Mark dialog as closed
      setState(() {
        _isAdminChatOpen = false;
        _pendingCall = null;
      });
      // Re-join all conversations after dialog closes to keep receiving messages
      for (final convId in _backgroundConversationIds) {
        _chatService.joinConversation(convId);
      }
      _log.info('Re-joined ${_backgroundConversationIds.length} conversations after dialog close', tag: 'DASH');
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(isMobile ? 'ICD360S e.V' : 'ICD360S e.V - Schatzmeister Panel'),
        backgroundColor: const Color(0xFF1a1a2e),
        foregroundColor: Colors.white,
        flexibleSpace: SeasonalBackground.isEasterSeason
            ? IgnorePointer(
                child: CustomPaint(
                  painter: EasterAppBarPainter(),
                  size: Size.infinite,
                ),
              )
            : null,
        // Show hamburger menu on mobile
        leading: isMobile
            ? Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  tooltip: AppLocalizations.of(context).menu,
                ),
              )
            : null,
        actions: [
          // Welcome text - hide on mobile
          if (!isMobile)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  AppLocalizations.of(context).welcome(widget.userName),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          // Dokumente, die der Schatzmeister SELBST unterschreiben soll —
          // vom Vorsitzenden eingestellt (Kassenbericht, Bankvollmacht).
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.draw_outlined),
                tooltip: 'Meine Unterschriften',
                onPressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => EigeneUnterschriftenScreen(
                      apiService: _apiService,
                    ),
                  ));
                  // Nach der Rückkehr neu zählen: wer gerade unterschrieben
                  // hat, soll das Abzeichen nicht weiter sehen.
                  if (mounted) _loadOffeneUnterschriften();
                },
              ),
              if (_offeneUnterschriften > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      _offeneUnterschriften > 9 ? '9+' : '$_offeneUnterschriften',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          // Live Chat (Admin can chat with members) with unread badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.chat_outlined),
                onPressed: _showAdminChatDialog,
                tooltip: AppLocalizations.of(context).liveChat,
              ),
              // Unread count badge (shows when > 0)
              if (_unreadChatCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      _unreadChatCount > 9 ? '9+' : '$_unreadChatCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                // Online indicator (only when no unread messages)
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          // Weather widget
          if (_weatherData != null && !isMobile)
            InkWell(
              onTap: () => _showWeatherDialog(),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_weatherData!.icon, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 4),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_weatherData!.temperature.toStringAsFixed(0)}°C',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          _weatherData!.city,
                          style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.7)),
                        ),
                      ],
                    ),
                    if (_weatherAlerts.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${_weatherAlerts.length}',
                          style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: _showProfileDialog,
            tooltip: AppLocalizations.of(context).myProfile,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: AppLocalizations.of(context).logout,
          ),
        ],
      ),
      // Mobile: Use drawer for navigation
      drawer: isMobile
          ? Drawer(
              child: DashboardSidebar(
                userName: widget.userName,
                mitgliedernummer: widget.currentMitgliedernummer,
                selectedMenuIndex: _selectedMenuIndex,
                onMenuSelected: (index) {
                  setState(() => _selectedMenuIndex = index);
                  Navigator.pop(context); // Close drawer after selection
                },
              ),
            )
          : null,
      // Desktop: Sidebar + content, Mobile: Just content
      body: SeasonalBackground(
        child: isMobile
            ? _buildMainContent()
            : Row(
                children: [
                  DashboardSidebar(
                    userName: widget.userName,
                    mitgliedernummer: widget.currentMitgliedernummer,
                    selectedMenuIndex: _selectedMenuIndex,
                    onMenuSelected: (index) => setState(() => _selectedMenuIndex = index),
                  ),
                  Expanded(
                    child: _buildMainContent(),
                  ),
                ],
              ),
      ),
      // Impressum, Datenschutz, Changelog UND die automatische Update-Suche
      // (alle 5 Minuten) haengen an dieser Leiste. Sie stand bisher auf
      // `null`: damit fehlten die Pflichtangaben, und `checkForUpdate()`
      // wurde im ganzen laufenden Programm kein einziges Mal aufgerufen.
      // Dieselbe Platzierung wie in der Mitglieder-App.
      bottomNavigationBar: const LegalFooter(),
    );
  }


  Widget _buildMainContent() {
    switch (_selectedMenuIndex) {
      case 0:
        return _buildDashboardOverview();
      case 1:
        return const FinanzverwaltungScreen();
      case 2:
        return _buildMyTicketsReadOnly();
      case 3:
        return _buildMyTermineReadOnly();
      case 4:
        return VereinverwaltungScreen(
          apiService: _apiService,
          users: _users,
          getRoleColor: getRoleColor,
          getRoleText: getRoleText,
        );
      case 5:
        return ArchivScreen(apiService: _apiService, users: _users);
      case 6:
        return RoutinenaufgabenScreen(
          users: _users,
          currentMitgliedernummer: widget.currentMitgliedernummer,
        );
      case 7:
        return StatistikScreen(
          apiService: _apiService,
          users: _users,
          currentMitgliedernummer: widget.currentMitgliedernummer,
        );
      case 8:
        return const DiensteScreen();
      default:
        return _buildDashboardOverview();
    }
  }

  Widget _buildDashboardOverview() {
    final totalTickets = _myTickets.length;
    final openTickets = _myTickets.where((t) => t.status == 'open').length;
    final inProgressTickets = _myTickets.where((t) => t.status == 'in_progress').length;
    final doneTickets = _myTickets.where((t) => t.status == 'done' || t.status == 'closed').length;

    final l = AppLocalizations.of(context);
    final isMobile = ResponsiveLayout.isMobile(context);
    final padding = isMobile ? 12.0 : 24.0;
    final spacing = isMobile ? 8.0 : 16.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.dashboard, size: isMobile ? 22 : 28, color: const Color(0xFF4a90d9)),
              SizedBox(width: isMobile ? 8 : 12),
              Expanded(
                child: Text(
                  l.financialOverview,
                  style: TextStyle(fontSize: isMobile ? 18 : 24, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: l.refresh,
                onPressed: () {
                  _loadMyTickets();
                  _loadMyTermine();
                },
              ),
            ],
          ),
          SizedBox(height: isMobile ? 12 : 24),

          // Section: Finanzen
          Text(
            l.finances,
            style: TextStyle(fontSize: isMobile ? 15 : 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _buildCardGrid([
            _dashCardData(l.accountBalance, '–', Icons.account_balance_wallet, Colors.green),
            _dashCardData(l.income, '–', Icons.trending_up, Colors.blue),
            _dashCardData(l.expenses, '–', Icons.trending_down, Colors.red),
            _dashCardData(l.openContributions, '–', Icons.warning_amber, Colors.orange),
          ], isMobile, spacing),
          SizedBox(height: isMobile ? 16 : 24),

          // Section: Mitgliedsbeiträge
          Text(
            l.membershipFees,
            style: TextStyle(fontSize: isMobile ? 15 : 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _buildCardGrid([
            _dashCardData(l.paid, '–', Icons.check_circle, Colors.green),
            _dashCardData(l.pending, '–', Icons.schedule, Colors.amber.shade700),
            _dashCardData(l.overdue, '–', Icons.error_outline, Colors.red),
            _dashCardData(l.reminders, '–', Icons.mail_outline, Colors.deepPurple),
          ], isMobile, spacing),
          SizedBox(height: isMobile ? 16 : 24),

          // Section: Meine Tickets
          Text(
            l.myTickets,
            style: TextStyle(fontSize: isMobile ? 15 : 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _buildCardGrid([
            _dashCardData(l.total, '$totalTickets', Icons.confirmation_number, Colors.blue),
            _dashCardData(l.statusOpen, '$openTickets', Icons.inbox, Colors.red),
            _dashCardData(l.inProgress, '$inProgressTickets', Icons.hourglass_top, Colors.orange),
            _dashCardData(l.completed, '$doneTickets', Icons.check_circle, Colors.green),
          ], isMobile, spacing),
        ],
      ),
    );
  }

  /// Responsive grid: 2 columns on mobile, wrap on desktop
  Widget _buildCardGrid(List<_DashCardData> cards, bool isMobile, double spacing) {
    if (isMobile) {
      // 2-column grid on mobile
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: 1.4,
        children: cards.map((c) => _dashCard(c.title, c.value, c.icon, c.color, isMobile: true)).toList(),
      );
    }
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: cards.map((c) => _dashCard(c.title, c.value, c.icon, c.color, isMobile: false)).toList(),
    );
  }

  /// Read-only view of Schatzmeister's own tickets
  Widget _buildMyTicketsReadOnly() {
    final isMobile = ResponsiveLayout.isMobile(context);
    // Split tickets into 3 categories
    final active = _myTickets.where((t) => t.status == 'open' || t.status == 'waiting_member' || t.status == 'waiting_authority' || t.status == 'waiting_staff' || t.status == 'waiting_documents').toList();
    final inProgress = _myTickets.where((t) => t.status == 'in_progress').toList();
    final completed = _myTickets.where((t) => t.status == 'done' || t.status == 'closed').toList();

    // Sort all by scheduled_date
    active.sort((a, b) => (a.scheduledDate ?? a.createdAt).compareTo(b.scheduledDate ?? b.createdAt));
    inProgress.sort((a, b) => (a.scheduledDate ?? a.createdAt).compareTo(b.scheduledDate ?? b.createdAt));
    completed.sort((a, b) => (b.scheduledDate ?? b.createdAt).compareTo(a.scheduledDate ?? a.createdAt));

    // All tickets sorted by scheduled_date
    final all = List<Ticket>.from(_myTickets)
      ..sort((a, b) => (a.scheduledDate ?? a.createdAt).compareTo(b.scheduledDate ?? b.createdAt));

    // Current week tickets (all statuses including done)
    final now = DateTime.now();
    final currentWeekStart = _weekStart(now);
    final currentWeekEnd = currentWeekStart.add(const Duration(days: 7));
    final currentWeek = _myTickets.where((t) {
      final d = t.scheduledDate ?? t.createdAt;
      return !d.isBefore(currentWeekStart) && d.isBefore(currentWeekEnd);
    }).toList()
      ..sort((a, b) => (a.scheduledDate ?? a.createdAt).compareTo(b.scheduledDate ?? b.createdAt));

    final l = AppLocalizations.of(context);
    return DefaultTabController(
      length: 5,
      initialIndex: 0,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(isMobile ? 12 : 24, isMobile ? 12 : 24, isMobile ? 12 : 24, 0),
            child: Row(
              children: [
                Icon(Icons.confirmation_number, size: isMobile ? 22 : 28, color: const Color(0xFF4a90d9)),
                SizedBox(width: isMobile ? 8 : 12),
                Expanded(
                  child: Text(l.myTickets, style: TextStyle(fontSize: isMobile ? 18 : 24, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: l.refresh,
                  onPressed: _loadMyTickets,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TabBar(
            labelColor: const Color(0xFF4a90d9),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF4a90d9),
            isScrollable: true,
            labelStyle: TextStyle(fontSize: isMobile ? 11 : 14),
            tabs: [
              Tab(
                icon: isMobile ? null : const Icon(Icons.today),
                text: l.currentTab(currentWeek.length),
              ),
              Tab(
                icon: isMobile ? null : const Icon(Icons.list),
                text: l.allTab(all.length),
              ),
              Tab(
                icon: isMobile ? null : const Icon(Icons.inbox),
                text: l.activeTab(active.length),
              ),
              Tab(
                icon: isMobile ? null : const Icon(Icons.hourglass_top),
                text: l.inProgressTab(inProgress.length),
              ),
              Tab(
                icon: isMobile ? null : const Icon(Icons.check_circle),
                text: l.completedTab(completed.length),
              ),
            ],
          ),
          Expanded(
            child: _isLoadingMyTickets
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    children: [
                      _buildTicketWeeklyList(currentWeek, AppLocalizations.of(context).noTicketsThisWeek, Icons.today),
                      _buildTicketWeeklyList(all, AppLocalizations.of(context).noTicketsAvailable, Icons.confirmation_number_outlined),
                      _buildTicketWeeklyList(active, AppLocalizations.of(context).noActiveTickets, Icons.inbox_outlined),
                      _buildTicketWeeklyList(inProgress, AppLocalizations.of(context).noTicketsInProgress, Icons.hourglass_empty),
                      _buildTicketWeeklyList(completed, AppLocalizations.of(context).noCompletedTickets, Icons.check_circle_outline),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// Get Monday of the week for a given date
  DateTime _weekStart(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  /// Get week label (e.g. "KW 11 • 10.03 - 16.03.2026" or "Diese Woche")
  String _weekLabel(DateTime weekStart) {
    final now = DateTime.now();
    final currentWeekStart = _weekStart(now);
    final weekEnd = weekStart.add(const Duration(days: 6));
    final kw = _weekNumber(weekStart);

    String label = 'KW $kw • ${DateFormat('dd.MM').format(weekStart)} - ${DateFormat('dd.MM.yyyy').format(weekEnd)}';

    if (weekStart == currentWeekStart) {
      label = '${AppLocalizations.of(context).thisWeek} — $label';
    } else if (weekStart == currentWeekStart.add(const Duration(days: 7))) {
      label = '${AppLocalizations.of(context).nextWeek} — $label';
    } else if (weekStart == currentWeekStart.subtract(const Duration(days: 7))) {
      label = '${AppLocalizations.of(context).lastWeek} — $label';
    }
    return label;
  }

  int _weekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final firstMonday = firstDayOfYear.add(Duration(days: (8 - firstDayOfYear.weekday) % 7));
    if (date.isBefore(firstMonday)) return 1;
    return ((date.difference(firstMonday).inDays) ~/ 7) + 2;
  }

  Widget _buildTicketWeeklyList(List<Ticket> tickets, String emptyText, IconData emptyIcon) {
    if (tickets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(emptyText, style: const TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    // Group tickets by week (based on scheduled_date)
    final grouped = <DateTime, List<Ticket>>{};
    for (final ticket in tickets) {
      final date = ticket.scheduledDate ?? ticket.createdAt;
      final ws = _weekStart(date);
      grouped.putIfAbsent(ws, () => []).add(ticket);
    }

    // Sort weeks
    final sortedWeeks = grouped.keys.toList()..sort();
    final now = DateTime.now();
    final currentWeekStart = _weekStart(now);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedWeeks.length,
      itemBuilder: (context, weekIndex) {
        final weekStart = sortedWeeks[weekIndex];
        final weekTickets = grouped[weekStart]!;
        final isCurrentWeek = weekStart == currentWeekStart;
        final isNextWeek = weekStart == currentWeekStart.add(const Duration(days: 7));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Week header
            Container(
              margin: EdgeInsets.only(bottom: 8, top: weekIndex > 0 ? 16 : 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isCurrentWeek
                    ? const Color(0xFF4a90d9).withAlpha(20)
                    : isNextWeek
                        ? Colors.orange.withAlpha(20)
                        : Colors.grey.withAlpha(15),
                borderRadius: BorderRadius.circular(8),
                border: isCurrentWeek
                    ? Border.all(color: const Color(0xFF4a90d9).withAlpha(80))
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    isCurrentWeek ? Icons.today : Icons.date_range,
                    size: 18,
                    color: isCurrentWeek ? const Color(0xFF4a90d9) : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _weekLabel(weekStart),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isCurrentWeek ? const Color(0xFF4a90d9) : Colors.grey.shade700,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isCurrentWeek ? const Color(0xFF4a90d9) : Colors.grey.shade500,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${weekTickets.length}',
                      style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            // Tickets in this week
            ...weekTickets.map((ticket) {
              final bool isDone = ticket.status == 'done' || ticket.status == 'closed';
              final schedDate = ticket.scheduledDate;

              Color statusColor;
              IconData statusIcon;
              switch (ticket.status) {
                case 'open': statusColor = Colors.red; statusIcon = Icons.inbox; break;
                case 'in_progress': statusColor = Colors.orange; statusIcon = Icons.hourglass_top; break;
                case 'done': case 'closed': statusColor = Colors.green; statusIcon = Icons.check_circle; break;
                case 'waiting_member': statusColor = Colors.blue; statusIcon = Icons.person; break;
                case 'waiting_authority': statusColor = Colors.purple; statusIcon = Icons.account_balance; break;
                default: statusColor = Colors.grey; statusIcon = Icons.help_outline;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: statusColor.withAlpha(30),
                    child: Icon(statusIcon, color: statusColor),
                  ),
                  title: Text(
                    ticket.subject,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      color: isDone ? Colors.grey : null,
                    ),
                  ),
                  subtitle: Text(
                    '${schedDate != null ? DateFormat('EEEE, dd.MM.yyyy • HH:mm', 'de').format(schedDate) : DateFormat('dd.MM.yyyy').format(ticket.createdAt)} • ${_ticketStatusText(ticket.status)}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  trailing: Icon(
                    isDone ? Icons.done_all : Icons.visibility,
                    color: isDone ? Colors.green : Colors.grey,
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  String _ticketStatusText(String status) {
    final l = AppLocalizations.of(context);
    switch (status) {
      case 'open': return l.statusOpen;
      case 'in_progress': return l.inProgress;
      case 'done': return l.completed;
      case 'closed': return l.statusClosed;
      case 'waiting_member': return l.waitingForReply;
      case 'waiting_authority': return l.waitingForAuthority;
      default: return status;
    }
  }

  /// Read-only view of Schatzmeister's own appointments with 3 tabs
  Widget _buildMyTermineReadOnly() {
    final isMobile = ResponsiveLayout.isMobile(context);
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    // Split termine into 3 categories
    final upcoming = <Map<String, dynamic>>[];
    final current = <Map<String, dynamic>>[];
    final completed = <Map<String, dynamic>>[];

    for (final termin in _myTermine) {
      final status = termin['status'] ?? 'scheduled';
      if (status == 'completed') {
        completed.add(termin);
        continue;
      }
      try {
        final dt = DateTime.parse(termin['termin_date'] ?? '');
        if (dt.isAfter(todayEnd)) {
          upcoming.add(termin);
        } else if (dt.isAfter(todayStart.subtract(const Duration(hours: 1)))) {
          current.add(termin);
        } else {
          completed.add(termin);
        }
      } catch (_) {
        upcoming.add(termin);
      }
    }

    final l = AppLocalizations.of(context);
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(isMobile ? 12 : 24, isMobile ? 12 : 24, isMobile ? 12 : 24, 0),
            child: Row(
              children: [
                Icon(Icons.calendar_month, size: isMobile ? 22 : 28, color: const Color(0xFF4a90d9)),
                SizedBox(width: isMobile ? 8 : 12),
                Expanded(
                  child: Text(l.myAppointments, style: TextStyle(fontSize: isMobile ? 18 : 24, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: l.refresh,
                  onPressed: _loadMyTermine,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TabBar(
            labelColor: const Color(0xFF4a90d9),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF4a90d9),
            isScrollable: isMobile,
            labelStyle: TextStyle(fontSize: isMobile ? 11 : 14),
            tabs: [
              Tab(
                icon: isMobile ? null : const Icon(Icons.upcoming),
                text: l.upcomingTab(upcoming.length),
              ),
              Tab(
                icon: isMobile ? null : const Icon(Icons.today),
                text: l.currentAppTab(current.length),
              ),
              Tab(
                icon: isMobile ? null : const Icon(Icons.done_all),
                text: l.completedAppTab(completed.length),
              ),
            ],
          ),
          Expanded(
            child: _isLoadingMyTermine
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    children: [
                      _buildTerminList(upcoming, AppLocalizations.of(context).noUpcomingAppointments, Icons.event_available),
                      _buildTerminList(current, AppLocalizations.of(context).noCurrentAppointments, Icons.today),
                      _buildTerminList(completed, AppLocalizations.of(context).noCompletedAppointments, Icons.event_busy),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerminList(List<Map<String, dynamic>> termine, String emptyText, IconData emptyIcon) {
    if (termine.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(emptyText, style: const TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }
    final isMobileTl = ResponsiveLayout.isMobile(context);
    return ListView.builder(
      padding: EdgeInsets.all(isMobileTl ? 12 : 24),
      itemCount: termine.length,
      itemBuilder: (context, index) {
        final termin = termine[index];
        final title = termin['title'] ?? AppLocalizations.of(context).withoutTitle;
        final terminDate = termin['termin_date'] ?? '';
        final category = termin['category'] ?? '';
        final response = termin['response'] ?? 'pending';
        final location = termin['location'] ?? '';
        final status = termin['status'] ?? 'scheduled';

        Color typeColor;
        switch (category) {
          case 'vorstandssitzung': typeColor = Colors.purple; break;
          case 'mitgliederversammlung': typeColor = Colors.blue; break;
          case 'schulung': typeColor = Colors.green; break;
          default: typeColor = Colors.amber;
        }

        String dateDisplay = '';
        String timeDisplay = '';
        try {
          final dt = DateTime.parse(terminDate);
          dateDisplay = DateFormat('dd.MM.yyyy').format(dt);
          timeDisplay = DateFormat('HH:mm').format(dt);
        } catch (_) {
          dateDisplay = terminDate;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: status == 'completed' ? Colors.green.withAlpha(30) : typeColor.withAlpha(30),
              child: Icon(
                status == 'completed' ? Icons.check_circle : Icons.event,
                color: status == 'completed' ? Colors.green : typeColor,
              ),
            ),
            title: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                decoration: status == 'completed' ? TextDecoration.lineThrough : null,
                color: status == 'completed' ? Colors.grey : null,
              ),
            ),
            subtitle: Text(
              '$dateDisplay${AppLocalizations.of(context).atTime(timeDisplay)}${location.isNotEmpty ? ' • $location' : ''}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            trailing: status == 'completed'
              ? const Icon(Icons.done_all, color: Colors.green)
              : response == 'confirmed'
                ? const Icon(Icons.check_circle, color: Colors.green)
                : response == 'declined'
                  ? const Icon(Icons.cancel, color: Colors.red)
                  : const Icon(Icons.help_outline, color: Colors.orange),
          ),
        );
      },
    );
  }



  _DashCardData _dashCardData(String title, String value, IconData icon, Color color) {
    return _DashCardData(title: title, value: value, icon: icon, color: color);
  }

  Widget _dashCard(String title, String value, IconData icon, Color color, {bool isMobile = false}) {
    final card = Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: isMobile ? 20 : 24),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isMobile ? 22 : 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 4 : 8),
            Text(
              title,
              style: TextStyle(
                fontSize: isMobile ? 11 : 13,
                color: Colors.grey.shade600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );

    if (isMobile) return card;
    return SizedBox(width: 180, child: card);
  }
}

class _DashCardData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _DashCardData({required this.title, required this.value, required this.icon, required this.color});
}

