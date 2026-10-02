import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icd360sev_schatzmeister/services/chat_service.dart';
import 'package:icd360sev_schatzmeister/services/fernwartung_anfragen.dart';
import 'package:icd360sev_schatzmeister/services/language_service.dart';
import 'package:icd360sev_schatzmeister/services/notification_service.dart';
import 'package:icd360sev_schatzmeister/services/remote_agent_service.dart';
import 'package:icd360sev_schatzmeister/services/remote_input/input_injector_android.dart';
import 'package:icd360sev_schatzmeister/services/secure_screen.dart';
import 'package:icd360sev_schatzmeister/utils/ice_server_eintraege.dart';
import 'package:icd360sev_schatzmeister/widgets/fernsteuerung_zeile.dart';
import 'package:icd360sev_schatzmeister/widgets/remote_consent_dialog.dart';
import 'package:icd360sev_schatzmeister/widgets/remote_touch_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fernwartung in der Schatzmeister-App — die GETEILTE Seite, übernommen aus
/// der Mitglieder-App. Geprüft wird ohne Gerät: die Signalisierung gegen einen
/// WebSocket auf localhost, Dialoge und Leiste als Widgets, die Übersetzung
/// Maus → Geste gegen einen nachgebildeten Kanal, und Kotlin/Manifest im
/// Quelltext (die PR-Prüfung baut zwar ein APK, startet es aber nicht).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  RemoteOfferEvent angebot({int conv = 42, String name = 'Vorsitz'}) =>
      RemoteOfferEvent(
        conversationId: conv,
        controllerId: '2',
        controllerName: name,
        sdp: 'v=0',
        sdpType: 'offer',
      );

  // ─────────────────────────────────────────────────────────────────────────
  /// 🔴 Aus der Mitglieder-App (30.08.2026, gemessen im coturn-Log): der
  /// Vorsitz schickte Kandidaten, während der Zustimmungsdialog offen stand —
  /// `remoteIceStream` ist ein Broadcast-Stream, und ohne Vormerkung fielen
  /// alle ins Leere.
  group('ICE während des Zustimmungsdialogs geht nicht verloren', () {
    final agent = RemoteAgentService();
    tearDown(agent.vormerkungVerwerfen);

    RemoteIceEvent kandidat(int conv, int n) => RemoteIceEvent(
          conversationId: conv,
          candidate: 'candidate:$n 1 tcp 1 1.2.3.4 100$n typ relay',
          sdpMid: '0',
          sdpMLineIndex: 0,
        );

    test('vorgemerkte Kandidaten landen in der Warteschlange', () {
      agent.angebotVormerken(angebot());
      for (var n = 0; n < 3; n++) {
        agent.handleIce(kandidat(42, n));
      }
      expect(agent.vorgemerkteKandidaten, 3);
    });

    test('Kandidaten einer FREMDEN Unterhaltung werden nicht gesammelt', () {
      agent.angebotVormerken(angebot());
      agent.handleIce(kandidat(99, 0));
      expect(agent.vorgemerkteKandidaten, 0);
    });

    test('Ablehnen räumt die Vormerkung ab', () {
      agent.angebotVormerken(angebot());
      agent.handleIce(kandidat(42, 0));
      agent.vormerkungVerwerfen();
      expect(agent.vorgemerkteKandidaten, 0);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('Zustimmungsdialog', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      LanguageService.instance.resetForTest();
    });
    tearDown(() => LanguageService.instance.resetForTest());

    Future<({List<String> rufe})> zeigen(WidgetTester tester) async {
      final rufe = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: RemoteConsentDialog(
          controllerName: 'Vorsitz',
          onAccept: () => rufe.add('ja'),
          onDecline: () => rufe.add('nein'),
        ),
      ));
      return (rufe: rufe);
    }

    testWidgets('nennt den Vorsitz und sagt, dass es in anderen Apps weitergeht',
        (tester) async {
      await zeigen(tester);
      expect(find.textContaining('„Vorsitz" möchte Ihren Bildschirm sehen und steuern'),
          findsOneWidget);
      expect(find.textContaining('auch in anderen Apps weiter'), findsOneWidget);
      expect(find.text('Erlauben'), findsOneWidget);
      expect(find.text('Ablehnen (60)'), findsOneWidget);
    });

    testWidgets('auf Rumänisch, wenn Rumänisch gewählt ist', (tester) async {
      await LanguageService.instance.setLanguage('ro');
      await zeigen(tester);
      expect(find.textContaining('dorește să vă vadă și să vă controleze ecranul'),
          findsOneWidget);
      expect(find.text('Permite'), findsOneWidget);
      expect(find.text('Refuză (60)'), findsOneWidget);
    });

    testWidgets('nach 60 Sekunden ohne Antwort gilt: abgelehnt — genau einmal',
        (tester) async {
      final z = await zeigen(tester);
      await tester.pump(const Duration(seconds: 59));
      expect(z.rufe, isEmpty);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 5));
      expect(z.rufe, ['nein']);
    });

    testWidgets('Erlauben ruft genau einmal zu', (tester) async {
      final z = await zeigen(tester);
      await tester.tap(find.text('Erlauben'));
      await tester.tap(find.text('Erlauben'));
      await tester.pump(const Duration(seconds: 70));
      expect(z.rufe, ['ja']);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('Anfragen annehmen (FernwartungAnfragen)', () {
    final anfragen = FernwartungAnfragen.instance;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      LanguageService.instance.resetForTest();
      FernwartungAnfragen.istAndroidFuerTest = true;
      FernwartungAnfragen.imBlickFuerTest = true;
    });

    tearDown(() {
      FernwartungAnfragen.istAndroidFuerTest = null;
      FernwartungAnfragen.imBlickFuerTest = null;
      RemoteAgentService().vormerkungVerwerfen();
    });

    Future<void> app(WidgetTester tester) => tester.pumpWidget(MaterialApp(
          navigatorKey: NotificationService.navigatorKey,
          home: const Scaffold(body: Text('dashboard')),
        ));

    /// Offenen Dialog ablehnen und die 90-s-Vormerkung abräumen — sonst
    /// meldet der Test zu Recht eine noch laufende Uhr.
    Future<void> aufraeumen(WidgetTester tester) async {
      if (find.textContaining('Ablehnen').evaluate().isNotEmpty) {
        await tester.tap(find.textContaining('Ablehnen'));
      }
      RemoteAgentService().vormerkungVerwerfen();
      await tester.pumpAndSettle();
    }

    testWidgets('eine Anfrage öffnet den Dialog über der App', (tester) async {
      await app(tester);
      anfragen.anfrageErhalten(angebot(name: 'Vorsitz'));
      await tester.pump();
      expect(find.byType(RemoteConsentDialog), findsOneWidget);
      expect(anfragen.dialogOffen, isTrue);
      expect(find.textContaining('„Vorsitz"'), findsOneWidget);
      await aufraeumen(tester);
    });

    testWidgets('Ablehnen schließt den Dialog und verwirft die Vormerkung',
        (tester) async {
      await app(tester);
      anfragen.anfrageErhalten(angebot());
      await tester.pump();
      RemoteAgentService().handleIce(RemoteIceEvent(
        conversationId: 42,
        candidate: 'candidate:0 1 tcp 1 1.2.3.4 1 typ relay',
        sdpMid: '0',
        sdpMLineIndex: 0,
      ));
      expect(RemoteAgentService().vorgemerkteKandidaten, 1);

      await tester.tap(find.textContaining('Ablehnen'));
      await tester.pumpAndSettle();
      expect(find.byType(RemoteConsentDialog), findsNothing);
      expect(anfragen.dialogOffen, isFalse);
      expect(RemoteAgentService().vorgemerkteKandidaten, 0);
      expect(find.text('dashboard'), findsOneWidget,
          reason: 'nur der Dialog geht, nicht die Seite darunter');
    });

    testWidgets('eine neue Anfrage ersetzt die offene — nie zwei Dialoge',
        (tester) async {
      await app(tester);
      anfragen.anfrageErhalten(angebot(name: 'Erster'));
      await tester.pump();
      anfragen.anfrageErhalten(angebot(name: 'Zweiter'));
      await tester.pumpAndSettle();
      expect(find.byType(RemoteConsentDialog), findsOneWidget);
      expect(find.textContaining('„Zweiter"'), findsOneWidget);
      await aufraeumen(tester);
    });

    testWidgets('liegt etwas über dem Dialog, schließt die Absage nur den Dialog',
        (tester) async {
      await app(tester);
      anfragen.anfrageErhalten(angebot());
      await tester.pump();
      // Etwa der Update-Dialog legt sich darüber.
      NotificationService.navigatorKey.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('darueber')),
      ));
      await tester.pumpAndSettle();
      // Ablauf der Minute: der Dialog lehnt selbst ab.
      await tester.pump(const Duration(seconds: 61));
      await tester.pumpAndSettle();
      expect(find.text('darueber'), findsOneWidget,
          reason: 'pop() hätte die falsche Route geschlossen');
      expect(anfragen.dialogOffen, isFalse);
    });

    testWidgets('außerhalb von Android: kein Dialog', (tester) async {
      FernwartungAnfragen.istAndroidFuerTest = false;
      await app(tester);
      anfragen.anfrageErhalten(angebot());
      await tester.pump();
      expect(find.byType(RemoteConsentDialog), findsNothing);
    });

    testWidgets('zieht der Vorsitz zurück, verschwindet der Dialog', (tester) async {
      late HttpServer server;
      final verbindungen = <WebSocket>[];
      // Die Widget-Bindung ersetzt HttpClient durch eine Attrappe; für diesen
      // einen Test braucht es das echte Netz (localhost).
      await tester.runAsync(() => HttpOverrides.runWithHttpOverrides(() async {
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((anfrage) async {
          final ws = await WebSocketTransformer.upgrade(anfrage);
          verbindungen.add(ws);
          ws.listen((roh) {
            final data = jsonDecode(roh as String) as Map<String, dynamic>;
            if (data['type'] == 'auth') {
              ws.add(jsonEncode({'type': 'auth_success', 'user_id': 3}));
            }
          }, onError: (_) {}, cancelOnError: true);
        });
        ChatService.testWsUrl = 'ws://127.0.0.1:${server.port}/';
        await ChatService().connect('S00001');
      }, _EchtesNetz()));
      addTearDown(() async {
        ChatService().disconnect();
        ChatService.testWsUrl = null;
        await tester.runAsync(() => server.close(force: true));
      });

      await app(tester);
      anfragen.anfrageErhalten(angebot(conv: 34));
      await tester.pump();
      expect(find.byType(RemoteConsentDialog), findsOneWidget);

      await tester.runAsync(() async {
        verbindungen.single.add(jsonEncode({
          'type': 'remote_ended',
          'conversation_id': 34,
          'ended_by': 'Vorsitz',
        }));
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      expect(find.byType(RemoteConsentDialog), findsNothing,
          reason: 'ein späteres „Erlauben" teilte sonst mit niemandem');
      await aufraeumen(tester);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('Ausschalter in der Benachrichtigung', () {
    test('„Beenden" kommt in Dart an und ruft den Rückweg', () async {
      var gerufen = 0;
      await ScreenCaptureFgService.start(
        titel: 't',
        text: 'x',
        stopp: 's',
        beiStopp: () => gerufen++,
      );
      const codec = StandardMethodCodec();
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'de.icd360sev.schatzmeister/screen_capture',
        codec.encodeMethodCall(const MethodCall('stoppGetippt')),
        (_) {},
      );
      expect(gerufen, 1);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  /// Ein laufender Ticker fordert bei jedem vsync ein Bild an — die App
  /// zeichnete dann dauernd. Ohne Sitzung muss die Anzeige ruhen.
  testWidgets('ohne Sitzung ruht die Berührungsanzeige', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: RemoteTouchOverlay(child: Scaffold(body: Text('inhalt'))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('inhalt'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('Profil: Steuerung erlauben', () {
    const kanal = MethodChannel('de.icd360sev.schatzmeister/fernsteuerung');
    late bool dienstLaeuft;
    late int geoeffnet;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      LanguageService.instance.resetForTest();
      dienstLaeuft = false;
      geoeffnet = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(kanal, (ruf) async {
        if (ruf.method == 'verfuegbar') return dienstLaeuft;
        if (ruf.method == 'einstellungenOeffnen') {
          geoeffnet++;
          return true;
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(kanal, null);
    });

    Future<void> zeile(WidgetTester tester, {bool android = true}) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: FernsteuerungZeile(istAndroid: android)),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('aus: der Schalter öffnet die Bedienungshilfen', (tester) async {
      await zeile(tester);
      expect(find.text('Steuerung erlauben'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('fernsteuerung_schalter')));
      await tester.pumpAndSettle();
      expect(geoeffnet, 1, reason: 'eine App kann sich den Dienst nicht selbst erteilen');
    });

    testWidgets('nach der Rückkehr steht der echte Zustand da', (tester) async {
      await zeile(tester);
      dienstLaeuft = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Steuerung ist eingeschaltet'), findsOneWidget);
    });

    testWidgets('nicht auf Android: keine Zeile', (tester) async {
      await zeile(tester, android: false);
      expect(find.byType(Switch), findsNothing);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('ICE-Server: ein Eintrag je URI', () {
    const uris = [
      'stun:turn.icd360s.de:3478',
      'turn:turn.icd360s.de:3478?transport=tcp',
      'turns:turn.icd360s.de:5349?transport=tcp',
    ];

    test('jede URI bekommt einen eigenen Eintrag, `urls` immer ein String', () {
      final e = iceServerEintraege(uris, 'u', 'p');
      expect(e.length, 3);
      for (final s in e) {
        expect(s['urls'], isA<String>());
      }
    });

    test('Zugangsdaten nur an den TURN-Einträgen', () {
      final e = iceServerEintraege(uris, 'u', 'p');
      expect(e.first.containsKey('username'), isFalse);
      expect(e.last['username'], 'u');
      expect(e.last['credential'], 'p');
    });

    test('höchstens acht Einträge', () {
      final viele = [for (var n = 0; n < 20; n++) 'turn:h$n.example:3478'];
      expect(iceServerEintraege(viele, 'u', 'p').length, kMaxIceServer);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('Bildgüte', () {
    test('Voreinstellung ist die Automatik, unbekannte Namen fallen darauf', () {
      expect(Bildguete.alle.first, Bildguete.automatik);
      expect(Bildguete.vonName('gibt-es-nicht'), Bildguete.automatik);
      expect(Bildguete.vonName('scharf'), Bildguete.scharf);
    });

    test('keine Stufe verkleinert — auf einem Telefon wird gelesen', () {
      for (final g in Bildguete.alle) {
        expect(g.verkleinern, 1.0, reason: g.name);
      }
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('Android: Maus wird zu Gesten', () {
    const kanal = MethodChannel('de.icd360sev.schatzmeister/fernsteuerung');
    late List<MethodCall> rufe;
    late bool dienstLaeuft;

    setUp(() {
      rufe = [];
      dienstLaeuft = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(kanal, (ruf) async {
        rufe.add(ruf);
        if (ruf.method == 'verfuegbar') return dienstLaeuft;
        return true;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(kanal, null);
    });

    Future<AndroidInputInjector> bereit() async {
      final i = AndroidInputInjector();
      await i.vorbereiten();
      rufe.clear();
      return i;
    }

    List<MethodCall> zuege() => rufe.where((r) => r.method == 'zug').toList();

    test('kurz gedrückt am selben Punkt ergibt einen Tipp', () async {
      final i = await bereit();
      await i.mouseMove(0.4, 0.6);
      await i.mouseButton(0, true);
      await i.mouseButton(0, false);
      final a = zuege().single.arguments as Map;
      expect(a['x1'], closeTo(0.4, 1e-9));
      expect(a['x2'], closeTo(0.4, 1e-9));
      expect(a['ms'] as int, lessThan(500));
    });

    test('gedrückt ziehen ergibt ein Wischen von A nach B', () async {
      final i = await bereit();
      await i.mouseMove(0.1, 0.8);
      await i.mouseButton(0, true);
      await i.mouseMove(0.1, 0.2);
      await i.mouseButton(0, false);
      final a = zuege().single.arguments as Map;
      expect(a['y1'], closeTo(0.8, 1e-9));
      expect(a['y2'], closeTo(0.2, 1e-9));
    });

    test('Rad nach unten wischt nach oben', () async {
      final i = await bereit();
      await i.mouseMove(0.5, 0.5);
      await i.mouseWheel(0, 120);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final a = zuege().single.arguments as Map;
      expect(a['y2'] as double, lessThan(a['y1'] as double));
    });

    test('ohne eingeschalteten Dienst geht keine Geste hinaus', () async {
      dienstLaeuft = false;
      final i = AndroidInputInjector();
      await i.vorbereiten();
      rufe.clear();
      await i.mouseMove(0.5, 0.5);
      await i.mouseButton(0, true);
      await i.mouseButton(0, false);
      await i.systemAktion('home');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(rufe, isEmpty);
    });

    test('das Sitzungsende sperrt die Steuerung wieder zu', () async {
      final i = await bereit();
      i.dispose();
      await Future<void>.delayed(Duration.zero);
      final frei = rufe.where((r) => r.method == 'freigeben').toList();
      expect(frei.single.arguments['frei'], isFalse);
    });

    test('Escape wird zu Zurück, andere Tasten fallen weg', () async {
      final i = await bereit();
      await i.keyEvent(hid: 0x29, character: null, down: true);
      await i.keyEvent(hid: 0x04, character: 'a', down: true);
      final aktionen = rufe.where((r) => r.method == 'aktion').toList();
      expect(aktionen.single.arguments['name'], 'back');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  /// Was ein Test ohne Gerät nicht ausführen kann, wird im Quelltext belegt.
  group('Quelltext', () {
    String lies(String pfad) => File(pfad).readAsStringSync();
    final agent = lies('lib/services/remote_agent_service.dart');

    /// Die Schatzmeister-App ist getrennt — eigene Kanäle, eigenes API.
    test('nirgends die Kanalnamen der Mitglieder-App', () {
      for (final d in [
        ...Directory('lib').listSync(recursive: true),
        ...Directory('android/app/src/main/kotlin').listSync(recursive: true),
      ].whereType<File>()) {
        expect(d.readAsStringSync().contains('de.icd360sev.mitglied/'), isFalse,
            reason: d.path);
      }
    });

    test('TURN aus /api/schatzmeister/, nicht aus dem gemeinsamen /auth/', () {
      expect(agent, contains("'/schatzmeister/fernwartung_turn.php'"));
      for (final pfad in [
        'lib/services/remote_agent_service.dart',
        'lib/services/fernwartung_anfragen.dart',
        'lib/services/secure_screen.dart',
      ]) {
        final q = lies(pfad);
        expect(q.contains("'/auth/turn_credentials.php'"), isFalse, reason: pfad);
        expect(RegExp(r"""['"]/admin/""").hasMatch(q), isFalse, reason: pfad);
        expect(RegExp(r"""['"]/member/""").hasMatch(q), isFalse, reason: pfad);
      }
    });

    /// Eine Sitzung beginnt ausschließlich beim Vorsitz. (Dieselbe Regel wie
    /// in der Mitglieder-App — auch in Kommentaren.)
    test('diese Seite bietet nie an', () {
      expect(agent.contains('createOffer'), isFalse);
      expect(lies('lib/services/chat_service.dart').contains("'remote_offer',\n      'conversation_id'"),
          isFalse);
    });

    test('Reihenfolge: Zustimmung → Mikrofon → Vordergrunddienst → Aufnahme', () {
      final a = agent.indexOf('await _bildschirmFreigabeHolen();');
      final b = agent.indexOf('_mikroStream = await _mikrofonHolen();');
      final c = agent.indexOf('await ScreenCaptureFgService.start(');
      final d = agent.indexOf('_screenStream = await _captureScreen();');
      expect([a, b, c, d].every((i) => i > 0), isTrue);
      expect(a < b && b < c && c < d, isTrue,
          reason: 'ab Android 14 braucht der Typ microphone die Erlaubnis VOR dem Dienst');
    });

    test('die Bildgüte wird VOR der Steuerungsprüfung behandelt', () {
      final q = agent.indexOf("if (m['t'] == 'q')");
      final pruef = agent.indexOf('if (injector == null || !injector.isSupported) return;');
      expect(q > 0 && pruef > q, isTrue);
    });

    test('MainActivity setzt FLAG_SECURE nicht mitten in einer Sitzung', () {
      final kt = lies('android/app/src/main/kotlin/de/icd360sev/schatzmeister/MainActivity.kt');
      final oncreate = kt.substring(kt.indexOf('override fun onCreate'));
      final waechter = oncreate.indexOf('if (!fernwartungLaeuft)');
      // ⚠️ Erst auf Vorhandensein prüfen: ein fehlender Wächter liefert -1,
      // und -1 liegt immer „vor" FLAG_SECURE.
      expect(waechter, greaterThan(0));
      expect(waechter, lessThan(oncreate.indexOf('FLAG_SECURE')));
    });

    test('der Dienst nimmt microphone nur mit erteilter Mikrofon-Erlaubnis', () {
      final kt = lies('android/app/src/main/kotlin/de/icd360sev/schatzmeister/ScreenCaptureService.kt');
      expect(kt, contains('Manifest.permission.RECORD_AUDIO'));
      expect(kt, contains('AKTION_BEENDEN'),
          reason: 'Beenden muss auch aus einer fremden App heraus gehen');
      expect(kt, contains('setContentIntent'));
    });

    test('Manifest: beide Dienste, Rechte und Typen', () {
      final m = lies('android/app/src/main/AndroidManifest.xml');
      expect(m, contains('android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION'));
      expect(m, contains('android.permission.FOREGROUND_SERVICE_MICROPHONE'));
      expect(m, contains('android:name=".ScreenCaptureService"'));
      expect(m, contains('android:foregroundServiceType="mediaProjection|microphone"'));
      final dienst = m.substring(m.indexOf('android:name=".FernwartungService"'));
      expect(dienst, contains('android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE"'));
      expect(dienst, contains('@xml/fernwartung_accessibility'));
    });

    /// Der wichtigste Satz der ganzen Funktion: der Dienst sieht nichts.
    test('Bedienungshilfe: Gesten ja, Bildschirminhalt nein', () {
      final x = lies('android/app/src/main/res/xml/fernwartung_accessibility.xml');
      expect(x, contains('android:canRetrieveWindowContent="false"'));
      expect(x, contains('android:canPerformGestures="true"'));
      expect(x.contains('android:packageNames'), isFalse,
          reason: 'geholfen wird gerade in anderen Apps');
    });

    test('eigener Name in den Bedienungshilfen, auf Deutsch und Rumänisch', () {
      final de = lies('android/app/src/main/res/values/strings.xml');
      final ro = lies('android/app/src/main/res/values-ro/strings.xml');
      expect(de, contains('ICD360S Schatzmeister – Fernwartung (Steuerung)'));
      expect(ro, contains('ICD360S Trezorier – asistență la distanță (control)'));
      expect(de.contains('>ICD360S Fernwartung (Steuerung)<'), isFalse,
          reason: 'das ist der Name der Mitglieder-App');
    });

    test('verdrahtet: Dashboard hört zu, Leiste und Anzeige hängen', () {
      final dash = lies('lib/screens/dashboard_screen.dart');
      expect(dash, contains('FernwartungAnfragen.instance.starten();'));
      expect(dash, contains('FernwartungAnfragen.instance.stoppen();'));
      expect(dash, contains('const RemoteSharingBanner()'));
      expect(lies('lib/main.dart'), contains('RemoteTouchOverlay(child:'));
      expect(lies('lib/widgets/profile_dialog.dart'), contains('const FernsteuerungZeile()'));
    });
  });
}

/// Die eingebaute Umsetzung von HttpOverrides — also echte Verbindungen.
class _EchtesNetz extends HttpOverrides {}
