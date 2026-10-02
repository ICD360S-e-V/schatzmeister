// Passt der PDF-Manager MIT EINEM GEÖFFNETEN PDF auf jedes Telefon?
//
// test/bildschirme_telefon_test.dart sieht den PDF-Manager nur leer. Mit
// einem Dokument stehen Dateiname und Seitenzahl in der Kopfzeile, im
// Textmodus ein langer Hinweis daneben, und die Werkzeuge öffnen Dialoge
// (Text hinzufügen, Aufteilen, Komprimieren, Zusammenführen) — gebaut für
// den Schreibtisch.
//
// Hier öffnet der Test über einen Ersatz für den Dateiauswahl-Dialog ein
// echtes PDF mit drei Seiten und langem Namen; pdfrx lädt es mit der
// PDFium-Bibliothek, die `flutter test` über den Build-Hook von
// pdfium_dart mitbringt (ohne sie wird die Gruppe übersprungen). Geprüft
// wird auf jeder Breite in beiden Sprachen: Kopfzeile, Textmodus, jeder
// Dialog — kein Überlauf, kein Wort mitten im Wort zerrissen.
//
// ⚠️ Mit der echten Schrift (Roboto) — die Testschrift zeichnet jede Glyphe
// als 1-em-Quadrat und macht Texte viel breiter als auf dem Gerät.
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:icd360sev_schatzmeister/l10n/app_localizations.dart';
import 'package:icd360sev_schatzmeister/services/language_service.dart';
import 'package:icd360sev_schatzmeister/screens/pdf_manager_screen.dart';

/// Android-Telefone, die Grenze zum Tablet, Tablet und Schreibtisch.
const Map<String, Size> kBreiten = {
  '320 dp': Size(320, 640),
  '360 dp': Size(360, 800),
  '393 dp (Redmi)': Size(393, 873),
  '412 dp': Size(412, 915),
  '600 dp': Size(600, 960),
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

/// Name des geöffneten Dokuments — lang, mit Leerzeichen und Umlauten.
const kDateiname =
    'Protokoll Mitgliederversammlung 12.09.2026 – Beschlüsse zur Beitragsordnung (unterschrieben).pdf';

/// Wo `flutter test` die PDFium-Bibliothek des Build-Hooks von
/// `pdfium_dart` ablegt (wie in der Vorsitzer-App).
String? _pdfiumImBuild() {
  final hook = Directory('.dart_tool/hooks_runner/shared/pdfium_dart/build');
  final kandidaten = <File>[
    File('build/native_assets/linux/libpdfium.so'),
    if (hook.existsSync())
      ...hook
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('/linux-x64/libpdfium.so')),
  ];
  for (final f in kandidaten) {
    if (f.existsSync()) return f.absolute.path;
  }
  return null;
}

Future<Uint8List> _dreiSeiten() {
  final doc = pw.Document();
  for (var i = 1; i <= 3; i++) {
    doc.addPage(pw.Page(build: (_) => pw.Text('Seite $i', style: const pw.TextStyle(fontSize: 40))));
  }
  return doc.save();
}

/// Ersatz für den Dateiauswahl-Dialog: ein PDF zum Öffnen, drei zum
/// Zusammenführen.
class _Dateiauswahl extends FilePicker {
  _Dateiauswahl(this.pfad, this.groesse);
  final String pfad;
  final int groesse;

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
  }) async {
    if (!allowMultiple) {
      return FilePickerResult([PlatformFile(path: pfad, name: kDateiname, size: groesse)]);
    }
    return FilePickerResult([
      PlatformFile(path: '$pfad.1', name: kDateiname, size: groesse),
      PlatformFile(path: '$pfad.2', name: 'Kassenbericht_2025_mit_Anlagen_und_Belegen_Kassenpruefung.pdf', size: 3 * 1024 * 1024),
      PlatformFile(path: '$pfad.3', name: 'Bankvollmacht Sparkasse Neu-Ulm.pdf', size: 245760),
    ]);
  }
}

/// Lässt pdfrx laden: abwechselnd echte Zeit (Datei lesen, Hintergrund-
/// Isolat) und Pumpen — bis das Dokument da ist und die Seitenzahl steht.
Future<bool> _geladen(WidgetTester tester) async {
  for (var i = 0; i < 300; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 50));
    final viewer = find.byType(PdfViewer);
    if (viewer.evaluate().isEmpty) continue;
    final l = tester.widget<PdfViewer>(viewer).documentRef.resolveListenable();
    if (l.error != null) return false;
    if (l.document != null) {
      // Noch ein paar Runden: onViewerReady setzt die Seitenzahl.
      for (var j = 0; j < 10; j++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      return true;
    }
  }
  return false;
}

/// Sammelt, was Flutter während [aktion] meldet: Überläufe mit der
/// Codezeile, die sie verursacht, und jeden anderen Fehler mit seiner
/// ersten Zeile.
Future<List<String>> _ueberlaeufe(Future<void> Function() aktion) async {
  final funde = <String>[];
  final vorher = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.toString();
    final ort = RegExp(r'lib/[\w/]+\.dart:\d+').firstMatch(text)?.group(0) ?? '?';
    final m = RegExp(r'overflowed by ([0-9.]+) pixels on the (\w+)')
        .firstMatch(text);
    if (m != null) {
      funde.add('Überlauf ${m.group(1)} px ${m.group(2)} @ $ort');
    } else {
      funde.add('Fehler „${details.exceptionAsString().split('\n').first}“ @ $ort');
    }
  };
  try {
    await aktion();
  } finally {
    FlutterError.onError = vorher;
  }
  return funde;
}

/// Wörter, die mitten im Wort auf zwei Zeilen zerrissen sind — das Zeichen
/// einer zu schmalen Spalte. Ein Umbruch nach einem Bindestrich oder
/// Schrägstrich ist erlaubt: geprüft werden nur Folgen aus Buchstaben und
/// Ziffern.
List<String> _wortbrueche() {
  final funde = <String>[];
  final wort = RegExp(r'[\p{L}\p{N}]+', unicode: true);
  for (final e in find.byType(RichText).evaluate()) {
    final p = e.renderObject;
    if (p is! RenderParagraph || !p.hasSize) continue;
    final text = p.text.toPlainText();
    for (final m in wort.allMatches(text)) {
      final kaesten = p.getBoxesForSelection(
          TextSelection(baseOffset: m.start, extentOffset: m.end));
      if (kaesten.length < 2) continue;
      final erste = kaesten.first;
      if (kaesten.any((k) => k.top >= erste.bottom - 1)) {
        funde.add('„${m.group(0)}“ in „${text.replaceAll('\n', ' ')}“');
      }
    }
  }
  return funde;
}

void main() {
  late Directory tmp;
  late File pdfDatei;
  final pdfium = Platform.isLinux ? _pdfiumImBuild() : null;

  setUpAll(() async {
    tmp = Directory.systemTemp.createTempSync('teil7_pdf_manager');
    // Ohne das fragt pdfrx `path_provider`, und das gibt es im Testlauf nicht.
    Pdfrx.cacheDirectoryPath = tmp.path;
    Pdfrx.pdfiumModulePath = pdfium;
    final bytes = await _dreiSeiten();
    pdfDatei = File('${tmp.path}/dokument.pdf')..writeAsBytesSync(bytes);
    FilePicker.platform = _Dateiauswahl(pdfDatei.path, bytes.length);
    if (!_schriftenDa) return;
    await _laden('Roboto', [
      'Roboto-Regular.ttf',
      'Roboto-Bold.ttf',
      'Roboto-Medium.ttf',
      'Roboto-Italic.ttf',
    ]);
    await _laden('MaterialIcons', ['MaterialIcons-Regular.otf']);
  });
  tearDownAll(() => tmp.deleteSync(recursive: true));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('PDF-Manager mit Dokument', () {
    for (final sprache in kSprachen) {
      for (final fall in kBreiten.entries) {
        testWidgets('lesbar — ${fall.key} [$sprache]', (tester) async {
          tester.view.physicalSize = fall.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          await LanguageService.instance.setLanguage(sprache);

          final befunde = <String>[];
          Future<void> schritt(String name, Future<void> Function() aktion) async {
            final ueber = await _ueberlaeufe(() async {
              await aktion();
              await tester.pumpAndSettle();
            });
            befunde
              ..addAll(_wortbrueche().map((w) => '$name: Wortbruch $w'))
              ..addAll(ueber.map((u) => '$name: $u'));
          }

          // Werkzeug antippen (die Leiste rollt auf dem Telefon).
          Future<void> werkzeug(String text) async {
            final knopf = find.text(text).first;
            await tester.ensureVisible(knopf);
            await tester.pumpAndSettle();
            await tester.tap(knopf);
          }

          Future<void> dialogPruefen(String name, Future<void> Function() oeffnen) async {
            await schritt(name, oeffnen);
            if (find.byType(AlertDialog).evaluate().isEmpty) {
              befunde.add('$name ging nicht auf');
              return;
            }
            await tester.tap(find.text(tr('Abbrechen', 'Anulare')).last);
            await tester.pumpAndSettle();
          }

          try {
            await tester.pumpWidget(_rahmen(PdfManagerView(onBack: () {}), sprache));
            await tester.pump();
            final ueber = await _ueberlaeufe(() async {
              await tester.tap(find.text(tr('PDF öffnen', 'Deschide PDF')).last);
              expect(await _geladen(tester), isTrue, reason: 'Das PDF wurde nicht geladen');
            });
            befunde
              ..addAll(_wortbrueche().map((w) => 'Geöffnet: Wortbruch $w'))
              ..addAll(ueber.map((u) => 'Geöffnet: $u'));
            expect(find.text(kDateiname), findsOneWidget, reason: 'Der Dateiname fehlt');
            if (find.text(tr('Seite 1 von 3', 'Pagina 1 din 3')).evaluate().isEmpty) {
              befunde.add('Geöffnet: Seitenzahl nicht zu sehen');
            }

            await schritt('Textmodus', () => werkzeug(tr('Text hinzufügen', 'Adaugă text')));
            if (find.text(tr('Textmodus - Klicken zum Platzieren', 'Mod text - clic pentru plasare'))
                .evaluate()
                .isEmpty) {
              befunde.add('Textmodus: Hinweis nicht zu sehen');
            }
            await dialogPruefen('Dialog Text', () async {
              await tester.tapAt(tester.getCenter(find.byType(PdfViewer)));
              // Der Betrachter wartet auf einen möglichen Doppeltipp, erst
              // danach zählt der einfache Tipp.
              await tester.pump(const Duration(milliseconds: 500));
            });
            await dialogPruefen('Dialog Aufteilen', () => werkzeug(tr('PDF aufteilen', 'Împarte PDF')));
            await dialogPruefen('Dialog Komprimieren', () => werkzeug(tr('PDF komprimieren', 'Comprimă PDF')));
            await dialogPruefen('Dialog Zusammenführen', () => werkzeug(tr('PDFs zusammenführen', 'Combină PDF-uri')));
          } finally {
            // Abbauen und die Testzeit laufen lassen (100-ms-Takt des Viewers).
            await tester.pumpWidget(const SizedBox());
            await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
            await tester.pump(const Duration(seconds: 1));
          }

          expect(befunde, isEmpty,
              reason: 'PDF-Manager auf ${fall.key} [$sprache]:\n'
                  '${befunde.toSet().join('\n')}');
        });
      }
    }
  },
      skip: !_schriftenDa
          ? 'Roboto fehlt unter $_schriften'
          : pdfium == null
              ? 'PDFium aus dem Build-Hook fehlt'
              : false);
}
