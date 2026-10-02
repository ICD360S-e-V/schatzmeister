import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'chat_service.dart';
import 'language_service.dart';
import 'logger_service.dart';
import 'notification_service.dart';
import 'remote_agent_service.dart';
import '../widgets/remote_consent_dialog.dart';

final _log = LoggerService();

/// Nimmt die Fernwartungs-Anfragen des Vorsitzes entgegen und zeigt den
/// Zustimmungsdialog — in der Mitglieder-App stand das im Dashboard
/// (`_handleRemoteOffer`), hier steht es für sich.
///
/// ⚠️ Die Anfrage kommt an, solange die App LÄUFT — auch im Hintergrund, denn
/// der Chat bleibt dort verbunden. Ist die App gerade nicht vorne, erscheint
/// zusätzlich eine Benachrichtigung; ein Tipp darauf holt die App mit dem
/// schon offenen Dialog nach vorne. Ist die App ganz geschlossen, kommt nichts
/// an (dafür bräuchte es einen eigenen Hintergrunddienst wie in der
/// Mitglieder-App — bewusst nicht Teil dieser Fassung).
///
/// Der Dialog hängt am Navigator der App ([NotificationService.navigatorKey]),
/// nicht an einem Bildschirm: so erscheint er auch über einem offenen Chat.
class FernwartungAnfragen {
  FernwartungAnfragen._();
  static final FernwartungAnfragen instance = FernwartungAnfragen._();

  StreamSubscription<RemoteOfferEvent>? _sub;

  /// Schließt den gerade offenen Zustimmungsdialog, falls einer offen ist.
  VoidCallback? _offenerDialog;

  /// Ist gerade ein Zustimmungsdialog offen? Für Tests und das Protokoll.
  bool get dialogOffen => _offenerDialog != null;

  /// Nur für Tests: Android vortäuschen.
  @visibleForTesting
  static bool? istAndroidFuerTest;

  /// Nur für Tests: Vorder-/Hintergrund vortäuschen.
  @visibleForTesting
  static bool? imBlickFuerTest;

  bool get _android => istAndroidFuerTest ?? Platform.isAndroid;

  /// Ist die App wirklich IM BLICK? `mounted` sagt das nicht — nur der
  /// Lebenszyklus.
  bool get _imBlick =>
      imBlickFuerTest ??
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  /// Ab jetzt zuhören. Mehrfacher Aufruf schadet nicht.
  void starten() {
    _sub ??= ChatService().remoteOfferStream.listen(anfrageErhalten);
  }

  /// Nicht mehr zuhören — und eine laufende Sitzung beenden: wer sich
  /// abmeldet, teilt danach keinen Bildschirm mehr.
  void stoppen() {
    _sub?.cancel();
    _sub = null;
    _offenerDialog?.call();
    final agent = RemoteAgentService();
    if (agent.isSharing) agent.stop(reason: 'abgemeldet');
  }

  /// Eine Anfrage des Vorsitzes.
  @visibleForTesting
  void anfrageErhalten(RemoteOfferEvent e) {
    final chat = ChatService();
    final agent = RemoteAgentService();
    _log.info('Fernwartung: Anfrage von ${e.controllerName} (conv ${e.conversationId}, '
        '${_imBlick ? "App vorne" : "App im Hintergrund"})', tag: 'REMOTE');

    // Die Schatzmeister-App wird nur für Android gebaut. Anderswo sofort
    // absagen, statt den Vorsitz eine Minute warten zu lassen.
    if (!_android) {
      chat.sendRemoteReject(e.conversationId, 'nicht_unterstuetzt');
      return;
    }
    if (agent.isSharing) {
      chat.sendRemoteReject(e.conversationId, 'busy');
      return;
    }

    // Eine neue Anfrage ERSETZT eine noch offene: der Vorsitz hat neu
    // angesetzt, die alte gilt bei ihm nicht mehr. Ihr wird nichts geantwortet
    // — eine Absage trüge dieselbe Unterhaltung und träfe die NEUE Anfrage.
    _offenerDialog?.call();

    final navigator = NotificationService.navigatorKey.currentState;
    if (navigator == null) {
      chat.sendRemoteReject(e.conversationId, 'nicht_bereit');
      return;
    }

    // 🔴 VOR dem Dialog: ab jetzt die ICE-Kandidaten des Vorsitzes einsammeln.
    agent.angebotVormerken(e);

    if (!_imBlick) {
      // Die App ist nicht vorne — ohne diesen Hinweis liefe die Minute ab,
      // ohne dass die Schatzmeisterin von der Anfrage erfährt. Ein Tipp holt
      // die App samt Dialog nach vorne.
      NotificationService().show(
        title: tr('Fernwartung-Anfrage', 'Cerere de asistență la distanță'),
        body: tr(
          '${e.controllerName} möchte Ihren Bildschirm sehen. Tippen Sie hier, um zu antworten.',
          '${e.controllerName} dorește să vă vadă ecranul. Atingeți aici pentru a răspunde.',
        ),
      );
    }

    StreamSubscription<RemoteEndedEvent>? endeSub;
    var offen = true;
    late final DialogRoute<void> route;
    void schliessen() {
      if (!offen) return;
      offen = false;
      endeSub?.cancel();
      if (_offenerDialog == schliessen) _offenerDialog = null;
      // ⚠️ Gezielt DIESE Route, nicht `pop()`: liegt inzwischen etwas darüber
      // (etwa der Update-Dialog), schlösse `pop()` das Falsche.
      if (route.isActive) navigator.removeRoute(route);
    }

    route = DialogRoute<void>(
      context: navigator.context,
      barrierDismissible: false,
      builder: (_) => RemoteConsentDialog(
        controllerName: e.controllerName,
        onAccept: () {
          schliessen();
          agent.accept(e);
        },
        onDecline: () {
          schliessen();
          agent.decline(e);
        },
      ),
    );
    _offenerDialog = schliessen;

    // Gibt der Vorsitz auf (60-s-Zeitablauf) oder legt er auf, muss der Dialog
    // verschwinden — ein späteres „Erlauben" teilte sonst mit niemandem.
    endeSub = chat.remoteEndedStream.listen((ende) {
      if (ende.conversationId != e.conversationId || !offen) return;
      _log.info('Fernwartung: Anfrage vom Vorsitz zurückgezogen', tag: 'REMOTE');
      agent.vormerkungVerwerfen();
      schliessen();
    });

    navigator.push(route).then((_) {
      // Auf anderem Weg geschlossen (z. B. Zurück-Taste trotz
      // barrierDismissible): aufräumen wie bei „Ablehnen".
      if (offen) {
        offen = false;
        endeSub?.cancel();
        if (_offenerDialog == schliessen) _offenerDialog = null;
        agent.decline(e);
      }
    });
  }
}
