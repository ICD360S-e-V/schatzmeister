/// Obergrenze der ICE-Einträge — gegen eine Serverantwort mit beliebig vielen
/// URIs, an denen sonst jeder Verbindungsaufbau mitwartet.
const int kMaxIceServer = 8;

/// Baut die `iceServers`-Liste für `createPeerConnection`: **ein Eintrag je
/// URI, `urls` immer ein einzelner String, nie eine Liste.**
///
/// ⚠️ Übernommen aus der Mitglieder-App (`voice_call_service.dart`), dort mit
/// derselben Begründung: die Desktop-Brücke von flutter_webrtc liest `urls` in
/// EINEN String und überschreibt ihn je Schleifendurchlauf — von N URIs bliebe
/// nur die letzte. Android behält zwar alle, aber beide Enden sollen gleich
/// sammeln, sonst erreicht nur eines von ihnen das Relais.
///
/// Die Zugangsdaten hängen nur an den TURN-Einträgen; ein `stun:`-Eintrag
/// bekommt keine.
List<Map<String, dynamic>> iceServerEintraege(
  List<String> uris,
  String username,
  String password,
) {
  final servers = <Map<String, dynamic>>[];
  for (final u in uris) {
    if (u.startsWith('stun:')) {
      servers.add({'urls': u});
    } else if (u.startsWith('turn:') || u.startsWith('turns:')) {
      servers.add({'urls': u, 'username': username, 'credential': password});
    }
  }
  if (servers.length > kMaxIceServer) {
    servers.removeRange(kMaxIceServer, servers.length);
  }
  return servers;
}
