import 'package:flutter/widgets.dart';
import 'package:flutter_monaco/src/platform/platform_webview.dart';
import 'package:flutter_monaco/src/platform/web_view_controller/web_view_controller.dart'
    as base;

// Export the interface so consumers can use it
export 'platform_webview_interface.dart';

/// Factory for creating platform-specific controllers
class PlatformWebViewFactory {
  /// Creates a new platform web view controller.
  ///
  /// Returns the appropriate platform web view controller based on the platform.
  static PlatformWebViewController createController() {
    return WebViewController();
  }
}

/// A [PlatformWebViewController] that just forwards to the base [WebViewController].
///
/// This hides away the platform-specific details and provides a consistent interface.
class WebViewController implements PlatformWebViewController {
  /// Creates a new [WebViewController] that forwards to the base [WebViewController].
  WebViewController() : _controller = base.WebViewController();

  final base.WebViewController _controller;

  @override
  Widget get widget => _controller.widget;

  @override
  Future<void> initialize() => _controller.initialize();

  @override
  Future<void> load({String? customCss, bool allowCdnFonts = false}) {
    return _controller.load(
      customCss: customCss,
      allowCdnFonts: allowCdnFonts,
    );
  }

  @override
  void dispose() {
    return _controller.dispose();
  }

  @override
  Future<Object?> addJavaScriptChannel(
    String name,
    void Function(String p1) onMessage,
  ) {
    return _controller.addJavaScriptChannel(name, onMessage);
  }

  @override
  Future<Object?> removeJavaScriptChannel(String name) {
    return _controller.removeJavaScriptChannel(name);
  }

  @override
  Future<Object?> runJavaScript(String script) {
    return _controller.runJavaScript(script);
  }

  @override
  Future<Object?> runJavaScriptReturningResult(String script) {
    return _controller.runJavaScriptReturningResult(script);
  }
}
