import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_mode.dart';
import 'package:lachancuocgoi_flutter/app/settings_controller.dart';
import 'package:lachancuocgoi_flutter/data/app_database.dart';
import 'package:lachancuocgoi_flutter/data/call_history.dart';
import 'package:lachancuocgoi_flutter/data/call_history_retention.dart';
import 'package:lachancuocgoi_flutter/data/cloud_analysis_consent_store.dart';
import 'package:lachancuocgoi_flutter/data/sensitive_data_reset_service.dart';
import 'package:lachancuocgoi_flutter/data/session_recovery_store.dart';
import 'package:lachancuocgoi_flutter/data/transcript_saver.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('privacy defaults and consent gate stay synchronized', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(settingsControllerProvider);
    await tester.pump();

    final initial = container.read(settingsControllerProvider);
    expect(initial.callHistoryRetention, CallHistoryRetention.thirtyDays);
    expect(initial.cloudAnalysisConsent, isFalse);
    expect(initial.onboardingCompleted, isFalse);

    final gate = container.read(cloudAnalysisConsentStoreProvider);
    expect(gate.isGranted, isFalse);
    expect(
      gate.requireConsent,
      throwsA(isA<CloudAnalysisConsentRequiredException>()),
    );

    await container
        .read(settingsControllerProvider.notifier)
        .setCloudAnalysisConsent(true);
    expect(gate.isGranted, isTrue);
    expect(gate.requireConsent, returnsNormally);
  });

  testWidgets('retention and onboarding choices are persisted', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(settingsControllerProvider);
    await tester.pump();
    final controller = container.read(settingsControllerProvider.notifier);
    await controller.update(
      container
          .read(settingsControllerProvider)
          .copyWith(
            analysisMode: AnalysisMode.gDetection,
            callHistoryRetention: CallHistoryRetention.sevenDays,
          ),
    );
    await controller.completeOnboarding();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('CALL_HISTORY_RETENTION'), '7_days');
    expect(prefs.getBool('onboarding_completed'), isTrue);
  });

  test('retention deletes only parseable records before cutoff', () async {
    final database = InMemoryAppDatabase();
    addTearDown(database.close);
    await database.insert(_history('2025-01-01T00:00:00'));
    await database.insert(_history('12:30:00 25/01/2025'));
    await database.insert(_history('legacy unknown'));

    final deleted = await const CallHistoryRetentionService().cleanup(
      database,
      CallHistoryRetention.thirtyDays,
      now: DateTime(2025, 2, 1),
    );
    expect(deleted, 1);
    final remaining = await database.getAll();
    expect(remaining.map((entry) => entry.dateTime), <String>[
      'legacy unknown',
      '12:30:00 25/01/2025',
    ]);
  });

  test(
    'sensitive reset clears history, recovery and transcript files',
    () async {
      SharedPreferences.setMockInitialValues({});
      final database = InMemoryAppDatabase();
      final temp = await Directory.systemTemp.createTemp('sensitive_reset_');
      addTearDown(database.close);
      addTearDown(() async {
        if (await temp.exists()) await temp.delete(recursive: true);
      });
      await database.insert(_history(DateTime.now().toIso8601String()));
      await SessionRecoveryStore.save(
        SessionSnapshot(
          phoneNumber: '0900000000',
          transcript: 'nội dung',
          elapsedSeconds: 1,
          riskLevel: 'GREEN',
          analysisResultJson: null,
          recordingError: null,
          startedAt: DateTime.now(),
        ),
      );
      await TranscriptSaver.saveTranscript(
        'nội dung nhạy cảm',
        baseDirectory: temp,
      );
      var logsCleared = false;

      final result = await const SensitiveDataResetService().reset(
        database: database,
        transcriptBaseDirectory: temp,
        clearPersistedLogs: () async {
          logsCleared = true;
        },
      );
      expect(result.deletedHistoryCount, 1);
      expect(result.deletedTranscriptCount, 1);
      expect(await database.count(), 0);
      expect(await SessionRecoveryStore.load(), isNull);
      expect(logsCleared, isTrue);
    },
  );
}

CallHistory _history(String dateTime) => CallHistory(
  dateTime: dateTime,
  riskLevel: 'GREEN',
  summary: 'test',
  duration: '00:01',
  flagCount: 0,
  transcript: 'test',
);
