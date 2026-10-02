// Google for Nonprofits, Microsoft for Nonprofits und Stifter-helfen MIT
// gespeicherten Zugangsdaten, Aufgaben und Notizen — auf Telefonbreiten, dem
// Tablet und dem Schreibtisch, auf Deutsch und Rumänisch, mit Roboto.
//
// bildschirme_telefon_test sieht diese Bildschirme nur leer. Eng wird es aber
// erst mit Daten: Website, E-Mail und Passwort mit Kopier-/Anzeige-Knöpfen in
// einer Zeile, Aufgaben mit Fälligkeit, „Überfällig“ und „Erledigt: …“,
// lange Notizen, die Bearbeitung und die Dialoge „Neue Aufgabe“/„Neue Notiz“
// (auch mit offener Bildschirmtastatur).
// Alle drei Bildschirme sind gleich gebaut und werden gleich geprüft.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:icd360sev_schatzmeister/l10n/app_localizations.dart';
import 'package:icd360sev_schatzmeister/services/api_service.dart';
import 'package:icd360sev_schatzmeister/services/device_key_service.dart';
import 'package:icd360sev_schatzmeister/services/language_service.dart';
import 'package:icd360sev_schatzmeister/screens/google_nonprofit_screen.dart';
import 'package:icd360sev_schatzmeister/screens/microsoft_nonprofit_screen.dart';
import 'package:icd360sev_schatzmeister/screens/stifter_helfen_screen.dart';

const Map<String, Size> kBreiten = {
  '320 dp': Size(320, 640),
  '360 dp': Size(360, 800),
  '384 dp': Size(384, 854),
  '393 dp (Redmi)': Size(393, 873),
  '412 dp': Size(412, 915),
  '600 dp (Grenze Telefon/Tablet)': Size(600, 960),
  '800 dp (Tablet)': Size(800, 1280),
  '1280 dp (Schreibtisch)': Size(1280, 800),
};

const kSprachen = ['de', 'ro'];

final String _schriften =
    '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
final bool _schriftenDa = File('$_schriften/Roboto-Regular.ttf').existsSync();

Future<void> _laden(String familie, List<String> dateien) async {
  final loader = FontLoader(familie);
  for (final d in dateien) {
    loader.addFont(Future.value(
        ByteData.sublistView(File('$_schriften/$d').readAsBytesSync())));
  }
  await loader.load();
}

Widget _rahmen(Widget kind, String sprache) => MaterialApp(
      locale: Locale(sprache),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('de'), Locale('ro')],
      home: Scaffold(body: SafeArea(child: kind)),
    );

// ── Gespeicherter Stand, wie ihn api/platform/*.php liefert ──────────────────

const kEmail = 'schatzmeisterin.foerderantraege@icd360s-ev.de';
const kPasswort = r'Gq7#vLm2!pX9$wRt4&Zk8@hN';
const kWebsite = 'https://www.google.com/intl/de/nonprofits/account/verification/';

/// Überfällig (Vergangenheit), offen (ferne Zukunft) und erledigt — die
/// Fälligkeit hängt an DateTime.now(), die Daten sind deshalb weit weg.
final kAufgaben = [
  {
    'id': 11,
    'titel': 'Freistellungsbescheid hochladen und Gemeinnützigkeitsnachweis bestätigen lassen',
    'beschreibung': 'Bescheid des Finanzamts Neu-Ulm (Steuernummer 151/123/45678) als PDF, '
        'dazu die aktuelle Satzung und der Vereinsregisterauszug VR 201234.',
    'faellig_am': '2025-09-15 10:00:00',
    'erledigt': false,
    'erledigt_am': null,
  },
  {
    'id': 12,
    'titel': 'Verlängerung der Nonprofit-Verifizierung (Prüfung durch TechSoup/Percent)',
    'beschreibung': null,
    'faellig_am': '2031-03-31 23:59:00',
    'erledigt': false,
    'erledigt_am': null,
  },
  {
    'id': 13,
    'titel': 'Zugänge für Vorsitzenden, Schatzmeisterin und Schriftführer einrichten',
    'beschreibung': 'Konten mit Zwei-Faktor-Anmeldung, Wiederherstellungscodes im Tresor.',
    'faellig_am': '2026-08-01 09:00:00',
    'erledigt': true,
    'erledigt_am': '2026-07-28 17:42:10',
  },
];

final kNotizen = [
  {
    'id': 21,
    'inhalt': 'Ansprechpartnerin bei der Verifizierung: Frau Dr. Müller-Lüdenscheidt, '
        'Rückruf zugesagt bis Freitag. Unterlagen liegen im Ordner „Gemeinnützigkeit 2026".',
    'created_at': '2026-09-28 16:45:12',
  },
  {
    'id': 22,
    'inhalt': 'Contul a fost verificat; următoarea reînnoire a verificării este programată '
        'pentru martie 2027. Documentele justificative sunt în arhivă.',
    'created_at': '2026-09-30 08:05:00',
  },
];

http.Client _server() => MockClient((anfrage) async {
      final pfad = anfrage.url.path;
      Object antwort;
      if (pfad.endsWith('/platform/get_credentials.php')) {
        antwort = {
          'success': true,
          'credentials': {'email': kEmail, 'password': kPasswort, 'website': kWebsite},
        };
      } else if (pfad.endsWith('/platform/aufgaben_list.php')) {
        antwort = {'success': true, 'aufgaben': kAufgaben};
      } else if (pfad.endsWith('/platform/notizen_list.php')) {
        antwort = {'success': true, 'notizen': kNotizen};
      } else {
        antwort = {'success': false, 'message': 'test'};
      }
      return http.Response(jsonEncode(antwort), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });

// ── Ablauf ───────────────────────────────────────────────────────────────────

/// Erst baut die Lokalisierung (lädt asynchron) den Bildschirm, dann kommen
/// die drei Serverantworten — gewartet wird auf den geladenen Inhalt, nicht
/// auf das Verschwinden der Ladeanzeige (die es anfangs noch gar nicht gibt).
Future<void> _bisGeladen(WidgetTester tester) async {
  for (var i = 0; i < 40 && find.text(kEmail).evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _tippe(WidgetTester tester, Finder ziel) async {
  await tester.ensureVisible(ziel);
  await tester.pump();
  await tester.tap(ziel);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Bildschirmtastatur (40 % der Höhe) auf und wieder zu — im Dialog wird
/// getippt, der Platz darüber ist dann knapp.
Future<void> _mitTastatur(WidgetTester tester, Size groesse, void Function() markiere) async {
  markiere();
  tester.view.viewInsets = FakeViewPadding(bottom: groesse.height * 0.4);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  tester.view.resetViewInsets();
  await tester.pump();
}

void pruefeMitDaten(String name, Widget Function(ApiService api) bauen) {
  group('$name mit Daten', () {
    for (final sprache in kSprachen) {
      for (final fall in kBreiten.entries) {
        testWidgets('läuft nicht über — ${fall.key} [$sprache]', (tester) async {
          tester.view.physicalSize = fall.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          await LanguageService.instance.setLanguage(sprache);

          final ueberlaeufe = <String>[];
          var zustand = 'Ansicht';
          final vorher = FlutterError.onError;
          FlutterError.onError = (details) {
            final text = details.toString();
            final m = RegExp(r'overflowed by ([0-9.]+) pixels on the (\w+)').firstMatch(text);
            if (m == null) {
              vorher?.call(details);
              return;
            }
            final ort = RegExp(r'lib/[\w/]+\.dart:\d+').firstMatch(text);
            ueberlaeufe.add('[$zustand] ${m.group(1)} px ${m.group(2)} @ ${ort?.group(0) ?? '?'}');
          };
          try {
            await tester.pumpWidget(_rahmen(bauen(ApiService()), sprache));
            await _bisGeladen(tester);
            // Sonst prüfte der Test still den leeren Zustand.
            expect(find.text(kEmail), findsOneWidget, reason: 'Zugangsdaten nicht geladen');
            expect(find.text(kAufgaben.first['titel'] as String), findsOneWidget);
            expect(find.text(kNotizen.first['inhalt'] as String), findsOneWidget);

            zustand = 'Passwort sichtbar';
            await _tippe(tester, find.byIcon(Icons.visibility));
            expect(find.text(kPasswort), findsOneWidget);

            zustand = 'Bearbeiten';
            await _tippe(tester, find.byIcon(Icons.settings));
            expect(find.byType(TextField), findsNWidgets(2));

            zustand = 'Dialog Neue Aufgabe';
            await _tippe(tester, find.byIcon(Icons.add_circle));
            expect(find.byType(AlertDialog), findsOneWidget);
            await _mitTastatur(tester, fall.value, () => zustand = 'Dialog Neue Aufgabe + Tastatur');
            await _tippe(tester, find.widgetWithText(TextButton, tr('Abbrechen', 'Anulare')));

            zustand = 'Dialog Neue Notiz';
            await _tippe(tester, find.byIcon(Icons.note_add));
            expect(find.byType(AlertDialog), findsOneWidget);
            await _mitTastatur(tester, fall.value, () => zustand = 'Dialog Neue Notiz + Tastatur');
            await _tippe(tester, find.widgetWithText(TextButton, tr('Abbrechen', 'Anulare')));

            zustand = 'Dialog Aufgabe löschen';
            await _tippe(tester, find.byIcon(Icons.delete_outline).first);
            expect(find.byType(AlertDialog), findsOneWidget);
            await _tippe(tester, find.widgetWithText(TextButton, tr('Abbrechen', 'Anulare')));
          } finally {
            FlutterError.onError = vorher;
          }
          await tester.pumpWidget(const SizedBox());

          expect(ueberlaeufe, isEmpty,
              reason: '$name auf ${fall.key} [$sprache]:\n${ueberlaeufe.toSet().join('\n')}');
        });
      }
    }
  }, skip: _schriftenDa ? false : 'Roboto fehlt unter $_schriften');
}

void main() {
  setUpAll(() async {
    if (!_schriftenDa) return;
    await _laden('Roboto', [
      'Roboto-Regular.ttf',
      'Roboto-Bold.ttf',
      'Roboto-Medium.ttf',
      'Roboto-Italic.ttf',
    ]);
    await _laden('MaterialIcons', ['MaterialIcons-Regular.otf']);
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // Ohne Geräteschlüssel wirft ApiService._headers, bevor der Server
    // gefragt wird — der Bildschirm bliebe leer.
    FlutterSecureStorage.setMockInitialValues({'device_key': 'TEST-GERAET', 'device_id': 'TEST-ID'});
    await DeviceKeyService().loadStoredDeviceKey();
    ApiService().testClient = _server();
  });

  pruefeMitDaten('Google Nonprofit', (api) => GoogleNonprofitScreen(apiService: api, onBack: () {}));
  pruefeMitDaten('Microsoft Nonprofit', (api) => MicrosoftNonprofitScreen(apiService: api, onBack: () {}));
  pruefeMitDaten('Stifter-helfen', (api) => StifterHelfenScreen(apiService: api, onBack: () {}));
}
