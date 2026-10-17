import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:icd_installer/icd_installer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'platform_service.dart';
import 'logger_service.dart';
import 'update_gespraechssperre.dart';

final _log = LoggerService();

/// Update Service - checks for app updates and handles download
/// Cross-platform: Windows (Inno Setup), macOS (DMG), Linux (AppImage),
/// Android (APK), iOS (not supported - use TestFlight)
class UpdateService {
  /// Versionsauskunft aus dem GitHub-Release, nicht mehr vom Vereinsserver.
  ///
  /// ⚠️ Vorher: `https://icd360sev.icd360s.de/api/version_schatzmeister.php`.
  /// Das hatte drei Nachteile, die sich alle gezeigt haben:
  ///   • die Datei dort wurde von Hand gepflegt und zeigte monatelang auf
  ///     ein APK, das nach der Servermigration gar nicht mehr existierte;
  ///   • der Endpunkt verlangt einen Device-Key — den ein frisch
  ///     installiertes Gerät noch nicht hat;
  ///   • der Server muss laufen, damit die App überhaupt erfährt, dass es
  ///     eine neue Fassung gibt.
  ///
  /// Jetzt entsteht das Manifest im selben Arbeitsablauf, der das APK baut
  /// (`.github/workflows/build-android.yml`). Version und Download-Adresse
  /// können damit nicht mehr auseinanderlaufen.
  ///
  /// `releases/latest/download/…` leitet auf die neueste Fassung um; das
  /// http-Paket folgt Weiterleitungen bei GET von sich aus.
  static const String versionUrl =
      'https://github.com/ICD360S-e-V/schatzmeister/releases/latest/download/version_schatzmeister.json';
  static const String currentVersion = '1.6.2';
  static const int currentBuildNumber = 51;
  // ✅ SECURITY FIX: Removed hardcoded API key (extractable via reverse engineering)
  // All requests now use dynamic Device Key only

  late http.Client _client;
  late HttpClient _httpClient;

  // Singleton
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal() {
    _httpClient = HttpClient();
    _client = IOClient(_httpClient);
  }

  // ---------------------------------------------------------------------------
  // Von selbst installieren — Android, seit 17.10.2026 wie die Vorsitzer-App
  // ---------------------------------------------------------------------------
  //
  // Wunsch des Vorsitzenden: „se poate aplica si la aplicatia mitglieder si
  // schatzmeister auto actualizarea ca pe vorsitzer“ — auf jedem Netz, gleich
  // nach dem Laden, nie während eines Anrufs oder einer Fernwartung, je
  // Fassung EIN Versuch. Wo Android ohne Rückfrage nicht installiert (vor
  // Android 12, ohne „Apps aus unbekannten Quellen installieren“), wird nichts
  // im Hintergrund geladen, und es bleibt beim Dialog.

  /// Läuft gerade ein Update von selbst (laden, aufs Gesprächsende warten,
  /// installieren)? Instanzzustand — UpdateService ist ein Singleton.
  bool _unattendedInProgress = false;

  /// Dann prüft und fragt das Dashboard nicht noch einmal dazwischen.
  bool get unattendedInProgress => _unattendedInProgress;

  /// Für welche Fassung sich das Update zuletzt von selbst versucht hat.
  static const vonSelbstSchluessel = 'update_von_selbst_build';

  /// So lange steht der Hinweis „… startet gleich neu“, bevor installiert wird.
  static const _hinweisZeit = Duration(seconds: 3);

  /// Würde Android ein Update hier jetzt ohne Rückfrage einspielen?
  /// (IcdInstaller.kannOhneNachfrage — nur Android.)
  Future<bool> kannUnbeaufsichtigt() async =>
      Platform.isAndroid && await IcdInstaller.kannOhneNachfrage();

  /// Darf sich die App jetzt von selbst auf [build] aktualisieren? Kopie von
  /// `UpdateHud.vonSelbstFreigeben` der Vorsitzer-App.
  ///
  /// - Je Fassung nur EIN Versuch, über Neustarts hinweg. Kommt er nicht durch
  ///   (Android fragt doch, das Paket ist kaputt), bleibt es beim Dialog. Ein
  ///   zweiter Versuch von selbst brächte die Dialogschleife zurück, die die
  ///   Vorsitzer-App vom 01.–13.10.2026 hatte (122 abgebrochene Dialoge).
  /// - Nie während eines Anrufs oder einer Fernwartung: dann wartet es
  ///   ([UpdateGespraechssperre.abwarten]) und vermerkt den Versuch erst danach.
  @visibleForTesting
  static Future<bool> vonSelbstFreigeben(int build) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (prefs.getInt(vonSelbstSchluessel) == build) return false;
    await _ohneGespraech();
    await prefs.setInt(vonSelbstSchluessel, build);
    return true;
  }

  /// Schon einmal von selbst versucht? Dann wird gar nicht erst geladen.
  static Future<bool> _schonVersucht(int build) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getInt(vonSelbstSchluessel) == build;
  }

  /// Wartet, bis kein Anruf und keine Fernwartung mehr läuft.
  static Future<void> _ohneGespraech() async {
    final sperre = UpdateGespraechssperre.grund;
    if (sperre == null) return;
    _log.info('Update von selbst wartet, bis vorbei ist: $sperre', tag: 'UPDATE');
    await UpdateGespraechssperre.abwarten();
  }

  /// Lädt [updateInfo] und installiert es ohne Rückfrage (nur Android).
  ///
  /// true: Android installiert — die App ist gleich weg, nichts danach läuft
  /// noch sicher —, oder ein anderer Lauf ist schon dabei; dann darf auch der
  /// Aufrufer nicht fragen. false: es ging nicht, der Aufrufer zeigt den
  /// Dialog. Vor dem Installieren steht [_hinweisZeit] lang der Hinweis
  /// ([vorDemNeustart]), dass die App gleich neu startet.
  Future<bool> installUnattended(
    UpdateInfo updateInfo, {
    void Function(String version)? vorDemNeustart,
  }) async {
    if (!Platform.isAndroid) return false;
    if (_unattendedInProgress) {
      _log.info('Update von selbst läuft schon', tag: 'UPDATE');
      return true;
    }
    _unattendedInProgress = true;

    if (!await kannUnbeaufsichtigt()) {
      _log.info('Android installiert hier nicht ohne Rückfrage - Dialog wie bisher', tag: 'UPDATE');
      _unattendedInProgress = false;
      return false;
    }
    if (await _schonVersucht(updateInfo.buildNumber)) {
      _log.info('Update ${updateInfo.version} hat sich schon einmal von selbst versucht - Dialog',
          tag: 'UPDATE');
      _unattendedInProgress = false;
      return false;
    }
    // Auch das Laden wartet: es nähme dem Gespräch die Bandbreite.
    await _ohneGespraech();

    _log.info('Update ${updateInfo.version} lädt von selbst', tag: 'UPDATE');
    final pfad = await downloadUpdate(
      updateInfo.downloadUrl,
      (_) {},
      expectedSha256: updateInfo.sha256,
    );
    if (pfad == null) {
      _log.error('Update ${updateInfo.version}: Laden fehlgeschlagen oder Prüfsumme falsch', tag: 'UPDATE');
      _unattendedInProgress = false;
      return false;
    }

    // ⚠️ Noch einmal: das Laden dauert — genau da fiel bei der Vorsitzer-App
    // die Annahme eines Gesprächs hinein.
    await _ohneGespraech();
    vorDemNeustart?.call(updateInfo.version);
    // Den Hinweis lesen lassen — und das Protokoll noch hinaus, bevor die App
    // zugeht.
    await Future.wait<void>([
      Future<void>.delayed(_hinweisZeit),
      _log.jetztHochladen().timeout(_hinweisZeit, onTimeout: () {}),
    ]);
    if (!await vonSelbstFreigeben(updateInfo.buildNumber)) {
      _unattendedInProgress = false;
      return false;
    }
    _log.info('Update ${updateInfo.version} installiert sich selbst', tag: 'UPDATE');

    final uebergeben = await launchInstaller(pfad);
    // Nur bei einem Fehlschlag erreicht: bei Erfolg beendet Android die App.
    if (!uebergeben) _unattendedInProgress = false;
    return uebergeben;
  }

  /// Fragt das GitHub-Release, ob es eine neuere Fassung gibt.
  ///
  /// ⚠️ OHNE Geräteschlüssel (17.10.2026). Bis dahin ging hier `X-Device-Key`
  /// mit — an github.com, alle 5 Minuten aus der Fußleiste und alle 15 aus dem
  /// Dashboard. Mit diesem Schlüssel meldet sich die App bei UNSEREM Server
  /// an; GitHub ist ein Dritter, und die Datei dort ist öffentlich. mitglieder
  /// schickt ihn an derselben Stelle bewusst nie mit. Seitdem fragt auch ein
  /// Gerät ohne Schlüssel (frisch installiert, noch nicht aktiviert).
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'User-Agent': 'ICD360S-Schatzmeister/1.0',
      };

      final response = await _client.get(
        Uri.parse(versionUrl),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        // Check if API returned success
        if (result['success'] == true) {
          final serverVersion = result['version'] as String;
          final serverBuildNumber = result['build_number'] as int;
          final downloadUrl = result['download_url'] as String;
          final changelog = result['changelog'] as String? ?? '';
          final minVersion = result['min_version'] as String?;
          final forceUpdate = result['force_update'] as bool? ?? false;
          // Schreibt build-android.yml seit jeher ins Manifest; geprüft wird
          // es erst seit dem 17.10.2026 (das Update installiert sich selbst).
          final sha256Hex = result['sha256'] as String?;

          // Compare versions
          if (_isNewerVersion(serverVersion, serverBuildNumber)) {
            return UpdateInfo(
              version: serverVersion,
              buildNumber: serverBuildNumber,
              downloadUrl: downloadUrl,
              changelog: changelog,
              minVersion: minVersion,
              forceUpdate: forceUpdate,
              sha256: sha256Hex,
            );
          }
        }
      }
    } catch (e) {
      // Silently fail - don't interrupt user if update check fails
    }
    return null;
  }

  /// Compare versions to determine if server has newer version
  bool _isNewerVersion(String serverVersion, int serverBuildNumber) {
    // First compare build numbers (most reliable)
    if (serverBuildNumber > currentBuildNumber) {
      return true;
    }

    // Then compare version strings
    final serverParts = serverVersion.split('.').map(int.parse).toList();
    final currentParts = currentVersion.split('.').map(int.parse).toList();

    for (int i = 0; i < serverParts.length && i < currentParts.length; i++) {
      if (serverParts[i] > currentParts[i]) {
        return true;
      } else if (serverParts[i] < currentParts[i]) {
        return false;
      }
    }

    return false;
  }

  /// Get platform-specific filename for the installer
  String _getInstallerFilename() {
    if (Platform.isWindows) {
      return 'icd360sev_schatzmeister_setup.exe';
    } else if (Platform.isMacOS) {
      return 'icd360sev_schatzmeister.dmg';
    } else if (Platform.isLinux) {
      return 'icd360sev_schatzmeister.AppImage';
    } else if (Platform.isAndroid) {
      return 'icd360sev_schatzmeister.apk';
    } else if (Platform.isIOS) {
      // iOS doesn't support direct install - redirect to TestFlight
      return 'icd360sev_schatzmeister.ipa';
    }
    return 'icd360sev_schatzmeister_update';
  }

  /// Download the update installer (cross-platform)
  ///
  /// Mit [expectedSha256] (das `sha256` des Manifests) wird das Geladene
  /// geprüft und bei falscher Prüfsumme gelöscht (`null`). Liegt die Datei
  /// schon geprüft da — der Versuch kam nicht durch, oder die App wurde beim
  /// Warten aufs Gesprächsende beendet —, wird nicht noch einmal geladen.
  Future<String?> downloadUpdate(
    String downloadUrl,
    Function(double) onProgress, {
    String? expectedSha256,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final separator = Platform.isWindows ? '\\' : '/';
      final filePath = '${tempDir.path}$separator${_getInstallerFilename()}';
      final file = File(filePath);
      final soll = expectedSha256?.toLowerCase();

      if (soll != null && soll.isNotEmpty && await file.exists() &&
          (await sha256.bind(file.openRead()).first).toString() == soll) {
        _log.info('Update schon geladen und geprüft: $filePath', tag: 'UPDATE');
        onProgress(1.0);
        return filePath;
      }

      _log.info('Downloading update to: $filePath', tag: 'UPDATE');

      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await _client.send(request);

      if (response.statusCode == 200) {
        final totalBytes = response.contentLength ?? 0;
        int receivedBytes = 0;

        final sink = file.openWrite();
        await for (final chunk in response.stream) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          if (totalBytes > 0) {
            onProgress(receivedBytes / totalBytes);
          }
        }
        await sink.close();

        // Prüfen, bevor irgendetwas die Datei installiert — von selbst sieht
        // niemand zu, wenn ein abgebrochener Download eingespielt würde.
        if (soll != null && soll.isNotEmpty) {
          final ist = (await sha256.bind(file.openRead()).first).toString();
          if (ist != soll) {
            _log.error('SHA-256 falsch: erwartet $soll, geladen $ist', tag: 'UPDATE');
            await file.delete();
            return null;
          }
          _log.info('SHA-256 geprüft', tag: 'UPDATE');
        }

        _log.info('Update downloaded successfully: $filePath', tag: 'UPDATE');
        return filePath;
      }
    } catch (e) {
      _log.error('Update download failed: $e', tag: 'UPDATE');
    }
    return null;
  }

  /// Launch the installer (cross-platform)
  /// - Windows: Inno Setup with silent flags
  /// - macOS: Open DMG file
  /// - Linux: Make AppImage executable and run
  /// - Android: PackageInstaller-Session, ab Android 12 ohne Rückfrage
  /// - iOS: Open TestFlight URL (direct install not supported)
  ///
  /// false: es ging nicht (Android: abgebrochen, Paket kaputt …). Bei Erfolg
  /// kehrt der Aufruf auf Windows, Linux und Android nicht zurück — die App
  /// ist dann weg.
  Future<bool> launchInstaller(String installerPath, {bool silent = true}) async {
    _log.info('Launching installer: $installerPath (${PlatformService.platformName})', tag: 'UPDATE');

    if (Platform.isWindows) {
      // Windows: Inno Setup silent installer
      final args = silent
          ? ['/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART']
          : <String>[];
      await Process.start(installerPath, args, mode: ProcessStartMode.detached);
      exit(0);

    } else if (Platform.isMacOS) {
      // macOS: Open DMG file (user will drag to Applications)
      await Process.start('open', [installerPath], mode: ProcessStartMode.detached);
      // Don't exit on macOS - let user manually restart after installation
      return true;

    } else if (Platform.isLinux) {
      // Linux: Make AppImage executable and run
      await Process.run('chmod', ['+x', installerPath]);
      await Process.start(installerPath, [], mode: ProcessStartMode.detached);
      exit(0);

    } else if (Platform.isAndroid) {
      // ⚠️ Vorher stand hier `launchUrl(Uri.file(installerPath))`. Das kann
      // auf keinem unterstuetzten Geraet funktionieren: seit Android 7
      // (API 24 — genau unser minSdk) loest ein file://-URI, das an eine
      // fremde App gereicht wird, FileUriExposedException aus. Das Update
      // wurde also geladen und dann still verworfen.
      //
      // Seit dem 17.10.2026 über die PackageInstaller-Session von
      // packages/icd_installer (Kopie aus der Vorsitzer-App) statt
      // android_package_installer: ab Android 12 ersetzt sich die App ohne
      // zweiten Dialog — auf „Jetzt aktualisieren" wie von selbst
      // ([installUnattended]); geht das nicht, fragt Android wie bisher.
      //
      // REQUEST_INSTALL_PACKAGES war bereits deklariert — die Berechtigung
      // allein half nur nichts, solange der Pfad nicht uebergeben werden
      // konnte.
      //
      // ⚠️ Kommt die Antwort, kam das Update NICHT durch: bei Erfolg beendet
      // Android die App vorher.
      _log.info('Installiere APK: $installerPath', tag: 'UPDATE');
      try {
        final status = await IcdInstaller.apkInstallieren(installerPath, ohneNachfrage: true);
        _log.info('APK-Installation: ${status.name}', tag: 'UPDATE');
        // Wartet schon eine Installation derselben Fassung: die läuft weiter.
        return status == InstallStatus.laeuft;
      } catch (e) {
        _log.error('APK-Installation fehlgeschlagen: $e', tag: 'UPDATE');
        return false;
      }

    } else if (Platform.isIOS) {
      // iOS: Direct installation not supported - redirect to download page
      _log.warning('iOS direct update not supported - use TestFlight', tag: 'UPDATE');
      // Could open a URL to TestFlight or download page
    }
    return false;
  }

  /// Check if automatic updates are supported on current platform
  bool get supportsAutoUpdate {
    // iOS doesn't support direct APK/IPA installation
    return !Platform.isIOS;
  }
}

/// Update information model
class UpdateInfo {
  final String version;
  final int buildNumber;
  final String downloadUrl;
  final String changelog;
  final String? minVersion;
  final bool forceUpdate;

  /// SHA-256 des APK aus dem Manifest (klein geschrieben, hex) — `null` bei
  /// einem Manifest ohne das Feld; dann wird ungeprüft geladen.
  final String? sha256;

  UpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.downloadUrl,
    required this.changelog,
    this.minVersion,
    this.forceUpdate = false,
    this.sha256,
  });
}
