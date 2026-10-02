import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import '../services/logger_service.dart';

/// Debug Console Dialog - shows app logs
class DebugConsole extends StatefulWidget {
  const DebugConsole({super.key});

  @override
  State<DebugConsole> createState() => _DebugConsoleState();
}

class _DebugConsoleState extends State<DebugConsole> {
  final _logger = LoggerService();
  final _scrollController = ScrollController();
  List<LogEntry> _logs = [];
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    _logs = _logger.logs;
    _logger.logStream.listen((logs) {
      if (mounted) {
        setState(() => _logs = logs);
        if (_autoScroll) {
          _scrollToBottom();
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _copyLogs() {
    final text = _logger.exportLogs();
    Clipboard.setData(ClipboardData(text: text));
    final loc = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(loc.logsCopied),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Entschieden wird nach der Breite, die der Dialog wirklich bekommt.
    return LayoutBuilder(builder: _baueDialog);
  }

  Widget _baueDialog(BuildContext context, BoxConstraints constraints) {
    final loc = AppLocalizations.of(context);
    // Telefon: ganzer Bildschirm, Kopf in zwei Zeilen — Titel, Zähler und
    // vier Knöpfe passen nicht in 393 dp.
    final schmal = constraints.maxWidth < 600;
    final titel = Text(
      loc.debugConsole,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
    final anzahl = Text(
      loc.entriesCount(_logs.length),
      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
    );
    final knoepfe = [
      IconButton(
        icon: Icon(
          _autoScroll ? Icons.vertical_align_bottom : Icons.vertical_align_center,
          color: _autoScroll ? Colors.green : Colors.grey,
        ),
        onPressed: () => setState(() => _autoScroll = !_autoScroll),
        tooltip: _autoScroll ? loc.autoScrollOn : loc.autoScrollOff,
      ),
      IconButton(
        icon: const Icon(Icons.copy, color: Colors.blue),
        onPressed: _copyLogs,
        tooltip: loc.copyLogs,
      ),
      IconButton(
        icon: const Icon(Icons.delete_outline, color: Colors.red),
        onPressed: () {
          _logger.clear();
          setState(() => _logs = []);
        },
        tooltip: loc.deleteLogs,
      ),
    ];
    final schliessen = IconButton(
      icon: const Icon(Icons.close),
      onPressed: () => Navigator.pop(context),
    );
    return Dialog(
      insetPadding: schmal ? EdgeInsets.zero : null,
      shape: schmal ? const RoundedRectangleBorder() : RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: schmal ? constraints.maxWidth : 700,
        height: schmal ? constraints.maxHeight : 500,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            if (schmal) ...[
              Row(
                children: [
                  const Icon(Icons.terminal, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(child: titel),
                  schliessen,
                ],
              ),
              Row(
                children: [
                  Expanded(child: anzahl),
                  ...knoepfe,
                ],
              ),
            ] else
              Row(
                children: [
                  const Icon(Icons.terminal, color: Colors.green),
                  const SizedBox(width: 8),
                  titel,
                  const Spacer(),
                  anzahl,
                  const SizedBox(width: 16),
                  ...knoepfe,
                  schliessen,
                ],
              ),
            const Divider(),

            // Logs
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1e1e1e),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _logs.isEmpty
                    ? Center(
                        child: Text(
                          loc.noLogs,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(8),
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          final entry = _logs[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: Text(
                              entry.toString(),
                              style: TextStyle(
                                fontFamily: 'Consolas',
                                fontSize: 12,
                                color: _getLogColor(entry.level),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getLogColor(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Colors.grey;
      case LogLevel.info:
        return Colors.white;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
    }
  }
}

/// Shows the debug console dialog
void showDebugConsole(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const DebugConsole(),
  );
}
