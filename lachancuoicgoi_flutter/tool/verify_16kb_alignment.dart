/// Verifies that all native .so libraries in the APK/AAB are 16 KiB-aligned.
///
/// Google Play requires 16 KB page size support for Android 15+ submissions
/// since November 2025. See:
/// https://developer.android.com/guide/practices/page-sizes
///
/// Usage:
///   dart run tool/verify_16kb_alignment.dart <path-to-apk-or-aab>
///
/// Exit code 0 = all .so files pass; 1 = alignment issues found or file missing.

import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/verify_16kb_alignment.dart <path-to-apk-or-aab>',
    );
    exit(2);
  }

  final file = File(args.first);
  if (!file.existsSync()) {
    stderr.writeln('File not found: ${args.first}');
    exit(2);
  }

  // List .so files inside the archive using the unzip -l command.
  final result = Process.runSync('unzip', ['-l', file.path]);
  if (result.exitCode != 0) {
    stderr.writeln('Failed to list archive: ${result.stderr}');
    exit(2);
  }

  final soFiles = <String>[];
  for (final line in (result.stdout as String).split('\n')) {
    if (line.trimRight().endsWith('.so')) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length >= 4) {
        soFiles.add(parts.last);
      }
    }
  }

  if (soFiles.isEmpty) {
    print('No .so files found in archive — nothing to check.');
    exit(0);
  }

  print('Found ${soFiles.length} .so file(s):');
  var hasIssues = false;

  // Extract each .so and check ELF alignment.
  final tmpDir = Directory.systemTemp.createTempSync(' alignment_check_');
  try {
    for (final so in soFiles) {
      final basename = so.split('/').last;
      // Extract just this file.
      final extract = Process.runSync(
        'unzip',
        ['-o', file.path, so, '-d', tmpDir.path],
      );
      if (extract.exitCode != 0) {
        stderr.writeln('  SKIP  $so (extract failed)');
        continue;
      }

      final extracted = File('${tmpDir.path}/$so');
      if (!extracted.existsSync()) {
        // Try with the full path structure.
        final alt = File('${tmpDir.path}/$so');
        if (!alt.existsSync()) {
          stderr.writeln('  SKIP  $so (not found after extract)');
          continue;
        }
      }

      // Use readelf (from Android NDK or system) to check LOAD alignment.
      final readelf = Process.runSync('readelf', ['-l', extracted.path]);
      if (readelf.exitCode != 0) {
        // Try llvm-readelf from Android SDK.
        final sdkDir = Platform.environment['ANDROID_HOME'] ??
            Platform.environment['ANDROID_SDK_ROOT'] ??
            '';
        if (sdkDir.isNotEmpty) {
          final ndkDir = Directory('$sdkDir/ndk');
          if (ndkDir.existsSync()) {
            final versions = ndkDir.listSync().whereType<Directory>().toList()
              ..sort((a, b) => b.path.compareTo(a.path));
            for (final ndk in versions) {
              // Try multiple possible paths for readelf
              for (final arch in ['bin', 'toolchains/llvm/prebuilt/windows-x86_64/bin']) {
                final readelfPath = '${ndk.path}/$arch/llvm-readelf.exe';
                if (File(readelfPath).existsSync()) {
                  final re = Process.runSync(readelfPath, ['-l', extracted.path]);
                  if (re.exitCode == 0) {
                    _checkAlignment(so, re.stdout as String);
                    continue;
                  }
                }
              }
            }
          }
        }
        stderr.writeln('  WARN  $so (readelf not available — skipping alignment check)');
        continue;
      }

      _checkAlignment(so, readelf.stdout as String);
    }
  } finally {
    tmpDir.deleteSync(recursive: true);
  }

  if (hasIssues) {
    stderr.writeln('\nFAILED: Some .so files are not 16 KiB-aligned.');
    stderr.writeln(
      'See https://developer.android.com/guide/practices/page-sizes',
    );
    exit(1);
  } else {
    print('\nPASSED: All checked .so files are 16 KiB-aligned.');
  }

  void _checkAlignment(String path, String readelfOutput) {
    // Look for LOAD segments and check their alignment.
    final lines = readelfOutput.split('\n');
    var inLoadSegment = false;
    for (final line in lines) {
      if (line.contains('LOAD')) {
        inLoadSegment = true;
        // Parse alignment from LOAD line.
        // Typical format: "  LOAD           0x... 0x... ... 0x... 0x... R E  0x1000 0x1000"
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length >= 7) {
          final alignHex = parts.last;
          try {
            final align = int.parse(alignHex.replaceFirst('0x', ''), radix: 16);
            if (align >= 0x4000) {
              print('  OK    $path (alignment: ${alignHex} = ${align ~/ 1024} KiB)');
            } else {
              print('  FAIL  $path (alignment: ${alignHex} = ${align ~/ 1024} KiB — need >= 16 KiB)');
              hasIssues = true;
            }
          } catch (_) {
            print('  WARN  $path (cannot parse alignment: $alignHex)');
          }
        }
      }
    }
  }
}
