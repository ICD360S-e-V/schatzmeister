import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfrx/pdfrx.dart';
import '../l10n/app_localizations.dart';

/// In-app file viewer for PDFs and images
/// Features: View, Download (save as), Print
class FileViewerDialog extends StatelessWidget {
  final String filePath;
  final String fileName;

  const FileViewerDialog({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  /// Show file viewer - returns true if handled in-app, false if needs system app
  static Future<bool> show(BuildContext context, String filePath, String fileName) async {
    final ext = fileName.toLowerCase().split('.').last;

    if (ext == 'pdf' || ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
      await showDialog(
        context: context,
        builder: (context) => FileViewerDialog(filePath: filePath, fileName: fileName),
      );
      return true;
    }

    // Unsupported - caller should open with system app
    return false;
  }

  bool get _isPdf => fileName.toLowerCase().endsWith('.pdf');
  bool get _isImage {
    final ext = fileName.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
  }

  Future<void> _saveFile(BuildContext context) async {
    final loc = AppLocalizations.of(context);
    try {
      final dotIndex = fileName.lastIndexOf('.');
      final ext = dotIndex != -1 ? fileName.substring(dotIndex) : '';

      final result = await FilePicker.platform.saveFile(
        dialogTitle: loc.saveFile,
        fileName: fileName,
      );

      if (result != null) {
        final savePath = result.endsWith(ext) ? result : '$result$ext';
        await File(filePath).copy(savePath);
        if (context.mounted) {
          final savedName = savePath.split(Platform.pathSeparator).last;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.savedLabel(savedName)),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.errorSavingWith('$e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _printFile(BuildContext context) async {
    try {
      if (Platform.isMacOS) {
        // macOS: open print dialog via system
        await Process.run('open', ['-a', 'Preview', filePath]);
        // Preview will open, user can print from there with Cmd+P
      } else if (Platform.isWindows) {
        // Windows: open print dialog
        await Process.run('rundll32', ['mshtml.dll,PrintHTML', filePath]);
      }
    } catch (e) {
      if (context.mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.printError),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 800,
        height: 650,
        child: Column(
          children: [
            // Header with actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(
                    _isPdf ? Icons.picture_as_pdf : Icons.image,
                    color: _isPdf ? Colors.red : Colors.blue,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      fileName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Download button
                  IconButton(
                    icon: const Icon(Icons.download),
                    tooltip: loc.downloadTooltip,
                    onPressed: () => _saveFile(context),
                  ),
                  // Print button
                  IconButton(
                    icon: const Icon(Icons.print),
                    tooltip: loc.printTooltip,
                    onPressed: () => _printFile(context),
                  ),
                  const SizedBox(width: 4),
                  // Close button
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: _isPdf ? _buildPdfViewer() : _isImage ? _buildImageViewer() : const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfViewer() {
    return PdfViewer.file(filePath);
  }

  Widget _buildImageViewer() {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: Image.file(
          File(filePath),
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
