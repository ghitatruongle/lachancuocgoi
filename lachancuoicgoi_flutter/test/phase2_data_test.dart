import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/data/alert_history_entry.dart';
import 'package:lachancuocgoi_flutter/data/app_database.dart';
import 'package:lachancuocgoi_flutter/data/call_history.dart';
import 'package:lachancuocgoi_flutter/data/transcript_saver.dart';
import 'package:lachancuocgoi_flutter/data/vocabulary_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
  });

  group('CallHistory JSON mapping', () {
    test('round-trips alert history safely', () {
      final alert = AlertHistoryEntry(
        timestamp: DateTime(2026, 5, 5, 11, 22, 33).millisecondsSinceEpoch,
        analysisLevel: 'L2',
        riskLevel: 'RED',
        alertCount: 2,
        displayedReason: 'Yeu cau OTP',
        allReasons: const ['OTP', 'Chuyen tien'],
      );

      final history = CallHistory(
        dateTime: '11:22:33 05/05/2026',
        riskLevel: 'RED',
        summary: 'Canh bao',
        duration: '30s',
        flagCount: 2,
        transcript: 'noi dung',
        audioPath: null,
        alertHistory: CallHistory.alertHistoryToJson([alert]),
      );

      final restored = CallHistory.fromMap(history.toMap());
      expect(restored.getAlertHistoryList(), hasLength(1));
      expect(
          restored.getAlertHistoryList().single.getFormattedTime(), '11:22:33');
      expect(
          restored.getAlertHistoryList().single.getRiskLevelColor().toARGB32(),
          0xFFD32F2F);
    });

    test('invalid alert history returns empty list', () {
      const history = CallHistory(
        dateTime: 'now',
        riskLevel: 'GREEN',
        summary: 'safe',
        duration: '0s',
        flagCount: 0,
        transcript: '',
        alertHistory: '{bad json',
      );

      expect(history.getAlertHistoryList(), isEmpty);
    });
  });

  group('AppDatabase and CallHistoryDao', () {
    late AppDatabase appDatabase;

    setUp(() async {
      appDatabase = await AppDatabase.open(
        databaseFactory: databaseFactoryFfi,
        inMemory: true,
      );
    });

    tearDown(() async {
      await appDatabase.close();
    });

    test('performs Room-equivalent CRUD operations', () async {
      final id = await appDatabase.callHistoryDao.insert(
        const CallHistory(
          dateTime: '11:00:00 05/05/2026',
          riskLevel: 'GREEN',
          summary: 'An toan',
          duration: '5s',
          flagCount: 0,
          transcript: 'xin chao',
          audioPath: null,
          analysisType: 'L1',
        ),
      );

      expect(id, greaterThan(0));
      expect(await appDatabase.callHistoryDao.getAll(), hasLength(1));

      await appDatabase.callHistoryDao.updateRiskLevel(id, 'RED');
      final updatedRisk = await appDatabase.callHistoryDao.getById(id);
      expect(updatedRisk?.riskLevel, 'RED');

      await appDatabase.callHistoryDao.update(
        updatedRisk!.copyWith(summary: 'Canh bao moi'),
      );
      final updatedSummary = await appDatabase.callHistoryDao.getByIdSync(id);
      expect(updatedSummary?.summary, 'Canh bao moi');

      await appDatabase.callHistoryDao.deleteById(id);
      expect(await appDatabase.callHistoryDao.getAll(), isEmpty);
    });

    test('watchAll emits after insert', () async {
      final emissions = <List<CallHistory>>[];
      final firstEmission = Completer<void>();
      final secondEmission = Completer<void>();
      final subscription =
          appDatabase.callHistoryDao.watchAll().listen((items) {
        emissions.add(items);
        if (emissions.length == 1 && !firstEmission.isCompleted) {
          firstEmission.complete();
        }
        if (emissions.length == 2 && !secondEmission.isCompleted) {
          secondEmission.complete();
        }
      });
      addTearDown(subscription.cancel);

      await firstEmission.future.timeout(const Duration(seconds: 1));
      expect(emissions, hasLength(1));
      expect(emissions.first, isEmpty);

      await appDatabase.callHistoryDao.insert(
        const CallHistory(
          dateTime: '11:00:00 05/05/2026',
          riskLevel: 'ORANGE',
          summary: 'Canh bao',
          duration: '7s',
          flagCount: 1,
          transcript: 'otp',
          audioPath: null,
        ),
      );
      await secondEmission.future.timeout(const Duration(seconds: 1));
      expect(emissions.last, hasLength(1));
    });

    test('ResultPage provider reads stored history by id', () async {
      final id = await appDatabase.callHistoryDao.insert(
        const CallHistory(
          dateTime: '11:00:00 05/05/2026',
          riskLevel: 'RED',
          summary: 'Canh bao tu database',
          duration: '15s',
          flagCount: 1,
          transcript: 'noi dung fake',
          audioPath: null,
          analysisType: 'L2',
        ),
      );

      final history = await appDatabase.getById(id);

      expect(history, isNotNull);
      expect(history?.riskLevel, 'RED');
      expect(history?.summary, 'Canh bao tu database');
      expect(history?.transcript, 'noi dung fake');
      expect(history?.analysisType, 'L2');
    });
  });

  group('TranscriptSaver', () {
    test('trims and saves transcript into transcripts directory', () async {
      final tempDir = await Directory.systemTemp.createTemp('lccg_test_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final prepared =
          TranscriptSaver.prepareTranscriptForLocalStorage('  noi dung  ');
      final savedPath = await TranscriptSaver.saveTranscript(
        prepared,
        baseDirectory: tempDir,
        timestamp: DateTime(2026, 5, 5, 1, 2, 3),
      );

      expect(prepared, 'noi dung');
      expect(savedPath, isNotNull);
      expect(savedPath, contains('transcript_20260505_010203.txt'));
      expect(await File(savedPath!).readAsString(), 'noi dung');
    });
  });

  group('VocabularyRepository', () {
    test('loads flexible sentence JSON structures', () async {
      final repository = VocabularyRepository(
        assetBundle: _FakeAssetBundle({
          'assets/risk_model_sentences.json': jsonEncode({
            'riskLevels': [
              {
                'sentences': ['an toan'],
                'threats': {
                  'otp': ['doc ma otp'],
                },
              },
            ],
          }),
        }),
      );

      final sentences = await repository.getSituationSentences();
      expect(sentences, containsAll(['an toan', 'doc ma otp']));
    });

    test('loads vocab tokens', () async {
      final repository = VocabularyRepository(
        assetBundle: _FakeAssetBundle({
          'assets/vocab.txt': '[PAD]\n[UNK]\notp\n',
        }),
      );

      expect(await repository.getVocabularyTokens(), ['[PAD]', '[UNK]', 'otp']);
    });
  });
}

class _FakeAssetBundle extends CachingAssetBundle {
  _FakeAssetBundle(this.assets);

  final Map<String, String> assets;

  @override
  Future<ByteData> load(String key) async {
    final value = assets[key];
    if (value == null) {
      throw StateError('Missing fake asset: $key');
    }
    final bytes = Uint8List.fromList(utf8.encode(value));
    return ByteData.view(bytes.buffer);
  }
}
