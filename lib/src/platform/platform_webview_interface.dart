import 'dart:async';

import 'package:flutter/widgets.dart';

/// Unified interface for all platform WebView implementations
abstract class PlatformWebViewController {
  /// Gets the widget for the WebView.
  Widget get widget;

  /// Execute JavaScript code without expecting a return value
  Future<Object?> runJavaScript(String script);

  /// Execute JavaScript and return the result
  Future<Object?> runJavaScriptReturningResult(String script);

  /// Add a JavaScript channel for communication between JS and Flutter
  Future<Object?> addJavaScriptChannel(
    String name,
    void Function(String) onMessage,
  );

  /// Remove a JavaScript channel
  Future<Object?> removeJavaScriptChannel(String name);

  /// Initializes the WebView.
  Future<void> initialize();

  /// Clean up resources
  void dispose();

  /// Load the Monaco editor into the WebView.
  ///
  /// [customCss] - Optional custom CSS to apply to the Monaco editor.
  /// [allowCdnFonts] - Whether to allow CDN fonts to be used.
  Future<void> load({
    String? customCss,
    bool allowCdnFonts = false,
  });
}
