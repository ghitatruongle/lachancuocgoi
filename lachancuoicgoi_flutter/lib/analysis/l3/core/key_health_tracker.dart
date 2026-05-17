import 'api_key_provider.dart';

enum KeyStatus {
  active,
  cooldown,
  exhausted,
}

class KeyHealth {
  const KeyHealth({
    required this.index,
    required this.status,
    required this.consecutiveErrors,
    required this.cooldownUntil,
    required this.lastErrorTime,
    required this.lastErrorMessage,
  });

  final int index;
  final KeyStatus status;
  final int consecutiveErrors;
  final DateTime? cooldownUntil;
  final DateTime? lastErrorTime;
  final String? lastErrorMessage;
}

class KeyHealthTracker {
  KeyHealthTracker(this.apiKeyProvider);

  final ApiKeyProvider apiKeyProvider;
  final Map<int, KeyStatus> _keyStatuses = <int, KeyStatus>{};
  final Map<int, int> _keyConsecutiveErrors = <int, int>{};
  final Map<int, DateTime> _keyCooldownUntil = <int, DateTime>{};
  final Map<int, DateTime> _keyLastErrorTime = <int, DateTime>{};
  final Map<int, String?> _keyLastErrorMessage = <int, String?>{};

  int _preferredKeyIndex = 0;

  void markQuotaExceeded(int keyIndex) {
    final cooldownUntil = _nextMidnight();
    _keyStatuses[keyIndex] = KeyStatus.cooldown;
    _keyCooldownUntil[keyIndex] = cooldownUntil;
    _keyLastErrorTime[keyIndex] = DateTime.now();
    _keyLastErrorMessage[keyIndex] = '429 Quota exceeded';
  }

  void markInvalid(int keyIndex, [String? message]) {
    _keyStatuses[keyIndex] = KeyStatus.exhausted;
    _keyLastErrorTime[keyIndex] = DateTime.now();
    _keyLastErrorMessage[keyIndex] = message ?? '403 Forbidden / Invalid key';
  }

  void markSuccess(int keyIndex) {
    _keyStatuses[keyIndex] = KeyStatus.active;
    _keyConsecutiveErrors[keyIndex] = 0;
    _keyCooldownUntil.remove(keyIndex);
    _keyLastErrorMessage.remove(keyIndex);
    _preferredKeyIndex = keyIndex;
  }

  void markError(int keyIndex, [String? message]) {
    final count = (_keyConsecutiveErrors[keyIndex] ?? 0) + 1;
    _keyConsecutiveErrors[keyIndex] = count;
    _keyLastErrorTime[keyIndex] = DateTime.now();
    _keyLastErrorMessage[keyIndex] = message;
    if (count >= 3) {
      _keyStatuses[keyIndex] = KeyStatus.cooldown;
      _keyCooldownUntil[keyIndex] = _nextMidnight();
    }
  }

  int getAvailableKeyIndex() {
    recoverCooldownKeysIfNeeded();
    final keys = apiKeyProvider.getApiKeys();
    if (keys.isEmpty) {
      return -1;
    }
    if (_preferredKeyIndex >= 0 &&
        _preferredKeyIndex < keys.length &&
        (_keyStatuses[_preferredKeyIndex] ?? KeyStatus.active) ==
            KeyStatus.active) {
      return _preferredKeyIndex;
    }
    for (var offset = 0; offset < keys.length; offset++) {
      final index = (_preferredKeyIndex + offset + 1) % keys.length;
      if ((_keyStatuses[index] ?? KeyStatus.active) == KeyStatus.active) {
        return index;
      }
    }
    return -1;
  }

  List<int> getActiveKeyIndices() {
    recoverCooldownKeysIfNeeded();
    final keys = apiKeyProvider.getApiKeys();
    final active = <int>[];
    for (var index = 0; index < keys.length; index++) {
      if ((_keyStatuses[index] ?? KeyStatus.active) == KeyStatus.active) {
        active.add(index);
      }
    }
    // Shuffle để tránh race condition: 2 luồng concurrent cùng lấy key 0.
    // Bằng cách shuffle, các luồng khác nhau sẽ bắt đầu với key khác nhau,
    // giảm khả năng cả 2 cùng đánh vào key đầu tiên.
    active.shuffle();
    return active;
  }

  bool hasActiveKeys() => getAvailableKeyIndex() >= 0;

  bool areAllKeysDown() => !hasActiveKeys();

  List<KeyHealth> getHealthSummary() {
    recoverCooldownKeysIfNeeded();
    final keys = apiKeyProvider.getApiKeys();
    return List<KeyHealth>.generate(keys.length, (index) {
      return KeyHealth(
        index: index,
        status: _keyStatuses[index] ?? KeyStatus.active,
        consecutiveErrors: _keyConsecutiveErrors[index] ?? 0,
        cooldownUntil: _keyCooldownUntil[index],
        lastErrorTime: _keyLastErrorTime[index],
        lastErrorMessage: _keyLastErrorMessage[index],
      );
    });
  }

  void recoverCooldownKeysIfNeeded() {
    final now = DateTime.now();
    final toRecover = <int>[];
    for (final entry in _keyCooldownUntil.entries) {
      if (!now.isBefore(entry.value)) {
        toRecover.add(entry.key);
      }
    }
    for (final index in toRecover) {
      if (_keyStatuses[index] == KeyStatus.cooldown) {
        _keyStatuses[index] = KeyStatus.active;
        _keyConsecutiveErrors[index] = 0;
      }
      _keyCooldownUntil.remove(index);
    }
  }

  DateTime _nextMidnight() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1);
  }
}
