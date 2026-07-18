import 'dart:async';
import 'dart:typed_data';

abstract class AssetLoader {
  Future<String> loadString(String key);
  Future<ByteData> load(String key);
}

/// Caches bundled text assets in memory after their first read.
///
/// Binary models are intentionally not duplicated in this cache because the
/// platform asset bundle already returns memory-backed [ByteData].
class CachingAssetLoader implements AssetLoader {
  CachingAssetLoader(this._delegate);

  final AssetLoader _delegate;
  final Map<String, String> _stringCache = <String, String>{};
  final Map<String, Future<String>> _inFlight = <String, Future<String>>{};

  @override
  Future<String> loadString(String key) {
    final cached = _stringCache[key];
    if (cached != null) return Future.value(cached);
    return _inFlight.putIfAbsent(key, () async {
      try {
        final value = await _delegate.loadString(key);
        _stringCache[key] = value;
        return value;
      } finally {
        final removed = _inFlight.remove(key);
        assert(removed != null);
      }
    });
  }

  @override
  Future<ByteData> load(String key) => _delegate.load(key);

  void clearCache() {
    _stringCache.clear();
    _inFlight.clear();
  }
}
