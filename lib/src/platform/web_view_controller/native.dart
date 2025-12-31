import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_monaco/flutter_monaco.dart';
import 'package:flutter_monaco/src/platform/platform_webview.dart';
import 'package:path/path.dart' as p;
import 'package:webview_flutter/webview_flutter.dart' as wf;
import 'package:webview_windows/webview_windows.dart' as ww;

/// A [PlatformWebViewController] implementation for native platforms.
///
/// This controller will return the appropriate native web view controller based on the platform.
abstract class WebViewController implements PlatformWebViewController {
  /// Creates a new native web view controller.
  factory WebViewController() {
    if (Platform.isWindows) {
      return WindowsWebViewController();
    } else {
      return FlutterWebViewController();
    }
  }

  const WebViewController._();

  Future<String> _ensureHtmlFile({
    String? customCss,
    bool allowCdnFonts = false,
  }) async {
    final htmlFilePath = await MonacoAssets.indexHtmlPath(
      cacheKey: Object.hash(customCss, allowCdnFonts),
    );

    // Use cache key in filename to avoid conflicts.
    final htmlFile = File(htmlFilePath);

    // Skip if file already exists (cached).
    if (htmlFile.existsSync()) {
      debugPrint('[MonacoAssets] Using cached HTML file: ${htmlFile.path}');
      return htmlFilePath;
    }

    // Generate platform-specific HTML
    String htmlContent;

    if (Platform.isWindows) {
      final targetDir = p.dirname(htmlFilePath);

      // Windows needs absolute paths since we load from file://
      final vsPath = p.join(targetDir, 'min', 'vs');
      final absoluteVsPath = Uri.file(vsPath).toString();
      htmlContent = MonacoAssets.generateIndexHtml(
        absoluteVsPath,
        isWindows: true,
        isIosOrMacOS: false,
        customCss: customCss,
        allowCdnFonts: allowCdnFonts,
      );
    } else {
      // macOS uses relative paths since HTML is in the same directory
      htmlContent = MonacoAssets.generateIndexHtml(
        p.join('min', 'vs'),
        isWindows: false,
        isIosOrMacOS: Platform.isIOS || Platform.isMacOS,
        customCss: customCss,
        allowCdnFonts: allowCdnFonts,
      );
    }

    // Write the HTML file
    await htmlFile.writeAsString(htmlContent);

    debugPrint('[MonacoAssets] HTML file created at: ${htmlFile.path}');
    return htmlFilePath;
  }
}

/// A [PlatformWebViewController] implementation for `webview_flutter`.
///
/// This controller is used on Android, iOS, and macOS.
class FlutterWebViewController extends WebViewController {
  /// Creates a new `webview_flutter` controller.
  FlutterWebViewController() : super._() {
    _controller = wf.WebViewController();
  }

  @override
  Widget get widget => wf.WebViewWidget(controller: _controller);

  late final wf.WebViewController _controller;
  bool _disposed = false;

  /// The underlying [wf.WebViewController] from the `webview_flutter` package.
  wf.WebViewController get flutterController => _controller;

  @override
  Future<void> initialize() async {
    /// Sets the JavaScript mode for the WebView.
    await _controller.setJavaScriptMode(wf.JavaScriptMode.unrestricted);

    // Set up console logging for debugging
    await _controller.setOnConsoleMessage((message) {
      debugPrint('[Monaco Console] ${message.level.name}: ${message.message}');
    });

    /// Sets the navigation delegate for the WebView.
    _controller.setNavigationDelegate(
      wf.NavigationDelegate(
        onPageFinished: (url) {
          debugPrint('[MonacoController] WebView Page Finished: $url');
        },
        onWebResourceError: (error) {
          debugPrint(
            '[MonacoController] WebView Error: ${error.description} on ${error.url}',
          );
        },
      ),
    );
  }

  /// Sets the background color of the WebView.
  Future<Object?> setBackgroundColor(Color color) async {
    await _controller.setBackgroundColor(color);
    return null;
  }

  /// Loads a Flutter asset into the WebView.
  Future<Object?> loadFlutterAsset(String asset) async {
    await _controller.loadFlutterAsset(asset);
    return null;
  }

  @override
  Future<Object?> runJavaScript(String script) async {
    try {
      await _controller.runJavaScript(script);
    } catch (e) {
      debugPrint('[FlutterWebViewController] JS execution error: $e');
      rethrow;
    }
    return null;
  }

  @override
  Future<Object?> runJavaScriptReturningResult(String script) async {
    try {
      return await _controller.runJavaScriptReturningResult(script);
    } catch (e) {
      debugPrint('[FlutterWebViewController] JS result error: $e');
      rethrow;
    }
  }

  @override
  Future<Object?> addJavaScriptChannel(
    String name,
    void Function(String) onMessage,
  ) async {
    await _controller.addJavaScriptChannel(
      name,
      onMessageReceived: (wf.JavaScriptMessage message) {
        onMessage(message.message);
      },
    );
    return null;
  }

  @override
  Future<void> load({String? customCss, bool allowCdnFonts = false}) async {
    final htmlFilePath = await _ensureHtmlFile(
      customCss: customCss,
      allowCdnFonts: allowCdnFonts,
    );
    await _controller.loadFile(htmlFilePath);
  }

  @override
  Future<Object?> removeJavaScriptChannel(String name) async {
    await _controller.removeJavaScriptChannel(name);
    return null;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
  }
}

/// A [PlatformWebViewController] implementation for `webview_windows`.
///
/// This controller is used on the Windows platform and wraps the
/// `WebviewController` from the `webview_windows` package.
class WindowsWebViewController extends WebViewController {
  /// Creates a new `webview_windows` controller.
  WindowsWebViewController() : super._() {
    _controller = ww.WebviewController();
  }

  @override
  Widget get widget => ww.Webview(_controller);

  late final ww.WebviewController _controller;
  final Map<String, void Function(String)> _channels = {};
  StreamSubscription<dynamic>? _webMessageSubscription;
  bool _isInitialized = false;
  bool _disposed = false;

  /// The underlying [ww.WebviewController] from the `webview_windows` package.
  ww.WebviewController get windowsController => _controller;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('[WindowsWebViewController] Initializing WebView2...');
    await _controller.initialize();
    _isInitialized = true;

    // Set up default configuration
    await _controller.setBackgroundColor(const Color(0xFF1E1E1E));
    await _controller.setPopupWindowPolicy(ww.WebviewPopupWindowPolicy.deny);

    // Set up message handler BEFORE adding any channels
    _setupWebMessageHandler();

    debugPrint('[WindowsWebViewController] WebView2 initialized successfully');
  }

  void _setupWebMessageHandler() {
    _webMessageSubscription?.cancel();

    _webMessageSubscription = _controller.webMessage.listen((
      dynamic rawMessage,
    ) {
      debugPrint(
        '[WindowsWebViewController] Raw message: $rawMessage (${rawMessage.runtimeType})',
      );

      try {
        String messageStr;

        if (rawMessage is String) {
          messageStr = rawMessage;
        } else if (rawMessage is Map) {
          messageStr = json.encode(rawMessage);
        } else {
          messageStr = rawMessage.toString();
        }

        _channels.forEach((channelName, handler) {
          debugPrint(
            '[WindowsWebViewController] Forwarding to channel: $channelName',
          );
          handler(messageStr);
        });
      } catch (e) {
        debugPrint('[WindowsWebViewController] Error handling message: $e');
      }
    });
  }

  /// Loads the given HTML string into the WebView.
  Future<void> loadHtmlString(String html, {String? baseUrl}) async {
    debugPrint(
      '[WindowsWebViewController] Loading HTML string (length: ${html.length})',
    );
    await _controller.loadStringContent(html);
  }

  @override
  Future<void> load({String? customCss, bool allowCdnFonts = false}) async {
    final htmlFilePath = await _ensureHtmlFile(
      customCss: customCss,
      allowCdnFonts: allowCdnFonts,
    );
    await _controller.loadUrl(htmlFilePath);
  }

  @override
  Future<Object?> runJavaScript(String script) async {
    try {
      return await _controller.executeScript(script);
    } catch (e) {
      debugPrint('[WindowsWebViewController] JS execution error: $e');
      rethrow;
    }
  }

  @override
  Future<dynamic> runJavaScriptReturningResult(String script) async {
    try {
      final result = await _controller.executeScript(script);

      if (result == null) return null;

      if (result is String) {
        final trimmed = result.trim();
        final looksLikeJson =
            (trimmed.startsWith('{') && trimmed.endsWith('}')) ||
                (trimmed.startsWith('[') && trimmed.endsWith(']'));
        if (looksLikeJson) {
          try {
            return json.decode(result);
          } catch (_) {
            // fall through to raw handling
          }
        }
        if (trimmed.length >= 2 &&
            trimmed.startsWith('"') &&
            trimmed.endsWith('"')) {
          return trimmed.substring(1, trimmed.length - 1);
        }
        return result;
      }

      return result;
    } catch (e) {
      debugPrint('[WindowsWebViewController] JS result error: $e');
      rethrow;
    }
  }

  @override
  Future<Object?> addJavaScriptChannel(
    String name,
    void Function(String) onMessage,
  ) async {
    debugPrint(
        '[WindowsWebViewController] Registering handler for channel: $name');

    // Store the handler - HTML already defines window.flutterChannel
    _channels[name] = onMessage;

    // No need to inject JavaScript - the HTML already has the channel defined
    return null;
  }

  @override
  Future<Object?> removeJavaScriptChannel(String name) async {
    _channels.remove(name);
    return null; // No-op in JS; HTML owns flutterChannel
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    debugPrint('[WindowsWebViewController] Disposing...');
    _webMessageSubscription?.cancel();
    _channels.clear();
    if (_isInitialized) {
      _controller.dispose();
    }
  }
}
