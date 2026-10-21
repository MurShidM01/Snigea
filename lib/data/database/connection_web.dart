import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// Opens the Snigea database on the web.
///
/// The browser needs the SQLite WebAssembly module and the drift worker.
/// Both are shipped as Flutter assets (`assets/sqlite3.wasm` and
/// `assets/drift_worker.js`), which keeps the platform folders untouched.
/// The asset URLs follow the Flutter asset layout: the files are served
/// below `assets/assets/`.
DatabaseConnection openSnigeaConnection() {
  return driftDatabase(
    name: 'snigea',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('assets/assets/sqlite3.wasm'),
      driftWorker: Uri.parse('assets/assets/drift_worker.js'),
    ),
  );
}
