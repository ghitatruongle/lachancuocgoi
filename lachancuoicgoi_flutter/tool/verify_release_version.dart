import 'dart:io';

const String expectedVersionName = '1.6.1';
const int expectedVersionCode = 15;
const String expectedBuildVersion = '$expectedVersionName+$expectedVersionCode';

void main() {
  final checks = <String, RegExp>{
    'pubspec.yaml': RegExp(r'^version:\s*1\.6\.1\+15\s*$', multiLine: true),
    'README.md': RegExp(r'\*\*Version\*\*:\s*`?1\.6\.1\+15`?'),
    '.fvmrc': RegExp(r'"flutter"\s*:\s*"3\.44\.2"'),
    '../.github/workflows/ci.yml': RegExp(r"FLUTTER_VERSION:\s*'3\.44\.2'"),
    'fastlane/metadata/android/STORE_LISTING.md': RegExp(
      r'Release version:\s*1\.6\.1\+15',
    ),
    'fastlane/metadata/ios/STORE_LISTING.md': RegExp(
      r'Release version:\s*1\.6\.1\+15',
    ),
    'docs/RELEASE_NOTES_v1.6.1.md': RegExp(r'v1\.6\.1\+15'),
    'docs/RELEASE_CHECKLIST_v1.6.1.md': RegExp(r'v1\.6\.1\+15'),
    'tool/build_release.ps1': RegExp(r'v1\.6\.1\+15'),
  };

  var failed = false;
  for (final entry in checks.entries) {
    final file = File(entry.key);
    if (!file.existsSync() || !entry.value.hasMatch(file.readAsStringSync())) {
      stderr.writeln('VERSION MISMATCH: ${entry.key}');
      failed = true;
    }
  }

  final usedFlag = Platform.environment['PLAY_VERSION_CODE_ALREADY_USED'];
  if (usedFlag?.toLowerCase() == 'true' || usedFlag == '1') {
    stderr.writeln(
      'RELEASE BLOCKED: Google Play has already used versionCode '
      '$expectedVersionCode. This tool will not change it automatically.',
    );
    failed = true;
  }

  if (failed) {
    exitCode = 2;
    return;
  }
  stdout.writeln('Release version verified: $expectedBuildVersion.');
}
