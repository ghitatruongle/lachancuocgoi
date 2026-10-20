import 'dart:convert';
import '../../../core/asset_loader.dart';
import '../../../core/logger.dart';
import 'api_key_format.dart';
import 'api_key_obfuscator.dart';

abstract interface class ApiKeyProvider {
  List<String> getApiKeys();

  int getKeyCount();

  bool get isLoadedFromAssets => false;
}

class EnvironmentApiKeyProvider implements ApiKeyProvider {
  EnvironmentApiKeyProvider({
    String? commaSeparatedKeys,
    String? singleKey,
    AssetLoader? assetLoader,
    AppLogger? logger,
  }) : _commaSeparatedKeys =
           commaSeparatedKeys ??
           const String.fromEnvironment('GEMINI_API_KEYS'),
       _singleKey = singleKey ?? const String.fromEnvironment('GEMINI_API_KEY'),
       _assetLoader = assetLoader,
       _logger = logger {
    _keys = _parseKeys();
  }

  final String _commaSeparatedKeys;
  final String _singleKey;
  final AssetLoader? _assetLoader;
  final AppLogger? _logger;

  List<String> _keys = [];
  bool _envLoaded = false;

  bool _loadedFromAssets = false;

  @override
  bool get isLoadedFromAssets => _loadedFromAssets;

  static const List<String> _placeholderPatterns = <String>[
    'aizareplace',
    'aizayour',
    'aizaexample',
    'aizatest',
    'replace_me',
    'your_api_key',
    'placeholder',
  ];

  static bool isPlaceholderKey(String value) {
    final lower = value.toLowerCase();
    return _placeholderPatterns.any(lower.contains);
  }

  Future<void> ensureLoaded() async {
    if (_envLoaded) return;
    _envLoaded = true;

    if (_keys.isNotEmpty) return;

    try {
      if (_assetLoader == null) {
        throw StateError(
          'AssetLoader is null. Phải cung cấp AssetLoader để load env.json.',
        );
      }
      final raw = await _assetLoader.loadString('env.json');
      _loadedFromAssets = true;
      _warnAboutBundledKeys();
      _parseAndIngestEnvJson(raw);
      _logger?.info(
        'Loaded ${_keys.length} API keys from env.json asset '
        '(SECURITY WARNING: keys are bundled in APK).',
      );
    } on Object catch (e) {
      _logger?.warning('Failed to load env.json: $e');
    }
  }

  void _parseAndIngestEnvJson(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final seen = <String>{..._keys};
    var placeholderCount = 0;
    for (final entry in json.entries) {
      if (entry.key.startsWith('_')) {
        continue;
      }
      final value = entry.value;
      if (value is! String) continue;
      if (isPlaceholderKey(value)) {
        placeholderCount++;
        continue;
      }
      final decoded = _validateAndDecode(value);
      if (decoded != null && seen.add(decoded)) {
        _keys.add(decoded);
      }
    }
    if (placeholderCount > 0) {
      _logger?.warning(
        'SECURITY: Bỏ qua $placeholderCount placeholder key(s) trong env.json. '
        'Có thể bạn đang dùng env.example.json thay vì env.json thật. '
        'Hãy tạo env.json với key thật rồi mới chạy app.',
      );
    }
  }

  void _warnAboutBundledKeys() {
    const isRelease = bool.fromEnvironment('dart.vm.product');
    if (isRelease) {
      _logger?.warning(
        '🚨 SECURITY WARNING: env.json đang được bundle trong APK release. '
        'Bất kỳ ai cài app đều có thể extract API keys. '
        'Hãy giới hạn quota/API, theo dõi bất thường và xoay key khi cần. '
        'Xem docs/API_KEY_SECURITY.md.',
      );
    } else {
      _logger?.info(
        '⚠️ [DEBUG] env.json được load từ assets; key sẽ được bundle trong '
        'APK release và có thể bị trích xuất.',
      );
    }
  }

  @override
  List<String> getApiKeys() => List<String>.unmodifiable(_keys);

  @override
  int getKeyCount() => _keys.length;

  List<String> _parseKeys() {
    final commaKeys = _commaSeparatedKeys
        .split(',')
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty)
        .toList();

    final seen = <String>{};
    final normalized = <String>[];

    for (final rawValue in commaKeys) {
      final decoded = _validateAndDecode(rawValue);
      if (decoded != null && seen.add(decoded)) {
        normalized.add(decoded);
      }
    }

    final singleKey = _singleKey.trim();
    if (singleKey.isNotEmpty) {
      final decoded = _validateAndDecode(singleKey);
      if (decoded != null && seen.add(decoded)) {
        normalized.add(decoded);
      }
    }

    return normalized;
  }

  String? _validateAndDecode(String raw) {
    if (raw.isEmpty) return null;
    if (isSupportedGeminiKey(raw)) return raw;
    final decoded = ApiKeyObfuscator.decode(raw);
    if (decoded == null || decoded.isEmpty || !isSupportedGeminiKey(decoded)) {
      return null;
    }
    return decoded;
  }
}

class StaticApiKeyProvider implements ApiKeyProvider {
  StaticApiKeyProvider(List<String> keys)
    : _keys = List<String>.unmodifiable(
        keys.map((key) => key.trim()).where((key) => key.isNotEmpty),
      );

  final List<String> _keys;

  @override
  List<String> getApiKeys() => _keys;

  @override
  int getKeyCount() => _keys.length;

  @override
  bool get isLoadedFromAssets => false;
}
