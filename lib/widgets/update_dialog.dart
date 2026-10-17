import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/language_service.dart';
import '../services/notification_service.dart';
import '../services/update_service.dart';

/// Update Available Dialog - prompts user to download and install update
class UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;

  const UpdateDialog({super.key, required this.updateInfo});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.system_update, color: Colors.blue.shade700),
          const SizedBox(width: 12),
          Flexible(child: Text(l.updateAvailable)),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.newVersionAvailable(widget.updateInfo.version),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              l.currentVersionLabel(UpdateService.currentVersion),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            if (widget.updateInfo.changelog.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                l.changes,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                constraints: const BoxConstraints(maxHeight: 150),
                child: SingleChildScrollView(
                  child: Text(
                    widget.updateInfo.changelog,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
            if (_isDownloading) ...[
              const SizedBox(height: 20),
              LinearProgressIndicator(value: _downloadProgress),
              const SizedBox(height: 8),
              Text(
                _downloadProgress < 1.0
                    ? l.downloadProgress((_downloadProgress * 100).toStringAsFixed(0))
                    : l.installationStarting,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Text(
                l.appWillRestart,
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!_isDownloading && !widget.updateInfo.forceUpdate)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.later),
          ),
        if (!_isDownloading)
          ElevatedButton.icon(
            onPressed: _downloadAndInstall,
            icon: const Icon(Icons.download),
            label: Text(l.updateNow),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        if (_isDownloading)
          TextButton(
            onPressed: null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(width: 8),
                Text(l.downloading),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _downloadAndInstall() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _errorMessage = null;
    });

    final updateService = UpdateService();
    final installerPath = await updateService.downloadUpdate(
      widget.updateInfo.downloadUrl,
      (progress) {
        if (mounted) setState(() => _downloadProgress = progress);
      },
      expectedSha256: widget.updateInfo.sha256,
    );

    // Launch installer and exit app. Kommt die Antwort, kam das Update nicht
    // durch (seit 17.10.2026 meldet Android auch einen Abbruch zurück) — dann
    // nicht ewig „wird installiert", sondern wieder der Knopf.
    final uebergeben =
        installerPath != null && await updateService.launchInstaller(installerPath);
    if (!uebergeben && mounted) {
      final l = AppLocalizations.of(context);
      setState(() {
        _isDownloading = false;
        _errorMessage = l.downloadFailed;
      });
    }
  }
}

/// Der kurze Hinweis, bevor die App für ein Update zugeht (Android, seit dem
/// 17.10.2026 von selbst — UpdateService.installUnattended).
///
/// Über [context], solange der noch steht, sonst über den Navigator der App:
/// das Paket ist oft erst Minuten später geladen.
void updateHinweisZeigen(String version, {BuildContext? context}) {
  final ort = context != null && context.mounted
      ? context
      : NotificationService.navigatorKey.currentContext;
  if (ort == null) return;
  ScaffoldMessenger.maybeOf(ort)?.showSnackBar(
    SnackBar(
      content: Text(tr(
        'Version $version wird im Hintergrund installiert. Die App startet gleich neu.',
        'Versiunea $version se instalează în fundal. Aplicația va reporni imediat.',
      )),
      duration: const Duration(seconds: 8),
    ),
  );
}

/// Shows update dialog if update is available
///
/// Auf Android installiert sich das Update seit dem 17.10.2026 von selbst —
/// wie bei der Vorsitzer-App: im Hintergrund laden, nie während eines Anrufs
/// oder einer Fernwartung, je Fassung ein Versuch, kurz davor der Hinweis
/// (UpdateService.installUnattended). Der Dialog kommt nur noch, wo das nicht
/// geht oder der Versuch nicht durchkam.
Future<void> checkAndShowUpdateDialog(BuildContext context) async {
  final updateService = UpdateService();
  // Ein Update von selbst läuft schon: nicht noch einmal prüfen, laden oder
  // fragen.
  if (updateService.unattendedInProgress) return;
  final updateInfo = await updateService.checkForUpdate();
  if (updateInfo == null) return;

  if (await updateService.installUnattended(
    updateInfo,
    vorDemNeustart: (v) => updateHinweisZeigen(v, context: context),
  )) {
    return; // Android installiert gerade, oder ein anderer Lauf ist dabei
  }

  if (context.mounted) {
    showDialog(
      context: context,
      barrierDismissible: !updateInfo.forceUpdate,
      builder: (context) => UpdateDialog(updateInfo: updateInfo),
    );
  }
}
