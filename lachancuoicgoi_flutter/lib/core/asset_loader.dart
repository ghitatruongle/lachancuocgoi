import 'dart:async';
import 'dart:typed_data';

abstract class AssetLoader {
  Future<String> loadString(String key);
  Future<ByteData> load(String key);
}

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
