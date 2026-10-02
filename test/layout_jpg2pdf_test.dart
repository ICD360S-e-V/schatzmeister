// Bilder zu PDF MIT Bildern auf Telefon, Tablet und Schreibtisch.
//
// bildschirme_telefon_test.dart sieht nur die leere Seite. Mit Bildern
// kommen die Liste (Vorschau, langer Dateiname, Nummer, Entfernen) und der
// Speichern-Knopf mit Anzahl dazu. Die Bilder kommen über eine vorgetäuschte
// Dateiauswahl (FilePicker.platform) aus echten PNG-Dateien.
// Gemessen mit Roboto, wie in bildschirme_telefon_test.dart.
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icd360sev_schatzmeister/l10n/app_localizations.dart';
import 'package:icd360sev_schatzmeister/screens/jpg2pdf_screen.dart';
import 'package:icd360sev_schatzmeister/services/language_service.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

const Map<String, Size> kBreiten = {
  '320 dp': Size(320, 640),
  '360 dp': Size(360, 800),
  '393 dp (Redmi)': Size(393, 873),
  '412 dp': Size(412, 915),
  '800 dp (Tablet)': Size(800, 1280),
  '1280 dp (Schreibtisch)': Size(1280, 800),
};

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

const _namen = [
  'Kontoauszug_VR-Bank_Neu-Ulm_Maerz_2026_Seite_1_von_3.jpg',
  'IMG_20260115_103512_Quittung_Bueromaterial.png',
  'Scan_Spendenbescheinigung_Ioana-Alexandra_Dumitrescu-Popescu.jpeg',
  'x.png',
];

/// Dateiauswahl ohne Plattform: liefert die vorbereiteten Bilder.
class _Auswahl extends FilePicker {
  _Auswahl(this.dateien);
  final List<PlatformFile> dateien;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async =>
      FilePickerResult(dateien);
}

/// Lässt jede senkrechte Liste einmal von oben bis unten laufen: eine
/// ListView baut nur, was zu sehen ist — ein Überlauf weiter unten fiele
/// sonst nicht auf.
Future<void> _durchscrollen(WidgetTester tester) async {
  final listen = find
      .byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down)
      .evaluate()
      .map((e) => (e as StatefulElement).state as ScrollableState)
      .toList();
  for (final liste in listen) {
    if (!liste.mounted) continue;
    final pos = liste.position;
    // Zusammengedrückte Liste (Höhe 0): nichts zu sehen, nichts zu scrollen.
    if (pos.viewportDimension < 1) continue;
    for (var i = 0, p = 0.0; i < 100; i++, p += pos.viewportDimension / 2) {
      pos.jumpTo(p.clamp(0.0, pos.maxScrollExtent));
      await tester.pump();
      if (p >= pos.maxScrollExtent) break;
    }
    pos.jumpTo(0);
    await tester.pump();
  }
}

void main() {
  late Directory ordner;
  late List<PlatformFile> bilder;

  setUpAll(() async {
    if (!_schriftenDa) return;
    await _laden('Roboto', [
      'Roboto-Regular.ttf',
      'Roboto-Bold.ttf',
      'Roboto-Medium.ttf',
      'Roboto-Italic.ttf',
    ]);
    await _laden('MaterialIcons', ['MaterialIcons-Regular.otf']);
    ordner = Directory.systemTemp.createTempSync('layout_jpg2pdf_');
    bilder = [
      for (var i = 0; i < _namen.length; i++)
        () {
          final bytes = img.encodePng(img.Image(width: 40 + 20 * i, height: 60));
          final datei = File('${ordner.path}/bild_$i.png')..writeAsBytesSync(bytes);
          // Größen bis in den MB-Bereich, damit „MB“ statt „KB“ erscheint.
          return PlatformFile(name: _namen[i], path: datei.path, size: i == 0 ? 3456789 : bytes.length);
        }(),
    ];
  });
  tearDownAll(() {
    if (_schriftenDa) ordner.deleteSync(recursive: true);
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Bilder zu PDF mit Bildern', () {
    for (final sprache in ['de', 'ro']) {
      for (final fall in kBreiten.entries) {
        testWidgets('Bildliste und Knöpfe — ${fall.key} [$sprache]', (tester) async {
          tester.view.physicalSize = fall.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          await LanguageService.instance.setLanguage(sprache);
          FilePicker.platform = _Auswahl(bilder);

          final ueberlaeufe = <String>{};
          final vorher = FlutterError.onError;
          FlutterError.onError = (details) {
            final text = details.toString();
            final m = RegExp(r'overflowed by ([0-9.]+) pixels on the (\w+)').firstMatch(text);
            if (m == null) {
              vorher?.call(details);
              return;
            }
            final ort = RegExp(r'lib/[\w/]+\.dart:\d+').firstMatch(text);
            ueberlaeufe.add('${m.group(1)} px ${m.group(2)} @ ${ort?.group(0) ?? '?'}');
          };
          var zeilen = 0;
          var speichernMitAnzahl = false;
          try {
            await tester.pumpWidget(_rahmen(Jpg2PdfScreen(onBack: () {}), sprache));
            await tester.pump();
            // „Bilder hinzufügen“ in der Kopfzeile (das erste Symbol dieser Art).
            await tester.tap(find.byIcon(Icons.add_photo_alternate).first);
            // Die Bilder werden echt von der Platte gelesen.
            for (var i = 0; i < 50 && find.byType(ListTile).evaluate().isEmpty; i++) {
              await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
              await tester.pump();
            }
            await tester.pump(const Duration(milliseconds: 300));
            await _durchscrollen(tester);
            zeilen = find.byType(ListTile).evaluate().length;
            speichernMitAnzahl = find
                .text(tr('Als PDF speichern (${_namen.length})', 'Salvează ca PDF (${_namen.length})'))
                .evaluate()
                .isNotEmpty;
          } finally {
            FlutterError.onError = vorher;
          }
          await tester.pumpWidget(const SizedBox());

          expect(zeilen, greaterThanOrEqualTo(3), reason: 'die gewählten Bilder müssen in der Liste stehen');
          expect(speichernMitAnzahl, isTrue, reason: 'der Speichern-Knopf zeigt die Anzahl');
          expect(ueberlaeufe, isEmpty, reason: '${fall.key} [$sprache]:\n${ueberlaeufe.join('\n')}');
        });
      }
    }
  }, skip: _schriftenDa ? false : 'Roboto fehlt unter $_schriften');
}
