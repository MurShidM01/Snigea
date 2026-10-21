import 'file_store.dart';

/// The web file store.
///
/// Browsers cannot write to the file system, therefore downloads are not
/// available. The store reports the limitation instead of failing silently.
class WebFileStore implements FileStore {
  @override
  bool get isSupported => false;

  @override
  String? get unsupportedReason =>
      'Downloads are not available in the browser. Use the desktop or mobile '
      'build of Snigea to save media offline.';

  @override
  Future<String> downloadsDirectory() async =>
      throw UnsupportedError(unsupportedReason!);

  @override
  Future<ManagedFile> createFile(
    String relativePath, {
    int? preallocate,
    bool append = false,
  }) async => throw UnsupportedError(unsupportedReason!);

  @override
  Future<bool> exists(String relativePath) async => false;

  @override
  Future<int> lengthOf(String relativePath) async => 0;

  @override
  Future<void> delete(String relativePath) async {}

  @override
  Future<void> rename(String from, String to) async {}

  @override
  Future<String> readString(String relativePath) async => '';

  @override
  Future<void> writeString(String relativePath, String content) async {}

  @override
  Future<List<String>> list(String relativePath) async => const [];

  @override
  Future<String> absolutePath(String relativePath) async => relativePath;
}

/// Creates the web file store.
FileStore createFileStore() => WebFileStore();
