import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/api_service.dart';
import '../utils/message_emotion.dart';
import '../utils/chat_ablauf.dart';
import '../services/chat_service.dart';
import '../services/voice_call_service.dart';
import '../services/logger_service.dart';
import '../l10n/app_localizations.dart';
import 'incoming_call_dialog.dart';
import 'eastern.dart';

final _log = LoggerService();

/// Live Chat Dialog for members to chat with support
class LiveChatDialog extends StatefulWidget {
  final String mitgliedernummer;
  final String userName;
  final CallOfferEvent? pendingCall;

  const LiveChatDialog({
    super.key,
    required this.mitgliedernummer,
    required this.userName,
    this.pendingCall,
  });

  @override
  State<LiveChatDialog> createState() => _LiveChatDialogState();
}

class _LiveChatDialogState extends State<LiveChatDialog> {
  final _apiService = ApiService();
  final _chatService = ChatService();
  final _voiceCallService = VoiceCallService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  int? _conversationId;
  /// Bildschirmposition der letzten Berührung — das Auswahlband öffnet dort,
  /// wo getippt wurde, nicht in der Bildschirmmitte.
  Offset _reactTapPos = Offset.zero;
  bool _isLoading = true;
  bool _isConnected = false;
  bool _isSending = false;
  String? _typingUser;
  Timer? _typingTimer;

  // Voice call state - most WebRTC state now managed by VoiceCallService
  Timer? _callDurationTimer;
  Duration _callDuration = Duration.zero;
  String _remoteName = 'Support';

  // Incoming call state (when admin calls member)
  String? _pendingSdp;
  String? _pendingSdpType;
  int? _incomingCallConvId;

  // File upload state
  List<File> _selectedFiles = [];
  bool _isUploading = false;

  // Stream subscriptions
  StreamSubscription? _messageSubscription;
  StreamSubscription? _typingSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _errorSubscription;
  StreamSubscription? _callAnswerSubscription;
  StreamSubscription? _callRejectedSubscription;
  StreamSubscription? _callEndedSubscription;
  StreamSubscription? _iceCandidateSubscription;
  StreamSubscription? _callBusySubscription;
  StreamSubscription? _readReceiptSubscription;
  StreamSubscription? _messageExpiredSubscription;
  StreamSubscription? _callOfferSubscription;
  StreamSubscription? _callStateSubscription;
  StreamSubscription? _remoteStreamSubscription;
  StreamSubscription? _iceConnectionStateSubscription;

  // Remote audio stream for playback (Windows fix)
  MediaStream? _remoteAudioStream;
  RTCIceConnectionState? _iceConnectionState;

  // Network status of support (polled every 15s)
  Timer? _networkPollTimer;
  Timer? _countdownTimer;
  String? _supportConnectionType;
  int? _supportLatencyMs;
  String? _supportNetworkQuality;
  bool _supportOnline = false;

  @override
  void initState() {
    super.initState();

    // Configure VoiceCallService signaling via ChatService
    _voiceCallService.onSignalingMessage = (message) {
      final type = message['type'] as String;
      final convId = message['conversation_id'] as int;

      switch (type) {
        case 'call_offer':
          _chatService.sendCallOffer(convId, message['sdp'] as String, message['sdp_type'] as String);
          break;
        case 'call_answer':
          _chatService.sendCallAnswer(convId, message['sdp'] as String, message['sdp_type'] as String);
          break;
        case 'call_reject':
          _chatService.sendCallReject(convId, message['reason'] as String);
          break;
        case 'call_end':
          _chatService.sendCallEnd(convId);
          break;
        case 'ice_candidate':
          _chatService.sendIceCandidate(
            convId,
            message['candidate'] as String,
            message['sdp_mid'] as String,
            message['sdp_mline_index'] as int,
          );
          break;
      }
    };

    // Listen to VoiceCallService state changes to update UI
    _callStateSubscription = _voiceCallService.callStateStream.listen((state) {
      _log.info('LiveChat: VoiceCallService state changed to: $state', tag: 'CALL');
      if (mounted) {
        setState(() {}); // Trigger UI rebuild
      }
    });

    // Listen to remote audio stream for playback (Windows fix)
    _remoteStreamSubscription = _voiceCallService.remoteStreamStream.listen((stream) {
      _log.info('LiveChat: Remote stream updated: ${stream != null ? "RECEIVED" : "NULL"}', tag: 'CALL');
      if (mounted) {
        setState(() {
          _remoteAudioStream = stream;
        });
      }
    });

    // Listen to ICE connection state for network quality indicator
    _iceConnectionStateSubscription = _voiceCallService.iceConnectionStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _iceConnectionState = state;
        });
      }
    });

    // Handle pending call if passed from dashboard
    if (widget.pendingCall != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handlePendingCall(widget.pendingCall!);
      });
    }
  }

  bool _chatInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_chatInitialized) {
      _chatInitialized = true;
      _initChat();
    }
  }

  void _handlePendingCall(CallOfferEvent event) async {
    _log.info('LiveChat: _handlePendingCall() from ${event.callerName} (conv: ${event.conversationId})', tag: 'CALL');
    // Wait a bit for WebSocket to connect
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) {
      _log.warning('LiveChat: _handlePendingCall() - not mounted, aborting', tag: 'CALL');
      return;
    }

    _incomingCallConvId = event.conversationId;
    _pendingSdp = event.sdp;
    _pendingSdpType = event.sdpType;
    _remoteName = event.callerName;
    _log.debug('LiveChat: Pending call data set - SDP type: ${event.sdpType}', tag: 'CALL');

    // CRITICAL FIX: Inform VoiceCallService about incoming call BEFORE accepting
    // This sets the call state to ringing, which is required for acceptCall() to work
    _log.info('LiveChat: Informing VoiceCallService about incoming call...', tag: 'CALL');
    _voiceCallService.handleIncomingCall(
      event.conversationId,
      event.callerId,
      event.callerName,
      event.sdp,
      event.sdpType,
    );

    // Wait a tiny bit for state to update
    await Future.delayed(const Duration(milliseconds: 100));

    // Auto-accept the call (user already accepted in the dialog)
    if (mounted) {
      _log.info('LiveChat: Auto-accepting pending call', tag: 'CALL');
      _acceptCall();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    _callDurationTimer?.cancel();
    _networkPollTimer?.cancel();
    _countdownTimer?.cancel();
    _messageSubscription?.cancel();
    _typingSubscription?.cancel();
    _connectionSubscription?.cancel();
    _errorSubscription?.cancel();
    _callAnswerSubscription?.cancel();
    _callRejectedSubscription?.cancel();
    _callEndedSubscription?.cancel();
    _iceCandidateSubscription?.cancel();
    _callBusySubscription?.cancel();
    _readReceiptSubscription?.cancel();
    _messageExpiredSubscription?.cancel();
    _callOfferSubscription?.cancel();
    _callStateSubscription?.cancel();
    _remoteStreamSubscription?.cancel();
    _iceConnectionStateSubscription?.cancel();
    _endCallCleanup();
    // Don't leave conversation - dashboard maintains the subscription for background notifications
    super.dispose();
  }

  Future<void> _initChat() async {
    _log.info('LiveChat: _initChat() starting for ${widget.mitgliedernummer}', tag: 'CHAT');
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    try {
      // Start or get existing conversation via REST API
      _log.debug('LiveChat: Calling startChat API...', tag: 'CHAT');
      final result = await _apiService.startChat(widget.mitgliedernummer);
      if (!mounted) return;

      if (result['success'] == true) {
        // Parse conversation_id as int (API may return string)
        final convId = result['conversation_id'];
        _conversationId = convId is int ? convId : int.tryParse(convId.toString());
        _log.info('LiveChat: Got conversation_id=$_conversationId', tag: 'CHAT');

        // Load existing messages
        await _loadMessages();
        if (!mounted) return;

        // Connect to WebSocket for real-time updates
        await _connectWebSocket();
      } else {
        _log.error('LiveChat: startChat failed: ${result['message']}', tag: 'CHAT');
        if (!mounted) return;
        _showError(result['message'] ?? l.chatStartError);
      }
    } catch (e) {
      _log.error('LiveChat: _initChat exception: $e', tag: 'CHAT');
      if (!mounted) return;
      _showError(l.connectionErrorWith('$e'));
      // Start polling support network status every 15s
      _pollSupportNetworkInfo();
      _networkPollTimer = Timer.periodic(
        const Duration(seconds: 15),
        (_) => _pollSupportNetworkInfo(),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Poll support (Vorsitzer) network info via support_status API
  Future<void> _pollSupportNetworkInfo() async {
    try {
      final result = await _apiService.getSupportStatus();
      if (result['success'] == true && mounted) {
        final onlineAdmins = result['online_admins'] as List<dynamic>?;
        if (onlineAdmins != null && onlineAdmins.isNotEmpty) {
          // Use the first online admin (usually Vorsitzer)
          final admin = onlineAdmins[0] as Map<String, dynamic>;
          setState(() {
            _supportOnline = true;
            _supportConnectionType = admin['connection_type']?.toString();
            _supportLatencyMs = admin['latency_ms'] is int ? admin['latency_ms'] : int.tryParse('${admin['latency_ms'] ?? ''}');
            _supportNetworkQuality = admin['network_quality']?.toString();
          });
        } else {
          // Check most recent admin
          final recent = result['most_recent_admin'] as Map<String, dynamic>?;
          setState(() {
            _supportOnline = false;
            _supportConnectionType = recent?['connection_type']?.toString();
            _supportLatencyMs = recent?['latency_ms'] is int ? recent!['latency_ms'] : null;
            _supportNetworkQuality = recent?['network_quality']?.toString();
          });
        }
      }
    } catch (e) {
      _log.debug('LiveChat: Network poll error: $e', tag: 'CHAT');
    }
  }

  Future<void> _loadMessages() async {
    if (_conversationId == null) return;
    _log.debug('LiveChat: _loadMessages() for conversation $_conversationId', tag: 'CHAT');

    try {
      final result = await _apiService.getChatMessages(
        _conversationId!,
        widget.mitgliedernummer,
      );

      if (result['success'] == true && mounted) {
        // API returns messages in data.messages (with translation support)
        final data = result['data'] as Map<String, dynamic>? ?? result;
        final messagesList = List<Map<String, dynamic>>.from(data['messages'] ?? result['messages'] ?? []);
        _log.info('LiveChat: Loaded ${messagesList.length} messages', tag: 'CHAT');
        setState(() {
          _messages = messagesList;
        });
        _scrollToBottom();
        _ensureCountdownTimer();
      } else {
        _log.warning('LiveChat: _loadMessages failed: ${result['message']}', tag: 'CHAT');
      }
    } catch (e) {
      _log.error('LiveChat: _loadMessages exception: $e', tag: 'CHAT');
    }
  }

  Future<void> _connectWebSocket() async {
    _log.info('LiveChat: _connectWebSocket() starting...', tag: 'CHAT');
    // Set up chat listeners
    _messageSubscription = _chatService.messageStream.listen((message) {
      if (message.conversationId == _conversationId && mounted) {
        // Skip messages from ourselves (already added locally when sent)
        if (message.senderName == widget.userName) {
          _log.debug('LiveChat: Skipping own message from WebSocket', tag: 'CHAT');
          return;
        }
        setState(() {
          _messages.add({
            'id': message.id,
            'message': message.message,
            'sender_id': message.senderId,
            'sender_name': message.senderName,
            'sender_role': message.senderRole,
            'is_own': false,
            'created_at': message.createdAt.toIso8601String(),
          });
        });
        _scrollToBottom();
      }
    });

    _typingSubscription = _chatService.typingStream.listen((event) {
      if (mounted) {
        setState(() => _typingUser = event.userName);
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _typingUser = null);
        });
      }
    });

    _connectionSubscription = _chatService.connectionStream.listen((connected) {
      if (mounted) {
        setState(() => _isConnected = connected);
      }
    });

    _errorSubscription = _chatService.errorStream.listen((error) {
      debugPrint('Chat error: $error');
    });

    // Set up voice call listeners
    _callAnswerSubscription = _chatService.callAnswerStream.listen((event) {
      _log.info('LiveChat: [WS] Received call_answer from ${event.answererName} (conv: ${event.conversationId})', tag: 'CALL');
      if (!mounted) return;
      if (event.conversationId == _conversationId) {
        _handleCallAnswer(event.sdp, event.sdpType, event.answererName);
      } else {
        _log.warning('LiveChat: call_answer ignored - conversationId mismatch (expected: $_conversationId)', tag: 'CALL');
      }
    });

    _callRejectedSubscription = _chatService.callRejectedStream.listen((event) {
      _log.info('LiveChat: [WS] Received call_rejected (conv: ${event.conversationId}, reason: ${event.reason})', tag: 'CALL');
      if (!mounted) return;
      if (event.conversationId == _conversationId) {
        _handleCallRejected(event.reason);
      }
    });

    _callEndedSubscription = _chatService.callEndedStream.listen((event) {
      _log.info('LiveChat: [WS] Received call_ended (conv: ${event.conversationId})', tag: 'CALL');
      if (!mounted) return;
      if (event.conversationId == _conversationId) {
        _handleCallEnded();
      }
    });

    _iceCandidateSubscription = _chatService.iceCandidateStream.listen((event) {
      _log.debug('LiveChat: [WS] Received ice_candidate (conv: ${event.conversationId})', tag: 'CALL');
      if (!mounted) return;
      if (event.conversationId == _conversationId) {
        _handleIceCandidate(event.candidate, event.sdpMid, event.sdpMLineIndex);
      }
    });

    _callBusySubscription = _chatService.callBusyStream.listen((convId) {
      _log.info('LiveChat: [WS] Received call_busy (conv: $convId)', tag: 'CALL');
      if (!mounted) return;
      if (convId == _conversationId) {
        final l = AppLocalizations.of(context);
        _showError(l.supportInCall);
        _endCallCleanup();
      }
    });

    // Incoming call listener (when admin calls while member has chat open)
    _callOfferSubscription = _chatService.callOfferStream.listen((event) {
      _log.info('LiveChat: [WS] Received call_offer from ${event.callerName} (conv: ${event.conversationId})', tag: 'CALL');
      if (!mounted) return;
      if (event.conversationId == _conversationId) {
        _handleIncomingCall(event);
      }
    });

    // Read receipt listener
    _readReceiptSubscription = _chatService.readReceiptStream.listen((event) {
      if (!mounted) return;
      if (event.conversationId == _conversationId) {
        setState(() {
          for (var msg in _messages) {
            if (event.messageIds.contains(msg['id'])) {
              msg['status'] = event.status;
              if (event.status == 'read') {
                msg['is_read'] = true;
                // Der Server schickt die Frist im selben Rahmen mit. Ohne sie
                // liefe der Balken auf der Gegenseite gegen eine andere Uhr.
                final expIso = event.expires[msg['id'].toString()];
                if (expIso != null) msg['expires_at'] = expIso;
              }
            }
          }
        });
        _ensureCountdownTimer();
      }
    });

    // Der Server hat den Inhalt nach der 5-Minuten-Frist geleert: lokal
    // nachziehen, damit die Blase sofort verschwindet und nicht erst beim
    // naechsten Oeffnen des Fensters.
    _messageExpiredSubscription = _chatService.messageExpiredStream.listen((event) {
      if (!mounted) return;
      if (event.conversationId == _conversationId) {
        setState(() {
          for (var msg in _messages) {
            if (event.messageIds.contains(msg['id'])) {
              msg['message'] = null;
              msg['original_message'] = null;
              msg['attachments'] = [];
              msg['deleted_at'] = DateTime.now().toIso8601String();
            }
          }
        });
      }
    });

    // Connect and authenticate
    _log.info('LiveChat: Calling chatService.connect(${widget.mitgliedernummer})', tag: 'CHAT');
    final connected = await _chatService.connect(widget.mitgliedernummer, userName: widget.userName);
    _log.info('LiveChat: connect() returned: $connected', tag: 'CHAT');

    if (connected && _conversationId != null) {
      _log.info('LiveChat: Joining conversation $_conversationId', tag: 'CHAT');
      _chatService.joinConversation(_conversationId!);
      if (mounted) {
        setState(() => _isConnected = true);
        _log.info('LiveChat: Connected and joined successfully!', tag: 'CHAT');
      }
    } else {
      _log.warning('LiveChat: Failed to connect or conversationId is null (connected=$connected, convId=$_conversationId)', tag: 'CHAT');
    }
  }

  // ==================== Voice Call Methods ====================

  /// Start call to support - REFACTORED to use VoiceCallService
  /// Startet einen Anruf zum Support. Mit `video: true` wird zusätzlich die
  /// Kamera geöffnet — die Gegenseite erkennt das am SDP-Angebot und schaltet
  /// ihre eigene Kamera nur dann ein.
  Future<void> _startCall({bool video = false}) async {
    _log.info('LiveChat: _startCall(video: $video) initiated by member', tag: 'CALL');
    if (_conversationId == null || _voiceCallService.callState != CallState.idle) {
      _log.warning('LiveChat: _startCall() aborted - convId: $_conversationId, status: ${_voiceCallService.callState}', tag: 'CALL');
      return;
    }
    if (!mounted) return;
    final l = AppLocalizations.of(context);

    try {
      // Use VoiceCallService to start the call
      // For member calling support, we use "support" as targetUserId
      final success = await _voiceCallService.startCall(
          _conversationId!, 'support', 'Support', video: video);

      if (!success) {
        throw Exception('Failed to start call via VoiceCallService');
      }

      _log.info('LiveChat: Call to support started successfully via VoiceCallService', tag: 'CALL');

      if (mounted) {
        _startCallDurationTimer();
      }

    } catch (e) {
      _log.error('LiveChat: _startCall() error: $e', tag: 'CALL');
      if (e.toString().contains('NO_MICROPHONE')) {
        _showError(l.noMicrophoneFound);
      } else {
        _showError(l.errorStartingCall('$e'));
      }
      await _voiceCallService.endCall();
    }
  }

  /// Handle answer from support - REFACTORED to use VoiceCallService
  Future<void> _handleCallAnswer(String sdp, String sdpType, String answererName) async {
    _log.info('LiveChat: _handleCallAnswer() from $answererName, sdpType: $sdpType (using VoiceCallService)', tag: 'CALL');
    final l = AppLocalizations.of(context);

    try {
      _remoteName = answererName;
      await _voiceCallService.handleCallAnswer(sdp, sdpType);
      _log.info('LiveChat: Call answer handled successfully via VoiceCallService', tag: 'CALL');
      if (mounted) {
        _startCallDurationTimer();
      }
    } catch (e) {
      _log.error('LiveChat: _handleCallAnswer() error: $e', tag: 'CALL');
      _showError(l.errorConnecting('$e'));
      _endCallCleanup();
    }
  }

  /// Handle call rejection - REFACTORED to use VoiceCallService
  void _handleCallRejected(String reason) {
    _log.info('LiveChat: _handleCallRejected() reason: $reason (using VoiceCallService)', tag: 'CALL');
    final l = AppLocalizations.of(context);
    String message;
    switch (reason) {
      case 'busy':
        message = l.supportBusy;
        break;
      case 'rejected':
        message = l.callRejected;
        break;
      default:
        message = l.callCouldNotConnect;
    }
    _showError(message);
    _voiceCallService.handleCallRejected(reason);
    _endCallCleanup();
  }

  /// Handle call ended by remote peer - REFACTORED to use VoiceCallService
  void _handleCallEnded() {
    _log.info('LiveChat: _handleCallEnded() received (using VoiceCallService)', tag: 'CALL');
    final wasInCall = _voiceCallService.callState != CallState.idle;
    _voiceCallService.handleCallEnded();
    _endCallCleanup();
    if (wasInCall && mounted) {
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.callEnded),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  /// Handle ICE candidate - REFACTORED to use VoiceCallService
  Future<void> _handleIceCandidate(String candidate, String sdpMid, int sdpMLineIndex) async {
    if (!mounted) return;
    _log.debug('LiveChat: Handling ICE candidate via VoiceCallService', tag: 'CALL');
    await _voiceCallService.handleIceCandidate(candidate, sdpMid, sdpMLineIndex);
  }

  /// End call - REFACTORED to use VoiceCallService
  void _endCall() {
    _log.info('LiveChat: _endCall() (using VoiceCallService)', tag: 'CALL');
    _voiceCallService.endCall();
    _endCallCleanup();
  }

  /// Cleanup local UI state - WebRTC cleanup now handled by VoiceCallService
  void _endCallCleanup() {
    _log.info('LiveChat: _endCallCleanup() - cleaning up UI state', tag: 'CALL');
    _callDurationTimer?.cancel();
    _pendingSdp = null;
    _pendingSdpType = null;
    _callDuration = Duration.zero;
    _log.debug('LiveChat: Call cleanup completed', tag: 'CALL');
  }

  /// Handle incoming call while chat dialog is open - Uses VoiceCallService
  void _handleIncomingCall(CallOfferEvent event) {
    _log.info('LiveChat: _handleIncomingCall() from ${event.callerName}', tag: 'CALL');
    if (!mounted) return;

    if (_voiceCallService.callState != CallState.idle) {
      // Check if this is a duplicate offer for the SAME conversation
      if (_incomingCallConvId == event.conversationId) {
        _log.warning('LiveChat: Duplicate call_offer for same conversation (${event.conversationId}) - ignoring (state: ${_voiceCallService.callState})', tag: 'CALL');
        return; // Ignore duplicate, DON'T send reject
      }

      // Different call, we're busy
      _log.warning('LiveChat: Already in call (${_voiceCallService.callState}), auto-rejecting with busy', tag: 'CALL');
      _chatService.sendCallReject(event.conversationId, 'busy');
      return;
    }

    _incomingCallConvId = event.conversationId;
    _pendingSdp = event.sdp;
    _pendingSdpType = event.sdpType;
    _remoteName = event.callerName;

    // Also inform VoiceCallService about the incoming call
    _voiceCallService.handleIncomingCall(
      event.conversationId,
      event.callerId,
      event.callerName,
      event.sdp,
      event.sdpType,
    );

    // Show incoming call dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => IncomingCallDialog(
        callerName: event.callerName,
        onAccept: () {
          _log.info('LiveChat: User pressed ACCEPT in dialog', tag: 'CALL');
          Navigator.of(ctx).pop();
          if (mounted) _acceptCall();
        },
        onReject: () {
          _log.info('LiveChat: User pressed REJECT in dialog', tag: 'CALL');
          Navigator.of(ctx).pop();
          if (mounted) {
            _voiceCallService.rejectCall();
            _pendingSdp = null;
            _pendingSdpType = null;
          }
        },
      ),
    );
  }

  /// Accept an incoming call from admin - REFACTORED to use VoiceCallService
  Future<void> _acceptCall() async {
    _log.info('LiveChat: _acceptCall() - convId: $_incomingCallConvId, hasSdp: ${_pendingSdp != null} (using VoiceCallService)', tag: 'CALL');
    if (_pendingSdp == null || _incomingCallConvId == null || !mounted) {
      _log.warning('LiveChat: _acceptCall() aborted - missing data or not mounted', tag: 'CALL');
      return;
    }
    final l = AppLocalizations.of(context);

    try {
      // Use VoiceCallService to accept the call
      final success = await _voiceCallService.acceptCall(_pendingSdp!, _pendingSdpType!);

      if (!success) {
        throw Exception('Failed to accept call via VoiceCallService');
      }

      _log.info('LiveChat: Call accepted successfully via VoiceCallService', tag: 'CALL');

      if (mounted) {
        _startCallDurationTimer();
      }

    } catch (e) {
      _log.error('LiveChat: _acceptCall() error: $e', tag: 'CALL');
      if (e.toString().contains('NO_MICROPHONE')) {
        _showError(l.noMicrophoneFound);
      } else {
        _showError(l.errorAccepting('$e'));
      }
      await _voiceCallService.endCall();
    }
  }

  /// Toggle mute - REFACTORED to use VoiceCallService
  void _toggleMute() {
    if (!mounted) return;
    _voiceCallService.toggleMute();
    if (mounted) {
      setState(() {}); // Trigger UI update
    }
  }

  void _toggleSpeaker() {
    if (!mounted) return;
    _voiceCallService.toggleSpeaker();
    if (mounted) {
      setState(() {}); // Trigger UI update
    }
  }

  void _startCallDurationTimer() {
    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _callDuration += const Duration(seconds: 1));
      }
    });
  }

  // ==================== Chat Methods ====================

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _conversationId == null || _isSending) return;
    final l = AppLocalizations.of(context);
    _log.info('LiveChat: _sendMessage() - sending to conversation $_conversationId', tag: 'CHAT');

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      final result = await _apiService.sendChatMessage(
        _conversationId!,
        widget.mitgliedernummer,
        message,
      );
      _log.debug('LiveChat: sendChatMessage API result: ${result['success']}', tag: 'CHAT');

      if (result['success'] == true && mounted) {
        setState(() {
          _messages.add({
            'id': result['message_id'],
            'message': message,
            'sender_name': widget.userName,
            'sender_role': 'schatzmeister',
            'is_own': true,
            'created_at': result['created_at'] ?? DateTime.now().toIso8601String(),
          });
        });
        _scrollToBottom();
        // WebSocket broadcast is handled server-side by send.php (WebSocketNotifier)
        // No need to send again via _chatService.sendMessage (causes duplicate)
      } else {
        _log.error('LiveChat: sendChatMessage failed: ${result['message']}', tag: 'CHAT');
        _showError(result['message'] ?? l.errorSending);
        _messageController.text = message;
      }
    } catch (e) {
      _log.error('LiveChat: _sendMessage exception: $e', tag: 'CHAT');
      _showError(l.errorSendingWith('$e'));
      _messageController.text = message;
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _onTyping() {
    if (_isConnected && _conversationId != null) {
      _chatService.sendTyping(_conversationId!);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ==================== File Upload Methods ====================

  Future<void> _pickFiles() async {
    final l = AppLocalizations.of(context);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'txt'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final files = result.files
            .where((f) => f.path != null)
            .take(10)
            .map((f) => File(f.path!))
            .toList();

        // Check total size (max 100MB)
        int totalSize = 0;
        for (var file in files) {
          totalSize += await file.length();
        }

        if (totalSize > 100 * 1024 * 1024) {
          _showError(l.maxTotalSize);
          return;
        }

        setState(() => _selectedFiles = files);
        await _uploadFiles();
      }
    } catch (e) {
      _log.error('LiveChat: File picker error: $e', tag: 'CHAT');
      _showError(l.errorSelectingFiles);
    }
  }

  Future<void> _takePhoto() async {
    final l = AppLocalizations.of(context);
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (photo != null) {
        final file = File(photo.path);
        final size = await file.length();

        if (size > 100 * 1024 * 1024) {
          _showError(l.maxFileSize);
          return;
        }

        setState(() => _selectedFiles = [file]);
        await _uploadFiles();
      }
    } catch (e) {
      _log.error('LiveChat: Camera error: $e', tag: 'CHAT');
      _showError(l.errorTakingPhoto);
    }
  }

  Future<void> _uploadFiles() async {
    if (_selectedFiles.isEmpty || _conversationId == null || _isUploading) return;
    final l = AppLocalizations.of(context);

    setState(() => _isUploading = true);

    try {
      final result = await _apiService.uploadChatAttachments(
        conversationId: _conversationId!,
        mitgliedernummer: widget.mitgliedernummer,
        files: _selectedFiles,
        message: _messageController.text.trim().isNotEmpty ? _messageController.text.trim() : null,
      );

      if (result['success'] == true && mounted) {
        _messageController.clear();
        setState(() => _selectedFiles = []);

        // Add message to local list (server returns data at root level via array_merge)
        setState(() {
          _messages.add({
            'id': result['message_id'],
            'message': result['message'] ?? '',
            'sender_name': widget.userName,
            'sender_role': 'schatzmeister',
            'is_own': true,
            'status': 'sent',
            'created_at': result['created_at'] ?? DateTime.now().toIso8601String(),
            'attachments': result['attachments'] ?? [],
          });
        });
        _scrollToBottom();

        // Broadcast via WebSocket
        if (_isConnected) {
          _chatService.sendMessage(_conversationId!, result['message'] ?? '[${l.files}]');
        }
      } else {
        _showError(result['message'] ?? l.errorUploading);
      }
    } catch (e) {
      _log.error('LiveChat: Upload error: $e', tag: 'CHAT');
      _showError(l.errorUploadingWith('$e'));
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _downloadAttachment(Map<String, dynamic> attachment) async {
    final l = AppLocalizations.of(context);
    try {
      final result = await _apiService.downloadChatAttachment(
        attachmentId: attachment['id'],
        mitgliedernummer: widget.mitgliedernummer,
      );

      if (result['success'] == true && mounted) {
        final base64Data = result['content'];
        final filename = result['filename'];

        // Decode and save file
        final bytes = base64Decode(base64Data);
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$filename');
        await file.writeAsBytes(bytes);

        // Open file
        await OpenFilex.open(file.path);
      } else {
        _showError(result['message'] ?? l.errorDownloading);
      }
    } catch (e) {
      _log.error('LiveChat: Download error: $e', tag: 'CHAT');
      _showError(l.errorDownloadingWith('$e'));
    }
  }

  /// Mark all unread messages as read when user focuses on input
  /// Einmal je Sekunde neu zeichnen, solange eine Blase noch laeuft.
  /// Haelt von selbst an, sobald keine Frist mehr offen ist — ein
  /// Dauertimer im Chatfenster waere auf dem Telefon reine Akkulast.
  void _ensureCountdownTimer() {
    if (_countdownTimer != null && _countdownTimer!.isActive) return;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final now = DateTime.now();
      final anyPending = _messages.any((m) {
        if (m['deleted_at'] != null) return false;
        final exp = m['expires_at'];
        if (exp == null) return false;
        final dt = DateTime.tryParse(exp.toString());
        return dt != null && dt.isAfter(now);
      });
      if (!anyPending) {
        t.cancel();
        _countdownTimer = null;
        return;
      }
      setState(() {});
    });
  }

  Future<void> _markMessagesAsRead() async {
    if (_conversationId == null) return;

    // Find unread messages from others
    final unreadIds = _messages
        .where((m) => m['is_own'] != true && m['status'] != 'read' && m['deleted_at'] == null)
        .map((m) => m['id'] as int)
        .toList();

    if (unreadIds.isEmpty) return;

    try {
      final result = await _apiService.markMessagesRead(
        conversationId: _conversationId!,
        mitgliedernummer: widget.mitgliedernummer,
        status: 'read',
        messageIds: unreadIds,
      );

      if (result['success'] == true && mounted) {
        // Update local state
        final returned = (result['messages'] ?? result['data']?['messages']) as List?;
        setState(() {
          for (var msg in _messages) {
            if (unreadIds.contains(msg['id'])) {
              msg['status'] = 'read';
              msg['is_read'] = true;
              msg['read_at'] ??= DateTime.now().toIso8601String();
              // Die Frist kommt vom Server zurueck — nicht selbst rechnen,
              // sonst laeuft der Balken gegen eine andere Uhr als die Loeschung.
              if (returned != null) {
                final hit = returned.firstWhere(
                  (m) => m is Map && m['id'] == msg['id'],
                  orElse: () => null,
                );
                if (hit is Map && hit['expires_at'] != null) {
                  msg['expires_at'] = hit['expires_at'];
                }
              }
            }
          }
        });
        _ensureCountdownTimer();

        // Broadcast via WebSocket
        if (_isConnected) {
          _chatService.sendReadReceipt(_conversationId!, unreadIds, 'read');
        }
      }
    } catch (e) {
      _log.error('LiveChat: Mark read error: $e', tag: 'CHAT');
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    // For critical errors (NO_MICROPHONE), show persistent SnackBar
    final isCritical = message.contains('Mikrofon') || message.contains('Microphone');
    final duration = isCritical ? const Duration(seconds: 15) : const Duration(seconds: 4);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isCritical ? Icons.mic_off : Icons.error_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        action: isCritical
            ? SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        height: 550,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            _buildHeader(),
            // Support network status bar
            if (_supportConnectionType != null) _buildNetworkStatusBar(),
            const Divider(),

            // Messages area
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildMessagesList(),
            ),

            // Typing indicator
            if (_typingUser != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Text(
                      l.typingIndicator(_typingUser!),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),

            // Call overlay - moved to bottom (above input area)
            if (_voiceCallService.callState != CallState.idle) _buildCallOverlay(),

            // Input area
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkStatusBar() {
    final type = _supportConnectionType ?? 'unknown';
    final latency = _supportLatencyMs;
    final quality = _supportNetworkQuality ?? 'offline';

    // Connection type icon + label
    String typeIcon;
    String typeLabel;
    switch (type) {
      case 'wifi':
        typeIcon = '\u{1F4F6}'; // 📶
        typeLabel = 'WiFi';
        break;
      case 'mobile':
        typeIcon = '\u{1F4F6}';
        typeLabel = 'Mobile';
        break;
      case 'ethernet':
        typeIcon = '\u{1F4F6}';
        typeLabel = 'Ethernet';
        break;
      case 'none':
        typeIcon = '\u{1F4F5}'; // 📵
        typeLabel = 'Offline';
        break;
      default:
        typeIcon = '\u{1F4F6}';
        typeLabel = type;
    }

    // Quality icon
    String qualityIcon;
    Color qualityColor;
    switch (quality) {
      case 'good':
        qualityIcon = '\u2705'; // ✅
        qualityColor = Colors.green;
        break;
      case 'medium':
        qualityIcon = '\u26A0\uFE0F'; // ⚠️
        qualityColor = Colors.orange;
        break;
      case 'poor':
        qualityIcon = '\u274C'; // ❌
        qualityColor = Colors.red;
        break;
      default:
        qualityIcon = '\u274C';
        qualityColor = Colors.grey;
    }

    if (!_supportOnline) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('\u{1F4F5}', style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 6),
            Text('Support Offline', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            const SizedBox(width: 6),
            Text('\u274C', style: const TextStyle(fontSize: 12)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: qualityColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(typeIcon, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 6),
          Text(typeLabel, style: TextStyle(fontSize: 11, color: qualityColor, fontWeight: FontWeight.w500)),
          if (latency != null && latency >= 0) ...[
            const SizedBox(width: 8),
            Text('|', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
            const SizedBox(width: 8),
            Text('${latency}ms', style: TextStyle(fontSize: 11, color: qualityColor, fontWeight: FontWeight.w500)),
          ],
          const SizedBox(width: 8),
          Text('|', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
          const SizedBox(width: 8),
          Text(qualityIcon, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final l = AppLocalizations.of(context);
    return Row(
      children: [
        const Icon(Icons.chat, color: Color(0xFF4a90d9), size: 28),
        const SizedBox(width: 12),
        const Text(
          'Live Chat',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const Spacer(),

        // Voice call button
        if (_voiceCallService.callState == CallState.idle)
          IconButton(
            icon: const Icon(Icons.call, color: Colors.green),
            onPressed: _isConnected ? () => _startCall() : null,
            tooltip: l.callSupport,
          ),

        // Videoanruf — derselbe Weg, nur mit Kamera.
        if (_voiceCallService.callState == CallState.idle)
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.green),
            onPressed: _isConnected ? () => _startCall(video: true) : null,
            tooltip: 'Videoanruf',
          ),

        // Connection status
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _isConnected ? Colors.green.shade100 : Colors.orange.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _isConnected ? Colors.green : Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _isConnected ? l.connected : l.offline,
                style: TextStyle(
                  color: _isConnected ? Colors.green.shade700 : Colors.orange.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (_voiceCallService.callState != CallState.idle) {
              _endCall();
            }
            Navigator.pop(context);
          },
          tooltip: l.close,
        ),
      ],
    );
  }

  Widget _buildCallOverlay() {
    if (_voiceCallService.callState == CallState.calling) {
      return CallingOverlay(
        targetName: 'Support',
        onCancel: _endCall,
      );
    } else if (_voiceCallService.callState == CallState.inCall) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: InCallOverlay(
          remoteName: _remoteName,
          callDuration: _callDuration,
          isMuted: _voiceCallService.isMuted,
          isSpeakerOn: _voiceCallService.isSpeakerOn,
          onToggleMute: _toggleMute,
          onToggleSpeaker: _toggleSpeaker,
          onEndCall: _endCall,
          remoteStream: _remoteAudioStream,
          iceConnectionState: _iceConnectionState,
          isVideoCall: _voiceCallService.isVideoCall,
          localStream: _voiceCallService.localStream,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildMessagesList() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).startConversation,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).staffWillReply,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: Colors.grey.shade100,
        child: SeasonalBackground(
          paintBehind: true,
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(12),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              final isOwn = msg['is_own'] == true;
              return _buildMessageBubble(msg, isOwn);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isOwn) {
    final senderRole = msg['sender_role'] ?? 'vorsitzer';
    final isAdmin = ['vorsitzer', 'schatzmeister', 'kassierer'].contains(senderRole);
    final attachments = msg['attachments'] as List? ?? [];
    final raw = msg['message'];
    final messageText = (raw is String) ? raw : '';

    // Beide Entscheidungen stehen in utils/chat_ablauf.dart — dort sind sie
    // ohne WebSocket pruefbar. Siehe test/chat_ablauf_test.dart.
    final isGhost = istAbgelaufen(msg);
    final expireProgress = ablaufFortschritt(msg);

    // Wie in `vorsitzer`: die Blase verschwindet ganz. Bis zum 26.08.2026
    // blieb hier eine leere weisse Blase mit Absender und Uhrzeit stehen —
    // geloescht war die Nachricht da laengst, nur sah es nach einem Fehler aus.
    if (isGhost) return const SizedBox.shrink();

    // Eigentumsregel wie im Server erzwungen: reagiert wird auf Nachrichten
    // der Gegenseite. Eine dort gesetzte Reaktion erscheint auch auf eigenen
    // Blasen — nur nicht änderbar.
    final reaction = emotionFromKey(msg['reaction']);
    final reaktionDa = hatReaktion(msg['reaction']);
    final canReact = !isOwn && _conversationId != null;

    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
      Container(
        // Liegt eine Reaktion an, hält die Blase unten `kReaktionUeberhang`
        // frei: die Plakette hängt *im* Stack, weil Flutter außerhalb der
        // Elterngrenzen keine Treffer mehr auswertet.
        margin: EdgeInsets.only(
          bottom: reaktionDa ? 8 + kReaktionUeberhang : 8,
          left: isOwn ? 50 : 0,
          right: isOwn ? 0 : (reaktionDa ? 50 : 50 + kAusloeserRand),
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isOwn ? const Color(0xFF4a90d9) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isOwn)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      msg['sender_name'] ?? 'Support',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isAdmin ? Colors.purple.shade700 : const Color(0xFF4a90d9),
                      ),
                    ),
                    if (isAdmin) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Support',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.purple.shade700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            if (messageText.isNotEmpty)
              Text(
                messageText,
                style: TextStyle(
                  color: isOwn ? Colors.white : Colors.black87,
                ),
              ),
            // Attachments
            if (attachments.isNotEmpty) ...[
              if (messageText.isNotEmpty) const SizedBox(height: 8),
              ...attachments.map((att) => _buildAttachmentItem(att, isOwn)),
            ],
            // Schmaler Balken, der bis zum Loeschzeitpunkt volllaeuft.
            if (expireProgress != null) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: expireProgress,
                  minHeight: 3,
                  backgroundColor: (isOwn ? Colors.white : Colors.grey.shade300).withValues(alpha: 0.35),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isOwn ? Colors.white70 : Colors.lightBlue.shade300,
                  ),
                ),
              ),
            ],
            // Time and read receipt
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(msg['created_at']),
                    style: TextStyle(
                      fontSize: 10,
                      color: isOwn ? Colors.white70 : Colors.grey.shade500,
                    ),
                  ),
                  if (isOwn) ...[
                    const SizedBox(width: 4),
                    _buildReadReceipt(msg),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
          // Gesetzte Reaktion: Plakette am unteren Rand, zur Mitte hin —
          // weg von Uhrzeit und Lesehaken, die unten rechts in der Blase sitzen.
          if (reaktionDa)
            Positioned(
              bottom: 0,
              left: isOwn ? 60 : null,
              right: isOwn ? null : 60,
              child: canReact
                  ? GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (d) => _reactTapPos = d.globalPosition,
                      onTap: () => _openReactionPicker(msg, reaction),
                      child: ReaktionsPlakette(schluessel: msg['reaction']),
                    )
                  : ReaktionsPlakette(schluessel: msg['reaction']),
            )
          // Noch keine Reaktion: Auslöser senkrecht mittig im freien Rand
          // rechts neben der fremden Blase, nicht über der ersten Textzeile.
          else if (canReact)
            Positioned(
              top: 0,
              bottom: 0,
              right: 10,
              child: Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => _reactTapPos = d.globalPosition,
                  onTap: () => _openReactionPicker(msg, null),
                  child: const AddReactionButton(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Öffnet das Auswahlband und speichert optimistisch: die Blase zeigt die
  /// Reaktion sofort und nimmt sie zurück, wenn der Server sie ablehnt.
  /// Ohne das sähe ein Fehlschlag wie ein Erfolg aus.
  Future<void> _openReactionPicker(
      Map<String, dynamic> msg, MessageEmotion? current) async {
    final pick = await showEmotionPicker(context, _reactTapPos, current: current);
    if (pick == null || !mounted) return;

    final convId = _conversationId;
    final rawId = msg['id'];
    final messageId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (convId == null || messageId == null) return;

    final previous = msg['reaction'];
    final newKey = pick.emotion?.storageKey; // null => entfernen

    setState(() {
      if (newKey == null) {
        msg.remove('reaction');
      } else {
        msg['reaction'] = newKey;
      }
    });

    final result = await _apiService.reactToMessage(
      conversationId: convId,
      messageId: messageId,
      mitgliedernummer: widget.mitgliedernummer,
      reaction: newKey ?? '',
    );

    if (result['success'] != true && mounted) {
      setState(() {
        if (previous == null) {
          msg.remove('reaction');
        } else {
          msg['reaction'] = previous;
        }
      });
    }
  }

  Widget _buildAttachmentItem(Map<String, dynamic> attachment, bool isOwn) {
    final filename = attachment['filename'] ?? AppLocalizations.of(context).file;
    final size = attachment['size'] ?? 0;
    final extension = (attachment['extension'] ?? '').toString().toLowerCase();

    IconData icon;
    switch (extension) {
      case 'pdf':
        icon = Icons.picture_as_pdf;
        break;
      case 'png':
      case 'jpg':
      case 'jpeg':
        icon = Icons.image;
        break;
      case 'txt':
        icon = Icons.description;
        break;
      default:
        icon = Icons.attach_file;
    }

    return InkWell(
      onTap: () => _downloadAttachment(attachment),
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isOwn ? Colors.white.withValues(alpha: 0.2) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isOwn ? Colors.white : const Color(0xFF4a90d9)),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    filename,
                    style: TextStyle(
                      fontSize: 12,
                      color: isOwn ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _formatFileSize(size),
                    style: TextStyle(
                      fontSize: 10,
                      color: isOwn ? Colors.white70 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.download, size: 16, color: isOwn ? Colors.white70 : Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  Widget _buildReadReceipt(Map<String, dynamic> msg) {
    final status = msg['status'] ?? 'sent';
    final isRead = msg['is_read'] == true;

    if (isRead || status == 'read') {
      // Double blue checkmarks - read
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.done_all, size: 14, color: Colors.lightBlueAccent),
        ],
      );
    } else if (status == 'delivered') {
      // Double gray checkmarks - delivered
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.done_all, size: 14, color: Colors.white.withValues(alpha: 0.7)),
        ],
      );
    } else {
      // Single checkmark - sent
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.done, size: 14, color: Colors.white.withValues(alpha: 0.7)),
        ],
      );
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _buildInputArea() {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selected files preview
        if (_selectedFiles.isNotEmpty)
          Container(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _selectedFiles.map((file) {
                final name = file.path.split(Platform.pathSeparator).last;
                return Chip(
                  label: Text(name, style: const TextStyle(fontSize: 12)),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () {
                    setState(() => _selectedFiles.remove(file));
                  },
                );
              }).toList(),
            ),
          ),
        Row(
          children: [
            // Camera button
            IconButton(
              icon: const Icon(Icons.camera_alt, color: Color(0xFF4a90d9)),
              onPressed: _isUploading || _isLoading ? null : _takePhoto,
              tooltip: l.takePhoto,
            ),
            // Attachment button
            IconButton(
              icon: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.attach_file, color: Color(0xFF4a90d9)),
              onPressed: _isUploading || _isLoading ? null : _pickFiles,
              tooltip: l.attachFiles,
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                onChanged: (_) => _onTyping(),
                onSubmitted: (_) => _sendMessage(),
                onTap: _markMessagesAsRead,
                decoration: InputDecoration(
                  hintText: l.enterMessage,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                enabled: !_isLoading,
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: const Color(0xFF4a90d9),
              child: IconButton(
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: _isSending ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final messageDate = DateTime(date.year, date.month, date.day);

      if (messageDate == today) {
        return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } else {
        return '${date.day}.${date.month}. ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return '';
    }
  }
}
