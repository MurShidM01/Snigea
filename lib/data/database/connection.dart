/// Platform specific database connection.
///
/// The native platforms use a SQLite file inside the application support
/// directory; the web build uses the drift WASM assets.
library;

export 'connection_native.dart'
    if (dart.library.js_interop) 'connection_web.dart';
