import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Best-effort app-private persistence for scrubbed diagnostic logs.
class LocalLogStore {
  LocalLogStore._();

  static final LocalLogStore instance = LocalLogStore._();
  static const int _maxPersistedLines = 500;
  static const int _compactAtBytes = 512 * 1024;

  Future<File> _logFile() async {
    final supportDirectory = await getApplicationSupportDirectory();
    final logDirectory = Directory(
      '${supportDirectory.path}${Platform.pathSeparator}logs',
    );
    if (!await logDirectory.exists()) {
      await logDirectory.create(recursive: true);
    }
    return File('${logDirectory.path}${Platform.pathSeparator}system.jsonl');
  }

  Future<void> append(String line) async {
    final file = await _logFile();
    await file.writeAsString('$line\n', mode: FileMode.append, flush: true);
    if (await file.length() <= _compactAtBytes) {
      return;
    }
    final lines = await file.readAsLines();
    final start = lines.length > _maxPersistedLines
        ? lines.length - _maxPersistedLines
        : 0;
    await file.writeAsString('${lines.skip(start).join('\n')}\n', flush: true);
  }

  Future<void> clear() async {
    final file = await _logFile();
    if (await file.exists()) {
      await file.delete();
    }
  }
}
