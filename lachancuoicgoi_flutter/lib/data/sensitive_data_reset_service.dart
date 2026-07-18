import 'dart:io';

import 'app_database.dart';
import 'session_recovery_store.dart';
import 'transcript_saver.dart';

class SensitiveDataResetResult {
  const SensitiveDataResetResult({
    required this.deletedHistoryCount,
    required this.deletedTranscriptCount,
  });

  final int deletedHistoryCount;
  final int deletedTranscriptCount;
}

/// Deletes user-generated content while leaving non-sensitive preferences
/// such as theme and accessibility choices intact.
class SensitiveDataResetService {
  const SensitiveDataResetService();

  Future<SensitiveDataResetResult> reset({
    required AppDatabase database,
    Directory? transcriptBaseDirectory,
    Future<void> Function()? clearPersistedLogs,
  }) async {
    final historyCount = await database.count();
    await database.deleteAll();
    await SessionRecoveryStore.clear();
    final deletedTranscripts = await TranscriptSaver.deleteAll(
      baseDirectory: transcriptBaseDirectory,
    );
    if (clearPersistedLogs != null) {
      await clearPersistedLogs();
    }
    return SensitiveDataResetResult(
      deletedHistoryCount: historyCount,
      deletedTranscriptCount: deletedTranscripts,
    );
  }
}
