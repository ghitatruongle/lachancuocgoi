import 'dart:collection';

/// A fixed-capacity LRU (Least Recently Used) cache.
///
/// When the cache exceeds [maxSize], the least recently accessed entry is
/// evicted. Both [get] and [put] count as access.
class LruCache<K, V> {
  LruCache({this.maxSize = 1000}) : assert(maxSize > 0, 'maxSize must be > 0');

  final int maxSize;

  final LinkedHashMap<K, V> _cache = LinkedHashMap<K, V>();

  /// Returns the value for [key] if present and moves it to MRU position.
  V? get(K key) {
    final value = _cache.remove(key);
    if (value != null) {
      _cache[key] = value; // re-insert at tail (MRU)
    }
    return value;
  }

  /// Returns true if the key is present (and promotes it to MRU).
  bool containsKey(K key) {
    return _cache.containsKey(key);
  }

  /// Inserts or updates [key] → [value], evicting LRU if over capacity.
  void put(K key, V value) {
    _cache.remove(key); // ensure fresh insertion order
    _cache[key] = value;
    _evictIfNeeded();
  }

  /// Inserts [key] → [value] only if [key] is not already present.
  /// Returns the existing value if present, or null after insertion.
  V? putIfAbsent(K key, V Function() ifAbsent) {
    final existing = _cache[key];
    if (existing != null) {
      // Promote to MRU
      _cache.remove(key);
      _cache[key] = existing;
      return existing;
    }
    final value = ifAbsent();
    _cache[key] = value;
    _evictIfNeeded();
    return null;
  }

  /// Removes [key] from the cache.
  void remove(K key) {
    _cache.remove(key);
  }

  /// Removes all entries.
  void clear() {
    _cache.clear();
  }

  /// Number of entries currently in the cache.
  int get length => _cache.length;

  /// Iterates over all entries (LRU→MRU order).
  Iterable<MapEntry<K, V>> get entries => _cache.entries;

  void _evictIfNeeded() {
    while (_cache.length > maxSize) {
      _cache.remove(_cache.keys.first);
    }
  }

  @override
  String toString() => 'LruCache(${_cache.length}/$maxSize)';
}
