import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l1/l1_analysis.dart';
import 'package:lachancuocgoi_flutter/data/app_database.dart';
import 'package:lachancuocgoi_flutter/data/call_history.dart';
import 'package:lachancuocgoi_flutter/services/native_call_shield_bridge.dart';
import 'package:lachancuocgoi_flutter/ui/monitoring_page/monitoring_controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/fake_native_bridge.dart';

/// Sprint 1 (A7) end-to-end test: drives `MonitoringController.endSession()`
/// to verify the inserted `CallHistory` row carries the right
/// `recordingError` and `summary` text.
///
/// This is the most important new test in Sprint 1+2 because it covers
/// the wiring of three production features:
///   1. Sprint 1 (A7) `recordingError` derivation in `endSession()`.
///   2. Sprint 1 (A7) summary text for blank-transcript rows.
///   3. The `recordingError` column in the v6 schema.
///
/// We drive the controller directly through a `ProviderContainer`
/// (without mounting the widget tree) so that:
///   - the GoRouter-free path of `endSession` is exercised
///   - the `state.navigationIntent = NavigateToResult(id)` assignment
///     does NOT call `context.go(...)` (that listener is in the page)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
  });

  late AppDatabase db;
  late FakeNativeBridge fakeBridge;
  late ProviderContainer container;

  setUp(() async {
    db = await AppDatabase.open(
      databaseFactory: databaseFactoryFfi,
      inMemory: true,
    );
    fakeBridge = FakeNativeBridge();

    container = ProviderContainer(
      overrides: [
        appDatabaseFutureProvider.overrideWith((ref) async => db),
        nativeBridgeProvider.overrideWithValue(fakeBridge),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    fakeBridge.dispose();
    await db.database.close();
  });

  /// Set up the controller with a no-op test analyzer, mutate state,
  /// call endSession() in runAsync, and return the inserted row.
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
    c.state = c.state.copyWith(transcript: transcript);

    // Escape the fake async zone so the awaits inside endSession
    // (DB insert) actually run.
    await Future<void>.delayed(const Duration(milliseconds: 1));
    await c.endSession();
    return (await db.callHistoryDao.getAll()).firstOrNull;
  }

  // ─── Case 1: no audio (silent) ──────────────────────────────────────
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

  // ─── Case 2: STT failed (heard something but engine failed) ──────────
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

  // ─── Case 3: success path (transcript present) ──────────────────────
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

  // ─── Case 4: threshold boundary at 0.5 ──────────────────────────────
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

  // ─── Case 5: empty amplitudes list → 0.0 max → noAudio ──────────────
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

  // ─── Case 6: stopMonitoring is called on the bridge ────────────────
  test('endSession calls stopMonitoring on the bridge', () async {
    await driveEndSession(
      transcript: 'hello',
      peakAmplitude: 0.5,
      hasReceivedAnyAudio: true,
    );
    expect(fakeBridge.stopMonitoringCalls, 1);
  });

  // ─── Case 7: navigationIntent carries the inserted id ─────────────
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
