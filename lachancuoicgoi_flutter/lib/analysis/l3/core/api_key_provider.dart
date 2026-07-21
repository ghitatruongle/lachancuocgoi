import 'dart:convert';
import '../../../core/asset_loader.dart';
import '../../../core/logger.dart';
import 'api_key_format.dart';
import 'api_key_obfuscator.dart';

abstract interface class ApiKeyProvider {
  List<String> getApiKeys();

  int getKeyCount();

  /// True nếu keys đang được load từ bundled assets (env.json ship cùng APK).
  /// Bị set bởi [EnvironmentApiKeyProvider] khi fallback vào rootBundle.
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
    // Parse dart-define keys eagerly so getApiKeys() works without ensureLoaded().
    _keys = _parseKeys();
  }

  final String _commaSeparatedKeys;
  final String _singleKey;
  final AssetLoader? _assetLoader;
  final AppLogger? _logger;

  /// Mutable list — populated eagerly from dart-define in constructor,
  /// and optionally extended by [ensureLoaded] from env.json asset.
  List<String> _keys = [];
  bool _envLoaded = false;

  /// True nếu [ensureLoaded] đã fallback sang đọc env.json từ rootBundle
  /// (nghĩa là keys bị bundle trong APK — không an toàn).
  bool _loadedFromAssets = false;

  @override
  bool get isLoadedFromAssets => _loadedFromAssets;

  /// Sentinel patterns cho placeholder keys (AIzaReplace..., REPLACE_ME, etc.).
  /// Khi env.json chứa các giá trị này, keys bị bỏ qua hoàn toàn — tránh
  /// tình trạng dev commit nhầm env.example.json thay vì env.json thật.
  static const List<String> _placeholderPatterns = <String>[
    'aizareplace',
    'aizayour',
    'aizaexample',
    'aizatest',
    'replace_me',
    'your_api_key',
    'placeholder',
  ];

  /// True nếu value trông như placeholder (AIzaReplace..., REPLACE_ME, etc.).
  /// Public để test.
  static bool isPlaceholderKey(String value) {
    final lower = value.toLowerCase();
    return _placeholderPatterns.any(lower.contains);
  }

  /// Load keys from `env.json` asset if dart-define keys were not provided.
  /// Safe to call multiple times — only loads once.
  ///
  /// SECURITY: env.json trong assets bị bundle trong APK, vì vậy người cài
  /// app có thể trích xuất API key. Kiến trúc v1.6.1 chấp nhận ràng buộc này;
  /// key phải được giới hạn quota/API, theo dõi và xoay khi cần.
  Future<void> ensureLoaded() async {
    if (_envLoaded) return;
    _envLoaded = true;

    // If dart-define already provided keys, no need to load env.json.
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

  /// Parse JSON string và validate keys (loại bỏ placeholder, validate format).
  void _parseAndIngestEnvJson(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final seen = <String>{..._keys};
    var placeholderCount = 0;
    for (final entry in json.entries) {
      if (entry.key.startsWith('_')) {
        continue; // skip _comment, _warning, _format
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

  /// Log warning nếu keys đang load từ assets (không an toàn).
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

    // Thêm singleKey nếu chưa có trong comma list
    final singleKey = _singleKey.trim();
    if (singleKey.isNotEmpty) {
      final decoded = _validateAndDecode(singleKey);
      if (decoded != null && seen.add(decoded)) {
        normalized.add(decoded);
      }
    }

    return normalized;
  }

  /// Decode key và validate format hợp lệ (phải bắt đầu bằng 'AIza').
  /// Trả về null nếu key không hợp lệ.
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

  // Static provider luôn inject keys từ constructor → không bao giờ
  // load từ bundled assets. isLoadedFromAssets = false là an toàn.
  @override
  bool get isLoadedFromAssets => false;
}
