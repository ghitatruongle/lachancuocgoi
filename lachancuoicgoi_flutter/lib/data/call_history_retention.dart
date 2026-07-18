import 'app_database.dart';

/// How long locally stored call history is kept on this device.
enum CallHistoryRetention {
  sevenDays('7_days', 7, '7 ngày'),
  thirtyDays('30_days', 30, '30 ngày'),
  ninetyDays('90_days', 90, '90 ngày'),
  forever('forever', null, 'Không tự động xóa');

  const CallHistoryRetention(this.storageName, this.days, this.label);

  final String storageName;
  final int? days;
  final String label;

  static CallHistoryRetention fromStorageName(String? value) {
    return CallHistoryRetention.values.firstWhere(
      (candidate) => candidate.storageName == value,
      orElse: () => CallHistoryRetention.thirtyDays,
    );
  }
}

/// Applies a retention policy without loading transcript bodies into memory.
class CallHistoryRetentionService {
  const CallHistoryRetentionService();

  Future<int> cleanup(
    AppDatabase database,
    CallHistoryRetention retention, {
    DateTime? now,
  }) async {
    final days = retention.days;
    if (days == null) return 0;
    final cutoff = (now ?? DateTime.now()).subtract(Duration(days: days));
    return database.deleteOlderThan(cutoff);
  }
}
