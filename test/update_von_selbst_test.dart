// Das Update installiert sich auf Android selbst — wie bei der Vorsitzer-App.
//
// Wunsch des Vorsitzenden (17.10.2026): „se poate aplica si la aplicatia
// mitglieder si schatzmeister auto actualizarea ca pe vorsitzer“ — auf jedem
// Netz („B indiferent ca e pe date mobile sau wifi“).
//
// Diese Datei hält fest:
//  * nie während eines Anrufs oder einer Fernwartung — Android beendet die App
//    beim Ersetzen des Pakets und mit ihr das Gespräch;
//  * je Fassung nur EIN Versuch von selbst — sonst käme die Dialogschleife
//    zurück, die die Vorsitzer-App vom 01.–13.10.2026 hatte;
//  * nur dort, wo Android ohne Rückfrage installiert; sonst wird nichts im
//    Hintergrund geladen, und es bleibt beim Dialog;
//  * das Geladene wird gegen das `sha256` des Manifests geprüft;
//  * kurz davor der Hinweis, dass die App gleich neu startet.
//
// ⚠️ Anrufe, Fernwartung und Einstellungen sind hier nur im Test gesetzt
// (testZustand, SharedPreferences.setMockInitialValues) — nichts davon geht
// an ein Gerät oder einen Server.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icd360sev_schatzmeister/services/notification_service.dart';
import 'package:icd360sev_schatzmeister/services/remote_agent_service.dart';
import 'package:icd360sev_schatzmeister/services/update_gespraechssperre.dart';
import 'package:icd360sev_schatzmeister/services/update_service.dart';
import 'package:icd360sev_schatzmeister/services/voice_call_service.dart';
import 'package:icd360sev_schatzmeister/widgets/update_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ein Stück Quelltext von [anfang] bis vor [ende].
String _stueck(String text, String anfang, String ende) {
  final a = text.indexOf(anfang);
  expect(a, greaterThanOrEqualTo(0), reason: 'nicht gefunden: $anfang');
  final e = text.indexOf(ende, a + anfang.length);
  expect(e, greaterThan(a), reason: 'nicht gefunden: $ende');
  return text.substring(a, e);
}

/// Liest eine Datei ohne Wagenrücklauf (update_dialog.dart hat CRLF).
String _lesen(String pfad) => File(pfad).readAsStringSync().replaceAll('\r\n', '\n');

void main() {
  final chat = VoiceCallService();
  final fernwartung = RemoteAgentService();

  /// Lässt die Zuhörer zu Wort kommen (beide Dienste melden über Ströme).
  Future<void> durchlauf() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  tearDown(() {
    chat.testZustand(CallState.idle);
    fernwartung.testZustand(RemoteAgentState.idle);
  });

  group('was sperrt', () {
    test('ohne Anruf und ohne Fernwartung: frei', () {
      expect(UpdateGespraechssperre.grund, isNull);
      expect(UpdateGespraechssperre.gesperrt, isFalse);
    });

    test('Anruf: klingelnd, wählend, im Aufbau und im Gespräch', () {
      for (final s in CallState.values.where((s) => s != CallState.idle)) {
        chat.testZustand(s);
        expect(UpdateGespraechssperre.grund, 'Anruf', reason: s.name);
      }
    });

    test('Fernwartung: im Aufbau und während sie läuft', () {
      for (final s in RemoteAgentState.values.where((s) => s != RemoteAgentState.idle)) {
        fernwartung.testZustand(s);
        expect(UpdateGespraechssperre.grund, 'Fernwartung', reason: s.name);
      }
    });
  });

  group('abwarten()', () {
    test('ohne Anruf: sofort', () async {
      await UpdateGespraechssperre.abwarten().timeout(const Duration(seconds: 1));
    });

    test('erst, wenn der Anruf vorbei UND die Fernwartung zu ist', () async {
      chat.testZustand(CallState.inCall);
      fernwartung.testZustand(RemoteAgentState.active);
      var fertig = false;
      unawaited(UpdateGespraechssperre.abwarten().then((_) => fertig = true));
      await durchlauf();
      expect(fertig, isFalse);

      chat.testZustand(CallState.idle);
      await durchlauf();
      expect(fertig, isFalse, reason: 'die Fernwartung läuft noch');

      fernwartung.testZustand(RemoteAgentState.idle);
      await durchlauf();
      expect(fertig, isTrue);
    });
  });

  group('von selbst installieren', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<int?> vermerkt() async {
      final p = await SharedPreferences.getInstance();
      await p.reload();
      return p.getInt(UpdateService.vonSelbstSchluessel);
    }

    /// Reichlich Zeit für die Futures der Einstellungen.
    Future<void> weile() => Future<void>.delayed(const Duration(milliseconds: 20));

    test('ohne Anruf: sofort — und je Fassung nur EINMAL', () async {
      expect(await UpdateService.vonSelbstFreigeben(46), isTrue);
      expect(await vermerkt(), 46);
      expect(await UpdateService.vonSelbstFreigeben(46), isFalse,
          reason: 'zweiter Versuch derselben Fassung');
      expect(await UpdateService.vonSelbstFreigeben(47), isTrue,
          reason: 'die nächste Fassung darf wieder');
    });

    test('im Anruf: erst, wenn er vorbei ist — und erst dann vermerkt', () async {
      chat.testZustand(CallState.ringing);
      var frei = false;
      final f = UpdateService.vonSelbstFreigeben(46).then((v) => frei = v);
      await weile();
      expect(frei, isFalse);
      expect(await vermerkt(), isNull, reason: 'vermerkt wird erst nach dem Anruf');

      chat.testZustand(CallState.idle);
      await f;
      expect(frei, isTrue);
      expect(await vermerkt(), 46);
    });

    test('während einer Fernwartung ebenso', () async {
      fernwartung.testZustand(RemoteAgentState.connecting);
      var frei = false;
      final f = UpdateService.vonSelbstFreigeben(46).then((v) => frei = v);
      await weile();
      expect(frei, isFalse);
      expect(await vermerkt(), isNull);

      fernwartung.testZustand(RemoteAgentState.idle);
      await f;
      expect(frei, isTrue);
    });

    test('nicht auf Android (hier: Linux): nichts von selbst, es bleibt beim Dialog', () async {
      final info = UpdateInfo(
          version: '9.9.9', buildNumber: 999, downloadUrl: 'https://example.invalid/x.apk', changelog: '');
      expect(await UpdateService().installUnattended(info), isFalse);
      expect(UpdateService().unattendedInProgress, isFalse);
      expect(await vermerkt(), isNull);
    });
  });

  group('der Hinweis, bevor die App neu startet', () {
    testWidgets('kommt auch, wenn der Bildschirm schon zu ist — über den Navigator der App', (t) async {
      await t.pumpWidget(MaterialApp(
        navigatorKey: NotificationService.navigatorKey,
        home: const Scaffold(body: SizedBox.expand()),
      ));

      updateHinweisZeigen('1.6.0');
      await t.pump();
      await t.pump(const Duration(milliseconds: 750));

      expect(find.text('Version 1.6.0 wird im Hintergrund installiert. Die App startet gleich neu.'),
          findsOneWidget);
      await t.pump(const Duration(seconds: 9));
    });
  });

  group('Quelltext', () {
    late String dienst, installieren, laden, android, pruefen, knopf, manifest, kotlin;

    // In setUpAll, nicht beim Anlegen der Gruppe: `expect` geht nur in einem
    // Test (oder seinem setUpAll).
    setUpAll(() {
      dienst = _lesen('lib/services/update_service.dart');
      installieren = _stueck(dienst, 'Future<bool> installUnattended(', 'Future<UpdateInfo?> checkForUpdate()');
      laden = _stueck(dienst, 'Future<String?> downloadUpdate(', 'Future<bool> launchInstaller(');
      // Der Android-Zweig von launchInstaller — _getInstallerFilename hat
      // davor einen gleich beginnenden.
      android = _stueck(_stueck(dienst, 'Future<bool> launchInstaller(', 'bool get supportsAutoUpdate'),
          '} else if (Platform.isAndroid) {', '} else if (Platform.isIOS) {');
      final dialog = _lesen('lib/widgets/update_dialog.dart');
      pruefen = _stueck(dialog, 'Future<void> checkAndShowUpdateDialog(', 'showDialog(');
      knopf = _stueck(dialog, 'Future<void> _downloadAndInstall() async {', 'void updateHinweisZeigen(');
      manifest = _lesen('android/app/src/main/AndroidManifest.xml');
      kotlin = _lesen('packages/icd_installer/android/src/main/kotlin/de/icd360sev/icd_installer/'
          'IcdInstallerPlugin.kt');
    });

    test('Android installiert über die Session, ohne zweiten Dialog — nicht mehr über android_package_installer', () {
      expect(android, contains('IcdInstaller.apkInstallieren(installerPath, ohneNachfrage: true)'));
      expect(dienst, isNot(contains('AndroidPackageInstaller')));
      expect(File('pubspec.yaml').readAsStringSync(), isNot(contains('android_package_installer:')));
    });

    test('erst fragen, ob Android ohne Rückfrage installiert — und ob es schon versucht wurde — DANN laden', () {
      final l = installieren.indexOf('downloadUpdate(');
      expect(installieren.indexOf('if (!Platform.isAndroid) return false;'), inExclusiveRange(0, l));
      expect(installieren.indexOf('await kannUnbeaufsichtigt()'), inExclusiveRange(0, l));
      expect(installieren.indexOf('await _schonVersucht(updateInfo.buildNumber)'), inExclusiveRange(0, l));
    });

    test('nie im Gespräch: vor dem Laden, vor dem Hinweis, und erst danach der Versuch', () {
      final l = installieren.indexOf('downloadUpdate(');
      final hinweis = installieren.indexOf('vorDemNeustart?.call(updateInfo.version);');
      final frei = installieren.indexOf('await vonSelbstFreigeben(updateInfo.buildNumber)');
      final los = installieren.indexOf('await launchInstaller(pfad)');
      expect(installieren.indexOf('await _ohneGespraech();'), inExclusiveRange(0, l));
      expect(installieren.indexOf('await _ohneGespraech();', l), inExclusiveRange(l, hinweis));
      expect(hinweis, inExclusiveRange(l, frei));
      expect(frei, inExclusiveRange(hinweis, los));
      final freigeben = _stueck(dienst, 'static Future<bool> vonSelbstFreigeben(', 'static Future<bool> _schonVersucht(');
      expect(freigeben.indexOf('await _ohneGespraech();'),
          inExclusiveRange(0, freigeben.indexOf('await prefs.setInt(vonSelbstSchluessel, build);')));
    });

    test('geprüft wird gegen das sha256 des Manifests — von selbst wie auf den Knopf', () {
      expect(installieren, contains('expectedSha256: updateInfo.sha256'));
      expect(knopf, contains('expectedSha256: widget.updateInfo.sha256'));
      expect(dienst, contains("final sha256Hex = result['sha256'] as String?;"));
      final pruefung = laden.indexOf('if (ist != soll) {');
      expect(pruefung, greaterThan(laden.indexOf('await sink.close();')));
      expect(laden.indexOf('await file.delete();', pruefung), greaterThan(pruefung));
    });

    test('läuft schon ein Update von selbst, fragt der Dialog nicht dazwischen', () {
      expect(pruefen.indexOf('if (updateService.unattendedInProgress) return;'),
          inExclusiveRange(0, pruefen.indexOf('checkForUpdate()')));
      expect(pruefen.indexOf('await updateService.installUnattended('),
          inExclusiveRange(pruefen.indexOf('checkForUpdate()'), pruefen.length));
      final schon = _stueck(installieren, 'if (_unattendedInProgress) {', '_unattendedInProgress = true;');
      expect(schon, contains('return true;'));
    });

    test('kommt der Knopf nicht durch, steht er wieder da — kein ewiges „wird installiert“', () {
      expect(knopf, contains('await updateService.launchInstaller(installerPath)'));
      expect(knopf, contains('if (!uebergeben && mounted) {'));
    });

    test('das Manifest erklärt die Berechtigung', () {
      expect(manifest, contains('android.permission.UPDATE_PACKAGES_WITHOUT_USER_ACTION'));
      expect(manifest, contains('android.permission.REQUEST_INSTALL_PACKAGES'));
    });

    test('Kotlin: ohne Rückfrage nur ab Android 12, und das Paket nicht auf dem Hauptfaden', () {
      expect(kotlin, contains('if (ohneNachfrage && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {\n'
          '                    params.setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)'));
      final schreiben = _stueck(kotlin, 'private fun installieren(', 'private fun uebergebenAn(');
      expect(schreiben, contains('Thread({'));
      expect(schreiben.indexOf('sessionSchreiben(context, pfad, ohneNachfrage)'),
          greaterThan(schreiben.indexOf('Thread({')));
      final kann = _stueck(kotlin, 'fun kannOhneNachfrage(ctx: Context): Boolean {', 'fun sessionSchreiben(');
      expect(kann, contains('if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return false'));
      expect(kann, contains('pm.canRequestPackageInstalls()'));
      expect(kann, contains('UPDATE_OHNE_NACHFRAGE'));
      expect(kann, contains('updateOwnerPackageName'));
      expect(kotlin, contains('const val KANAL = "de.icd360sev.schatzmeister/installer"'));
    });

    test('Kotlin: minSdk 24 — Neueres nur hinter der Android-Fassung', () {
      expect(kotlin, contains('if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {\n'
          '                    params.setInstallReason('));
      expect(kotlin, contains('if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) s.isCommitted else false'));
      expect(kotlin, contains('Build.VERSION.SDK_INT >= Build.VERSION_CODES.R &&\n'
          '                    System.currentTimeMillis() - s.createdMillis'));
      expect(kotlin, contains('if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {\n'
          '                PendingIntent.FLAG_MUTABLE'));
    });
  });
}
