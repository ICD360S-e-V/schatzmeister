import 'dart:async';

import 'package:flutter/material.dart';

import '../services/language_service.dart';
import '../services/remote_agent_service.dart';

/// Leiste oben im Dashboard, solange eine Fernwartung aufgebaut wird oder
/// läuft — übernommen aus der Mitglieder-App.
///
/// Zwei Aufgaben: unübersehbar zeigen, dass der Bildschirm geteilt wird, und
/// ein „Stopp", das immer erreichbar ist. Ohne Sitzung zeichnet sie nichts.
/// Außerhalb der App übernimmt die Benachrichtigung des Vordergrunddienstes
/// diese Rolle (siehe `ScreenCaptureFgService`).
class RemoteSharingBanner extends StatefulWidget {
  const RemoteSharingBanner({super.key});

  @override
  State<RemoteSharingBanner> createState() => _RemoteSharingBannerState();
}

class _RemoteSharingBannerState extends State<RemoteSharingBanner> {
  final RemoteAgentService _agent = RemoteAgentService();
  StreamSubscription<RemoteAgentState>? _sub;
  RemoteAgentState _state = RemoteAgentState.idle;
  bool _stumm = false;

  @override
  void initState() {
    super.initState();
    _state = _agent.state;
    _sub = _agent.stateStream.listen((s) {
      if (!mounted) return;
      setState(() {
        _state = s;
        // Nach dem Ende wieder „nicht stumm" — der nächste Anlauf finge sonst
        // mit einem Schalter an, der etwas anderes zeigt, als gilt.
        if (s == RemoteAgentState.idle) _stumm = false;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_state == RemoteAgentState.idle) return const SizedBox.shrink();
    final connecting = _state == RemoteAgentState.connecting;
    final rot = Colors.red.shade700;
    final label = connecting
        ? tr('Verbindung wird aufgebaut …', 'Se conectează …')
        : tr('Ihr Bildschirm wird geteilt', 'Ecranul dvs. este partajat');
    return Material(
      color: connecting ? Colors.orange.shade800 : rot,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(connecting ? Icons.sync : Icons.screen_share, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
            // Stummschalten, ohne die Sitzung zu beenden — nur wenn überhaupt
            // ein Mikrofon anliegt.
            if (_agent.hatMikrofon)
              IconButton(
                tooltip: _stumm
                    ? tr('Mikrofon an', 'Pornește microfonul')
                    : tr('Mikrofon aus', 'Oprește microfonul'),
                icon: Icon(_stumm ? Icons.mic_off : Icons.mic, color: Colors.white),
                onPressed: () {
                  _agent.mikrofonStumm(!_stumm);
                  setState(() => _stumm = !_stumm);
                },
              ),
            TextButton(
              onPressed: () => _agent.stop(reason: 'member_stop'),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: rot,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              ),
              child: Text(tr('Stopp', 'Stop'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
