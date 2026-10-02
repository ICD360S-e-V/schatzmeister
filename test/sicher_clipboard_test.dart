import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icd360sev_schatzmeister/utils/sicher_clipboard.dart';

/// Ohne den nativen Kanal (Windows, Linux, macOS, iOS — und der Test-Host)
/// fällt SicherClipboard auf Clipboard.setData und einen Dart-Timer zurück.
/// Geprüft: der Wert wird kopiert, nach der Frist geleert, leere() leert
/// sofort — und fasst die Zwischenablage nicht an, wenn nichts von der App
/// darin liegt.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final gesetzt = <String?>[];

  setUp(() {
    gesetzt.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        gesetzt.add((call.arguments as Map)['text'] as String?);
      }
      return null;
    });
  });

  tearDown(() async {
    await SicherClipboard.leere();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test('kopiert den Wert und leert nach der Frist', () async {
    await SicherClipboard.kopiere('geheim123',
        ttl: const Duration(milliseconds: 50));
    expect(gesetzt, ['geheim123']);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(gesetzt.last, '', reason: 'Zwischenablage muss nach der Frist leer sein');
  });

  test('leere() leert sofort', () async {
    await SicherClipboard.kopiere('x');
    await SicherClipboard.leere();
    expect(gesetzt, ['x', '']);
  });

  test('leere() ohne Kopie der App fasst die Zwischenablage nicht an', () async {
    await SicherClipboard.leere();
    expect(gesetzt, isEmpty);
  });

  test('spaeterLeeren() — der Weg des Boten ohne Kanal', () async {
    SicherClipboard.spaeterLeeren(const Duration(milliseconds: 50));
    expect(gesetzt, isEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(gesetzt, ['']);
  });

  test('🔴 länger als 30 s bleibt nichts — eine längere Frist wird gekürzt', () {
    expect(SicherClipboard.standardTtl, const Duration(seconds: 30));
    expect(SicherClipboard.gekuerzt(const Duration(minutes: 2)),
        const Duration(seconds: 30));
    expect(SicherClipboard.gekuerzt(const Duration(seconds: 7)),
        const Duration(seconds: 7));
  });

  test('nach dem Leeren erfährt es der Hinweis', () async {
    final gemeldet = <bool>[];
    void melder(DateTime zeit, {required bool spaet}) => gemeldet.add(spaet);
    SicherClipboard.melderSetzen(melder);
    addTearDown(() => SicherClipboard.melderLoesen(melder));
    await SicherClipboard.kopiere('x', ttl: const Duration(milliseconds: 50));
    expect(gemeldet, isEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(gemeldet, [false]);
  });
}
