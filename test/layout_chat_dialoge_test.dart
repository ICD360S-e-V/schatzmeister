// Passen die Chat-Dialoge auf jedes Telefon — mit echten Gesprächen, auf
// Deutsch und auf Rumänisch?
//
//  * Live-Chat (aus dem Dashboard): Kopfzeile mit Anruf-, Video- und
//    Schließen-Knopf, Nachrichten mit Anhängen, Reaktionen, Links.
//  * Admin-Chat: Gesprächsliste + Gespräch. Auf dem Schreibtisch
//    nebeneinander, auf dem Telefon zwei Seiten nacheinander.
//  * Eingehender Anruf, laufender Anruf, ausgehender Anruf.
//
// Die Daten kommen über ApiService.testClient; der WebSocket scheitert über
// den falschen Server aus layout_teil8_hilfen.dart wie ohne Netz.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:icd360sev_schatzmeister/l10n/app_localizations.dart';
import 'package:icd360sev_schatzmeister/services/api_service.dart';
import 'package:icd360sev_schatzmeister/services/chat_service.dart';
import 'package:icd360sev_schatzmeister/services/language_service.dart';
import 'package:icd360sev_schatzmeister/widgets/admin_chat_dialog.dart';
import 'package:icd360sev_schatzmeister/widgets/chat_message_bubble.dart';
import 'package:icd360sev_schatzmeister/widgets/conversation_list_item.dart';
import 'package:icd360sev_schatzmeister/widgets/incoming_call_dialog.dart';
import 'package:icd360sev_schatzmeister/widgets/live_chat_dialog.dart';

import 'layout_teil8_hilfen.dart';

const _knopf = 'Öffnen';
const _langerName = 'Alexandru-Constantin Popescu-Ionescu (Vorsitzender)';

Widget _gastgeber(Widget Function() dialog) => Scaffold(
      body: Builder(
        builder: (ctx) => Center(
          child: ElevatedButton(
            onPressed: () => showDialog(
              context: ctx,
              barrierDismissible: false,
              builder: (_) => dialog(),
            ),
            child: const Text(_knopf),
          ),
        ),
      ),
    );

Future<void> _warten(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _tippen(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await _warten(tester);
}

/// Öffnet [dialog] auf [groesse] in [sprache], führt [schritte] aus und
/// verlangt: kein Überlauf, keine sonstige Ausnahme.
Future<void> _pruefe(
  WidgetTester tester,
  Size groesse,
  String sprache,
  Widget Function() dialog,
  Future<void> Function(AppLocalizations l, bool telefon) schritte, {
  Widget? seite,
}) async {
  tester.view.physicalSize = groesse;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await LanguageService.instance.setLanguage(sprache);

  final f = UeberlaufFaenger()..an();
  Object? fehler;
  try {
    await tester.pumpWidget(rahmenApp(seite ?? _gastgeber(dialog), sprache));
    await tester.pump();
    if (seite == null) {
      await tester.tap(find.text(_knopf));
      await _warten(tester);
    } else {
      await _warten(tester);
    }
    final l = AppLocalizations.of(tester.element(find.byType(Scaffold).first));
    await schritte(l, groesse.width < 600);
  } finally {
    f.aus();
    fehler = tester.takeException();
    await tester.pumpWidget(const SizedBox());
    ChatService().disconnect();
    await tester.pump(const Duration(minutes: 10));
  }
  expect(f.ueberlaeufe, isEmpty,
      reason: '${groesse.width} dp [$sprache]:\n${f.ueberlaeufe.toSet().join('\n')}');
  expect(fehler, isNull);
}

void main() {
  setUpAll(() async {
    await schriftenLaden();
    await geraetAktivieren();
    HttpOverrides.global = FalscherServer(teil8Antworten);
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Teil8Daten.zuruecksetzen();
    ApiService().testClient = mockClient(teil8Antworten);
    ChatService.testWsUrl = 'ws://ws.test/';
  });

  for (final sprache in kSprachenTeil8) {
    for (final fall in kBreitenTeil8.entries) {
      group('${fall.key} [$sprache]', () {
        testWidgets('Live-Chat mit Gegenüber und Nachrichten', (tester) async {
          await _pruefe(
            tester,
            fall.value,
            sprache,
            () => const LiveChatDialog(
              mitgliedernummer: kIch,
              userName: kIchName,
              conversationId: 11,
              gegenueber: _langerName,
            ),
            (l, telefon) async {
              expect(find.byType(LiveChatDialog), findsOneWidget);
              await bisSichtbar(tester, find.textContaining('Kontoauszüge'));
              // Ans Ende der Liste: dort hängen Anhänge und Reaktionen.
              await tester.drag(find.byType(ListView).last, const Offset(0, -2000));
              await _warten(tester);
            },
          );
        });

        testWidgets('Live-Chat mit Support-Leiste (Fehlerzweig)', (tester) async {
          Teil8Daten.startChatKaputt = true;
          await _pruefe(
            tester,
            fall.value,
            sprache,
            () => const LiveChatDialog(mitgliedernummer: kIch, userName: kIchName),
            (l, telefon) async {
              await bisSichtbar(tester, find.text('1048ms'));
            },
          );
        });

        testWidgets('Admin-Chat: Liste, Gespräch und seine Dialoge', (tester) async {
          await _pruefe(
            tester,
            fall.value,
            sprache,
            () => const AdminChatDialog(mitgliedernummer: 'V00001', userName: _langerName),
            (l, telefon) async {
              await bisSichtbar(tester, find.byType(ConversationListItem));
              expect(find.byType(ConversationListItem), findsNWidgets(3));
              // Neues Gespräch, Statusnachricht, automatische Nachrichten.
              for (final symbol in [Icons.add_comment, Icons.campaign, Icons.edit_calendar]) {
                await _tippen(tester, find.byIcon(symbol).first);
                expect(find.byType(AlertDialog), findsOneWidget, reason: '$symbol');
                if (symbol == Icons.add_comment) {
                  // Eingespeist: vier Mitglieder zur Auswahl.
                  await bisSichtbar(tester, find.textContaining('Constantinescu-Georgescu'));
                }
                if (symbol == Icons.edit_calendar) {
                  await bisSichtbar(tester, find.text('Poftă bună la prânz!'));
                  final imDialog = find.byType(AlertDialog);
                  // Neue und bearbeitete automatische Nachricht: jeweils
                  // öffnen, prüfen, abbrechen — danach kommt die Liste zurück.
                  await _tippen(tester,
                      find.descendant(of: imDialog, matching: find.byIcon(Icons.add_circle)));
                  expect(find.text(l.newAutomaticMessage), findsOneWidget);
                  await tester.tap(find.text(l.cancel).last);
                  await _warten(tester);
                  await bisSichtbar(tester, find.text('Poftă bună la prânz!'));
                  await _tippen(tester,
                      find.descendant(of: find.byType(AlertDialog), matching: find.byIcon(Icons.edit)).first);
                  expect(find.text(l.editMessage), findsOneWidget);
                  await tester.tap(find.text(l.cancel).last);
                  await _warten(tester);
                  await bisSichtbar(tester, find.text('Poftă bună la prânz!'));
                }
                await tester.tap(find.text(symbol == Icons.edit_calendar ? l.close : l.cancel).last);
                await _warten(tester);
              }
              // Ein Gespräch öffnen: seine eingespeisten Nachrichten stehen da
              // (die Liste springt ans Ende, darum nach Blasen gefragt).
              await _tippen(tester, find.byType(ConversationListItem).first);
              await bisSichtbar(tester, find.byType(ChatMessageBubble));
              expect(find.text('Kontoauszug_Sparkasse_Neu-Ulm_Q3_2026_Vereinskonto.pdf'),
                  findsOneWidget);
              await tester.drag(find.byType(ListView).last, const Offset(0, -2000));
              await _warten(tester);
              // Seine automatischen Nachrichten.
              await _tippen(tester, find.byIcon(Icons.schedule_send).first);
              expect(find.byType(AlertDialog), findsOneWidget);
              await tester.tap(find.text(l.close).last);
              await _warten(tester);
              if (telefon) {
                // Zurück zur Liste — auf dem Telefon eine eigene Seite.
                await _tippen(tester, find.byIcon(Icons.arrow_back));
                expect(find.byType(ConversationListItem), findsNWidgets(3));
              }
            },
          );
        });

        testWidgets('Eingehender Anruf', (tester) async {
          await _pruefe(
            tester,
            fall.value,
            sprache,
            () => IncomingCallDialog(
              callerName: _langerName,
              onAccept: () {},
              onReject: () {},
            ),
            (l, telefon) async {
              expect(find.text(_langerName), findsOneWidget);
              await tester.pump(const Duration(seconds: 2));
            },
          );
        });

        testWidgets('Laufender und ausgehender Anruf', (tester) async {
          await _pruefe(
            tester,
            fall.value,
            sprache,
            () => const SizedBox(),
            (l, telefon) async {
              expect(find.byType(InCallOverlay), findsOneWidget);
              await tester.pump(const Duration(seconds: 1));
            },
            // So breit wie der Inhalt des Live-Chats auf dem Telefon.
            seite: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    InCallOverlay(
                      remoteName: _langerName,
                      callDuration: const Duration(hours: 1, minutes: 2, seconds: 3),
                      isMuted: false,
                      isSpeakerOn: true,
                      onToggleMute: () {},
                      onToggleSpeaker: () {},
                      onEndCall: () {},
                      iceConnectionState:
                          RTCIceConnectionState.RTCIceConnectionStateConnected,
                    ),
                    const SizedBox(height: 8),
                    CallingOverlay(targetName: _langerName, onCancel: () {}),
                  ],
                ),
              ),
            ),
          );
        });
      });
    }
  }
}
