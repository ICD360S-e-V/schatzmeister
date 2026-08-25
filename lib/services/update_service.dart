import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:path_provider/path_provider.dart';
import 'package:android_package_installer/android_package_installer.dart';
import 'device_key_service.dart';
import 'platform_service.dart';
import 'logger_service.dart';

final _log = LoggerService();

/// Update Service - checks for app updates and handles download
/// Cross-platform: Windows (Inno Setup), macOS (DMG), Linux (AppImage),
/// Android (APK), iOS (not supported - use TestFlight)
class UpdateService {
  // Protected API endpoint (requires Device Key)
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
  static const String currentVersion = '1.0.23';
  static const int currentBuildNumber = 24;
  // ✅ SECURITY FIX: Removed hardcoded API key (extractable via reverse engineering)
  // All requests now use dynamic Device Key only

  late http.Client _client;
  late HttpClient _httpClient;
  final _deviceKeyService = DeviceKeyService();

  // Singleton
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal() {
    _httpClient = HttpClient();
    _client = IOClient(_httpClient);
  }

  /// Check if an update is available (protected endpoint - requires Device Key)
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final deviceKey = _deviceKeyService.deviceKey;

      // Build headers with Device Key authentication
      if (deviceKey == null) {
        _log.error('Device not registered - cannot check for updates', tag: 'UPDATE');
        return null;
      }

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'User-Agent': 'ICD360S-Schatzmeister/1.0',
        'X-Device-Key': deviceKey,
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

          // Compare versions
          if (_isNewerVersion(serverVersion, serverBuildNumber)) {
            return UpdateInfo(
              version: serverVersion,
              buildNumber: serverBuildNumber,
              downloadUrl: downloadUrl,
              changelog: changelog,
              minVersion: minVersion,
              forceUpdate: forceUpdate,
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
  Future<String?> downloadUpdate(String downloadUrl, Function(double) onProgress) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final separator = Platform.isWindows ? '\\' : '/';
      final filePath = '${tempDir.path}$separator${_getInstallerFilename()}';
      final file = File(filePath);

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
  /// - Android: Install APK via file manager
  /// - iOS: Open TestFlight URL (direct install not supported)
  Future<void> launchInstaller(String installerPath, {bool silent = true}) async {
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
      // AndroidPackageInstaller kapselt den PackageInstaller samt
      // FileProvider; der noetige <provider>-Eintrag steht im Manifest,
      // die Freigaben in res/xml/file_paths.xml.
      //
      // REQUEST_INSTALL_PACKAGES war bereits deklariert — die Berechtigung
      // allein half nur nichts, solange der Pfad nicht uebergeben werden
      // konnte.
      _log.info('Installiere APK: $installerPath', tag: 'UPDATE');
      try {
        final code = await AndroidPackageInstaller.installApk(apkFilePath: installerPath);
        final status = PackageInstallerStatus.byCode(code ?? -1);
        _log.info('APK-Installation: ${status.name}', tag: 'UPDATE');
      } catch (e) {
        _log.error('APK-Installation fehlgeschlagen: $e', tag: 'UPDATE');
      }
      // Kein exit(): das System uebernimmt und fragt den Benutzer.

    } else if (Platform.isIOS) {
      // iOS: Direct installation not supported - redirect to download page
      _log.warning('iOS direct update not supported - use TestFlight', tag: 'UPDATE');
      // Could open a URL to TestFlight or download page
    }
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

  UpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.downloadUrl,
    required this.changelog,
    this.minVersion,
    this.forceUpdate = false,
  });
}
