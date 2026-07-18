import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

const List<String> _placeholderPatterns = <String>[
  'aizareplace',
  'aizayour',
  'aizaexample',
  'aizatest',
  'replace_me',
  'your_api_key',
  'placeholder',
];

const List<int> _xorKey = <int>[
  0x42,
  0x9A,
  0x3F,
  0xC7,
  0x58,
  0xE1,
  0x6B,
  0x24,
  0xD5,
  0x7E,
  0x19,
  0xA3,
  0x8C,
  0x4F,
  0x62,
  0xB0,
];

void main(List<String> arguments) {
  final path = arguments.isEmpty ? 'env.json' : arguments.first;
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('RELEASE BLOCKED: env.json does not exist.');
    exitCode = 2;
    return;
  }

  Object? decoded;
  try {
    decoded = jsonDecode(file.readAsStringSync());
  } on Object {
    stderr.writeln('RELEASE BLOCKED: env.json is not valid JSON.');
    exitCode = 2;
    return;
  }
  if (decoded is! Map<String, dynamic>) {
    stderr.writeln('RELEASE BLOCKED: env.json must contain a JSON object.');
    exitCode = 2;
    return;
  }

  var candidateCount = 0;
  var validCount = 0;
  var placeholderCount = 0;
  final supportedPrefixLengths = <int>{};
  for (final entry in decoded.entries) {
    if (entry.key.startsWith('_') || entry.value is! String) {
      continue;
    }
    final value = (entry.value as String).trim();
    if (value.isEmpty) continue;
    candidateCount++;
    final lower = value.toLowerCase();
    if (_placeholderPatterns.any(lower.contains)) {
      placeholderCount++;
      continue;
    }
    if (_isValidRawKey(value) || _decodeObfuscatedKey(value) != null) {
      validCount++;
    } else {
      for (
        var prefixLength = 1;
        prefixLength <= 8 && prefixLength < value.length;
        prefixLength++
      ) {
        final suffix = value.substring(prefixLength);
        if (_isValidRawKey(suffix) || _decodeObfuscatedKey(suffix) != null) {
          supportedPrefixLengths.add(prefixLength);
        }
      }
    }
  }

  if (candidateCount == 0) {
    stderr.writeln('RELEASE BLOCKED: env.json contains no key candidates.');
    exitCode = 2;
    return;
  }
  if (validCount == 0) {
    final prefixHint = supportedPrefixLengths.isEmpty
        ? ''
        : ' A key becomes decodable only after removing an unsupported '
              'prefix of ${supportedPrefixLengths.join('/')} character(s).';
    stderr.writeln(
      'RELEASE BLOCKED: env.json contains no valid Gemini key '
      '(placeholders found: $placeholderCount).$prefixHint',
    );
    exitCode = 2;
    return;
  }
  stdout.writeln(
    'env.json validation passed ($validCount valid key(s); values hidden).',
  );
}

bool _isValidRawKey(String value) {
  return value.startsWith('AIza') && value.length >= 30;
}

String? _decodeObfuscatedKey(String value) {
  List<int> encoded;
  try {
    encoded = base64.decode(value);
  } on Object {
    return null;
  }
  final primary = Uint8List(encoded.length);
  for (var index = 0; index < encoded.length; index++) {
    primary[index] = encoded[index] ^ _xorKey[index % _xorKey.length];
  }
  final decoded = _tryUtf8(primary);
  if (decoded != null && _isValidRawKey(decoded)) return decoded;

  final legacy = Uint8List(encoded.length);
  for (var index = 0; index < encoded.length; index++) {
    legacy[index] = encoded[index] ^ 0x42;
  }
  final legacyDecoded = _tryUtf8(legacy);
  return legacyDecoded != null && _isValidRawKey(legacyDecoded)
      ? legacyDecoded
      : null;
}

String? _tryUtf8(Uint8List bytes) {
  try {
    return utf8.decode(bytes);
  } on Object {
    return null;
  }
}
