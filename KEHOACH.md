# Kế hoạch chuyển dự án Lắng Nghe Cuộc Gọi sang Flutter

Nguồn tham chiếu:

- Dự án Kotlin/Android gốc: `E:\lachancuocgoi\lachancuocgoi`
- Báo cáo và source gốc: `E:\lachancuocgoi\lccg_kt.md`
- Source Flutter dự kiến: `E:\lachancuocgoi\lccg_fl.md`
- Thư mục Flutter hiện có: `E:\lachancuocgoi\lachancuoicgoi_flutter`

Mục tiêu bắt buộc:

- Không mất tính năng: mọi workflow trong app Kotlin phải có bản Flutter tương đương.
- Giao diện in đúng: layout, màu, typography, spacing, icon, dialog, overlay, trang lịch sử/result/simulation/monitoring phải khớp theo từng màn hình.
- Giai đoạn đầu chỉ chạy Android, nhưng code Dart/module phải tách để sau này có thể mở iOS. Các tính năng Android độc quyền được đặt sau native bridge.
- Không đưa dependency/generated/binary vào source Dart, nhưng phải copy đúng assets runtime cần thiết.

## Phần 1 - Báo cáo kỹ thuật đối chiếu Kotlin sang Flutter

### 1. Tổng quan kiến trúc dự án gốc

Dự án gốc là Android native Kotlin/Jetpack Compose, package runtime `com.lachancuocgoi.app`, namespace code `com.example.lachancuocgoi`, minSdk 26, target/compileSdk 34. Dự án có ba khối chính:

1. App Android: UI Compose, Room database, foreground service, accessibility/call screening, STT, overlay cảnh báo, phân tích L1/L2/L3.
2. Server phụ trợ: Node.js Express/Socket.IO/Twilio và Whisper Python.
3. Model/data tooling: Python scripts và assets GhitaV3/TFLite/Vosk/JSON runtime.

Bản Flutter dự kiến trong `lccg_fl.md` mới là khung port: đã có `pubspec.yaml`, router, settings, core analysis, data, service bridge, UI cơ bản, Android manifest/native bridge và parity stub. Khi triển khai thật phải biến các parity stub thành code chạy được, đồng thời giữ native Android service cho những API Flutter thuần không thay thế được.

### 2. Module build và cấu hình

Kotlin gốc:

- `settings.gradle.kts`, `build.gradle.kts`, `gradle/libs.versions.toml`, `app/build.gradle.kts`
- Android Gradle Plugin, Kotlin, KSP, Compose compiler, Room, Gson, Gemini SDK, ML Kit, Google Play Services TFLite, Vosk, JNA.
- `local.properties` có API keys Gemini nhưng không được đưa vào Markdown.

Flutter tương ứng:

- `pubspec.yaml` trong `lccg_fl.md`
- Dependencies: Flutter Material, Riverpod, GoRouter, sqflite, shared_preferences, permission_handler, speech_to_text, tflite_flutter, google_generative_ai, path_provider.
- Android native module vẫn cần thêm Gradle deps riêng cho Accessibility, CallScreening, foreground service, overlay, Vosk/JNA nếu tiếp tục dùng native Vosk.

Việc cần làm:

- Tạo project Flutter thật trong `E:\lachancuocgoi\lachancuoicgoi_flutter`.
- Đồng bộ `applicationId`, versionCode/versionName, minSdk/targetSdk, signing/release config.
- Thêm Android manifest permissions y hệt app gốc.
- Chuyển assets từ `app/src/main/assets` sang `assets/`.
- Tách secrets/API keys sang build config hoặc secure local config, không hardcode vào repo.

Tiêu chí đạt:

- `flutter pub get` thành công.
- `flutter build apk --debug` thành công.
- APK cài được trên Android và có đầy đủ assets.

### 3. App shell, navigation và settings

Kotlin gốc:

- `MainActivity.kt`: xin quyền, splash, Room init, NavHost Compose.
- `MainViewModel.kt`: khởi tạo database async.
- `MainApplication.kt`: application lifecycle.
- Router Compose gồm `home`, `simulation`, `monitoring`, `result/{historyId}`, `history`, `tips_lesson`.
- Settings gồm theme, analysis mode, audio boost, developer mode, speakerphone, permission dialogs.

Flutter dự kiến:

- `lib/main.dart`
- `lib/app/lachancuocgoi_app.dart`
- `lib/app/router.dart`
- `lib/app/settings_controller.dart`

Việc cần làm:

- Port NavHost sang GoRouter dùng path khớp: `/`, `/simulation`, `/monitoring`, `/result/:historyId`, `/history`, `/tips_lesson`.
- Port settings từ SharedPreferences Android sang `shared_preferences`.
- Giữ `AnalysisMode` storage name đúng Kotlin: `NORMAL`, `GDetection`, `GEMINI_API`.
- Xử lý intent native vào Flutter qua MethodChannel/EventChannel để mở monitoring và show alert.
- Splash screen Android/Flutter phải giống app gốc.

Rủi ro:

- Tên enum/cấu hình sai sẽ làm fallback mode sai.
- Deep link/intents từ service native không vào đúng route nếu bridge thiếu event.

### 4. UI theme và giao diện

Kotlin gốc:

- `ui/theme/Color.kt`, `Theme.kt`, `Shape.kt`, `Spacing.kt`, `Type.kt`.
- UI Compose gồm Home, Monitoring, History, Result, Simulation, TipsLesson, dialogs, warning overlays, waveform components.
- XML resources có icon/drawable/layout cũ, nhưng UI chính đang dùng Compose.

Flutter dự kiến:

- `lib/ui/theme/app_theme.dart`
- `lib/ui/home_page/home_page.dart`
- `lib/ui/monitoring_page/*`
- `lib/ui/history_page/history_page.dart`
- `lib/ui/result_page/result_page.dart`
- `lib/ui/simulation_page/simulation_page.dart`
- `lib/ui/tips_lesson_page/tips_lesson_page.dart`
- Parity stub cho nhiều component con.

Việc cần làm:

- Dùng màu gốc từ Kotlin:
  - Light primary `0xFF1257C0`, background `0xFFF6F8FC`, surface `0xFFFFFFFF`, error `0xFFC53E3E`, warning container `0xFFFFE8C4`.
  - Dark primary `0xFFADC6FF`, background `0xFF0D1119`, surface `0xFF141A24`, error `0xFFFFB4AB`, warning container `0xFF5D4300`.
- Port typography/shape/spacing dùng `AppSpacing`: 4, 8, 12, 16, 20, 24, 32 dp.
- Tạo Flutter widget riêng cho từng Composable:
  - HomePage, InstructDialog, RightsDialog, PermissionPromptCard, PermissionsTab.
  - SettingsDialog, SettingsTab, DeveloperModeManager/DevPasswordDialog.
  - MonitoringPage, AlertHistorySection, AudioWaveform, LiveConversation, Warning/RedWarning/OrangeWarning.
  - HistoryPage, HistoryViewModel, HistoryItemCard.
  - ResultPage, RecordingCard, TranscriptCard, AnalysisSummaryCard.
  - SimulationPage, SearchBar, CategoryChips, ScenarioCard, Skeleton/Empty/NoResults.
  - TipsLessonPage và TipCard.
- Port icons: ưu tiên Material Icons/asset vector từ Android; nếu icon custom thì copy asset.
- Chụp screenshot Kotlin gốc làm baseline, sau đó so với Flutter bằng pixel/golden/manual QA.

Tiêu chí đạt:

- Mọi màn hình có cùng nội dung, thứ tự, spacing, màu, icon, trạng thái loading/empty/error.
- Dialog/overlay cảnh báo RED/ORANGE khớp về hành vi và hình thức.
- Không có text tràn, overlap, layout vỡ trên các kích thước mobile phổ biến.

### 5. Data layer và lưu lịch sử

Kotlin gốc:

- `data/AppDatabase.kt`: Room database version 5, table `call_history`.
- `data/CallHistory.kt`: entity có `alert_history` JSON.
- `data/CallHistoryDao.kt`: insert/getAll/getById/delete/update.
- `data/TranscriptSaver.kt`: lưu transcript local.
- `data/VocabularyRepository.kt`: đọc vocabulary/assets.

Flutter dự kiến:

- `lib/data/app_database.dart`
- `lib/data/call_history.dart`
- `lib/data/alert_history_entry.dart`
- Stub: `call_history_dao.dart`, `transcript_saver.dart`, `vocabulary_repository.dart`.

Việc cần làm:

- Tạo schema sqflite giống Room:
  - `id INTEGER PRIMARY KEY AUTOINCREMENT`
  - `dateTime TEXT NOT NULL`
  - `riskLevel TEXT NOT NULL`
  - `summary TEXT NOT NULL`
  - `duration TEXT NOT NULL`
  - `flagCount INTEGER NOT NULL`
  - `transcript TEXT NOT NULL`
  - `audioPath TEXT`
  - `analysisResult TEXT`
  - `analysisType TEXT`
  - `alert_history TEXT`
- Viết DAO Dart đầy đủ: insert, getAll stream/future, getById, getByIdSync, deleteAll, deleteById, updateRiskLevel, update.
- Viết migration từ version cũ lên version 5.
- Port JSON parse `AlertHistoryEntry`.
- Port `TranscriptSaver.prepareTranscriptForLocalStorage` và save file sang app documents/downloads.

Tiêu chí đạt:

- Lịch sử cuộc gọi tạo từ Flutter đọc/ghi đúng.
- ResultPage đọc lại được transcript, alert history, risk, duration.
- Xóa một item/xóa tất cả hoạt động.

### 6. Analysis common và model domain

Kotlin gốc:

- `AnalysisResult.kt`, `AnalysisLevel.kt`, `Analyzer.kt`, `HealthCheck.kt`.
- `TextNormalizer.kt`, `FuzzyMatcher.kt`.
- `RiskLevel.kt`.

Flutter dự kiến:

- `lib/core/risk_level.dart`
- `lib/analysis/analysis_result.dart`
- `lib/analysis/analysis_level.dart`
- `lib/analysis/analyzer.dart`
- `lib/analysis/health_check.dart`
- `lib/analysis/common/text_normalizer.dart`
- `lib/analysis/common/fuzzy_matcher.dart`

Việc cần làm:

- Giữ enum order RiskLevel: GREEN/YELLOW/ORANGE/RED tương ứng index 0/1/2/3.
- Giữ hàm `fromInt`, `fromString`, `deescalate`.
- Kiểm tra `TextNormalizer` Dart có loại dấu tiếng Việt đúng bằng Kotlin. Bản dự kiến hiện là logic rút gọn, cần bổ sung đầy đủ phonetic/slang/noise modes.
- Port `FuzzyMatcher` Damerau-Levenshtein dùng cutoff maxDistance.
- Viết unit test so sánh output Kotlin và Dart trên tập câu tiếng Việt có dấu/không dấu/sai STT.

Tiêu chí đạt:

- Tokenization của Dart khớp Kotlin với cùng input và config.
- RiskLevel serialize/deserialize khớp database và UI.

### 7. L1 - Keyword/trie/Aho-Corasick

Kotlin gốc:

- `Analysis/L1/L1Analysis.kt`: `FlatTrie`, build trie từ `risk_model_vocabulary.json`, bigram corrections, fuzzy single token, streaming session.
- `Analysis/L1/L1Result.kt`: parse matches thành risk/reason/confidence.

Flutter dự kiến:

- `lib/analysis/l1/l1_analysis.dart` hiện mới là manual core rút gọn.
- `lib/analysis/l1/l1_result.dart` hiện là parity stub.

Việc cần làm:

- Port đầy đủ `FlatTrie` sang Dart:
  - node arrays/maps
  - failure links
  - metadata pack/unpack
  - original keyword storage
  - category id mapping
- Port load `risk_model_vocabulary.json`.
- Port load `bigram_corrections.json`.
- Port `applyBigramCorrections`.
- Port `analyzeStream`, `analyze`, `findMatchesLinear`, `findExactMatchNode`.
- Port `L1ResultParser`:
  - critical keywords
  - category grouping
  - confidence calculation
  - adjusted risk level/reason.
- Kiểm tra incremental state: `processedWordCount`, `processedTextLength`, `lastResult`.

Tiêu chí đạt:

- Cùng transcript cho L1 phải ra cùng risk, keywords, categories, reason logic với Kotlin.
- Sai số chấp nhận chỉ ở format string nếu đã được quy ước, không sai risk.

### 8. L2 - GDetection, TFLite, WFSA, Safety

Kotlin gốc:

- `L2Analysis.kt`: chạy song song MobileBERT và GDetection, fuse kết quả, high confidence fast path, cross-validation override, fallback.
- `GDetectionEngine.kt`: load slang/scoring/tier/patterns, build trie, match sentences/scenarios/patterns/context.
- `GModels.kt`, `GFlash.kt`, `GPatternMatcher.kt`, `GThinking.kt`, `ScenarioMatcher.kt`, `SentenceMatcher.kt`, `RiskScenariosMasterModel.kt`.
- `TFLiteIntentClassifier.kt`: Google Play Services TFLite, vocab WordPiece, logits/quantization, softmax, cache.
- `WFSA`: `ScamGraphBuilder.kt`, `WfsaEngine.kt`.
- `SafetyFilter.kt`.

Flutter dự kiến:

- Manual core: `lib/analysis/l2/l2_analysis.dart`, `g_detection/g_detection_engine.dart`, `intent/tflite_intent_classifier.dart`, `safety/safety_filter.dart`, `wfsa/wfsa_engine.dart`.
- Nhiều stub: `g_flash.dart`, `g_models.dart`, `g_pattern_matcher.dart`, `g_thinking.dart`, `scenario_matcher.dart`, `sentence_matcher.dart`, `scam_graph_builder.dart`, `l2_result.dart`.

Việc cần làm:

- Port `GModels` đầy đủ:
  - `GResult`, `RiskScore`, `SituationMatchResult`, `SentenceMatch`, `ScenarioMatch`.
  - DTO cho risk vocabulary, situation, sentence, patterns, scoring, tiers.
- Port `GFlash.tokenize` và slang config đúng Kotlin.
- Port `GDetectionEngine` đầy đủ:
  - `initialize` với mutex/guard.
  - load assets: `slang_config`, `scoring_config`, `tier_config`, `risk_model_vocabulary`, `risk_model_situation`, `risk_model_sentences`, `phrase_patterns`, `risk_scenarios_master`.
  - build keyword trie và topic map.
  - sentence match, scenario match, pattern match, context score, proximity, position weight.
- Port `GThinking` đầy đủ:
  - tier1/tier2/tier3 logic.
  - charity false-positive guard.
  - force RED rules.
  - weighted score.
  - alertEnabled logic.
- Port `GPatternMatcher` với template keyword/category/wildcard, min/max gap.
- Port `ScenarioMatcher` và `SentenceMatcher` để dùng TF-IDF/Jaccard/cosine nếu Kotlin đang dùng.
- Port `TFLiteIntentClassifier`:
  - Kiểm tra plugin `tflite_flutter` có load được `ghitav3.tflite`.
  - Giữ `MAX_SEQ_LEN = 256`.
  - Giữ label order 23 class y hệt Kotlin.
  - Port WordPiece tokenizer dùng fallback remove accent.
  - Xử lý quantized output int8/uint8/float32.
  - Giữ inference cache threshold 20%.
- Port `WFSA`:
  - Graph scenarios/stages/weights.
  - Active scenario name/stage.
  - `analyzeSegment`.
- Port `SafetyFilter`.
- Port `L2ResultParser`.
- Port `L2Analyzer` fuse logic:
  - AI high confidence >= 0.80.
  - direct confidence >= 0.62, margin >= 0.15.
  - assist confidence >= 0.50, margin >= 0.08.
  - GDetection override khi AI safe nhưng context RED.
  - WFSA score thresholds.

Tiêu chí đạt:

- L2 Flutter với cùng asset/cùng transcript cho kết quả risk khớp Kotlin.
- Model TFLite chạy on-device trên Android thật.
- Nếu TFLite lỗi, GDetection/WFSA vẫn chạy.

### 9. L3 - Gemini online AI

Kotlin gốc:

- `L3Analysis.kt`: one-shot + session incremental, smart buffering, risk decay, parse JSON, health check.
- `GeminiClient.kt`: API key rotation, model fallback, rate limit, circuit breaker, metrics.
- `GeminiChatSession.kt`, `GeminiConfig.kt`, `GeminiMetrics.kt`, `GeminiResponse.kt`, `KeyHealthTracker.kt`, `ResponseCache.kt`, `ApiKeyProvider.kt`, `ApiKeyObfuscator.kt`, `PIIStripper.kt`, `PromptBuilder.kt`, `GeminiSummarizer.kt`.

Flutter dự kiến:

- Manual core: `l3_analysis.dart`, `gemini_client.dart`, `pii_stripper.dart`, `prompt_builder.dart`.
- Stub: chat session, config, metrics, response, key health, response cache, summarizer, api key provider/obfuscator.

Việc cần làm:

- Port API key provider:
  - Android debug/local properties hoặc secure storage.
  - Không hardcode secret vào Dart.
- Port `GeminiConfig.forAnalysis`.
- Port `GeminiClient` đầy đủ:
  - rate limit 1s.
  - fallback model list.
  - key rotation.
  - classify 403/404/429/quota/network.
  - circuit breaker closed/open/half-open.
  - metrics.
- Port `KeyHealthTracker`:
  - ACTIVE/COOLDOWN/EXHAUSTED.
  - quota reset 00:00.
  - invalid/revoked handling.
- Port `ResponseCache` với TTL theo risk.
- Port `PIIStripper` dùng regex Kotlin, không rút gọn.
- Port `PromptBuilder` đầy đủ examples/schema.
- Port `GeminiChatSession` cho incremental conversation.
- Port `GeminiSummarizer` nếu ResultPage/history đang cần summary.
- Giữ fallback L3 -> L2 khi mất mạng hoặc API error.

Tiêu chí đạt:

- Không gửi PII gốc lên cloud.
- L3 có fallback an toàn về L2.
- L3 parse được JSON kể cả model trả text bao quanh.

### 10. STT, audio và transcript

Kotlin gốc:

- `SpeechToTextManager.kt`: Google Speech, auto-restart, error handling, overlap detection, RMS waveform, Vosk fallback.
- `VoskSttManager.kt`: offline STT model-vn.
- `CreatorAudioCaptureManager.kt`, `CreatorMediaProjectionService.kt`: creator mode/media projection.
- `TranscriptionHub.kt`: hợp nhất transcript từ Accessibility Live Caption.
- `SttEngine.kt`.

Flutter dự kiến:

- `lib/services/speech_to_text_manager.dart` hiện mới dùng package `speech_to_text`.
- Stub: `vosk_stt_manager.dart`, `creator_media_projection_service.dart`, `creator_audio_capture_manager.dart`, `transcription_hub.dart`, `stt_engine.dart`.
- Native bridge: `NativeCallShieldBridge`.

Việc cần làm:

- Quyết định ranh giới:
  - UI/state transcript ở Dart.
  - Foreground service, media projection, accessibility caption, Vosk native nên giữ Kotlin native.
- Nếu dùng `speech_to_text` Dart:
  - Port overlap detection.
  - Auto restart.
  - Partial/final transcript rules.
  - RMS waveform nếu package expose đủ.
- Nếu cần parity cao hơn:
  - Giữ `SpeechToTextManager.kt` native và stream transcript/RMS sang Flutter qua EventChannel.
- Port `TranscriptionHub` thành native singleton + EventChannel.
- Copy Vosk model `model-vn/` và test load path trong Flutter Android assets.
- Port Creator Mode nếu developer mode bật:
  - MediaProjection request.
  - Foreground service type `mediaProjection|microphone`.
  - Stream transcript vào Flutter.

Tiêu chí đạt:

- Nói vào microphone và transcript cập nhật real time.
- Google STT lỗi/mất mạng thì fallback Vosk nếu app gốc có.
- Waveform vẫn chạy.
- Không lặp transcript do partial result.

### 11. Android native service và bridge

Kotlin gốc:

- `BackgroundMonitoringService.kt`
- `UnifiedAccessibilityService.kt`
- `CallScreeningServiceImpl.kt`
- `TransparentTrampolineActivity.kt`
- `CreatorMediaProjectionService.kt`
- `receiver/CallReceiver.kt`
- `ui/OverlayManager.kt`

Flutter dự kiến:

- `android/app/src/main/kotlin/com/lachancuocgoi/MainActivity.kt` có MethodChannel cơ bản.
- Stub Dart cho các service.

Việc cần làm:

- Copy/port native Kotlin service vào Flutter Android module.
- Đổi package sang `com.lachancuocgoi` hoặc cấu hình namespace thống nhất.
- Tạo MethodChannel:
  - request permissions.
  - start/stop monitoring service.
  - show red/orange alert.
  - permission snapshot.
  - open accessibility settings/call screening role.
- Tạo EventChannel:
  - transcript stream.
  - RMS stream.
  - call events.
  - monitoring state.
  - alert events.
- Manifest:
  - permissions y hệt Kotlin gốc.
  - foreground service types.
  - accessibility meta-data XML.
  - call screening service.
  - receiver phone state.
- Xử lý Android 14 background start restriction bằng `TransparentTrampolineActivity` như gốc.
- Giữ notification channel IDs để không đổi hành vi.

Tiêu chí đạt:

- Cuộc gọi đến có notification/overlay giám sát.
- Nút giám sát trong notification start foreground service.
- Accessibility auto-answer/end call hoạt động nếu được cấp quyền.
- Alert overlay RED/ORANGE hiện ngoài app.

### 12. Monitoring workflow

Kotlin gốc:

- `MonitoringViewModel.kt` là module lớn nhất: state transcript, selected/effective mode, L3 fallback/recovery, alert queues L1/L2, batching, waveform, timer, simulation, save history, media projection.
- `MonitoringPage.kt` hiện UI live.

Flutter dự kiến:

- `lib/ui/monitoring_page/monitoring_controller.dart`
- `lib/ui/monitoring_page/monitoring_page.dart`
- Stub cho subcomponents.

Việc cần làm:

- Port state:
  - selectedMode, effectiveMode, networkAvailable, isFallbackActive.
  - transcript, analysisResult, currentAlert, amplitudes, elapsedTime, isListening.
  - navigation event/result id.
  - alert history batch.
- Port logic:
  - startListening.
  - loadAndStartSimulation.
  - analyzeTranscriptIncrementally.
  - analyzeWithL3/analyzeWithLocalMode.
  - publishAnalysisResult merge risk.
  - tryRecoverL3Session/enterL3FallbackMode.
  - updateAlert.
  - L1/L2 batch timer.
  - stopListeningAndSave.
  - final analysis and update history.
- Port UI:
  - live conversation.
  - audio waveform.
  - alert history section.
  - fallback/network indicator.
  - warning modal/overlay trigger.

Tiêu chí đạt:

- Bật/dừng monitoring cho kết quả y hệt app gốc.
- Transcript, alert, history, result flow không mất dữ liệu.
- Simulation mode chạy script theo timestamp.

### 13. Home, permissions và settings dialogs

Kotlin gốc:

- `HomePage.kt`
- `InstructDialog.kt`
- `RightsDialog.kt`
- `PermissionsTab.kt`
- `PermissionUtils.kt`
- `SettingsDialog.kt`, `SettingsState.kt`, `SettingsTab.kt`, `AnalysisMode.kt`, `DeveloperModeManager.kt`, `DevPasswordDialog.kt`.

Flutter dự kiến:

- HomePage cơ bản.
- Settings controller cơ bản.
- Nhiều dialog chưa port.

Việc cần làm:

- Port permission utils:
  - record audio.
  - phone state/call log.
  - overlay.
  - notification.
  - foreground service.
  - call screening role.
  - accessibility enabled.
- Port rights dialog đầy đủ tab/card/state.
- Port instruction dialog.
- Port settings dialog:
  - theme switch.
  - analysis mode radio.
  - audio boost.
  - auto speakerphone.
  - developer mode password.
  - creator mode gates.

Tiêu chí đạt:

- User mới mở app có thể cấp quyền đầy đủ.
- Trang Home giống Compose gốc, không thiếu nút/chức năng.

### 14. History và Result

Kotlin gốc:

- `HistoryPage.kt`, `HistoryViewModel.kt`, `HistoryItemCard.kt`.
- `ResultPage.kt`, `ResultViewModel.kt`.
- Result có share/download transcript, summary, alert history.

Flutter dự kiến:

- `history_page.dart`, `result_page.dart` cơ bản.
- Stub cho view model/card.

Việc cần làm:

- Port history list UI, delete, empty state, item card.
- Port ResultPage:
  - risk summary card.
  - recording/transcript card.
  - share intent.
  - save/download transcript.
  - alert history processing.
- Port `ResultViewModel` state: alertHistory, isSaving, saveResult.

Tiêu chí đạt:

- Lịch sử sắp xếp giảm dần theo id.
- Bấm item vào đúng result.
- Share/download transcript hoạt động.

### 15. Simulation và Tips Lesson

Kotlin gốc:

- `SimulationPage.kt`, `SimulationViewModel.kt`.
- `TipsLessonPage.kt`.
- Simulation đọc `situation_test.json`, filter search/category, normal/dev mode.

Flutter dự kiến:

- Simulation/Tips cơ bản.
- Stub cho view model logic.

Việc cần làm:

- Port `SimulationScenarioData`, `SimulationScriptLine`.
- Load `situation_test.json`.
- Port normal mode titles và developer mode.
- Port search/category filter.
- Port skeleton/loading/empty/no-results.
- Port simulation playback vào MonitoringController theo timestamp.
- Port TipsLesson đầy đủ list, severity, share action.

Tiêu chí đạt:

- Chọn scenario mở monitoring với title encoded.
- Script phát đúng thứ tự/timestamp.

### 16. Server phụ trợ

Kotlin source package có server:

- `server/src/index.js`
- `routes/twilioRoutes.js`
- `services/audioStreamHandler.js`
- `speechService.js`
- `twilioService.js`
- `whisper_server.py`

Flutter migration:

- Không bắt buộc viết lại server bằng Dart.
- Giữ server Node như backend phụ trợ nếu workflow Twilio/Whisper cần.
- App Flutter chỉ cần client/bridge nếu có kết nối server.

Việc cần làm:

- Xác định app mobile hiện có gọi server ở đâu. Nếu không gọi trực tiếp thì server giữ nguyên.
- Nếu cần, tạo Dart service client cho Socket.IO/HTTP.
- Cập nhật README/chạy server riêng.

Tiêu chí đạt:

- Server vẫn start được bằng `npm start`.
- Webhook/Twilio/Whisper không bị ảnh hưởng bởi migration mobile.

### 17. Assets và model

Cần copy sang Flutter:

- `ghitav3.tflite`
- `vocab.txt`
- `bigram_corrections.json`
- `context_rules.json`
- `phrase_patterns.json`
- `risk_model_sentences.json`
- `risk_model_situation.json`
- `risk_model_vocabulary.json`
- `risk_scenarios_master.json`
- `safety_keywords.json`
- `scoring_config.json`
- `situation_test.json`
- `slang_config.json`
- `tier_config.json`
- `logo.png`
- `model-vn/`

Không copy vào source Dart:

- APK, ZIP model archive, `.h5`, checkpoints, Gradle build, `.cxx`, node_modules, virtualenv, logcat.

Việc cần làm:

- Tạo `assets/` trong Flutter.
- Copy file đúng đường dẫn trong `pubspec.yaml`.
- Test `rootBundle.loadString` cho JSON/text.
- Test TFLite asset load.
- Test Vosk model path với native service.

Tiêu chí đạt:

- Mọi asset runtime load được trên Android debug/release.

## Phần 2 - Lộ trình chuyển Kotlin sang Flutter

### Giai đoạn 0 - Đóng băng baseline Kotlin

Công việc:

- Build và cài app Kotlin gốc trên thiết bị/emulator.
- Chụp screenshot baseline cho tất cả màn hình: Home, Settings, Rights, Instruct, Monitoring idle/active, RedWarning, OrangeWarning, History, Result, Simulation, Tips.
- Ghi lại video workflow:
  - lần đầu cấp quyền.
  - bật monitoring mic.
  - simulation scenario.
  - L1/L2/L3 modes.
  - cuộc gọi đến/call screening/accessibility nếu có thiết bị thật.
- Chạy unit/instrumented tests hiện có.
- Tạo tập transcript mẫu cho L1/L2/L3 để so sánh.

Kết quả cần có:

- Thư mục `migration_baseline/` gồm screenshot, video, transcript, expected result.
- Danh sách tính năng gốc có bằng chứng.

### Giai đoạn 1 - Tạo skeleton Flutter Android

Công việc:

- Tạo project Flutter trong `E:\lachancuocgoi\lachancuoicgoi_flutter`.
- Đồng bộ `pubspec.yaml` từ `lccg_fl.md`.
- Tạo tree `lib/app`, `lib/core`, `lib/analysis`, `lib/data`, `lib/services`, `lib/ui`, `android/app/src/main/kotlin`.
- Copy Android manifest và native XML config.
- Copy assets runtime.
- Thêm lint, format, test config.

Kết quả cần có:

- `flutter pub get` chạy được.
- App hiện HomePage trên Android.
- Router mở được các route rỗng/cơ bản.

### Giai đoạn 2 - Port domain model và data

Công việc:

- [x] Implement RiskLevel, AnalysisMode, AnalysisLevel, AnalysisResult, KeywordMatch, HealthReport.
- [x] Implement sqflite database, DAO, migration, CallHistory, AlertHistoryEntry.
- [x] Implement TranscriptSaver, VocabularyRepository.
- [x] Viết unit test cho mapping database và JSON.

Kết quả cần có:

- Thêm/xóa/đọc lịch sử local được.
- ResultPage đọc dữ liệu fake được.

Cập nhật 2026-05-05:

- Đã hoàn tất các module Phase 2 trong `E:\lachancuocgoi\lachancuoicgoi_flutter`.
- `ResultPage` đã đọc được bản ghi `CallHistory` qua provider dùng chung với data layer.
- Đã khôi phục asset thiếu `assets/risk_model_situation.json` từ bản backup cùng thư mục assets để Flutter asset bundle build được.
- Xác minh: `flutter analyze` không có lỗi, `flutter test` pass 15/15 test.

### Giai đoạn 3 - Port UI pixel parity lần 1

Công việc:

- Port theme exact từ Kotlin.
- Port HomePage và dialogs.
- Port Settings/Rights/Instruct.
- Port History/Result/Tips/Simulation UI.
- Port Monitoring UI idle và active mock.
- Copy icon/assets cần thiết.
- Chụp screenshot Flutter so với baseline.

Kết quả cần có:

- UI tĩnh chưa cần service thật nhưng hình dáng khớp gốc.
- Tất cả screen route không crash.

### Giai đoạn 4 - Port analysis common và L1

Công việc:

- Port TextNormalizer đầy đủ.
- Port FuzzyMatcher đầy đủ.
- Port FlatTrie/Aho-Corasick L1.
- Port BigramCorrections.
- Port L1ResultParser.
- Viết tests với transcript mẫu và JSON gốc.

Kết quả cần có:

- L1 Flutter ra cùng risk/matches với Kotlin trên bộ test.
- Monitoring mock gọi L1 được.

### Giai đoạn 5 - Port L2 GDetection

Công việc:

- Port model DTO.
- Port GFlash tokenizer.
- Port GDetectionEngine load config/keyword trie/topic map.
- Port PatternMatcher, SentenceMatcher, ScenarioMatcher.
- Port GThinking full tier/scoring/alert logic.
- Port L2ResultParser.
- Viết tests đối chiếu L2 GDetection không TFLite.

Kết quả cần có:

- GDetection Flutter đọc đủ assets và phân tích transcript mẫu.
- Risk/reason/alertEnabled khớp Kotlin.

### Giai đoạn 6 - Port TFLite intent và WFSA

Công việc:

- Load `ghitav3.tflite` bằng `tflite_flutter` hoặc native TFLite bridge nếu plugin không hỗ trợ shape/quantization.
- Port WordPiece tokenizer.
- Port output tensor quantization guard.
- Port intent labels/extensions.
- Port inference cache.
- Port ScamGraphBuilder/WfsaEngine.
- Hợp nhất vào L2Analyzer.

Kết quả cần có:

- TFLite inference chạy trên Android.
- L2 full fusion khớp Kotlin với transcript benchmark.
- Nếu model lỗi, fallback GDetection/WFSA không crash.

### Giai đoạn 7 - Port L3 Gemini

Công việc:

- Port ApiKeyProvider/Obfuscator.
- Port GeminiConfig/Client/ChatSession.
- Port KeyHealthTracker, Metrics, ResponseCache.
- Port PIIStripper đầy đủ.
- Port PromptBuilder/GeminiSummarizer.
- Port L3Analyzer one-shot/incremental.
- Port L3 fallback về L2 trong AnalysisCoordinator/MonitoringController.

Kết quả cần có:

- L3 chạy được khi có key.
- Mất mạng/API error fallback về L2.
- PII redaction test pass.

### Giai đoạn 8 - Port native Android services

Công việc:

- Copy/port BackgroundMonitoringService vào Flutter Android module.
- Copy/port UnifiedAccessibilityService, CallScreeningServiceImpl, CallReceiver, TransparentTrampolineActivity, CreatorMediaProjectionService.
- Port OverlayManager native hoặc viết bridge để Flutter UI hiện alert trong app và native overlay hiện ngoài app.
- Thêm MethodChannel/EventChannel đầy đủ.
- Thêm manifest services/permissions/meta-data.

Kết quả cần có:

- Native service start/stop từ Flutter.
- Transcript/RMS/call events stream vào Flutter.
- Alert overlay ngoài app hoạt động.

### Giai đoạn 9 - Port Monitoring workflow thực

Công việc:

- Port MonitoringViewModel thành Riverpod controller.
- Kết nối STT/native transcript.
- Kết nối AnalysisCoordinator L1/L2/L3.
- Port timer, waveform, alert queue, batching, fallback, recovery.
- Port save history khi stop.
- Port simulation playback vào monitoring.

Kết quả cần có:

- End-to-end: start monitoring -> transcript -> analysis -> alert -> stop -> history -> result.

### Giai đoạn 10 - Android permission và onboarding

Công việc:

- Port permission utils qua native bridge.
- Port RightsDialog state live.
- Test lần đầu cài app.
- Test từ chối/cấp lại quyền.
- Test Android 10, 12, 13, 14 nếu có.

Kết quả cần có:

- User có thể cấp đủ quyền và dùng app không cần Android Studio.

### Giai đoạn 11 - Server và tooling

Công việc:

- Giữ server Node nếu không cần port.
- Nếu Flutter cần client, viết API/socket service.
- Cập nhật start scripts/docs.
- Đảm bảo Twilio/Whisper không phụ thuộc app Kotlin cũ.

Kết quả cần có:

- Server phụ trợ vẫn chạy độc lập.

### Giai đoạn 12 - QA parity và release Android

Công việc:

- Chạy unit/widget/integration tests.
- Chạy screenshot/golden compare.
- Test real device với quyền call/accessibility/overlay.
- Test release build minify/shrink nếu dùng.
- Kiểm tra memory/CPU/battery khi monitoring dài.
- Đối chiếu từng module với `lccg_kt.md`.

Kết quả cần có:

- APK Flutter đạt parity chức năng và UI với app Kotlin.

## Phần 3 - Bảng khái quát kế hoạch và tiến trình

Trạng thái:

- `[x]` đã làm
- `[ ]` chưa làm
- `[~]` đang làm hoặc cần kiểm tra lại

| STT | Hạng mục | Trạng thái | Đầu ra cần có | Ghi chú |
|---:|---|:---:|---|---|
| 1 | Tạo `lccg_kt.md` từ source Kotlin | [x] | Báo cáo + source gốc | Đã có tại `E:\lachancuocgoi\lccg_kt.md` |
| 2 | Tạo `lccg_fl.md` source Flutter dự kiến | [x] | Mapping + source/stub Flutter | Đã có tại `E:\lachancuocgoi\lccg_fl.md` |
| 3 | Tạo `KEHOACH.md` | [x] | Kế hoạch chi tiết | File này |
| 4 | Đóng băng baseline Kotlin | [ ] | Screenshot/video/test expected | Chưa thực hiện |
| 5 | Tạo project Flutter skeleton | [x] | App Flutter build được | Đã khởi tạo cấu trúc và chạy flutter pub get thành công |
| 6 | Copy assets runtime | [x] | `assets/` đầy đủ | Đã copy toàn bộ model, json và slang từ dự án gốc |
| 7 | Port build/manifest Android | [x] | Permissions/services khai báo đủ | Đã copy AndroidManifest và thiết lập config |
| 8 | Port app shell/router/settings | [x] | Route + settings hoạt động | GoRouter và cơ sở route rỗng đã thiết lập xong |
| 9 | Port theme pixel parity | [ ] | Màu/typography/spacing khớp | Cần screenshot compare |
| 10 | Port Home + dialogs | [ ] | Home/Rights/Instruct/Settings | UI parity |
| 11 | Port database sqflite | [x] | CRUD history | Room -> sqflite, unit test pass |
| 12 | Port TranscriptSaver/VocabularyRepository | [x] | Lưu/đọc file/assets | Unit test pass, cần test Android storage ở giai đoạn thiết bị |
| 13 | Port common analysis | [x] | RiskLevel/TextNormalizer/FuzzyMatcher | Unit test pass |
| 14 | Port L1 đầy đủ | [ ] | L1 parity | FlatTrie/Aho-Corasick |
| 15 | Port GDetection DTO/tokenizer | [ ] | GModels/GFlash | L2 base |
| 16 | Port GDetectionEngine | [ ] | Keyword/scenario/sentence/pattern | L2 core |
| 17 | Port GThinking/scoring | [ ] | Risk/alert logic khớp | Tier rules |
| 18 | Port TFLite intent classifier | [ ] | GhitaV3 inference | Có thể cần native bridge |
| 19 | Port WFSA/SafetyFilter | [ ] | Context scoring | L2 fusion |
| 20 | Port L2Analyzer full fusion | [ ] | L2 parity | High confidence/cross-validation |
| 21 | Port L3 Gemini client | [ ] | API rotation/fallback | Key health/cache |
| 22 | Port PIIStripper/PromptBuilder | [ ] | Privacy parity | Regex cần khớp Kotlin |
| 23 | Port MonitoringController | [ ] | Live analysis state | Từ MonitoringViewModel |
| 24 | Port STT/native transcript | [ ] | Transcript real-time | Google/Vosk/Live Caption |
| 25 | Port native BackgroundMonitoringService | [ ] | Foreground monitoring | Android only |
| 26 | Port AccessibilityService | [ ] | OTT/dialer/caption/auto-answer | Android only |
| 27 | Port CallScreeningService | [ ] | Incoming phone calls | Android 10+ |
| 28 | Port OverlayManager/alerts | [ ] | RED/ORANGE overlay | Native overlay |
| 29 | Port Creator Mode/media projection | [ ] | Dev capture mode | Android only |
| 30 | Port History/Result | [ ] | Lịch sử + export/share | UI/data |
| 31 | Port Simulation | [ ] | Scenario playback | JSON/timestamp |
| 32 | Port TipsLesson | [ ] | Tips UI/share | UI parity |
| 33 | Server compatibility | [ ] | Node/Twilio/Whisper vẫn chạy | Nếu cần mobile client thì thêm |
| 34 | Unit tests analysis | [ ] | L1/L2/L3 tests | Expected từ Kotlin |
| 35 | Widget/golden tests UI | [ ] | Pixel parity report | Desktop/mobile sizes |
| 36 | Integration tests Android | [ ] | Permission/service/call flow | Cần emulator/device |
| 37 | Fix bug parity pass 1 | [ ] | Danh sách bug đã fix | Theo Phần 4 |
| 38 | Release APK Flutter | [ ] | APK install/chạy được | Android target |
| 39 | Final parity sign-off | [ ] | Checklist không thiếu tính năng | Trước khi Kotlin |

## Phần 4 - Fix bug và đối chiếu toàn diện

### 1. Nguyên tắc fix bug

- Mọi bug phải gắn với module, workflow, bước tái hiện, expected Kotlin, actual Flutter.
- Không sửa UI theo cảm tính: so với screenshot baseline Kotlin.
- Không sửa analysis theo cảm tính: so với transcript expected Kotlin.
- Nếu Flutter không thể làm thuần Dart, phải đưa logic về native Android bridge thay vì cắt tính năng.
- Mọi bug fix xong phải thêm test hoặc checklist tái hiện.

### 2. Danh mục bug cần chủ động kiểm tra

Build/cấu hình:

- Sai package/applicationId làm service/permission/role không được nhận.
- Thiếu minSdk/targetSdk/foregroundServiceType.
- Assets không được khai báo trong `pubspec.yaml`.
- TFLite/Vosk bị nén/compress sai cách.
- Release build thiếu keep rules/native libs.

Encoding/ngôn ngữ:

- Source gốc có dấu hiệu mojibake trong comment/string. Cần đối chiếu `strings.xml` và UI thực tế, không copy lỗi encoding vào Flutter nếu UI gốc hiện đúng.
- Text tiếng Việt trên Flutter phải hiện Unicode đúng.
- Search/tokenizer không được vỡ vì dấu tiếng Việt.

UI:

- Sai màu theme light/dark.
- Sai spacing/dialog/card radius.
- Icon khác gốc.
- Button/label thiếu.
- Trạng thái loading/empty/error thiếu.
- Overlay RED/ORANGE không rung/không âm thanh/không đúng z-order.
- Waveform không cập nhật.

Data:

- Migration database sai version.
- `alert_history` parse lỗi.
- Transcript bị mất dấu xuống dòng hoặc bị lặp.
- Save/share transcript không hoạt động Android storage.

Analysis L1:

- Tokenizer không khớp.
- Bigram correction thiếu.
- Fuzzy matching quá rộng gây false positive.
- `processedWordCount`/incremental bị sai.
- Risk/reason/confidence không khớp Kotlin.

Analysis L2:

- Label order TFLite sai 23 class.
- WordPiece tokenizer không khớp vocab.
- Quantized output đọc sai byte.
- GDetection thiếu tier_config/scoring_config.
- Pattern/scenario/sentence matcher chỉ là stub.
- Fuse logic AI/GDetection/WFSA sai ngưỡng.
- SafetyFilter discount sai.
- AlertEnabled sai làm hiện cảnh báo quá nhiều/quá ít.

Analysis L3:

- API key provider không lấy đủ keys.
- Quota/cooldown/circuit breaker sai.
- PII redaction quá rộng làm mất ngữ cảnh hoặc quá hẹp làm lộ thông tin.
- JSON parse không chịu được response có text ngoài JSON.
- Risk decay sai.
- Mất mạng không fallback về L2.

Android native:

- Foreground service bị chặn trên Android 14.
- Accessibility meta-data sai.
- CallScreening role không request được.
- Overlay permission thiếu.
- Notification channel sai importance.
- EventChannel bị leak subscription.
- Service chạy nhưng Flutter UI không nhận transcript.

Performance:

- TFLite inference quá chậm.
- L2/GDetection load JSON nhiều lần.
- Monitoring leak coroutine/timer/subscription.
- Battery drain khi speakerphone enforcement/STT restart loop.
- Memory tăng khi transcript dài.

### 3. Ma trận đối chiếu tính năng

| Tính năng gốc | Kotlin baseline | Flutter expected | Cách test | Đạt |
|---|---|---|---|:---:|
| Lần đầu mở app xin quyền | Toast/dialog/settings | Dialog/bridge tương đương | Cài mới app | [ ] |
| HomePage | Compose Home | Flutter Home in đúng | Screenshot | [ ] |
| Settings mode L1/L2/L3 | SharedPreferences | shared_preferences | Đổi mode, restart app | [ ] |
| RightsDialog | Permission cards | Permission cards Flutter | Cấp/tắt quyền | [ ] |
| Monitoring mic | Google STT/Vosk | Native/Dart STT | Nói transcript mẫu | [ ] |
| Waveform | RMS flow | RMS stream/UI | Nói/lắc im lặng | [ ] |
| L1 analysis | Keyword trie | Dart L1 | Transcript benchmark | [ ] |
| L2 GDetection | JSON/scoring | Dart L2 | Transcript benchmark | [ ] |
| L2 TFLite | GhitaV3 | tflite_flutter/native | Inference sample | [ ] |
| L3 Gemini | Gemini SDK | google_generative_ai | Mock/API test | [ ] |
| L3 fallback | Mất mạng -> L2 | Mất mạng -> L2 | Tắt internet | [ ] |
| RED alert | Overlay + vibration | Overlay + vibration | Trigger RED | [ ] |
| ORANGE alert | Overlay | Overlay | Trigger ORANGE | [ ] |
| CallScreening | Incoming phone | Native service | Gọi thật/emulator | [ ] |
| Accessibility OTT | Zalo/Messenger/dialer | Native service | UI automation/manual | [ ] |
| Live Caption ingest | TranscriptionHub | EventChannel | Caption text | [ ] |
| Stop/save call | Room history | sqflite history | Stop monitoring | [ ] |
| HistoryPage | List/delete | List/delete | CRUD | [ ] |
| ResultPage | Summary/transcript/share | Summary/transcript/share | Open history item | [ ] |
| SimulationPage | JSON/filter/playback | JSON/filter/playback | Chọn scenario | [ ] |
| TipsLesson | Tips cards/share | Tips cards/share | UI/share | [ ] |
| Creator Mode | MediaProjection | Native bridge | Dev mode | [ ] |
| Server phụ trợ | Node/Twilio/Whisper | Không bị ảnh hưởng | Start server | [ ] |

### 4. Bộ test bắt buộc

Unit tests Dart:

- `risk_level_test.dart`: fromInt/fromString/deescalate.
- `text_normalizer_test.dart`: dấu tiếng Việt, slang, punctuation, noise modes.
- `fuzzy_matcher_test.dart`: Damerau-Levenshtein.
- `l1_analysis_test.dart`: vocabulary, bigram, fuzzy, incremental.
- `g_detection_engine_test.dart`: keyword/topic/pattern/scenario/sentence.
- `tflite_intent_classifier_test.dart`: tokenizer, input tensor, output mapping.
- `l2_analysis_test.dart`: fuse logic.
- `pii_stripper_test.dart`: redact/restore.
- `l3_analysis_test.dart`: parse JSON, risk decay, fallback error.
- `call_history_test.dart`: JSON/db mapping.

Widget/golden tests:

- Home light/dark.
- Settings dialog.
- Rights dialog.
- Monitoring idle/active/red/orange.
- History empty/list.
- Result detail.
- Simulation list/filter/empty.
- Tips list.

Integration tests Android:

- Permission flow.
- Start/stop monitoring.
- Transcript stream.
- Alert overlay.
- Save history.
- Native service lifecycle.
- Call screening/accessibility cần test manual nếu emulator không hỗ trợ.

Manual real-device tests:

- Android 10, 12, 13, 14.
- Mic permission granted/denied.
- Overlay permission granted/denied.
- Accessibility on/off.
- Network on/off khi L3.
- 15-30 phút monitoring liên tục.
- Incoming GSM call và OTT call nếu có.

### 5. Quy trình đối chiếu mọi module

1. Đọc module Kotlin trong `lccg_kt.md`.
2. Tìm file Flutter tương ứng trong mapping `lccg_fl.md`.
3. Nếu file Flutter là parity stub, port logic thật.
4. Nếu file Flutter là manual core, so sánh từng hàm với Kotlin và bổ sung phần thiếu.
5. Viết test module.
6. Chạy test.
7. Chụp/ghi kết quả đối chiếu.
8. Cập nhật bảng tiến trình ở Phần 3.

### 6. Điều kiện hoàn thành toàn dự án

Dự án Flutter chỉ được coi là hoàn thành khi:

- Bảng tính năng ở Phần 4 đạt hết.
- Tất cả parity stub quan trọng đã được thay bằng implementation thật.
- Không còn tính năng Kotlin nào không có đường Flutter/native bridge tương đương.
- UI được đối chiếu bằng screenshot baseline.
- L1/L2/L3 có kết quả khớp trên bộ transcript benchmark.
- Native Android services chạy được trên APK Flutter.
- Release APK cài và chạy được trên thiết bị Android.
- Có tài liệu rõ phần nào đã viết bằng Dart, phần nào còn native Android, và phần nào sau này mới có thể port sang iOS.

<!-- CHECKPOINT id="ckpt_mos4a5hr_pne1ok" time="2026-05-05T04:17:11.247Z" note="auto" fixes=0 questions=0 highlights=0 sections="" -->

<!-- CHECKPOINT id="ckpt_mosk5782_t5ryoj" time="2026-05-05T11:41:14.066Z" note="auto" fixes=0 questions=0 highlights=0 sections="" -->
