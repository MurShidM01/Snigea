import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'file_store.dart';

/// A file handle backed by `dart:io`.
class IoManagedFile implements ManagedFile {
  IoManagedFile(this._file);

  final RandomAccessFile _file;

  @override
  Future<void> append(List<int> bytes) async {
    await _file.writeFrom(bytes);
  }

  @override
  Future<void> writeAt(int position, List<int> bytes) async {
    _file.setPositionSync(position);
    await _file.writeFrom(bytes);
  }

  @override
  Future<int> length() async => _file.lengthSync();

  @override
  Future<void> flush() async {
    _file.flushSync();
  }

  @override
  Future<void> close() async {
    _file.closeSync();
  }
}

/// The native file store.
class NativeFileStore implements FileStore {
  String? _root;

  @override
  bool get isSupported => true;

  @override
  String? get unsupportedReason => null;

  Future<String> _rootDirectory() async {
    final cached = _root;
    if (cached != null) return cached;
    final base = await getApplicationSupportDirectory();
    final directory = Directory(p.join(base.path, 'Snigea'));
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    _root = directory.path;
    return _root!;
  }

  @override
  Future<String> downloadsDirectory() async {
    final root = await _rootDirectory();
    final directory = Directory(p.join(root, 'Downloads'));
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    return directory.path;
  }

  /// Resolves a relative path against the application directory.
  ///
  /// The root is always resolved first, otherwise the path would stay
  /// relative and the file would be created in the working directory.
  Future<String> _resolve(String relativePath) async {
    final root = await _rootDirectory();
    return p.join(root, relativePath);
  }

  @override
  Future<ManagedFile> createFile(
    String relativePath, {
    int? preallocate,
    bool append = false,
  }) async {
    final path = await _resolve(relativePath);
    final file = File(path);
    await file.parent.create(recursive: true);
    final handle = await file.open(
      mode: append ? FileMode.append : FileMode.write,
    );
    if (!append && preallocate != null && preallocate > 0) {
      handle.truncateSync(preallocate);
    }
    return IoManagedFile(handle);
  }

  @override
  Future<bool> exists(String relativePath) async =>
      File(await _resolve(relativePath)).existsSync();

  @override
  Future<int> lengthOf(String relativePath) async {
    final file = File(await _resolve(relativePath));
    if (!file.existsSync()) return 0;
    return file.lengthSync();
  }

  @override
  Future<void> delete(String relativePath) async {
    final file = File(await _resolve(relativePath));
    if (file.existsSync()) await file.delete();
  }

  @override
  Future<void> rename(String from, String to) async {
    final source = File(await _resolve(from));
    if (!source.existsSync()) return;
    final target = File(await _resolve(to));
    await target.parent.create(recursive: true);
    await source.rename(target.path);
  }

  @override
  Future<String> readString(String relativePath) async {
    final file = File(await _resolve(relativePath));
    if (!file.existsSync()) return '';
    return file.readAsString();
  }

  @override
  Future<void> writeString(String relativePath, String content) async {
    final file = File(await _resolve(relativePath));
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  @override
  Future<List<String>> list(String relativePath) async {
    final root = await _rootDirectory();
    final directory = Directory(p.join(root, relativePath));
    if (!directory.existsSync()) return const [];
    return directory
        .listSync()
        .whereType<File>()
        .map((file) => p.relative(file.path, from: root))
        .toList();
  }

  @override
  Future<String> absolutePath(String relativePath) async =>
      _resolve(relativePath);
}

/// Creates the native file store.
FileStore createFileStore() => NativeFileStore();
