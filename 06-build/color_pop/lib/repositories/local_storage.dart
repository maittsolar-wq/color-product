import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// PASS 4 — low-level, engine-agnostic local file storage.
///
/// Everything lives under the app's private documents directory
/// (`path_provider`), inside a single `color_pop_progress/` folder — never
/// public/Downloads storage, so no runtime permission is ever needed on
/// Android. Writes are atomic (write to a `.tmp` sibling, then rename over
/// the target — POSIX `rename()` is an atomic replace, so a crash mid-write
/// never leaves a half-written file as the only copy). Reads never throw:
/// a missing or corrupt file is reported as `null` so callers can fall back
/// to a clean/default state instead of crashing.
///
/// Every write/delete for a given path is serialized behind a per-path
/// queue: two callers writing the same file "at the same time" (e.g.
/// ProgressRepository.saveDrawingState and saveProgress firing back-to-back
/// for the same lesson) would otherwise both target the exact same `.tmp`
/// staging file and race on rename() — the second rename fails because the
/// first one already consumed the tmp file. Queuing makes concurrent writes
/// to one path safe by construction rather than relying on every caller to
/// coordinate.
class LocalStorage {
  LocalStorage._();
  static final LocalStorage instance = LocalStorage._();

  Directory? _root;
  final Map<String, Future<void>> _writeQueue = {};

  Future<void> _enqueue(String relativePath, Future<void> Function() action) {
    final previous = _writeQueue[relativePath] ?? Future<void>.value();
    final chained = previous.then((_) => action()).catchError((Object e) {
      debugPrint('[LocalStorage] write/delete failed for $relativePath: $e');
    });
    _writeQueue[relativePath] = chained;
    return chained;
  }

  Future<Directory> _rootDir() async {
    final cached = _root;
    if (cached != null) return cached;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/color_pop_progress');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _root = dir;
    return dir;
  }

  Future<File> _file(String relativePath) async {
    final root = await _rootDir();
    final file = File('${root.path}/$relativePath');
    final parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    return file;
  }

  Future<void> _atomicWrite(File target, List<int> bytes) async {
    final tmp = File('${target.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(target.path);
  }

  Future<Map<String, dynamic>?> readJson(String relativePath) async {
    try {
      final file = await _file(relativePath);
      if (!await file.exists()) return null;
      final text = await file.readAsString();
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) return null;
      return decoded;
    } catch (e) {
      debugPrint('[LocalStorage] corrupt/unreadable JSON at $relativePath: $e');
      return null;
    }
  }

  Future<void> writeJson(String relativePath, Map<String, dynamic> json) {
    return _enqueue(relativePath, () async {
      final file = await _file(relativePath);
      final bytes = utf8.encode(jsonEncode(json));
      await _atomicWrite(file, bytes);
    });
  }

  Future<Uint8List?> readBytes(String relativePath) async {
    try {
      final file = await _file(relativePath);
      if (!await file.exists()) return null;
      return await file.readAsBytes();
    } catch (e) {
      debugPrint('[LocalStorage] unreadable bytes at $relativePath: $e');
      return null;
    }
  }

  Future<void> writeBytes(String relativePath, Uint8List bytes) {
    return _enqueue(relativePath, () async {
      final file = await _file(relativePath);
      await _atomicWrite(file, bytes);
    });
  }

  Future<void> deleteFile(String relativePath) {
    return _enqueue(relativePath, () async {
      final file = await _file(relativePath);
      if (await file.exists()) {
        await file.delete();
      }
      final tmp = File('${file.path}.tmp');
      if (await tmp.exists()) {
        await tmp.delete();
      }
    });
  }

  /// Bare file names (without extension) of every file matching [ext] in
  /// [relativeDir] — used at startup to discover which lessons have a
  /// persisted progress record without reading each file's contents.
  Future<List<String>> listFileNames(String relativeDir, String ext) async {
    try {
      final root = await _rootDir();
      final dir = Directory('${root.path}/$relativeDir');
      if (!await dir.exists()) return const [];
      final entries = await dir.list().toList();
      final suffix = '.$ext';
      return entries
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .where((name) => name.endsWith(suffix))
          .map((name) => name.substring(0, name.length - suffix.length))
          .toList();
    } catch (e) {
      debugPrint('[LocalStorage] failed to list $relativeDir: $e');
      return const [];
    }
  }
}

/// Lesson ids are already simple slug-like strings (e.g. `animal_babydeer`)
/// but this guards against any unexpected character reaching the filesystem.
String sanitizeFileName(String id) => id.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
