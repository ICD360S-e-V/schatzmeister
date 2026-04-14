import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../services/platform_service.dart';

// Platform-specific imports
import 'package:webview_flutter/webview_flutter.dart' as mobile_webview;

// Windows-specific WebView (conditional)
import 'package:webview_windows/webview_windows.dart' as windows_webview;

/// Cross-Platform WebView Screen
/// - Windows: webview_windows (Edge WebView2)
/// - macOS/Linux: Opens in external browser (webview_flutter desktop not stable)
/// - Android/iOS: webview_flutter (native WebView)
class WebViewScreen extends StatefulWidget {
  final String title;
  final String url;
  final String? autoFillUsername;
  final String? autoFillPassword;

  const WebViewScreen({
    super.key,
    required this.title,
    required this.url,
    this.autoFillUsername,
    this.autoFillPassword,
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  // Windows WebView controller
  windows_webview.WebviewController? _windowsController;

  // Mobile WebView controller
  mobile_webview.WebViewController? _mobileController;

  bool _isLoading = true;
  bool _isInitialized = false;
  String _currentUrl = '';

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    if (Platform.isWindows) {
      await _initWindowsWebView();
    } else if (Platform.isMacOS || PlatformService.isMobile) {
      // macOS uses WKWebView via webview_flutter (same as iOS)
      await _initMobileWebView();
    } else {
      // Linux: Open in external browser
      await _openInExternalBrowser();
    }
  }

  /// Initialize Windows WebView (Edge WebView2)
  Future<void> _initWindowsWebView() async {
    try {
      _windowsController = windows_webview.WebviewController();
      await _windowsController!.initialize();

      _windowsController!.url.listen((url) {
        if (mounted) {
          setState(() {
            _currentUrl = url;
          });
        }
      });

      _windowsController!.loadingState.listen((state) {
        if (mounted) {
          setState(() {
            _isLoading = state == windows_webview.LoadingState.loading;
          });
          if (state == windows_webview.LoadingState.navigationCompleted) {
            _tryAutoFill();
          }
        }
      });

      await _windowsController!.setBackgroundColor(Colors.white);
      await _windowsController!.loadUrl(widget.url);

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      _showError('Windows WebView Fehler: $e');
    }
  }

  /// Initialize WebView (macOS/iOS/Android via WKWebView/native)
  Future<void> _initMobileWebView() async {
    try {
      debugPrint('[WebView] Initializing for ${Platform.operatingSystem}...');
      final controller = mobile_webview.WebViewController();
      await controller.setJavaScriptMode(mobile_webview.JavaScriptMode.unrestricted);
      // setBackgroundColor not supported on macOS WKWebView (opaque not implemented)
      if (!Platform.isMacOS) {
        await controller.setBackgroundColor(Colors.white);
      }
      await controller.setNavigationDelegate(
        mobile_webview.NavigationDelegate(
          onPageStarted: (url) {
            debugPrint('[WebView] Page started: $url');
            if (mounted) {
              setState(() {
                _isLoading = true;
                _currentUrl = url;
              });
            }
          },
          onPageFinished: (url) {
            debugPrint('[WebView] Page finished: $url');
            if (mounted) {
              setState(() {
                _isLoading = false;
                _currentUrl = url;
              });
            }
            // Auto-fill credentials if provided
            _tryAutoFill();
          },
          onWebResourceError: (error) {
            debugPrint('[WebView] Error: ${error.description}');
          },
        ),
      );
      await controller.loadRequest(Uri.parse(widget.url));
      _mobileController = controller;

      debugPrint('[WebView] Initialized successfully');
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e, stack) {
      debugPrint('[WebView] Init ERROR: $e');
      debugPrint('[WebView] Stack: $stack');
      _showError('WebView Fehler: $e');
    }
  }

  /// macOS/Linux: Open URL in system browser
  Future<void> _openInExternalBrowser() async {
    final uri = Uri.parse(widget.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      // Close this screen since we opened external browser
      if (mounted) {
        Navigator.pop(context);
      }
    } else {
      if (mounted) {
        _showError(AppLocalizations.of(context).couldNotOpenBrowser);
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _windowsController?.dispose();
    super.dispose();
  }

  bool _autoFillDone = false;

  /// Auto-fill login credentials via JavaScript injection
  Future<void> _tryAutoFill() async {
    if (_autoFillDone) return;
    final user = widget.autoFillUsername;
    final pass = widget.autoFillPassword;
    if (user == null || user.isEmpty) return;

    // Escape quotes for JS string safety
    final jsUser = user.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
    final jsPass = (pass ?? '').replaceAll('\\', '\\\\').replaceAll("'", "\\'");

    final js = '''
(function() {
  // Find username/email field
  var userField = document.querySelector('input[type="email"]')
    || document.querySelector('input[name*="user" i]')
    || document.querySelector('input[name*="email" i]')
    || document.querySelector('input[name*="login" i]')
    || document.querySelector('input[autocomplete="username"]')
    || document.querySelector('input[type="text"]');
  // Find password field
  var passField = document.querySelector('input[type="password"]');

  if (userField) {
    userField.value = '$jsUser';
    userField.dispatchEvent(new Event('input', {bubbles: true}));
    userField.dispatchEvent(new Event('change', {bubbles: true}));
  }
  if (passField) {
    passField.value = '$jsPass';
    passField.dispatchEvent(new Event('input', {bubbles: true}));
    passField.dispatchEvent(new Event('change', {bubbles: true}));
  }
  return (userField ? 'user:ok' : 'user:miss') + ' ' + (passField ? 'pass:ok' : 'pass:miss');
})();
''';

    try {
      if (Platform.isWindows && _windowsController != null) {
        await _windowsController!.executeScript(js);
        _autoFillDone = true;
        debugPrint('[WebView] Auto-fill injected (Windows)');
      } else if (_mobileController != null) {
        final result = await _mobileController!.runJavaScriptReturningResult(js);
        _autoFillDone = true;
        debugPrint('[WebView] Auto-fill result: $result');
      }
    } catch (e) {
      debugPrint('[WebView] Auto-fill error: $e');
    }
  }

  // Navigation methods
  Future<void> _goBack() async {
    if (Platform.isWindows) {
      _windowsController?.goBack();
    } else if (_mobileController != null) {
      if (await _mobileController!.canGoBack()) {
        _mobileController!.goBack();
      }
    }
  }

  Future<void> _goForward() async {
    if (Platform.isWindows) {
      _windowsController?.goForward();
    } else if (_mobileController != null) {
      if (await _mobileController!.canGoForward()) {
        _mobileController!.goForward();
      }
    }
  }

  Future<void> _reload() async {
    if (Platform.isWindows) {
      _windowsController?.reload();
    } else {
      _mobileController?.reload();
    }
  }

  Future<void> _loadHome() async {
    if (Platform.isWindows) {
      _windowsController?.loadUrl(widget.url);
    } else {
      _mobileController?.loadRequest(Uri.parse(widget.url));
    }
  }

  Future<void> _openExternal() async {
    final url = _currentUrl.isNotEmpty ? _currentUrl : widget.url;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color(0xFF4a90d9),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _goBack,
            tooltip: loc.backNav,
          ),
          // Forward button
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: _goForward,
            tooltip: loc.forwardNav,
          ),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
            tooltip: loc.refreshNav,
          ),
          // Home button
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: _loadHome,
            tooltip: loc.homePage,
          ),
          // Open in external browser
          IconButton(
            icon: const Icon(Icons.open_in_new),
            onPressed: _openExternal,
            tooltip: loc.openInBrowser,
          ),
        ],
      ),
      body: Column(
        children: [
          // Loading indicator
          if (_isLoading)
            const LinearProgressIndicator(
              backgroundColor: Colors.grey,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4a90d9)),
            ),
          // URL bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                Icon(
                  Icons.lock,
                  size: 16,
                  color: _currentUrl.startsWith('https')
                      ? Colors.green
                      : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _currentUrl.isNotEmpty ? _currentUrl : widget.url,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // WebView content (platform-specific)
          Expanded(
            child: _buildWebViewContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildWebViewContent() {
    if (!_isInitialized) {
      final loc = AppLocalizations.of(context);
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(loc.browserLoading),
          ],
        ),
      );
    }

    if (Platform.isWindows && _windowsController != null) {
      return windows_webview.Webview(_windowsController!);
    } else if ((Platform.isMacOS || PlatformService.isMobile) && _mobileController != null) {
      return mobile_webview.WebViewWidget(controller: _mobileController!);
    }

    // Fallback - should not reach here
    final loc = AppLocalizations.of(context);
    return Center(
      child: Text(loc.webviewNotSupported),
    );
  }
}
