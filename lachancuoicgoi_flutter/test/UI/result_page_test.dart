import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lachancuocgoi_flutter/data/app_database.dart';
import 'package:lachancuocgoi_flutter/data/call_history.dart';
import 'package:lachancuocgoi_flutter/ui/result_page/result_page.dart';

import 'test_helpers.dart';

void main() {
  Future<Widget> buildPage({
    required int historyId,
    String initialRoute = '/result/1',
  }) async {
    return ProviderScope(
      overrides: [
        // Provide a failing database future so tests don't need sqflite FFI.
        appDatabaseFutureProvider.overrideWith(
          (ref) => Future<AppDatabase>.error(
            UnsupportedError('Database not available in tests'),
          ),
        ),
        bridgeOverride(),
        settingsOverride(),
        devModeOverride(),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: initialRoute,
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => const Scaffold(body: Text('Home')),
            ),
            GoRoute(
              path: '/history',
              builder: (_, __) => const Scaffold(body: Text('History')),
            ),
            GoRoute(
              path: '/result/:id',
              builder: (_, state) {
                final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
                return ResultPage(historyId: id);
              },
            ),
          ],
        ),
      ),
    );
  }

  group('ResultPage', () {
    test('stored analysis parser rejects malformed payloads', () {
      expect(parseStoredAnalysisResult(null), isNull);
      expect(parseStoredAnalysisResult('{broken'), isNull);
      expect(parseStoredAnalysisResult('[]'), isNull);
      expect(parseStoredAnalysisResult('{}'), isNull);
    });

    test('default share text is scrubbed and excludes transcript', () {
      const item = CallHistory(
        dateTime: 'now',
        riskLevel: 'RED',
        summary: 'Gọi lại số 0912345678 để xác minh',
        duration: '00:10',
        flagCount: 1,
        transcript: 'Transcript bí mật 0123456789',
        analysisResult:
            '{"overallRiskLevel":"RED","matches":[],"analysisLevel":"l1"}',
      );

      final normal = buildHistoryShareText(item, statusLabel: 'Nguy hiểm');
      final explicit = buildHistoryShareText(
        item,
        statusLabel: 'Nguy hiểm',
        includeTranscript: true,
      );

      expect(normal, isNot(contains('0912345678')));
      expect(normal, isNot(contains('Transcript bí mật')));
      expect(explicit, contains('Transcript bí mật 0123456789'));
    });

    testWidgets('shows loading indicator initially', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseFutureProvider.overrideWith(
            (ref) => Completer<AppDatabase>().future,
          ),
          bridgeOverride(),
          settingsOverride(),
          devModeOverride(),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ResultPage(historyId: 1)),
        ),
      );

      // First frame should show loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      container.dispose();
    });

    testWidgets('shows error when database fails', (tester) async {
      await tester.pumpWidget(await buildPage(historyId: 1));
      await tester.pumpAndSettle();

      // Should show an error message because the DB future threw
      expect(find.textContaining('Lỗi'), findsOneWidget);
    });

    testWidgets('back button navigates to home on error state', (tester) async {
      await tester.pumpWidget(await buildPage(historyId: 1));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('no-audio green record is never rendered as safe', (
      tester,
    ) async {
      final db = InMemoryAppDatabase();
      final id = await db.insert(
        const CallHistory(
          dateTime: 'now',
          riskLevel: 'GREEN',
          summary: 'An toàn',
          duration: '00:10',
          flagCount: 0,
          transcript: '',
          recordingError: 'noAudio',
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseFutureProvider.overrideWith((ref) async => db),
          ],
          child: MaterialApp(home: ResultPage(historyId: id)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Không thu được âm thanh'), findsWidgets);
      expect(find.text('An toàn'), findsNothing);
      expect(find.textContaining('kiểm tra quyền micro'), findsWidgets);

      await db.close();
    });

    testWidgets('renders structured analysis and transcript opt-in dialog', (
      tester,
    ) async {
      final db = InMemoryAppDatabase();
      final id = await db.insert(
        const CallHistory(
          dateTime: 'now',
          riskLevel: 'RED',
          summary: 'Phát hiện yêu cầu OTP',
          duration: '00:20',
          flagCount: 1,
          transcript: 'Hãy đọc mã OTP',
          analysisResult:
              '{"overallRiskLevel":"RED","matches":[{"keyword":"OTP","level":"RED","category":"Chiếm đoạt tài khoản"}],"analysisLevel":"l2","isFallback":true}',
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseFutureProvider.overrideWith((ref) async => db),
          ],
          child: MaterialApp(home: ResultPage(historyId: id)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chi tiết phân tích'), findsOneWidget);
      expect(find.textContaining('L2'), findsOneWidget);
      expect(find.text('Chiếm đoạt tài khoản'), findsOneWidget);
      expect(find.text('Đã dùng bộ phân tích dự phòng.'), findsOneWidget);

      final transcriptShare = find.byTooltip('Chia sẻ nội dung');
      await tester.ensureVisible(transcriptShare);
      await tester.pumpAndSettle();
      await tester.tap(transcriptShare);
      await tester.pumpAndSettle();
      expect(find.text('Chia sẻ toàn bộ nội dung?'), findsOneWidget);
      expect(find.text('Thêm nội dung cuộc gọi'), findsOneWidget);

      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      await db.close();
    });
  });
}
