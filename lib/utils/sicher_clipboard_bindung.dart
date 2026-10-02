import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'sicher_clipboard.dart';

/// Das Binding der App: wie [WidgetsFlutterBinding], nur geht JEDES
/// [Clipboard.setData] über [SicherClipboard] — auf Android sensibel markiert,
/// überall nach 30 s gelöscht.
///
/// WARUM: „Kopieren" im Kontextmenü (Rechtsklick, langes Drücken) jedes
/// Textfelds und jedes SelectableText und die Kopier-Knöpfe rufen Flutters
/// [Clipboard.setData] direkt — keiner davon muss so davon wissen, auch kein
/// künftiger. Wie in der Vorsitzer-App (#1045, 02.10.2026).
///
/// ⚠️ `main` legt DIESES Binding an, als Allererstes. Ein Test hält das fest.
class SicherClipboardBindung extends WidgetsFlutterBinding {
  /// Wie [WidgetsFlutterBinding.ensureInitialized]. Steht schon ein Binding
  /// (im Test), bleibt es.
  static WidgetsBinding ensureInitialized() {
    if (!_steht()) SicherClipboardBindung();
    return WidgetsBinding.instance;
  }

  /// Ob schon ein Binding steht. Flutter fragt dafür ein privates Feld ab;
  /// von außen bleibt nur der Versuch.
  static bool _steht() {
    try {
      WidgetsBinding.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  BinaryMessenger createBinaryMessenger() =>
      SicherClipboardBote(super.createBinaryMessenger());
}

/// Der Bote zur Plattform: reicht alles unverändert durch, nur
/// `Clipboard.setData` nicht.
///
///  * **Android:** der Text geht an [SicherClipboard.nativ]; nur wenn der
///    Kanal fehlt, kopiert Flutter selbst, und ein Dart-Timer leert.
///  * **Sonst:** Flutter kopiert selbst — die Nachricht geht im SELBEN Takt
///    weiter —, und [SicherClipboard.spaeterLeeren] leert nach 30 s.
///
/// Die Reihenfolge der Nachrichten bleibt (Flutter verlangt das von jedem
/// Boten): auch der Weg über den Kanal wird im selben Takt abgeschickt.
class SicherClipboardBote extends BinaryMessenger {
  SicherClipboardBote(
    this._innen, {
    Future<bool> Function(String text)? kopieren,
    void Function()? spaeterLeeren,
    bool? mitKanal,
  })  : _kopieren = kopieren ?? SicherClipboard.nativ,
        _spaeterLeeren = spaeterLeeren ?? SicherClipboard.spaeterLeeren,
        _mitKanal = mitKanal ?? Platform.isAndroid;

  final BinaryMessenger _innen;
  final Future<bool> Function(String text) _kopieren;
  final void Function() _spaeterLeeren;

  /// Gibt es den nativen Kanal (Android)?
  final bool _mitKanal;

  @override
  Future<void> handlePlatformMessage(
    String channel,
    ByteData? data,
    ui.PlatformMessageResponseCallback? callback,
  ) {
    // ignore: deprecated_member_use
    return _innen.handlePlatformMessage(channel, data, callback);
  }

  @override
  Future<ByteData?>? send(String channel, ByteData? message) {
    final text =
        channel == SystemChannels.platform.name ? kopierterText(message) : null;
    if (text == null) return _innen.send(channel, message);
    if (!_mitKanal) {
      final antwort = _innen.send(channel, message);
      // Leerer Text ist schon das Leeren — der plant nichts.
      if (text.isNotEmpty) _spaeterLeeren();
      return antwort;
    }
    return _abfangen(text, channel, message);
  }

  Future<ByteData?> _abfangen(
      String text, String channel, ByteData? message) async {
    if (await _kopieren(text)) {
      return const JSONMethodCodec().encodeSuccessEnvelope(null);
    }
    // Der Kanal fehlt: wie Flutter es selbst täte, und der Dart-Timer leert.
    final antwort = await _innen.send(channel, message);
    if (text.isNotEmpty) _spaeterLeeren();
    return antwort;
  }

  @override
  void setMessageHandler(String channel, MessageHandler? handler) =>
      _innen.setMessageHandler(channel, handler);
}

/// Der Text eines `Clipboard.setData` auf dem Plattform-Kanal — bei jeder
/// anderen Nachricht null.
@visibleForTesting
String? kopierterText(ByteData? message) {
  if (message == null) return null;
  try {
    final call = const JSONMethodCodec().decodeMethodCall(message);
    if (call.method != 'Clipboard.setData') return null;
    final args = call.arguments;
    return args is Map && args['text'] is String ? args['text'] as String : null;
  } catch (_) {
    return null;
  }
}
