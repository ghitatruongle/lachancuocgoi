import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l1/l1_analysis.dart';
import 'package:lachancuocgoi_flutter/analysis/analysis_result.dart';
import 'package:lachancuocgoi_flutter/app/settings_controller.dart';
import 'package:lachancuocgoi_flutter/core/analysis_availability.dart';
import 'package:lachancuocgoi_flutter/core/risk_level.dart';
import 'package:lachancuocgoi_flutter/data/app_database.dart';
import 'package:lachancuocgoi_flutter/data/call_history.dart';
import 'package:lachancuocgoi_flutter/data/call_history_retention.dart';
import 'package:lachancuocgoi_flutter/data/session_recovery_store.dart';
import 'package:lachancuocgoi_flutter/services/native_call_shield_bridge.dart';
import 'package:lachancuocgoi_flutter/ui/monitoring_page/monitoring_controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_native_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
  });

  late AppDatabase db;
  late FakeNativeBridge fakeBridge;
  late _RecordingRetentionService retentionService;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = await AppDatabase.open(
      databaseFactory: databaseFactoryFfi,
      inMemory: true,
    );
    fakeBridge = FakeNativeBridge();
    retentionService = _RecordingRetentionService();

    container = ProviderContainer(
      overrides: [
        appDatabaseFutureProvider.overrideWith((ref) async => db),
        nativeBridgeProvider.overrideWithValue(fakeBridge),
        callHistoryRetentionServiceProvider.overrideWithValue(retentionService),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    fakeBridge.dispose();
    await db.database.close();
  });

  Future<CallHistory?> driveEndSession({
    required String transcript,
    double peakAmplitude = 0.0,
    bool hasReceivedAnyAudio = false,
  }) async {
    final analyzer = L1Analyzer(
      vocabularyProvider: () => '{"riskLevels": []}',
      bigramCorrectionsProvider: () => '{"corrections": []}',
    );
    final c = container.read(monitoringControllerProvider.notifier);
    c.init(l1AnalyzerOverride: analyzer);
    c.debugSetAudioState(
      peakAmplitude: peakAmplitude,
      hasReceivedAnyAudio: hasReceivedAnyAudio,
    );
    c.state = c.state.copyWith(
      transcript: transcript,
      analysisResult: transcript.trim().isEmpty
          ? null
          : const AnalysisResult(
              overallRiskLevel: RiskLevel.green,
              matches: [],
            ),
      availability: transcript.trim().isEmpty
          ? AnalysisAvailability.pending
          : AnalysisAvailability.sufficient,
    );

    await Future<void>.delayed(const Duration(milliseconds: 1));
    await c.endSession();
    return (await db.callHistoryDao.getAll()).firstOrNull;
  }

  test(
    'endSession with empty transcript + zero amplitudes → noAudio',
    () async {
      final row = await driveEndSession(
        transcript: '',
        peakAmplitude: 0.0,
        hasReceivedAnyAudio: false,
      );
      expect(row, isNotNull, reason: 'no row inserted');
      expect(row!.recordingError, 'noAudio');
      expect(row.transcript, '');
      expect(row.summary, contains('Không thu được âm thanh'));
      expect(row.summary, contains('micro'));
    },
  );

  test(
    'endSession with empty transcript + loud amplitudes → sttFailed',
    () async {
      final row = await driveEndSession(
        transcript: '',
        peakAmplitude: 0.8,
        hasReceivedAnyAudio: true,
      );
      expect(row, isNotNull);
      expect(row!.recordingError, 'sttFailed');
      expect(row.summary, contains('STT'));
      expect(row.summary, contains('nhận diện'));
    },
  );

  test('endSession with non-empty transcript → null recordingError', () async {
    final row = await driveEndSession(
      transcript: 'Anh ơi cho em xin OTP',
      peakAmplitude: 0.9,
      hasReceivedAnyAudio: true,
    );
    expect(row, isNotNull);
    expect(row!.recordingError, isNull);
    expect(row.transcript, 'Anh ơi cho em xin OTP');
    expect(row.summary, isNotEmpty);
  });

  test(
    'endSession with empty transcript + amplitude == 0.5 → sttFailed',
    () async {
      final row = await driveEndSession(
        transcript: '',
        peakAmplitude: 0.5,
        hasReceivedAnyAudio: true,
      );
      expect(row, isNotNull);
      expect(row!.recordingError, 'sttFailed');
    },
  );

  test(
    'endSession with empty transcript + empty amplitudes → noAudio',
    () async {
      final row = await driveEndSession(
        transcript: '',
        peakAmplitude: 0.0,
        hasReceivedAnyAudio: false,
      );
      expect(row, isNotNull);
      expect(row!.recordingError, 'noAudio');
    },
  );

  test('endSession calls stopMonitoring on the bridge', () async {
    await driveEndSession(
      transcript: 'hello',
      peakAmplitude: 0.5,
      hasReceivedAnyAudio: true,
    );
    expect(fakeBridge.stopMonitoringCalls, 1);
  });

  test('repeated endSession does not stop or save twice', () async {
    await driveEndSession(
      transcript: 'hello',
      peakAmplitude: 0.5,
      hasReceivedAnyAudio: true,
    );
    final controller = container.read(monitoringControllerProvider.notifier);

    await controller.endSession();

    expect(fakeBridge.stopMonitoringCalls, 1);
    expect(await db.callHistoryDao.count(), 1);
    expect(controller.state.phase, MonitoringPhase.saved);
  });

  test('successful save clears the active recovery snapshot', () async {
    await SessionRecoveryStore.save(
      SessionSnapshot(
        phoneNumber: '',
        transcript: 'hello',
        elapsedSeconds: 5,
        riskLevel: 'GREEN',
        analysisResultJson: null,
        recordingError: null,
        startedAt: DateTime.now(),
      ),
    );
    expect(await SessionRecoveryStore.load(), isNotNull);

    await driveEndSession(
      transcript: 'hello',
      peakAmplitude: 0.5,
      hasReceivedAnyAudio: true,
    );

    expect(await SessionRecoveryStore.load(), isNull);
    expect(retentionService.calls, 1);
    expect(retentionService.snapshotWasPresentDuringCleanup, isTrue);
  });

  test('post-save cleanup uses the current retention setting', () async {
    final settings = container.read(settingsControllerProvider);
    await container
        .read(settingsControllerProvider.notifier)
        .update(
          settings.copyWith(
            callHistoryRetention: CallHistoryRetention.sevenDays,
          ),
        );

    await driveEndSession(
      transcript: 'hello',
      peakAmplitude: 0.5,
      hasReceivedAnyAudio: true,
    );

    expect(retentionService.calls, 1);
    expect(retentionService.lastRetention, CallHistoryRetention.sevenDays);
  });

  test('call-event consumer keeps only the canonical masked number', () async {
    final analyzer = L1Analyzer(
      vocabularyProvider: () => '{"riskLevels": []}',
      bigramCorrectionsProvider: () => '{"corrections": []}',
    );
    final controller = container.read(monitoringControllerProvider.notifier);
    controller.init(l1AnalyzerOverride: analyzer);
    controller.streamHandler.initStreams();

    fakeBridge.emitCallEvent(
      NativeCallEvent.fromMap({
        'type': 'INCOMING',
        'timestampMs': 1,
        'numberAvailable': true,
        'phoneNumber': '+84912345678',
      }),
    );
    await Future<void>.delayed(Duration.zero);
    expect(controller.maskedNumber, isNull);

    fakeBridge.emitCallEvent(
      NativeCallEvent.fromMap({
        'type': 'INCOMING',
        'timestampMs': 2,
        'numberAvailable': true,
        'maskedNumber': '******5678',
      }),
    );
    await Future<void>.delayed(Duration.zero);
    expect(controller.maskedNumber, '******5678');
  });

  test('endSession emits NavigateToResult with the inserted id', () async {
    final c = container.read(monitoringControllerProvider.notifier);
    final analyzer = L1Analyzer(
      vocabularyProvider: () => '{"riskLevels": []}',
      bigramCorrectionsProvider: () => '{"corrections": []}',
    );
    c.init(l1AnalyzerOverride: analyzer);
    c.debugSetAudioState(peakAmplitude: 0.5, hasReceivedAnyAudio: true);
    c.state = c.state.copyWith(transcript: 'hello');
    await Future<void>.delayed(const Duration(milliseconds: 1));
    await c.endSession();

    final row = (await db.callHistoryDao.getAll()).firstOrNull;
    expect(row, isNotNull);
    expect(row!.id, greaterThan(0));

    final intent = c.state.navigationIntent;
    expect(intent, isA<NavigateToResult>());
    expect((intent as NavigateToResult).historyId, row.id);
  });
}

class _RecordingRetentionService extends CallHistoryRetentionService {
  int calls = 0;
  CallHistoryRetention? lastRetention;
  bool? snapshotWasPresentDuringCleanup;

  @override
  Future<int> cleanup(
    AppDatabase database,
    CallHistoryRetention retention, {
    DateTime? now,
  }) async {
    calls++;
    lastRetention = retention;
    snapshotWasPresentDuringCleanup = await SessionRecoveryStore.load() != null;
    return 0;
  }
}
