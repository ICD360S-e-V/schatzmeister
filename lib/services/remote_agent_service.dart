import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/io_client.dart';

import 'api_service.dart';
import 'chat_service.dart';
import 'device_key_service.dart';
import 'http_client_factory.dart';
import 'language_service.dart';
import 'logger_service.dart';
import 'remote_input/input_injector.dart';
import 'secure_screen.dart';
import '../utils/ice_server_eintraege.dart';
import '../utils/sdp_kurz.dart';
import '../utils/sende_befund.dart';

final _log = LoggerService();

/// Zustand einer Fernwartung auf DIESEM Gerät (der geteilten Seite).
enum RemoteAgentState { idle, connecting, active }

/// Wie der Bildstrom eingestellt wird.
///
/// ⚠️ Unverändert aus der Mitglieder-App: die Zahlen folgen dort den eigenen
/// Messungen des Vereins (Telekom-Uplink im Median rund 18 Mbit/s, aber
/// schwerer Bufferbloat — Latenz unter Last bis 7402 ms). Ein Deckel weit unter
/// der Leitung ist deshalb keine Sparsamkeit, sondern die eigentliche
/// Reparatur der Verzögerung.
class Bildguete {
  final String name;
  final int kbit;
  final int fps;
  final double verkleinern;

  /// Was aufgegeben wird, wenn die Bandbreite knapp wird.
  final RTCDegradationPreference nachgeben;

  const Bildguete(
      this.name, this.kbit, this.fps, this.verkleinern, this.nachgeben);

  /// Voreinstellung: regelt sich selbst (siehe [RemoteAgentService]).
  static const automatik = Bildguete(
      'automatik', 2500, 30, 1.0, RTCDegradationPreference.MAINTAIN_RESOLUTION);

  /// „Flüssig": Bewegung zählt mehr als Schärfe.
  static const fluessig = Bildguete(
      'fluessig', 2000, 30, 1.0, RTCDegradationPreference.MAINTAIN_FRAMERATE);

  /// „Scharf": Schrift zählt mehr als Bewegung.
  static const scharf = Bildguete(
      'scharf', 4000, 15, 1.0, RTCDegradationPreference.MAINTAIN_RESOLUTION);

  static const alle = [automatik, fluessig, scharf];

  static Bildguete vonName(String? n) =>
      alle.firstWhere((g) => g.name == n, orElse: () => automatik);
}

/// Die geteilte Seite der Fernwartung in der Schatzmeister-App.
///
/// Übernommen aus der Mitglieder-App (`remote_agent_service.dart`) und auf
/// Android zugeschnitten. Getrennt von Anrufen und vom RDP-Büroarbeitsplatz.
///
/// Ablauf: die Schatzmeisterin stimmt zu → dieser Dienst nimmt den GANZEN
/// Bildschirm auf, beantwortet das WebRTC-Angebot des Vorsitzes und reicht die
/// Eingaben aus dem Datenkanal an den [InputInjector] weiter. VOR der
/// Zustimmung startet nichts, und sie kann jederzeit [stop]pen.
///
/// ⚠️ Die Sitzung läuft WEITER, wenn die App in den Hintergrund geht — das ist
/// ihr Zweck: geholfen wird meistens in anderen Apps. Getragen wird das vom
/// Vordergrunddienst ([ScreenCaptureFgService]); seine Benachrichtigung ist
/// der Ausschalter, solange die App nicht vorne ist.
///
/// WebRTC-Rollen: der Vorsitz bietet an (Angebot + Eingabekanal), dieses Gerät
/// antwortet und legt die Bildschirmspur dazu.
class RemoteAgentService {
  static final RemoteAgentService _instance = RemoteAgentService._internal();
  factory RemoteAgentService() => _instance;
  RemoteAgentService._internal();

  /// TURN-Zugang — aus dem EIGENEN Bereich des Schatzmeister-API.
  ///
  /// ⚠️ Bewusst nicht `/auth/turn_credentials.php`, das sich Vorsitzer- und
  /// Mitglieder-App teilen: die Schatzmeister-App spricht nur mit
  /// `/api/schatzmeister/` (Rollenprüfung `smRequireSchatzmeister`).
  static const String turnPfad = '/schatzmeister/fernwartung_turn.php';

  final ChatService _chat = ChatService();

  RTCPeerConnection? _pc;
  MediaStream? _screenStream;
  MediaStream? _mikroStream;
  RTCDataChannel? _inputChannel;
  InputInjector? _injector;

  int? _conversationId;
  String? _controllerName;
  bool _remoteDescriptionSet = false;
  final List<RTCIceCandidate> _queuedIce = [];

  StreamSubscription<RemoteIceEvent>? _iceSub;
  StreamSubscription<RemoteEndedEvent>? _endedSub;
  Timer? _vormerkUhr;

  final _stateController = StreamController<RemoteAgentState>.broadcast();
  RemoteAgentState _state = RemoteAgentState.idle;

  Stream<RemoteAgentState> get stateStream => _stateController.stream;
  RemoteAgentState get state => _state;
  String? get controllerName => _controllerName;

  /// Wie viele Kandidaten warten gerade — für den Test, der belegt, dass die
  /// Vormerkung greift.
  int get vorgemerkteKandidaten => _queuedIce.length;

  /// True, solange eine Sitzung aufgebaut wird oder läuft.
  bool get isSharing => _state != RemoteAgentState.idle;

  /// Kurzname der Plattform fürs Prüfprotokoll des Vorsitzes.
  String _plattformName() =>
      Platform.isAndroid ? 'android' : Platform.operatingSystem;

  void _setState(RemoteAgentState s) {
    _state = s;
    if (!_stateController.isClosed) _stateController.add(s);
  }

  // ─── TURN-Zugang (nur der eigene coturn) ──────────────────────────────────
  static Map<String, dynamic>? _cachedIceServers;
  static DateTime? _cacheExpiry;

  static Future<Map<String, dynamic>> _getIceServers() async {
    if (_cachedIceServers != null &&
        _cacheExpiry != null &&
        DateTime.now().isBefore(_cacheExpiry!)) {
      return _cachedIceServers!;
    }
    const empty = {'iceServers': <Map<String, dynamic>>[]};
    try {
      final token = ApiService().token;
      final geraet = DeviceKeyService().deviceKey;
      if (token == null || geraet == null) {
        _log.warning('RemoteAgent: TURN ohne Anmeldung nicht abrufbar', tag: 'REMOTE');
        return empty;
      }
      final client = IOClient(HttpClientFactory.createPinnedHttpClient(
        connectionTimeout: const Duration(seconds: 10),
      ));
      try {
        final response = await client.get(
          Uri.parse('${ApiService.baseUrl}$turnPfad'),
          headers: {
            'User-Agent': 'ICD360S-Schatzmeister/1.0',
            'X-Device-Key': geraet,
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) {
          _log.warning('RemoteAgent: TURN-Zugang abgelehnt (HTTP ${response.statusCode})',
              tag: 'REMOTE');
          return empty;
        }
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final uris = (data['uris'] as List?)?.map((e) => e.toString()).toList() ??
            const <String>[];
        final username = data['username']?.toString();
        final password = data['password']?.toString();
        if (uris.isEmpty || username == null || password == null) return empty;
        // EIN Eintrag je URI — siehe [iceServerEintraege].
        final servers = iceServerEintraege(uris, username, password);
        if (servers.isEmpty) return empty;
        _cachedIceServers = {'iceServers': servers};
        final ttl = (data['ttl'] as num?)?.toInt() ?? 86400;
        _cacheExpiry = DateTime.now()
            .add(Duration(seconds: ttl > 60 ? (ttl * 9 ~/ 10) : ttl));
        return _cachedIceServers!;
      } finally {
        client.close();
      }
    } catch (e) {
      _log.warning('RemoteAgent: TURN-Abruf fehlgeschlagen: $e', tag: 'REMOTE');
      return empty;
    }
  }

  // ─── Öffentlich ───────────────────────────────────────────────────────────

  /// 🔴 AB HIER die ICE-Kandidaten des Vorsitzes einsammeln — nicht erst nach
  /// dem Antworten.
  ///
  /// `remoteIceStream` ist ein **Broadcast**-Stream: was ankommt, während
  /// niemand zuhört, ist weg. Der Vorsitz sammelt seine Kandidaten aber schon
  /// Sekundenbruchteile nach dem Angebot, während hier noch der
  /// Zustimmungsdialog offen steht. In der Mitglieder-App fielen sie bis zum
  /// 30.08.2026 ins Leere — ein ICE-Agent ohne Gegenkandidaten fängt gar nicht
  /// erst an.
  void angebotVormerken(RemoteOfferEvent offer) {
    if (_state != RemoteAgentState.idle) return;
    _vormerkUhr?.cancel();
    _iceSub?.cancel();
    _conversationId = offer.conversationId;
    _queuedIce.clear();
    _iceSub = _chat.remoteIceStream.listen((e) {
      if (e.conversationId == _conversationId) handleIce(e);
    });
    // Etwas mehr als die 60 s, nach denen der Vorsitz aufgibt.
    _vormerkUhr = Timer(const Duration(seconds: 90), () {
      if (_state == RemoteAgentState.idle) vormerkungVerwerfen();
    });
    _log.info('RemoteAgent: sammle ICE ab Angebot (conv ${offer.conversationId})', tag: 'REMOTE');
  }

  /// Zurücknehmen, wenn nicht zugestimmt wurde.
  void vormerkungVerwerfen() {
    _vormerkUhr?.cancel();
    _vormerkUhr = null;
    _iceSub?.cancel();
    _iceSub = null;
    _queuedIce.clear();
    if (_state == RemoteAgentState.idle) _conversationId = null;
  }

  /// Zugestimmt: Bildschirm aufnehmen und das Angebot beantworten.
  /// Gibt false zurück, wenn der Aufbau misslang.
  Future<bool> accept(RemoteOfferEvent offer) async {
    if (_state != RemoteAgentState.idle) return false;
    // ⚠️ `_queuedIce` NICHT leeren: darin liegen die Kandidaten, die während
    // des Zustimmungsdialogs eingetroffen sind.
    _vormerkUhr?.cancel();
    _vormerkUhr = null;
    if (_iceSub == null) angebotVormerken(offer);
    _conversationId = offer.conversationId;
    _controllerName = offer.controllerName;
    _setState(RemoteAgentState.connecting);

    try {
      // Dem Raum beitreten, damit ICE und Sitzungsende des Vorsitzes auch über
      // den Raum ankommen (das Angebot selbst kam per Weiterleitung).
      _chat.joinConversation(offer.conversationId);

      // FLAG_SECURE aufheben, sonst ist die App selbst im Bild schwarz.
      // ⚠️ Das Ergebnis wird ausgewertet und geht mit der Antwort mit.
      _sperreOffen = await SecureScreen.setSecure(false);
      if (!_sperreOffen) {
        _log.error('RemoteAgent: FLAG_SECURE liess sich NICHT aufheben — '
            'die App bleibt im geteilten Bild schwarz', tag: 'REMOTE');
      }
      _injector = createInputInjector();
      // ⚠️ Vor dem Antworten: erst danach steht fest, ob gesteuert werden darf,
      // und genau das wird der Gegenseite gemeldet.
      await _injector!.vorbereiten();
      await _createPeerConnection();

      // 🔴 REIHENFOLGE: Zustimmung → Mikrofon → Vordergrunddienst → Aufnahme.
      //
      // Erst die Bildschirmfreigabe (der Systemdialog IST die Einwilligung,
      // die Android verlangt), DANN der Dienst — so steht es in der
      // Android-Doku zu den Diensttypen.
      //
      // ⚠️ Das Mikrofon VOR dem Dienst, anders als in der Mitglieder-App: ab
      // Android 14 darf ein Vordergrunddienst den Typ `microphone` nur
      // anmelden, wenn RECORD_AUDIO zu diesem Zeitpunkt schon erteilt ist.
      // Erst danach gefragt, liefe der Ton ohne diesen Typ — und Android
      // schnitte ihn ab, sobald die App im Hintergrund ist. Genau dort wird
      // aber geholfen.
      await _bildschirmFreigabeHolen();
      _mikroStream = await _mikrofonHolen();
      await ScreenCaptureFgService.start(
        titel: tr('Fernwartung aktiv', 'Asistență la distanță activă'),
        text: tr(
          'Ihr Bildschirm wird mit ${offer.controllerName} geteilt. Tippen, um die App zu öffnen.',
          'Ecranul dvs. este partajat cu ${offer.controllerName}. Atingeți pentru a deschide aplicația.',
        ),
        stopp: tr('Beenden', 'Oprește'),
        beiStopp: () => stop(reason: 'member_stop'),
      );

      _screenStream = await _captureScreen();
      for (final track in _screenStream!.getTracks()) {
        await _pc!.addTrack(track, _screenStream!);
      }

      if (_mikroStream != null) {
        for (final track in _mikroStream!.getTracks()) {
          // 🔴 Der Ton geht in DIESELBE Spurgruppe wie der Bildschirm — so
          // enthält `streams[0]` beim Vorsitz immer auch das Bild (vorsitzer#523).
          await _pc!.addTrack(track, _screenStream!);
        }
        _tonwegSetzen();
      }

      _sdpProtokollieren('Angebot', offer.sdp);
      await _pc!.setRemoteDescription(RTCSessionDescription(offer.sdp, offer.sdpType));
      _remoteDescriptionSet = true;
      await _flushQueuedIce();
      final answer = await _pc!.createAnswer();
      await _pc!.setLocalDescription(answer);
      _sdpProtokollieren('Antwort', answer.sdp);
      // Plattform, Steuerbarkeit und Sperre gehen MIT der Antwort zurück —
      // der Vorsitz kann sie beim Anfragen nicht wissen.
      _chat.sendRemoteAnswer(
        offer.conversationId,
        answer.sdp ?? '',
        answer.type ?? 'answer',
        plattform: _plattformName(),
        steuerung: _injector?.isSupported ?? false,
        bildFrei: _sperreOffen,
      );

      // Erst NACH setLocalDescription: vorher hat der Sender keine Encodings.
      await bildgueteSetzen(_guete);
      _befundUhrStarten();

      _subscribeSession();
      _log.info('RemoteAgent: answered offer, sharing screen (control=${_injector?.isSupported})', tag: 'REMOTE');
      return true;
    } catch (e) {
      _log.error('RemoteAgent: accept failed: $e', tag: 'REMOTE');
      stop(reason: 'error', notifyPeer: true);
      return false;
    }
  }

  /// Abgelehnt.
  void decline(RemoteOfferEvent offer, {String reason = 'declined'}) {
    vormerkungVerwerfen();
    _chat.sendRemoteReject(offer.conversationId, reason);
    _log.info('RemoteAgent: declined offer from ${offer.controllerName} ($reason)', tag: 'REMOTE');
  }

  /// Sitzung beenden. [notifyPeer] schickt remote_end an den Vorsitz (Stopp
  /// hier); false, wenn der Vorsitz selbst beendet hat.
  void stop({String reason = 'member_stop', bool notifyPeer = true}) {
    if (_state == RemoteAgentState.idle) return;
    if (notifyPeer && _conversationId != null) {
      _chat.sendRemoteEnd(_conversationId!);
    }
    _log.info('RemoteAgent: stopping session ($reason)', tag: 'REMOTE');
    _cleanup();
    _setState(RemoteAgentState.idle);
  }

  /// ICE-Kandidat aus der Signalisierung (wartet, bis das Angebot gesetzt ist).
  Future<void> handleIce(RemoteIceEvent e) async {
    // ⚠️ Die Prüfung gehört HIERHER: ein Kandidat aus einer fremden
    // Unterhaltung wäre in der Warteschlange sonst nicht mehr zu erkennen.
    if (_conversationId == null || e.conversationId != _conversationId) return;
    final cand = RTCIceCandidate(e.candidate, e.sdpMid, e.sdpMLineIndex);
    if (_pc == null || !_remoteDescriptionSet) {
      _queuedIce.add(cand);
      return;
    }
    try {
      await _pc!.addCandidate(cand);
    } catch (err) {
      _log.warning('RemoteAgent: addCandidate failed: $err', tag: 'REMOTE');
    }
  }

  // ─── Intern ───────────────────────────────────────────────────────────────

  Future<void> _createPeerConnection() async {
    final iceServers = await _getIceServers();
    if ((iceServers['iceServers'] as List).isEmpty) {
      throw StateError('TURN_UNAVAILABLE');
    }
    // Wie in der Mitglieder-App: nur über unser Relais, ein Transportweg.
    _pc = await createPeerConnection({
      ...iceServers,
      'sdpSemantics': 'unified-plan',
      'iceTransportPolicy': 'relay',
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
    });

    _pc!.onIceCandidate = (c) {
      if (c.candidate != null && _conversationId != null) {
        _chat.sendRemoteIce(_conversationId!, c.candidate!, c.sdpMid ?? '', c.sdpMLineIndex ?? 0);
      }
    };

    _pc!.onConnectionState = (s) {
      _log.info('RemoteAgent: PC state $s', tag: 'REMOTE');
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _setState(RemoteAgentState.active);
      } else if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          s == RTCPeerConnectionState.RTCPeerConnectionStateClosed ||
          s == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        stop(reason: 'disconnect', notifyPeer: false);
      }
    };

    // Der Vorsitz legt den Eingabekanal an; hier kommt er an.
    _pc!.onDataChannel = (channel) {
      _inputChannel = channel;
      channel.onMessage = (msg) => _handleInput(msg.text);
      _log.info('RemoteAgent: input data channel received (${channel.label})', tag: 'REMOTE');
    };
  }

  /// Holt die Bildschirmfreigabe — festgelegt auf den GANZEN Bildschirm.
  ///
  /// `fullScreenOnly: true` nimmt dem Systemdialog ab Android 14 die Auswahl
  /// „einzelne App": eine einzelne freigegebene App wäre für die Fernwartung
  /// nutzlos, geholfen wird gerade beim Wechsel in andere Apps.
  /// Fällt der Aufruf durch, übernimmt `getDisplayMedia` den gewohnten Dialog.
  Future<void> _bildschirmFreigabeHolen() async {
    if (!Platform.isAndroid) return;
    try {
      final erlaubt = await Helper.requestCapturePermission(fullScreenOnly: true);
      if (!erlaubt) throw StateError('BILDSCHIRM_ABGELEHNT');
    } on StateError {
      rethrow;
    } catch (e) {
      _log.warning('RemoteAgent: fullScreenOnly nicht moeglich ($e) — '
          'gewohnter Auswahldialog', tag: 'REMOTE');
    }
  }

  /// Den ganzen Bildschirm aufnehmen.
  ///
  /// ⚠️ Auf Android ignoriert das Plugin die Constraints und nimmt mit
  /// `DEFAULT_FPS = 30` auf; begrenzt wird über die Encodings des Senders.
  Future<MediaStream> _captureScreen() async {
    return navigator.mediaDevices.getDisplayMedia(<String, dynamic>{
      'video': {'mandatory': {'frameRate': 15.0}},
      'audio': false,
    });
  }

  /// Mikrofon für das Gespräch während der Sitzung.
  ///
  /// ⚠️ Gibt bei Ablehnung `null` zurück und lässt die Sitzung WEITERLAUFEN:
  /// wer sein Mikrofon nicht freigibt, will trotzdem Hilfe.
  Future<MediaStream?> _mikrofonHolen() async {
    try {
      return await navigator.mediaDevices.getUserMedia(<String, dynamic>{
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': false,
      });
    } catch (e) {
      _log.warning('RemoteAgent: kein Mikrofon ($e) — Sitzung laeuft ohne Ton',
          tag: 'REMOTE');
      return null;
    }
  }

  /// Ton auf eine angeschlossene Garnitur legen, sonst Lautsprecher.
  void _tonwegSetzen() {
    try {
      if (Platform.isAndroid) Helper.setSpeakerphoneOnButPreferBluetooth();
      _log.info('RemoteAgent: Tonweg gesetzt (Kopfhoerer bevorzugt)', tag: 'REMOTE');
    } catch (e) {
      _log.warning('RemoteAgent: Tonweg nicht setzbar: $e', tag: 'REMOTE');
    }
  }

  Bildguete _guete = Bildguete.automatik;

  /// Aktuell eingestellte Bildgüte.
  Bildguete get guete => _guete;

  /// Bitrate, Bildrate und Auflösung des Bildstroms setzen — sofort, ohne
  /// Neuverhandlung.
  Future<bool> bildgueteSetzen(Bildguete g) async {
    _guete = g;
    if (g == Bildguete.automatik) {
      _reglerStarten();
    } else {
      // Eine feste Stufe ist eine Ansage: der Regler darf sie nicht wegregeln.
      _reglerStoppen();
    }
    return _bitrateSetzen(g.kbit, g.fps, g.verkleinern, g.nachgeben);
  }

  Future<bool> _bitrateSetzen(int kbit, int fps, double verkleinern,
      RTCDegradationPreference nachgeben) async {
    final pc = _pc;
    if (pc == null) return false;
    try {
      RTCRtpSender? bild;
      for (final s in await pc.getSenders()) {
        if (s.track?.kind == 'video') {
          bild = s;
          break;
        }
      }
      if (bild == null) return false;

      final p = bild.parameters;
      final enc = p.encodings;
      if (enc == null || enc.isEmpty) {
        p.encodings = [RTCRtpEncoding()];
      }
      for (final e in p.encodings!) {
        e.maxBitrate = kbit * 1000;
        e.maxFramerate = fps;
        e.scaleResolutionDownBy = verkleinern;
        e.priority = RTCPriorityType.high;
        e.networkPriority = RTCPriorityType.high;
      }
      p.degradationPreference = nachgeben;
      await bild.setParameters(p);
      _log.info('RemoteAgent: $kbit kbit/s, $fps fps, 1/$verkleinern', tag: 'REMOTE');
      return true;
    } catch (e) {
      _log.warning('RemoteAgent: Bitrate nicht setzbar: $e', tag: 'REMOTE');
      return false;
    }
  }

  // ─── Selbstregelung auf Umlaufzeit (wie in der Mitglieder-App) ───────────
  //
  // Die eingebaute Regelung wartet auf Paketverlust; bei Bufferbloat kommt der
  // zu spät. Hier geht die Bitrate herunter, sobald die Umlaufzeit über ihren
  // eigenen Ruhewert steigt — bevor etwas verloren geht.

  Timer? _reglerUhr;
  int _kbit = 0;
  final List<double> _rttProben = [];
  int _ruhigeTakte = 0;

  static const int _kbitMin = 350;
  static const int _kbitMax = 8000;
  static const double _rttAufschlagMs = 120;
  static const int _taktzahlBisHoch = 3;

  void _reglerStarten() {
    _reglerUhr?.cancel();
    _rttProben.clear();
    _ruhigeTakte = 0;
    _kbit = Bildguete.automatik.kbit;
    _reglerUhr = Timer.periodic(const Duration(seconds: 2), (_) => _regelTakt());
  }

  void _reglerStoppen() {
    _reglerUhr?.cancel();
    _reglerUhr = null;
  }

  Future<void> _regelTakt() async {
    final pc = _pc;
    if (pc == null || _guete != Bildguete.automatik) return;
    try {
      double? rttMs;
      double? verfuegbarBit;
      String? grenze;

      for (final b in await pc.getStats()) {
        final w = b.values;
        if (b.type == 'candidate-pair' && w['nominated'] == true) {
          final rtt = w['currentRoundTripTime'];
          if (rtt is num) rttMs = rtt.toDouble() * 1000;
          final frei = w['availableOutgoingBitrate'];
          if (frei is num) verfuegbarBit = frei.toDouble();
        } else if (b.type == 'outbound-rtp' && w['kind'] == 'video') {
          final g = w['qualityLimitationReason'];
          if (g is String) grenze = g;
        }
      }
      if (rttMs == null) return;

      _rttProben.add(rttMs);
      if (_rttProben.length > 30) _rttProben.removeAt(0);
      final ruhe = _rttProben.reduce((a, b) => a < b ? a : b);

      final verstopft = rttMs > ruhe + _rttAufschlagMs || grenze == 'bandwidth';
      var neu = _kbit;

      if (verstopft) {
        neu = (_kbit * 0.75).round();
        _ruhigeTakte = 0;
      } else if (++_ruhigeTakte >= _taktzahlBisHoch) {
        final schaetzung = verfuegbarBit != null && verfuegbarBit > 0
            ? verfuegbarBit / 1000
            : null;
        neu = (schaetzung != null && _kbit < schaetzung * 0.7)
            ? (_kbit * 1.4).round()
            : _kbit + 250;
        _ruhigeTakte = 0;
      }

      if (verfuegbarBit != null && verfuegbarBit > 0) {
        final deckel = (verfuegbarBit * 0.9 / 1000).round();
        if (neu > deckel) neu = deckel;
      }
      neu = neu.clamp(_kbitMin, _kbitMax);

      if ((neu - _kbit).abs() * 100 ~/ _kbit >= 8) {
        _kbit = neu;
        await _bitrateSetzen(_kbit, Bildguete.automatik.fps, 1.0,
            Bildguete.automatik.nachgeben);
        _log.info('RemoteAgent: Automatik → $_kbit kbit/s '
            '(RTT ${rttMs.round()} ms, Ruhe ${ruhe.round()} ms'
            '${grenze != null ? ", Grenze $grenze" : ""})', tag: 'REMOTE');
      }
    } catch (e) {
      _log.warning('RemoteAgent: Regeltakt fehlgeschlagen: $e', tag: 'REMOTE');
    }
  }

  /// Aktuelle Bitrate der Automatik in kbit/s (0 = Automatik läuft nicht).
  int get automatikKbit => _guete == Bildguete.automatik ? _kbit : 0;

  // ─── Sendebefund (siehe [SendeBefund]) ────────────────────────────────────

  Timer? _befundUhr;
  int _befundTakte = 0;
  SendeBefund? _letzterBefund;
  String? _protokollierteLage;

  SendeBefund? get letzterSendeBefund => _letzterBefund;

  void _befundUhrStarten() {
    _befundUhr?.cancel();
    _befundTakte = 0;
    _letzterBefund = null;
    _protokollierteLage = null;
    _befundUhr = Timer.periodic(const Duration(seconds: 5), (_) => _befundLesen());
  }

  Future<void> _befundLesen() async {
    final pc = _pc;
    if (pc == null) return;
    try {
      final befund = SendeBefund.ausStatistik([
        for (final b in await pc.getStats())
          (id: b.id, type: b.type, werte: b.values),
      ]);
      final vorher = _letzterBefund;
      _letzterBefund = befund;
      _befundTakte++;
      final lage = befund.lage(vorher);
      final wechsel = lage != _protokollierteLage;
      if (!SendeBefund.faellig(_befundTakte, wechsel: wechsel)) return;
      _protokollierteLage = lage;
      final zeile = 'RemoteAgent: Bild $lage — ${befund.protokoll}';
      if (lage == SendeBefund.lageLaeuft) {
        _log.info(zeile, tag: 'REMOTE');
      } else {
        _log.warning(zeile, tag: 'REMOTE');
      }
    } catch (e) {
      _log.warning('RemoteAgent: Sendebefund nicht lesbar: $e', tag: 'REMOTE');
    }
  }

  void _sdpProtokollieren(String was, String? sdp) {
    for (final zeile in sdpVideoKurz(sdp)) {
      _log.info('RemoteAgent: SDP $was — $zeile', tag: 'REMOTE');
    }
  }

  /// Eigenes Mikrofon stummschalten, ohne die Sitzung zu beenden.
  void mikrofonStumm(bool stumm) {
    for (final t in _mikroStream?.getAudioTracks() ?? const <MediaStreamTrack>[]) {
      t.enabled = !stumm;
    }
  }

  /// Liegt überhaupt ein Mikrofon an? Für die Anzeige im Banner.
  bool get hatMikrofon => _mikroStream != null;

  /// Konnte FLAG_SECURE aufgehoben werden?
  bool get sperreOffen => _sperreOffen;
  bool _sperreOffen = true;

  /// Einen Eingaberahmen des Vorsitzes auswerten.
  void _handleInput(String text) {
    final Map<String, dynamic> m;
    try {
      m = jsonDecode(text) as Map<String, dynamic>;
    } catch (e) {
      _log.warning('RemoteAgent: bad input frame: $e', tag: 'REMOTE');
      return;
    }

    // ⚠️ Die Bildgüte VOR der Steuerungsprüfung: sie ist keine Eingabe und
    // muss auch greifen, wenn nur zugeschaut wird.
    if (m['t'] == 'q') {
      bildgueteSetzen(Bildguete.vonName(m['g']?.toString()));
      return;
    }
    // Bildschirmwahl: ein Telefon hat nur die eine Anzeige — nichts zu tun,
    // und vor allem keine Eingabe.
    if (m['t'] == 's') return;

    final injector = _injector;
    if (injector == null || !injector.isSupported) return; // nur zuschauen
    try {
      switch (m['t']) {
        case 'm':
          injector.mouseMove((m['x'] as num).toDouble(), (m['y'] as num).toDouble());
          break;
        case 'b':
          injector.mouseButton((m['b'] as num).toInt(), m['down'] == true);
          break;
        case 'w':
          injector.mouseWheel((m['dx'] as num?)?.toDouble() ?? 0, (m['dy'] as num?)?.toDouble() ?? 0);
          break;
        case 'g':
          injector.systemAktion((m['a'] ?? '').toString());
          break;
        case 'k':
          injector.keyEvent(
            hid: (m['hid'] as num).toInt(),
            character: m['ch'] as String?,
            down: m['down'] == true,
          );
          break;
      }
    } catch (e) {
      _log.warning('RemoteAgent: bad input frame: $e', tag: 'REMOTE');
    }
  }

  void _subscribeSession() {
    // Läuft schon seit dem Angebot — ein zweites Abo speiste doppelt ein.
    _iceSub ??= _chat.remoteIceStream.listen((e) {
      if (e.conversationId == _conversationId) handleIce(e);
    });
    _endedSub = _chat.remoteEndedStream.listen((e) {
      if (e.conversationId == _conversationId) stop(reason: 'controller_end', notifyPeer: false);
    });
  }

  Future<void> _flushQueuedIce() async {
    for (final c in _queuedIce) {
      try {
        await _pc!.addCandidate(c);
      } catch (_) {}
    }
    _queuedIce.clear();
  }

  void _cleanup() {
    _reglerStoppen();
    _befundUhr?.cancel();
    _befundUhr = null;
    final schluss = _letzterBefund;
    if (schluss != null) {
      _log.info('RemoteAgent: Bild am Ende — ${schluss.protokoll}', tag: 'REMOTE');
    }
    _letzterBefund = null;
    _vormerkUhr?.cancel();
    _vormerkUhr = null;
    // Sperre wieder setzen, Vordergrunddienst beenden.
    SecureScreen.setSecure(true);
    ScreenCaptureFgService.stop();
    _iceSub?.cancel();
    _endedSub?.cancel();
    _iceSub = null;
    _endedSub = null;
    try {
      _inputChannel?.close();
    } catch (_) {}
    _inputChannel = null;
    try {
      _screenStream?.getTracks().forEach((t) => t.stop());
      _screenStream?.dispose();
    } catch (_) {}
    _screenStream = null;
    try {
      _mikroStream?.getTracks().forEach((t) => t.stop());
      _mikroStream?.dispose();
    } catch (_) {}
    _mikroStream = null;
    try {
      _pc?.close();
    } catch (_) {}
    _pc = null;
    _injector?.dispose();
    _injector = null;
    _remoteDescriptionSet = false;
    _queuedIce.clear();
    _conversationId = null;
    _controllerName = null;
  }
}
