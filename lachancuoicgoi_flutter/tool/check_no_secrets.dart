import 'dart:io';

final RegExp _geminiKey = RegExp(r'AIzaSy[0-9A-Za-z_-]{24,}');
final RegExp _bearerToken = RegExp(
  r'Bearer\s+[A-Za-z0-9._~+/=-]{20,}',
  caseSensitive: false,
);

const List<String> _allowedPlaceholderParts = <String>[
  'replace',
  'your',
  'example',
  'placeholder',
  'dummy',
  'test',
  'fake',
];

const Set<String> _allowedSyntheticKeys = <String>{
  'aizasyaabb22ccddeeffgghhiijjkkllmmnnooppqq',
  'aizasyd1234567890abcdefghijklmnopqrstuvw',
};

Future<void> main(List<String> arguments) async {
  final rootResult = await Process.run('git', <String>[
    'rev-parse',
    '--show-toplevel',
  ]);
  if (rootResult.exitCode != 0) {
    stderr.writeln('Secret scan could not locate the repository root.');
    exitCode = 2;
    return;
  }
  final repositoryRoot = (rootResult.stdout as String).trim();
  final files = <_ScanTarget>[];
  final tracked = await Process.run('git', <String>[
    'ls-files',
    '-z',
    '--',
    '.github',
    'lachancuoicgoi_flutter',
  ], workingDirectory: repositoryRoot);
  if (tracked.exitCode != 0) {
    stderr.writeln('Secret scan could not enumerate repository files.');
    exitCode = 2;
    return;
  }
  files.addAll(
    (tracked.stdout as String)
        .split('\u0000')
        .where((path) => path.trim().isNotEmpty)
        .map(
          (path) => _ScanTarget(
            label: path,
            file: File.fromUri(
              Directory(repositoryRoot).uri.resolve(path.replaceAll('\\', '/')),
            ),
            forceScan: false,
          ),
        ),
  );
  files.addAll(
    arguments.map(
      (path) => _ScanTarget(label: path, file: File(path), forceScan: true),
    ),
  );

  final findings = <String>[];
  for (final target in files) {
    final file = target.file;
    if (!file.existsSync() || _looksBinary(target.label)) continue;
    // Bundled speech/ML artifacts do not always use a conventional binary
    // extension. Avoid decoding multi-megabyte tracked assets as UTF-8.
    if (!target.forceScan && file.lengthSync() > 5 * 1024 * 1024) continue;
    String content;
    try {
      content = file.readAsStringSync();
    } on Object {
      continue;
    }
    for (final match in _geminiKey.allMatches(content)) {
      final candidate = match.group(0)!.toLowerCase();
      if (!_allowedPlaceholderParts.any(candidate.contains) &&
          !_allowedSyntheticKeys.contains(candidate)) {
        findings.add('${target.label}: possible Gemini API key');
      }
    }
    if (_bearerToken.hasMatch(content)) {
      findings.add('${target.label}: possible bearer token');
    }
  }

  if (findings.isNotEmpty) {
    stderr.writeln(
      'SECRET SCAN FAILED (secret values are intentionally hidden):',
    );
    for (final finding in findings.toSet()) {
      stderr.writeln('- $finding');
    }
    exitCode = 2;
    return;
  }
  stdout.writeln('Secret scan passed (${files.length} files checked).');
}

class _ScanTarget {
  const _ScanTarget({
    required this.label,
    required this.file,
    required this.forceScan,
  });

  final String label;
  final File file;
  final bool forceScan;
}

bool _looksBinary(String path) {
  final lower = path.toLowerCase();
  return <String>[
    '.png',
    '.jpg',
    '.jpeg',
    '.gif',
    '.webp',
    '.ico',
    '.tflite',
    '.bin',
    '.mdl',
    '.fst',
    '.ark',
    '.so',
    '.jar',
    '.aar',
    '.apk',
    '.aab',
    '.zip',
    '.keystore',
    '.jks',
  ].any(lower.endsWith);
}
