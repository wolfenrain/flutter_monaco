import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter_monaco/src/core/monaco_assets.dart';
import 'package:flutter_monaco/src/platform/platform_webview.dart';
import 'package:web/web.dart' as web;

/// A [PlatformWebViewController] implementation for the web platform.
class WebViewController implements PlatformWebViewController {
  final Map<String, void Function(String)> _channels = {};
  bool _disposed = false;

  final Completer<void> _readyCompleter = Completer<void>();
  bool _isReady = false;

  web.HTMLIFrameElement? _iframe;
  String? _viewId;

  final _widgetKey = GlobalKey();
  Widget? _cachedWidget;

  @override
  Widget get widget =>
      _cachedWidget ??= HtmlElementView(key: _widgetKey, viewType: _viewId!);

  @override
  Future<void> initialize() async {
    _viewId = 'monaco-iframe-${DateTime.now().millisecondsSinceEpoch}';
    debugPrint('[WebViewController] Initializing iframe approach');

    // Create iframe for Monaco.
    _iframe = web.HTMLIFrameElement()
      ..id = _viewId!
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.border = 'none'
      ..allow = 'clipboard-read; clipboard-write';

    // Register the view factory.
    ui_web.platformViewRegistry.registerViewFactory(_viewId!, (_) => _iframe!);

    // Listen for messages from the iframe.
    web.window.addEventListener('message', _handleIframeMessage.toJS);

    debugPrint('[WebViewController] View factory registered with ID: $_viewId');
  }

  void _handleIframeMessage(web.MessageEvent event) {
    // Only accept messages from our iframe
    if (_iframe?.contentWindow != event.source) return;

    final data = event.data;
    String message;

    try {
      // Try to convert as string first
      message = (data as JSString).toDart;
    } catch (_) {
      // If not a string, try to convert as object
      try {
        message = jsonEncode((data as JSObject).dartify());
      } catch (_) {
        message = data.toString();
      }
    }

    debugPrint('[WebViewController] Received iframe message: $message');

    // Check if this is the ready event
    if (message == 'ready' ||
        message.contains('"event":"onEditorReady"') ||
        message.contains('"event": "onEditorReady"')) {
      _isReady = true;
      if (!_readyCompleter.isCompleted) {
        _readyCompleter.complete();
      }
      debugPrint('[WebViewController] Monaco ready!');
    }

    // When Monaco reports focus, unfocus Flutter widgets and ensure Monaco keeps focus.
    if (message.contains('"event":"focus"') ||
        message.contains('"event": "focus"')) {
      // Unfocus any Flutter widget
      FocusManager.instance.primaryFocus?.unfocus();
      // Use Monaco's forceFocus to ensure editor keeps focus
      _iframe?.contentWindow?.callMethod(
        'eval'.toJS,
        'window.flutterMonaco && window.flutterMonaco.forceFocus()'.toJS,
      );
    }

    // Forward to all channels
    for (final handler in _channels.values) {
      handler(message);
    }
  }

  Future<void> _ensureReady() async {
    if (!_isReady) {
      await _readyCompleter.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Monaco editor failed to initialize');
        },
      );
    }
  }

  @override
  Future<Object?> runJavaScript(String script) async {
    if (_disposed) return null;

    try {
      _iframe?.contentWindow?.callMethod('eval'.toJS, script.toJS);
      return null;
    } catch (e) {
      debugPrint('[WebViewController] JS execution error: $e');
      rethrow;
    }
  }

  @override
  Future<Object?> runJavaScriptReturningResult(String script) async {
    if (_disposed) return null;

    try {
      final result =
          _iframe?.contentWindow?.callMethod('eval'.toJS, script.toJS);
      return result?.dartify();
    } catch (e) {
      debugPrint('[WebViewController] JS result error: $e');
      rethrow;
    }
  }

  @override
  Future<Object?> addJavaScriptChannel(
    String name,
    void Function(String) onMessage,
  ) async {
    debugPrint('[WebViewController] Adding JS channel: $name');
    _channels[name] = onMessage;
    return null;
  }

  @override
  Future<Object?> removeJavaScriptChannel(String name) async {
    _channels.remove(name);
    return null;
  }

  @override
  Future<void> load({String? customCss, bool allowCdnFonts = false}) async {
    debugPrint('[WebViewController] Loading Monaco in iframe');

    // Get the current origin to build absolute URLs
    final origin = web.window.location.origin;
    final vsPath = '$origin/assets/${MonacoAssets.assetBaseDir}/min/vs';

    final html = MonacoAssets.generateIndexHtml(
      vsPath,
      isWindows: false,
      isIosOrMacOS: false,
      isWeb: true,
      customCss: customCss,
      allowCdnFonts: allowCdnFonts,
    );

    // Create a blob URL for the HTML content
    final blobUrl = web.URL.createObjectURL(web.Blob(
      [html.toJS].toJS,
      web.BlobPropertyBag(type: 'text/html'),
    ));
    _iframe!.src = blobUrl;

    await _ensureReady();

    // Clean up blob URL after Monaco is ready
    web.URL.revokeObjectURL(blobUrl);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    debugPrint('[WebViewController] Disposing...');
    _channels.clear();
    _cachedWidget = null;
    _iframe?.remove();
    _iframe = null;
  }
}
