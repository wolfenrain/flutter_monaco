import 'package:flutter/widgets.dart';
import 'package:flutter_monaco/src/platform/platform_webview.dart';

/// Stub implementation that throws an error if accidentally used.
class WebViewController implements PlatformWebViewController {
  Widget get widget => throw UnsupportedError('stub');

  @override
  Future<void> initialize() {
    throw UnsupportedError('stub');
  }

  @override
  Future<Object?> runJavaScript(String script) {
    throw UnsupportedError('stub');
  }

  @override
  Future<Object?> runJavaScriptReturningResult(String script) {
    throw UnsupportedError('stub');
  }

  @override
  Future<Object?> addJavaScriptChannel(
    String name,
    void Function(String) onMessage,
  ) {
    throw UnsupportedError('stub');
  }

  @override
  Future<Object?> removeJavaScriptChannel(String name) {
    throw UnsupportedError('stub');
  }

  @override
  void dispose() {
    throw UnsupportedError('stub');
  }

  @override
  Future<void> load({String? customCss, bool allowCdnFonts = false}) {
    throw UnsupportedError('stub');
  }
}
