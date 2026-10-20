import 'dart:collection';

class LruCache<K, V> {
  LruCache({this.maxSize = 1000}) : assert(maxSize > 0, 'maxSize must be > 0');

  final int maxSize;

  final LinkedHashMap<K, V> _cache = LinkedHashMap<K, V>();

  V? get(K key) {
    final value = _cache.remove(key);
    if (value != null) {
      _cache[key] = value;
    }
    return value;
  }

  bool containsKey(K key) {
    return _cache.containsKey(key);
  }

  void put(K key, V value) {
    _cache.remove(key);
    _cache[key] = value;
    _evictIfNeeded();
  }

  V? putIfAbsent(K key, V Function() ifAbsent) {
    final existing = _cache[key];
    if (existing != null) {
      _cache.remove(key);
      _cache[key] = existing;
      return existing;
    }
    final value = ifAbsent();
    _cache[key] = value;
    _evictIfNeeded();
    return null;
  }

  void remove(K key) {
    _cache.remove(key);
  }

  void clear() {
    _cache.clear();
  }

  int get length => _cache.length;

  Iterable<MapEntry<K, V>> get entries => _cache.entries;

  void _evictIfNeeded() {
    while (_cache.length > maxSize) {
      _cache.remove(_cache.keys.first);
    }
  }

  @override
  String toString() => 'LruCache(${_cache.length}/$maxSize)';
}
