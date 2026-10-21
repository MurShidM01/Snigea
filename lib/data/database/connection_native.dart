import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// Opens the Snigea database on the native platforms.
///
/// The SQLite file lives in the application support directory, which is
/// managed by the operating system and therefore safe to use on mobile and
/// desktop.
DatabaseConnection openSnigeaConnection() {
  return driftDatabase(name: 'snigea');
}
