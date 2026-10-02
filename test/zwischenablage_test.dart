import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icd360sev_schatzmeister/services/language_service.dart';
import 'package:icd360sev_schatzmeister/utils/sicher_clipboard.dart';
import 'package:icd360sev_schatzmeister/utils/sicher_clipboard_bindung.dart';
import 'package:icd360sev_schatzmeister/utils/zwischenablage_hinweis.dart';

/// Jede Kopie der App — Kopier-Knopf, „Kopieren" im Kontextmenü, WebView —
/// ist nach 30 s gelöscht, auf Android sensibel markiert, und die App sagt es
/// (wie in der Vorsitzer-App, #1045).
///
/// Der native Teil (Zwischenablage.kt) lässt sich hier nicht erleben. Geprüft
/// werden der Bote als Funktion, der Hinweis als Widget und die
/// **Kopplungen** am Quelltext — die brechen lautlos.

/// Die Plattform im Test: schreibt auf, was ankommt, und antwortet.
class _Plattform extends BinaryMessenger {
  final gesendet = <(String, ByteData?)>[];

  @override
  Future<void> handlePlatformMessage(
    String channel,
    ByteData? data,
    ui.PlatformMessageResponseCallback? callback,
  ) async {}

  @override
  Future<ByteData?>? send(String channel, ByteData? message) {
    gesendet.add((channel, message));
    return Future.value(
        const JSONMethodCodec().encodeSuccessEnvelope('von der Plattform'));
  }

  @override
  void setMessageHandler(String channel, MessageHandler? handler) {}
}

ByteData _setData(String? text) => const JSONMethodCodec()
    .encodeMethodCall(MethodCall('Clipboard.setData', {'text': text}));

String ohneKommentare(String s) {
  s = s.replaceAllMapped(
    RegExp(r'/\*.*?\*/', dotAll: true),
    (m) => '\n' * '\n'.allMatches(m[0]!).length,
  );
  return s.replaceAllMapped(RegExp(r'//[^\n]*'), (m) => ' ' * m[0]!.length);
}

String quelle(String pfad) =>
    ohneKommentare(File(pfad).readAsStringSync().replaceAll('\r\n', '\n'));

const _kt = 'android/app/src/main/kotlin/de/icd360sev/schatzmeister';

/// Der Rumpf ab [kopf] bis zur passenden schließenden Klammer.
String rumpf(String q, String kopf) {
  final i = q.indexOf(kopf);
  expect(i, greaterThanOrEqualTo(0), reason: '„$kopf" fehlt');
  final auf = q.indexOf('{', i + kopf.length - 1);
  var tiefe = 0;
  for (var j = auf; j < q.length; j++) {
    if (q[j] == '{') tiefe++;
    if (q[j] == '}' && --tiefe == 0) return q.substring(auf + 1, j);
  }
  fail('„$kopf" endet nicht');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('kopierterText', () {
    test('liest den Text aus Clipboard.setData', () {
      expect(kopierterText(_setData('DE12 3456')), 'DE12 3456');
      expect(kopierterText(_setData('')), '');
    });

    test('alles andere ist null', () {
      expect(kopierterText(null), isNull);
      expect(kopierterText(_setData(null)), isNull);
      expect(
          kopierterText(const JSONMethodCodec().encodeMethodCall(
              const MethodCall('Clipboard.getData', 'text/plain'))),
          isNull);
      expect(
          kopierterText(const JSONMethodCodec().encodeMethodCall(
              const MethodCall('SystemChrome.setApplicationSwitcherDescription',
                  {'label': 'Clipboard.setData'}))),
          isNull);
      expect(kopierterText(ByteData.sublistView(Uint8List.fromList([1, 2, 3]))),
          isNull);
    });
  });

  group('SicherClipboardBote auf Android', () {
    late _Plattform plattform;
    late List<String> kopiert;
    late int geplant;

    setUp(() {
      plattform = _Plattform();
      kopiert = [];
      geplant = 0;
    });

    SicherClipboardBote bote(bool nativOk) => SicherClipboardBote(
          plattform,
          mitKanal: true,
          kopieren: (t) async {
            kopiert.add(t);
            return nativOk;
          },
          spaeterLeeren: () => geplant++,
        );

    MethodChannel plattformKanal(SicherClipboardBote b) =>
        MethodChannel('flutter/platform', const JSONMethodCodec(), b);

    test('Clipboard.setData geht an den nativen Weg, nicht an die Plattform',
        () async {
      final antwort = await plattformKanal(bote(true))
          .invokeMethod<Object?>('Clipboard.setData', {'text': 'IBAN DE12'});
      expect(kopiert, ['IBAN DE12']);
      expect(plattform.gesendet, isEmpty);
      expect(geplant, 0, reason: 'der Zeitgeber lebt dann in Kotlin');
      expect(antwort, isNull, reason: 'wie Flutter selbst: Erfolg ohne Wert');
    });

    test('fehlt der Kanal: dieselbe Nachricht an die Plattform, Dart leert',
        () async {
      final antwort = await plattformKanal(bote(false))
          .invokeMethod<Object?>('Clipboard.setData', {'text': 'x'});
      expect(kopiert, ['x']);
      expect(plattform.gesendet, hasLength(1));
      expect(kopierterText(plattform.gesendet.single.$2), 'x');
      expect(geplant, 1);
      expect(antwort, 'von der Plattform');
    });

    test('alles andere geht unverändert durch', () async {
      final b = bote(true);
      await plattformKanal(b).invokeMethod<Object?>('Clipboard.getData');
      final fremd = _setData('nicht abfangen');
      await b.send('de.icd360sev.schatzmeister/irgendwas', fremd);
      expect(kopiert, isEmpty);
      expect(plattform.gesendet.map((e) => e.$1),
          ['flutter/platform', 'de.icd360sev.schatzmeister/irgendwas']);
      expect(identical(plattform.gesendet.last.$2, fremd), isTrue);
    });

    test('🔴 der native Weg startet im selben Takt — die Reihenfolge bleibt',
        () {
      final b = SicherClipboardBote(plattform, mitKanal: true, kopieren: (t) {
        kopiert.add(t);
        return Completer<bool>().future;
      });
      b.send('flutter/platform', _setData('a'));
      expect(kopiert, ['a']);
    });
  });

  group('SicherClipboardBote ohne Kanal (Windows, Linux, macOS, iOS)', () {
    test('🔴 Flutter kopiert im selben Takt, und Dart leert nach 30 s', () {
      final plattform = _Plattform();
      var geplant = 0;
      var nativ = 0;
      final b = SicherClipboardBote(plattform,
          mitKanal: false,
          kopieren: (_) async {
            nativ++;
            return true;
          },
          spaeterLeeren: () => geplant++);
      final nachricht = _setData('Passwort');
      b.send('flutter/platform', nachricht);
      expect(identical(plattform.gesendet.single.$2, nachricht), isTrue,
          reason: 'sofort und unverändert — nicht erst nach einem await');
      expect(geplant, 1);
      expect(nativ, 0);
    });

    test('Leeren (leerer Text) plant nichts — sonst leerte es sich ewig', () {
      final plattform = _Plattform();
      var geplant = 0;
      final b = SicherClipboardBote(plattform,
          mitKanal: false, spaeterLeeren: () => geplant++);
      b.send('flutter/platform', _setData(''));
      expect(plattform.gesendet, hasLength(1));
      expect(geplant, 0);
    });
  });

  testWidgets(
      '🔴 „Kopieren" im Kontextmenü eines Textfelds kommt als Clipboard.setData '
      'auf flutter/platform an — genau das fängt der Bote ab', (t) async {
    final roh = <ByteData?>[];
    t.binding.defaultBinaryMessenger.setMockMessageHandler('flutter/platform',
        (m) async {
      if (kopierterText(m) != null) roh.add(m);
      return const JSONMethodCodec().encodeSuccessEnvelope(null);
    });
    addTearDown(() => t.binding.defaultBinaryMessenger
        .setMockMessageHandler('flutter/platform', null));
    final c = TextEditingController(text: 'Kennwort 123');
    addTearDown(c.dispose);
    await t.pumpWidget(
        MaterialApp(home: Scaffold(body: TextField(controller: c))));
    c.selection = const TextSelection(baseOffset: 0, extentOffset: 12);
    t.state<EditableTextState>(find.byType(EditableText))
        .copySelection(SelectionChangedCause.toolbar);
    await t.pump();
    expect(roh.map(kopierterText), ['Kennwort 123']);
  });

  test('SicherClipboardBindung lässt ein stehendes Binding stehen', () {
    expect(SicherClipboardBindung.ensureInitialized(),
        same(TestWidgetsFlutterBinding.instance));
  });

  group('Hinweis „Zwischenablage gelöscht"', () {
    tearDown(() => LanguageService.instance.resetForTest());

    Future<void> zeige(WidgetTester t) async {
      final navigator = GlobalKey<NavigatorState>();
      zwischenablageHinweisAnmelden(navigator);
      await t.pumpWidget(MaterialApp(
        navigatorKey: navigator,
        home: const Scaffold(body: SizedBox()),
      ));
    }

    Future<void> android(WidgetTester t, DateTime zeit,
            {required bool spaet}) =>
        t.binding.defaultBinaryMessenger.handlePlatformMessage(
          SicherClipboard.kanal.name,
          const StandardMethodCodec().encodeMethodCall(MethodCall('geloescht',
              {'zeit': zeit.millisecondsSinceEpoch, 'spaet': spaet})),
          (_) {},
        );

    testWidgets('Android meldet „gelöscht" → SnackBar', (t) async {
      await zeige(t);
      await android(t, DateTime(2026, 10, 2, 14, 32, 5), spaet: false);
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Zwischenablage gelöscht'), findsOneWidget);
      expect(find.byIcon(Icons.content_paste_off), findsOneWidget);
      await t.pump(const Duration(seconds: 4));
      await t.pumpAndSettle();
      expect(find.text('Zwischenablage gelöscht'), findsNothing,
          reason: 'nach 3 s wieder weg');
    });

    testWidgets('gelöscht, während die App im Hintergrund war → mit Uhrzeit',
        (t) async {
      await zeige(t);
      await android(t, DateTime(2026, 10, 2, 14, 32, 5), spaet: true);
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Zwischenablage um 14:32:05 gelöscht'), findsOneWidget);
    });

    test('Deutsch und Rumänisch', () {
      final zeit = DateTime(2026, 1, 2, 3, 4, 5);
      expect(geloeschtText(zeit, spaet: false), 'Zwischenablage gelöscht');
      expect(geloeschtText(zeit, spaet: true),
          'Zwischenablage um 03:04:05 gelöscht');
      LanguageService.instance.localeNotifier.value = const Locale('ro');
      expect(geloeschtText(zeit, spaet: false), 'Clipboard golit');
      expect(geloeschtText(zeit, spaet: true), 'Clipboard golit la 03:04:05');
    });
  });

  group('Kopplungen am Quelltext', () {
    test('🔴 main legt ALS ERSTES SicherClipboardBindung an', () {
      final q = quelle('lib/main.dart');
      expect(rumpf(q, 'void main(List<String> args) async {').trimLeft(),
          startsWith('SicherClipboardBindung.ensureInitialized();'));
      expect(q, isNot(contains('WidgetsFlutterBinding.ensureInitialized()')));
    });

    test('🔴 main meldet den Hinweis an — am Navigator der App', () {
      final q = quelle('lib/main.dart');
      final m = rumpf(q, 'void main(List<String> args) async {');
      final hinweis =
          m.indexOf('zwischenablageHinweisAnmelden(NotificationService.navigatorKey);');
      expect(hinweis, greaterThanOrEqualTo(0));
      expect(m.indexOf('runApp('), greaterThan(hinweis));
      expect(q, contains('navigatorKey: NotificationService.navigatorKey'));
    });

    test('🔴 MainActivity bindet die Zwischenablage an ihre Engine', () {
      final konfig = rumpf(quelle('$_kt/MainActivity.kt'),
          'override fun configureFlutterEngine(flutterEngine: FlutterEngine) {');
      expect(konfig, contains('Zwischenablage.anbinden(this, flutterEngine)'));
    });

    test('🔴 kein Kotlin außer Zwischenablage.kt legt etwas in die Ablage', () {
      for (final f in Directory(_kt).listSync().whereType<File>()) {
        if (f.path.endsWith('/Zwischenablage.kt')) continue;
        expect(quelle(f.path), isNot(contains('setPrimaryClip')),
            reason: f.path);
      }
    });

    test('Zwischenablage.kt: 30 s, sensibel, überschreiben VOR dem Leeren', () {
      final q = quelle('$_kt/Zwischenablage.kt');
      expect(q, contains('const val KANAL = "${SicherClipboard.kanal.name}"'));
      final frist = RegExp(r'const val FRIST_MS = ([\d_]+)L').firstMatch(q);
      expect(frist, isNotNull);
      expect(Duration(milliseconds: int.parse(frist![1]!.replaceAll('_', ''))),
          SicherClipboard.standardTtl);
      expect(SicherClipboard.standardTtl, const Duration(seconds: 30));
      expect(q, contains('ClipDescription.EXTRA_IS_SENSITIVE'));
      expect(q, contains('"android.content.extra.IS_SENSITIVE"'));
      final leeren = rumpf(q, 'fun leeren() {');
      final ueber =
          leeren.indexOf('setPrimaryClip(ClipData.newPlainText("", "")');
      final weg = leeren.indexOf('cm.clearPrimaryClip()');
      expect(ueber, greaterThanOrEqualTo(0));
      expect(weg, greaterThan(ueber));
      expect(leeren, contains('Build.VERSION.SDK_INT >= Build.VERSION_CODES.P'),
          reason: 'clearPrimaryClip gibt es erst ab Android 9, minSdk ist 24');
      expect(leeren, contains('melden('));
    });

    test('🔴 minSdk 24: Lebenszyklus über die Application', () {
      final q = quelle('$_kt/Zwischenablage.kt');
      expect(q, contains('a.application.registerActivityLifecycleCallbacks('));
      expect(q, isNot(contains('a.registerActivityLifecycleCallbacks(')),
          reason: 'das gibt es erst ab Android 10');
    });

    test('🔴 der Beobachter handelt nur, wenn die App vorn ist', () {
      final q = quelle('$_kt/Zwischenablage.kt');
      final horcher = rumpf(
          q, 'val b = ClipboardManager.OnPrimaryClipChangedListener {');
      final vorn = horcher.indexOf('if (vorn.isEmpty()) return');
      final eigen = horcher.indexOf('getBoolean(EIGEN)');
      final nach = horcher.indexOf('nachmarkieren(cm)');
      final plan = horcher.indexOf('planen(FRIST_MS)');
      expect(vorn, greaterThanOrEqualTo(0),
          reason: 'vor Android 10 meldet das System auch fremde Kopien');
      expect(eigen, greaterThan(vorn));
      expect(nach, greaterThan(eigen), reason: 'sonst endlos');
      expect(plan, greaterThan(nach));
    });

    test('nachmarkieren: nur Text, sensibel, HTML bleibt', () {
      final nach = rumpf(quelle('$_kt/Zwischenablage.kt'),
          'private fun nachmarkieren(cm: ClipboardManager) {');
      expect(nach, contains('it.uri != null'));
      expect(nach, contains('it.intent != null'));
      expect(nach, contains('it.extras = sensibel()'));
      expect(nach, contains('htmlText'));
      expect(nach, contains('cm.setPrimaryClip(neu)'));
    });
  });
}
