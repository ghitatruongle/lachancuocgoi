import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/risk_level.dart';

class ResponseCache<T> {
  ResponseCache({this.maxSize = 100});

  static const Duration _ttlRed = Duration(seconds: 30);
  static const Duration _ttlOrange = Duration(minutes: 2);
  static const Duration _ttlDefault = Duration(minutes: 5);

  final int maxSize;
  final LinkedHashMap<String, _CacheEntry<T>> _cache =
      LinkedHashMap<String, _CacheEntry<T>>();

  T? get(String key, {RiskLevel? riskLevel}) {
    final hashedKey = _hashKey(key);
    final entry = _cache.remove(hashedKey);
    if (entry == null) {
      return null;
    }
    final ttl = riskLevel == null ? entry.ttl : _ttlForRisk(riskLevel);
    if (DateTime.now().difference(entry.timestamp) >= ttl) {
      return null;
    }
    _cache[hashedKey] = entry;
    return entry.value;
  }

  void put(String key, T value, {RiskLevel? riskLevel}) {
    // Sweep expired entries trước khi insert để tránh rò rỉ
    sweepExpired();
    final hashedKey = _hashKey(key);
    _cache.remove(hashedKey);
    _cache[hashedKey] = _CacheEntry<T>(
      value: value,
      timestamp: DateTime.now(),
      ttl: _ttlForRisk(riskLevel),
    );
    while (_cache.length > maxSize) {
      _cache.remove(_cache.keys.first);
    }
  }

  /// Removes all expired entries from the cache.
  /// Returns the number of entries removed.
  int sweepExpired() {
    final now = DateTime.now();
    final keysToRemove = <String>[];
    for (final entry in _cache.entries) {
      if (now.difference(entry.value.timestamp) >= entry.value.ttl) {
        keysToRemove.add(entry.key);
      }
    }
    for (final key in keysToRemove) {
      _cache.remove(key);
    }
    return keysToRemove.length;
  }

  CacheStats getStats() {
    return CacheStats(size: _cache.length, maxSize: maxSize);
  }

  void clear() {
    _cache.clear();
  }

  Duration _ttlForRisk(RiskLevel? riskLevel) {
    return switch (riskLevel) {
      RiskLevel.red => _ttlRed,
      RiskLevel.orange => _ttlOrange,
      _ => _ttlDefault,
    };
  }

  String _hashKey(String text) {
    final normalized = text.trim().toLowerCase();
    return sha256.convert(utf8.encode(normalized)).toString();
  }
}

class CacheStats {
  const CacheStats({
    required this.size,
    required this.maxSize,
  });

  final int size;
  final int maxSize;

  double get usagePercent => maxSize > 0 ? (size / maxSize) * 100 : 0;
}

class _CacheEntry<T> {
  const _CacheEntry({
    required this.value,
    required this.timestamp,
    required this.ttl,
  });

  final T value;
  final DateTime timestamp;
  final Duration ttl;
}
