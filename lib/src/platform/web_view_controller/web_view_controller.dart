export 'package:flutter_monaco/src/platform/web_view_controller/stub.dart'
    if (dart.library.io) 'package:flutter_monaco/src/platform/web_view_controller/native.dart'
    if (dart.library.js_interop) 'package:flutter_monaco/src/platform/web_view_controller/web.dart';
