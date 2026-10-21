import 'file_store_native.dart'
    if (dart.library.js_interop) 'file_store_web.dart'
    as impl;

/// A file that is being written to disk.
abstract interface class ManagedFile {
  /// Appends [bytes] to the file.
  Future<void> append(List<int> bytes);

  /// Writes [bytes] at [position] without changing the file length.
  Future<void> writeAt(int position, List<int> bytes);

  /// The current length of the file.
  Future<int> length();

  /// Flushes the buffered data to the storage.
  Future<void> flush();

  /// Closes the file handle.
  Future<void> close();
}

/// The file store used by the download engine.
///
/// The store resolves every path relative to the application support
/// directory so that no absolute or platform specific path ever leaks into
/// the shared code.
abstract interface class FileStore {
  /// Whether the platform can store files at all.
  bool get isSupported;

  /// The reason why the platform is not supported, if it is not.
  String? get unsupportedReason;

  /// The directory that holds the downloads.
  Future<String> downloadsDirectory();

  /// Creates a file below the downloads directory.
  ///
  /// When [append] is true the existing content is kept and new bytes are
  /// written at the end, which is what a resumed download needs.
  Future<ManagedFile> createFile(
    String relativePath, {
    int? preallocate,
    bool append = false,
  });

  /// Whether a file exists.
  Future<bool> exists(String relativePath);

  /// The length of a file.
  Future<int> lengthOf(String relativePath);

  /// Removes a file.
  Future<void> delete(String relativePath);

  /// Renames a file.
  Future<void> rename(String from, String to);

  /// Reads a file as text.
  Future<String> readString(String relativePath);

  /// Writes text into a file.
  Future<void> writeString(String relativePath, String content);

  /// Lists the files of a directory.
  Future<List<String>> list(String relativePath);

  /// The absolute path of a file, for display purposes.
  Future<String> absolutePath(String relativePath);
}

/// The file store of the current platform.
FileStore createFileStore() => impl.createFileStore();
