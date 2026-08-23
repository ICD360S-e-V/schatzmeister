import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../utils/message_emotion.dart';
import 'chat_attachment_item.dart';

/// A chat message bubble with optional attachments
class ChatMessageBubble extends StatefulWidget {
  final Map<String, dynamic> message;
  final bool isOwn;
  final Function(Map<String, dynamic>) onDownloadAttachment;

  /// Speichert eine Reaktion auf dem Server. [reactionKey] ist '' zum Löschen.
  /// Gibt true bei Erfolg zurück; bei false nimmt die Blase ihre optimistische
  /// Anzeige wieder zurück. Ist der Rückruf null, gibt es keine Reaktionen.
  final Future<bool> Function(int messageId, String reactionKey)? onReact;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isOwn,
    required this.onDownloadAttachment,
    this.onReact,
  });

  @override
  State<ChatMessageBubble> createState() => _ChatMessageBubbleState();
}

class _ChatMessageBubbleState extends State<ChatMessageBubble> {
  static final _urlRegex = RegExp(r'https?://[^\s<>\"\)]+', caseSensitive: false);
  bool _showCopied = false;
  bool _isHidden = false;
  Offset _reactTapPos = Offset.zero;
  int _tapCount = 0;
  DateTime? _lastTapTime;

  /// Öffnet das Auswahlband und speichert die Wahl optimistisch: die Blase
  /// zeigt die Reaktion sofort, nimmt sie aber zurück, wenn der Server sie
  /// ablehnt. Ohne das wirkt ein Fehlschlag wie ein Erfolg.
  Future<void> _openReactionPicker(MessageEmotion? current) async {
    final pick = await showEmotionPicker(context, _reactTapPos, current: current);
    if (pick == null || !mounted) return;

    final previous = widget.message['reaction'];
    final newKey = pick.emotion?.storageKey; // null => entfernen

    setState(() {
      if (newKey == null) {
        widget.message.remove('reaction');
      } else {
        widget.message['reaction'] = newKey;
      }
    });

    final rawId = widget.message['id'];
    final messageId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (messageId == null || widget.onReact == null) return;

    final ok = await widget.onReact!(messageId, newKey ?? '');
    if (!ok && mounted) {
      setState(() {
        if (previous == null) {
          widget.message.remove('reaction');
        } else {
          widget.message['reaction'] = previous;
        }
      });
    }
  }

  void _copyMessage(String text) {
    Clipboard.setData(ClipboardData(text: text));
    setState(() => _showCopied = true);
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _showCopied = false);
    });
  }

  void _handleTap() {
    final now = DateTime.now();
    if (_lastTapTime != null && now.difference(_lastTapTime!).inMilliseconds < 400) {
      _tapCount++;
    } else {
      _tapCount = 1;
    }
    _lastTapTime = now;

    // Triple tap = hide/show message
    if (_tapCount >= 3) {
      setState(() => _isHidden = !_isHidden);
      _tapCount = 0;
    }
    // Double tap = copy (handled after short delay to not conflict with triple)
    else if (_tapCount == 2) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (_tapCount == 2) {
          final messageText = widget.message['message'] ?? '';
          if (messageText.toString().isNotEmpty && !messageText.toString().startsWith('[')) {
            _copyMessage(messageText);
          }
          _tapCount = 0;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final attachments = List<Map<String, dynamic>>.from(widget.message['attachments'] ?? []);
    final status = widget.message['status'] ?? 'sent';
    final messageText = widget.message['message'] ?? '';
    final hasTextMessage = messageText.toString().isNotEmpty &&
                           !messageText.toString().startsWith('[');

    // 🆕 URGENT message support
    final isUrgent = widget.message['is_urgent'] == true || widget.message['is_urgent'] == 1;

    // Generate stars based on message length
    final hiddenText = _isHidden ? '★' * (messageText.toString().length.clamp(3, 20)) : messageText;

    // Reaktion im WhatsApp-Stil. Eigentumsregel: man reagiert auf Nachrichten
    // der GEGENSEITE, nie auf eigene. Eine von der Gegenseite gesetzte
    // Reaktion wird auf eigenen Blasen trotzdem angezeigt — nur nicht änderbar.
    final reaction = emotionFromKey(widget.message['reaction']);
    // `reaction != null` genügt nicht: liegt ein Schlüssel an, den diese App
    // nicht kennt (Gegenseite ist neuer), sähe die Blase leer aus — genau der
    // Fall, der früher als „die Reaktion kommt nicht an" gemeldet wurde.
    final reaktionDa = hatReaktion(widget.message['reaction']);
    final canReact = !widget.isOwn && widget.onReact != null;

    return Align(
      alignment: widget.isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: hasTextMessage ? _handleTap : null,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              // Liegt eine Reaktion an, hält die Blase unten genau
              // `kReaktionUeberhang` frei: die Plakette hängt *im* Stack, weil
              // Flutter außerhalb der Elterngrenzen keine Treffer auswertet.
              // Ein negativer Offset wäre sichtbar, aber nicht antippbar.
              margin: EdgeInsets.only(
                bottom: reaktionDa ? 8 + kReaktionUeberhang : 8,
                left: widget.isOwn ? 50 : 0,
                // Platz für den Auslöser NEBEN der Blase statt über dem Text.
                right: widget.isOwn
                    ? 0
                    : (reaktionDa ? 50 : 50 + kAusloeserRand),
              ),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                // 🆕 Red background for urgent messages
                color: isUrgent
                    ? (widget.isOwn ? Colors.red.shade900 : Colors.red.shade50)
                    : (widget.isOwn ? const Color(0xFF1a1a2e) : Colors.white),
                // 🆕 Red border for urgent messages
                border: isUrgent ? Border.all(color: Colors.red, width: 2) : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🆕 URGENT badge (shows for all urgent messages)
                  if (isUrgent)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.warning, color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              AppLocalizations.of(context).urgentBadge,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Sender name (only for non-own messages)
                  if (!widget.isOwn)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        widget.message['sender_name'] ?? AppLocalizations.of(context).userLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: isUrgent ? Colors.red.shade900 : Colors.blue.shade700,
                        ),
                      ),
                    ),
                  // Message text (hidden = stars, with clickable links)
                  if (hasTextMessage)
                    _isHidden
                        ? Text(
                            hiddenText,
                            style: TextStyle(
                              color: widget.isOwn ? Colors.white38 : Colors.black38,
                              letterSpacing: 2,
                            ),
                          )
                        : _buildLinkifiedText(hiddenText.toString(), widget.isOwn),
                  // Translation indicator
                  if (widget.message['is_translated'] == true && !_isHidden)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.translate,
                            size: 10,
                            color: widget.isOwn ? Colors.white54 : Colors.grey.shade400,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            AppLocalizations.of(context).translatedLabel,
                            style: TextStyle(
                              fontSize: 9,
                              fontStyle: FontStyle.italic,
                              color: widget.isOwn ? Colors.white54 : Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Attachments
                  if (attachments.isNotEmpty) ...[
                    if (hasTextMessage) const SizedBox(height: 8),
                    ...attachments.map((att) => ChatAttachmentItem(
                      attachment: att,
                      isOwn: widget.isOwn,
                      onDownload: widget.onDownloadAttachment,
                    )),
                  ],
                  // Time and read receipt
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(widget.message['created_at']),
                          style: TextStyle(
                            fontSize: 10,
                            color: widget.isOwn ? Colors.white70 : Colors.grey.shade500,
                          ),
                        ),
                        // Read receipt checkmarks (only for own messages)
                        if (widget.isOwn) ...[
                          const SizedBox(width: 4),
                          _buildReadReceipt(status),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // "Kopiert!" tooltip - appears briefly after double-click
            if (_showCopied)
              Positioned(
                top: -25,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade700,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      AppLocalizations.of(context).copiedLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            // Gesetzte Reaktion: Plakette am unteren Rand, überlappend — dort
            // sucht das Auge sie, und sie steht nicht über dem Text. Auf der
            // eigenen (rechtsbündigen) Blase links, auf der fremden rechts:
            // jeweils zur Mitte hin, weg von Uhrzeit und Lesehaken.
            if (reaktionDa)
              Positioned(
                bottom: 0,
                left: widget.isOwn ? 60 : null,
                right: widget.isOwn ? null : 60,
                child: canReact
                    ? GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (d) => _reactTapPos = d.globalPosition,
                        onTap: () => _openReactionPicker(reaction),
                        child: ReaktionsPlakette(
                            schluessel: widget.message['reaction']),
                      )
                    : ReaktionsPlakette(schluessel: widget.message['reaction']),
              )
            // Noch keine Reaktion: der Auslöser sitzt senkrecht mittig im
            // freien Rand rechts neben der fremden Blase — nicht über der
            // ersten Textzeile, wo er Inhalt verdecken würde.
            else if (canReact)
              Positioned(
                top: 0,
                bottom: 0,
                right: 10,
                child: Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) => _reactTapPos = d.globalPosition,
                    onTap: () => _openReactionPicker(null),
                    child: const AddReactionButton(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkifiedText(String text, bool isOwn) {
    final matches = _urlRegex.allMatches(text).toList();
    if (matches.isEmpty) {
      return Text(text, style: TextStyle(color: isOwn ? Colors.white : Colors.black87));
    }
    final spans = <TextSpan>[];
    int lastEnd = 0;
    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      final url = match.group(0)!;
      spans.add(TextSpan(
        text: url,
        style: TextStyle(
          color: isOwn ? Colors.lightBlueAccent : Colors.blue.shade700,
          decoration: TextDecoration.underline,
        ),
        recognizer: TapGestureRecognizer()..onTap = () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }
    return RichText(
      text: TextSpan(
        style: TextStyle(color: isOwn ? Colors.white : Colors.black87, fontSize: 14),
        children: spans,
      ),
    );
  }

  Widget _buildReadReceipt(String status) {
    // WhatsApp style: ✓ = sent, ✓✓ = delivered, ✓✓ blue = read
    switch (status) {
      case 'read':
        return const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.done_all, size: 14, color: Colors.lightBlueAccent),
          ],
        );
      case 'delivered':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.done_all, size: 14, color: Colors.white.withValues(alpha: 0.7)),
          ],
        );
      case 'sent':
      default:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.done, size: 14, color: Colors.white.withValues(alpha: 0.7)),
          ],
        );
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final messageDate = DateTime(date.year, date.month, date.day);

      if (messageDate == today) {
        return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } else {
        return '${date.day}.${date.month}. ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return '';
    }
  }
}
