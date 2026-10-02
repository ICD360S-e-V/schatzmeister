import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HardwareKeyboard;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'screens/login_with_code_screen.dart';
import 'screens/sprachauswahl_screen.dart';
import 'services/api_service.dart';
import 'services/language_service.dart';
import 'services/notification_service.dart';
import 'services/logger_service.dart';
import 'services/startup_service.dart';
import 'services/platform_service.dart';
import 'widgets/remote_touch_overlay.dart';

// Desktop-only packages (compile on all platforms, but only used on desktop)
import 'package:window_manager/window_manager.dart';
import 'services/tray_service.dart';

// Windows-only package
import 'package:windows_single_instance/windows_single_instance.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Gewählte Sprache vor dem ersten Bild laden — sonst blitzte die
  // Oberfläche einen Frame lang auf Deutsch auf.
  await LanguageService.instance.load();

  // ============================================================
  // DESKTOP-ONLY INITIALIZATION
  // ============================================================
  if (PlatformService.isDesktop) {
    // Windows: Ensure only one instance of the app runs at a time
    if (Platform.isWindows) {
      await WindowsSingleInstance.ensureSingleInstance(
        [],
        'icd360sev_schatzmeister_single_instance',
        onSecondWindow: (args) {
          // This callback runs when a second instance tries to start
          // Show the existing window
          TrayService().showWindow();
        },
      );
    }

    // Initialize window manager and maximize window
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      minimumSize: Size(800, 600),
      center: true,
      title: 'ICD360S e.V - Schatzmeister Portal',
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.maximize();
      await windowManager.show();
      await windowManager.focus();
    });

    // Initialize system tray (desktop only)
    await TrayService().initialize();
  }

  // ============================================================
  // CROSS-PLATFORM INITIALIZATION
  // ============================================================

  // Initialize logger service (device ID)
  await LoggerService().init();

  // Initialize API service (device key + tokens)
  await ApiService().initialize();

  // Initialize notification service
  await NotificationService().initialize();

  // Initialize startup service (auto-start with OS - desktop only)
  await StartupService().initialize();

  // Diagnostic service will be started from LoginScreen after user consent

  // Fix Flutter keyboard desync bug on desktop (github.com/flutter/flutter/issues/125975)
  // When HardwareKeyboard state desyncs, re-sync and clear pressed keys
  FlutterError.onError = (FlutterErrorDetails details) {
    final message = details.exceptionAsString();
    if (message.contains('KeyDownEvent') || message.contains('KeyUpEvent') || message.contains('KeyRepeatEvent')) {
      if (message.contains('physical key is already pressed') ||
          message.contains('physical key is not pressed') ||
          message.contains('pressed on a different logical key')) {
        // Re-sync keyboard state with engine immediately and after a short delay
        HardwareKeyboard.instance.syncKeyboardState();
        Future.delayed(const Duration(milliseconds: 100), () {
          HardwareKeyboard.instance.syncKeyboardState();
        });
        return;
      }
    }
    FlutterError.presentError(details);
  };

  runApp(const SchatzmeisterApp());
}

class SchatzmeisterApp extends StatefulWidget {
  const SchatzmeisterApp({super.key});

  @override
  State<SchatzmeisterApp> createState() => _SchatzmeisterAppState();
}

class _SchatzmeisterAppState extends State<SchatzmeisterApp> {
  @override
  void initState() {
    super.initState();

    LanguageService.instance.localeNotifier.addListener(_spracheGewechselt);

    // Desktop-only: Add window listener for tray minimize
    if (PlatformService.isDesktop) {
      _initDesktopWindowListener();
    }
  }

  @override
  void dispose() {
    LanguageService.instance.localeNotifier.removeListener(_spracheGewechselt);
    super.dispose();
  }

  /// Sprachwechsel: alles neu zeichnen.
  ///
  /// setState allein reicht nicht. Texte über tr() lesen die Sprache ohne
  /// BuildContext und hängen damit nicht an Localizations — solche Widgets
  /// (auch konstante) würden erst beim nächsten zufälligen Neuaufbau
  /// umschalten. Darum wird jedes Element darunter als veraltet markiert,
  /// auch in offenen Dialogen und Routen.
  void _spracheGewechselt() {
    setState(() {});
    void neu(Element e) {
      e.markNeedsBuild();
      e.visitChildren(neu);
    }

    (context as Element).visitChildren(neu);
  }

  void _initDesktopWindowListener() {
    windowManager.addListener(_DesktopWindowListener());
    // Prevent window from closing, minimize to tray instead
    windowManager.setPreventClose(true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Fenstertitel bzw. Name in der Android-Übersicht, in der gewählten Sprache.
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      // Navigator key for in-app notifications overlay
      navigatorKey: NotificationService.navigatorKey,
      // DE + RO — gewählt auf dem Sprachauswahlbildschirm, nicht mehr aus
      // der Geräteeinstellung abgeleitet.
      locale: LanguageService.instance.localeNotifier.value,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('de', 'DE'),
        Locale('ro', 'RO'),
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4a90d9),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        // Use system font on each platform
        fontFamily: Platform.isWindows ? 'Segoe UI' : null,
      ),
      // Fernwartung: zeigt während einer Sitzung, wohin getippt wird — im
      // geteilten Bild sieht der Vorsitz es mit. Ohne Sitzung unsichtbar.
      builder: (context, child) =>
          RemoteTouchOverlay(child: child ?? const SizedBox.shrink()),
      // Erster Start: erst die Sprache wählen, dann aktivieren.
      home: LanguageService.instance.hasUserChoice
          ? const LoginWithCodeScreen()
          : const SprachauswahlScreen(danach: LoginWithCodeScreen()),
    );
  }
}

/// Desktop-only window listener for tray minimize behavior
class _DesktopWindowListener extends WindowListener {
  @override
  void onWindowClose() async {
    // Instead of closing, hide to tray
    await TrayService().hideToTray();

    // Show notification that app is still running
    NotificationService().showSuccess(
      title: tr('App im Hintergrund', 'Aplicație în fundal'),
      message: tr(
        'ICD360S e.V läuft weiter im Hintergrund. Klicken Sie auf das Tray-Icon zum Öffnen.',
        'ICD360S e.V rulează în fundal. Faceți clic pe pictograma din tray pentru a deschide.',
      ),
    );
  }

  @override
  void onWindowFocus() {
    // Stop taskbar flashing when window gains focus
    TrayService().stopFlashing();
    // Re-sync keyboard state when window regains focus (fixes macOS keyboard desync)
    HardwareKeyboard.instance.syncKeyboardState();
    // Note: Don't clear unread count here - only clear when chat dialog is opened
    // This way the badge stays visible until user actually reads the messages
  }
}
