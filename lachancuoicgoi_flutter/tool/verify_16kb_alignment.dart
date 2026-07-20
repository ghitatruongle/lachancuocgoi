import 'dart:io';

/// Verifies the Google Play 16 KiB requirement for 64-bit native libraries.
///
/// Google Play applies the requirement to 64-bit devices. A 32-bit ABI can
/// therefore remain 4 KiB-aligned (for example Vosk's armeabi-v7a build), while
/// every arm64-v8a/x86_64 ELF LOAD segment must be at least 16 KiB-aligned.
/// APKs are additionally checked with `zipalign -P 16` as prescribed by the
/// Android documentation. The command fails closed when required tooling is
/// unavailable or a required check cannot be completed.
void main(List<String> arguments) {
  if (arguments.length != 1) {
    stderr.writeln(
      'Usage: dart run tool/verify_16kb_alignment.dart <apk-or-aab>',
    );
    exitCode = 2;
    return;
  }

  final archive = File(arguments.single).absolute;
  if (!archive.existsSync()) {
    stderr.writeln('File not found: ${archive.path}');
    exitCode = 2;
    return;
  }

  final archiveTool = _findArchiveTool();
  final readelf = _findReadelf();
  if (archiveTool == null) {
    stderr.writeln('RELEASE BLOCKED: neither tar nor unzip is available.');
    exitCode = 2;
    return;
  }
  if (readelf == null) {
    stderr.writeln(
      'RELEASE BLOCKED: llvm-readelf/readelf was not found. Install an '
      'Android NDK and set ANDROID_SDK_ROOT.',
    );
    exitCode = 2;
    return;
  }
  final isApk = archive.path.toLowerCase().endsWith('.apk');
  final zipalign = isApk ? _findSdkTool('zipalign') : null;
  if (isApk && zipalign == null) {
    stderr.writeln(
      'RELEASE BLOCKED: zipalign was not found in Android SDK build-tools.',
    );
    exitCode = 2;
    return;
  }

  final entries = _listArchiveEntries(archiveTool, archive);
  if (entries == null) {
    exitCode = 2;
    return;
  }
  final allSharedObjects =
      entries.where((entry) => entry.endsWith('.so')).toList()..sort();
  final sharedObjects = allSharedObjects
      .where(
        (entry) => entry.contains('/arm64-v8a/') || entry.contains('/x86_64/'),
      )
      .toList(growable: false);
  if (allSharedObjects.isEmpty) {
    stderr.writeln('RELEASE BLOCKED: archive contains no native libraries.');
    exitCode = 1;
    return;
  }
  if (sharedObjects.isEmpty) {
    stderr.writeln(
      'RELEASE BLOCKED: archive contains native code but no 64-bit ABI.',
    );
    exitCode = 1;
    return;
  }

  stdout.writeln(
    'Checking ${sharedObjects.length} 64-bit native libraries '
    '(${allSharedObjects.length - sharedObjects.length} 32-bit libraries are '
    'outside the Google Play 16 KiB requirement)...',
  );
  var passed = true;
  final temporaryDirectory = Directory.systemTemp.createTempSync(
    'alignment_check_',
  );
  try {
    for (final entry in sharedObjects) {
      final extracted = _extractEntry(
        archiveTool,
        archive,
        entry,
        temporaryDirectory,
      );
      if (extracted == null) {
        passed = false;
        continue;
      }
      final result = Process.runSync(readelf, <String>['-lW', extracted.path]);
      if (result.exitCode != 0) {
        stderr.writeln('FAIL  $entry (readelf failed: ${result.stderr})');
        passed = false;
        continue;
      }
      if (!_hasValidAlignment(entry, result.stdout as String)) {
        passed = false;
      }
    }
  } finally {
    temporaryDirectory.deleteSync(recursive: true);
  }

  if (isApk && zipalign != null) {
    final result = Process.runSync(zipalign, <String>[
      '-c',
      '-P',
      '16',
      '-v',
      '4',
      archive.path,
    ]);
    if (result.exitCode == 0) {
      stdout.writeln('OK    APK ZIP alignment');
    } else {
      stderr.writeln('FAIL  APK ZIP alignment: ${result.stderr}');
      passed = false;
    }
  }

  if (!passed) {
    stderr.writeln(
      '\nFAILED: one or more native libraries are not 16 KiB-safe.',
    );
    exitCode = 1;
    return;
  }
  stdout.writeln(
    isApk
        ? '\nPASSED: all 64-bit ELF LOAD segments and APK packaging are 16 '
              'KiB-aligned.'
        : '\nPASSED: all 64-bit ELF LOAD segments are 16 KiB-aligned.',
  );
}

String? _findArchiveTool() {
  for (final command in <String>['tar', 'unzip']) {
    final probe = Process.runSync(
      Platform.isWindows ? 'where.exe' : 'which',
      <String>[command],
    );
    if (probe.exitCode == 0) return command;
  }
  return null;
}

String? _findReadelf() {
  for (final command in <String>['llvm-readelf', 'readelf']) {
    final probe = Process.runSync(
      Platform.isWindows ? 'where.exe' : 'which',
      <String>[command],
    );
    if (probe.exitCode == 0) return command;
  }

  final sdkRoots = <String>{
    if (Platform.environment['ANDROID_SDK_ROOT'] case final String value) value,
    if (Platform.environment['ANDROID_HOME'] case final String value) value,
    ..._sdkRootsFromLocalProperties(),
  };
  for (final sdkRoot in sdkRoots) {
    final ndkRoot = Directory('$sdkRoot${Platform.pathSeparator}ndk');
    if (!ndkRoot.existsSync()) continue;
    final versions = ndkRoot.listSync().whereType<Directory>().toList()
      ..sort((left, right) => right.path.compareTo(left.path));
    for (final version in versions) {
      final executable = Platform.isWindows
          ? 'llvm-readelf.exe'
          : 'llvm-readelf';
      final candidates = <String>[
        '${version.path}${Platform.pathSeparator}toolchains${Platform.pathSeparator}'
            'llvm${Platform.pathSeparator}prebuilt${Platform.pathSeparator}'
            'windows-x86_64${Platform.pathSeparator}bin${Platform.pathSeparator}$executable',
        '${version.path}${Platform.pathSeparator}toolchains${Platform.pathSeparator}'
            'llvm${Platform.pathSeparator}prebuilt${Platform.pathSeparator}'
            'linux-x86_64${Platform.pathSeparator}bin${Platform.pathSeparator}$executable',
        '${version.path}${Platform.pathSeparator}toolchains${Platform.pathSeparator}'
            'llvm${Platform.pathSeparator}prebuilt${Platform.pathSeparator}'
            'darwin-x86_64${Platform.pathSeparator}bin${Platform.pathSeparator}$executable',
      ];
      for (final candidate in candidates) {
        if (File(candidate).existsSync()) return candidate;
      }
    }
  }
  return null;
}

String? _findSdkTool(String toolName) {
  final executable = Platform.isWindows ? '$toolName.exe' : toolName;
  final directProbe = Process.runSync(
    Platform.isWindows ? 'where.exe' : 'which',
    <String>[executable],
  );
  if (directProbe.exitCode == 0) {
    return (directProbe.stdout as String).split(RegExp(r'\r?\n')).first.trim();
  }

  final sdkRoots = <String>{
    if (Platform.environment['ANDROID_SDK_ROOT'] case final String value) value,
    if (Platform.environment['ANDROID_HOME'] case final String value) value,
    ..._sdkRootsFromLocalProperties(),
  };
  for (final sdkRoot in sdkRoots) {
    final buildTools = Directory(
      '$sdkRoot${Platform.pathSeparator}build-tools',
    );
    if (!buildTools.existsSync()) continue;
    final versions = buildTools.listSync().whereType<Directory>().toList()
      ..sort((left, right) => right.path.compareTo(left.path));
    for (final version in versions) {
      final candidate = '${version.path}${Platform.pathSeparator}$executable';
      if (File(candidate).existsSync()) return candidate;
    }
  }
  return null;
}

Set<String> _sdkRootsFromLocalProperties() {
  final result = <String>{};
  final properties = File('android/local.properties');
  if (!properties.existsSync()) return result;
  for (final line in properties.readAsLinesSync()) {
    if (!line.startsWith('sdk.dir=')) continue;
    final raw = line.substring('sdk.dir='.length).trim();
    final normalized = raw
        .replaceAll(r'\:', ':')
        .replaceAll(r'\\', Platform.pathSeparator);
    if (normalized.isNotEmpty) result.add(normalized);
  }
  return result;
}

List<String>? _listArchiveEntries(String tool, File archive) {
  final arguments = tool == 'tar'
      ? <String>['-tf', archive.path]
      : <String>['-Z1', archive.path];
  final result = Process.runSync(tool, arguments);
  if (result.exitCode != 0) {
    stderr.writeln('RELEASE BLOCKED: cannot list archive: ${result.stderr}');
    return null;
  }
  return (result.stdout as String)
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
}

File? _extractEntry(
  String tool,
  File archive,
  String entry,
  Directory destination,
) {
  final arguments = tool == 'tar'
      ? <String>['-xf', archive.path, '-C', destination.path, entry]
      : <String>['-o', archive.path, entry, '-d', destination.path];
  final result = Process.runSync(tool, arguments);
  final extracted = File(
    '${destination.path}${Platform.pathSeparator}'
    '${entry.replaceAll('/', Platform.pathSeparator)}',
  );
  if (result.exitCode != 0 || !extracted.existsSync()) {
    stderr.writeln('FAIL  $entry (archive extraction failed)');
    return null;
  }
  return extracted;
}

bool _hasValidAlignment(String path, String readelfOutput) {
  final loadLines = readelfOutput
      .split(RegExp(r'\r?\n'))
      .where((line) => RegExp(r'^\s*LOAD\s').hasMatch(line))
      .toList(growable: false);
  if (loadLines.isEmpty) {
    stderr.writeln('FAIL  $path (no ELF LOAD segments found)');
    return false;
  }

  var passed = true;
  for (final line in loadLines) {
    final match = RegExp(r'(0x[0-9a-fA-F]+)\s*$').firstMatch(line);
    final rawAlignment = match?.group(1);
    final alignment = rawAlignment == null
        ? null
        : int.tryParse(rawAlignment.substring(2), radix: 16);
    if (alignment == null) {
      stderr.writeln('FAIL  $path (cannot parse LOAD alignment)');
      passed = false;
    } else if (alignment < 0x4000) {
      stderr.writeln(
        'FAIL  $path (LOAD alignment $rawAlignment; require >= 0x4000)',
      );
      passed = false;
    }
  }
  if (passed) stdout.writeln('OK    $path');
  return passed;
}
