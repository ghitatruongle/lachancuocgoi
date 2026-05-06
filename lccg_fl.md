# lccg_fl.md - Source code dự kiến cho app Flutter

- Dự án gốc đã phân tích: `E:\lachancuocgoi\lachancuocgoi`
- File source gốc tham chiếu: `E:\lachancuocgoi\lccg_kt.md`
- Thời điểm tạo: `2026-05-05 08:47:43`

## Định hướng parity

Bản Flutter dự kiến giữ cùng domain và module nhỏ nhất của Android gốc: `analysis`, `data`, `services`, `ui`, `theme`, `receiver/native android`, server phụ trợ và asset runtime. Phần UI Compose được chuyển sang Flutter Widget; Room chuyển sang `sqflite`; StateFlow/ViewModel chuyển sang Riverpod controller; Android service đặc quyền vẫn nằm ở native Kotlin và giao tiếp qua MethodChannel/EventChannel.

Những tính năng không thể làm thuần Dart như CallScreeningService, AccessibilityService, foreground microphone/mediaProjection, overlay window, role request và Vosk native model được giữ ở `android/app/src/main/kotlin/...` như adapter native. Dart chỉ điều phối state, UI, phân tích text và lưu lịch sử.

## Mapping module

| Android/Kotlin gốc | Flutter dự kiến | Ghi chú |
|---|---|---|
| `app/src/androidTest/java/com/example/lachancuocgoi/Analysis/L2/Intent/TFLiteIntentClassifierTest.kt` | `integration_test/analysis/l2/intent/tf_lite_intent_classifier_test.dart` | parity stub |
| `app/src/androidTest/java/com/example/lachancuocgoi/ExampleInstrumentedTest.kt` | `integration_test/example_instrumented_test.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/Analysis/AnalysisCoordinator.kt` | `lib/analysis/analysis_coordinator.dart` | manual core |
| `app/src/main/java/com/example/lachancuocgoi/Analysis/AnalysisLevel.kt` | `lib/analysis/analysis_level.dart` | manual core |
| `app/src/main/java/com/example/lachancuocgoi/Analysis/AnalysisModePolicy.kt` | `lib/analysis/analysis_mode_policy.dart` | manual core |
| `app/src/main/java/com/example/lachancuocgoi/Analysis/AnalysisResult.kt` | `lib/analysis/analysis_result.dart` | manual core |
| `app/src/main/java/com/example/lachancuocgoi/Analysis/Analyzer.kt` | `lib/analysis/analyzer.dart` | manual core |
| `app/src/main/java/com/example/lachancuocgoi/Analysis/ChooseAnalysis.kt` | `lib/analysis/choose_analysis.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/Analysis/common/FuzzyMatcher.kt` | `lib/analysis/common/fuzzy_matcher.dart` | manual core |
| `app/src/main/java/com/example/lachancuocgoi/Analysis/common/TextNormalizer.kt` | `lib/analysis/common/text_normalizer.dart` | manual core |
| `app/src/main/java/com/example/lachancuocgoi/Analysis/HealthCheck.kt` | `lib/analysis/health_check.dart` | manual core |
| `app/src/main/java/com/example/lachancuocgoi/Analysis/L1/L1Analysis.kt` | `lib/analysis/l1/l1_analysis.dart` | manual core |
| `app/src/main/java/com/example/lachancuocgoi/Analysis/L1/L1Result.kt` | `lib/analysis/l1/l1_result.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/Analysis/L2/GDetection/GDetectionEngine.kt` | `lib/analysis/l2/g_detection/g_detection_engine.dart` | manual core |
| `app/src/main/java/com/example/lachancuocgoi/Analysis/L2/GDetection/GFlash.kt` | `lib/analysis/l2/g_detection/g_flash.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/Analysis/L2/GDetection/GModels.kt` | `lib/analysis/l2/g_detection/g_models.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/Analysis/L2/GDetection/GPatternMatcher.kt` | `lib/analysis/l2/g_detection/g_pattern_matcher.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/Analysis/L2/GDetection/GThinking.kt` | `lib/analysis/l2/g_detection/g_thinking.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/Analysis/L2/GDetection/RiskScenariosMasterModel.kt` | `lib/analysis/l2/g_detection/risk_scenarios_master_model.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/Analysis/L2/GDetection/ScenarioMatcher.kt` | `lib/analysis/l2/g_detection/scenario_matcher.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/Analysis/L2/GDetection/SentenceMatcher.kt` | `lib/analysis/l2/g_detection/sentence_matcher.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/Analysis/L2/Intent/ScamIntentExtensions.kt` | `lib/analysis/l2/intent/scam_intent_extensions.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/Analysis/L2/Intent/TFLiteIntentClassifier.kt` | `lib/analysis/l2/intent/tf_lite_intent_classifier.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/Analysis/L2/L2Analysis.kt` | `lib/analysis/l2/l2_analysis.dart` | manual core |
| `app/src/main/java/com/example/lachancuocgoi/Analysis/L2/L2Result.kt` | `lib/analysis/l2/l2_result.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/Analysis/L2/Safety/SafetyFilter.kt` | `lib/analysis/l2/safety/safety_filter.dart` | manual core |
| `app/src/main/java/com/example/lachancuocgoi/Analysis/L2/WFSA/ScamGraphBuilder.kt` | `lib/analysis/l2/wfsa/scam_graph_builder.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/Analysis/L2/WFSA/WfsaEngine.kt` | `lib/analysis/l2/wfsa/wfsa_engine.dart` | manual core |
| `app/src/main/java/com/example/lachancuocgoi/Analysis/L3/core/ApiKeyObfuscator.kt` | `lib/analysis/l3/core/api_key_obfuscator.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/Analysis/L3/core/ApiKeyProvider.kt` | `lib/analysis/l3/core/api_key_provider.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/Analysis/L3/core/GeminiChatSession.kt` | `lib/analysis/l3/core/gemini_chat_session.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/Analysis/L3/core/GeminiClient.kt` | `lib/analysis/l3/core/gemini_client.dart` | manual core |
| `app/src/main/java/com/example/lachancuocgoi/Analysis/L3/core/GeminiConfig.kt` | `lib/analysis/l3/core/gemini_config.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/Analysis/L3/core/GeminiMetrics.kt` | `lib/analysis/l3/core/gemini_metrics.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/Analysis/L3/core/GeminiResponse.kt` | `lib/analysis/l3/core/gemini_response.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/Analysis/L3/core/KeyHealthTracker.kt` | `lib/analysis/l3/core/key_health_tracker.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/Analysis/L3/core/PIIStripper.kt` | `lib/analysis/l3/core/pii_stripper.dart` | manual core |
| `app/src/main/java/com/example/lachancuocgoi/Analysis/L3/core/ResponseCache.kt` | `lib/analysis/l3/core/response_cache.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/Analysis/L3/GeminiSummarizer.kt` | `lib/analysis/l3/gemini_summarizer.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/Analysis/L3/L3Analysis.kt` | `lib/analysis/l3/l3_analysis.dart` | manual core |
| `app/src/main/java/com/example/lachancuocgoi/Analysis/L3/PromptBuilder.kt` | `lib/analysis/l3/prompt_builder.dart` | manual core |
| `app/src/main/java/com/example/lachancuocgoi/audio/CreatorAudioCaptureManager.kt` | `lib/audio/creator_audio_capture_manager.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/data/AlertHistoryEntry.kt` | `lib/data/alert_history_entry.dart` | manual core |
| `app/src/main/java/com/example/lachancuocgoi/data/AppDatabase.kt` | `lib/data/app_database.dart` | manual core |
| `app/src/main/java/com/example/lachancuocgoi/data/CallHistory.kt` | `lib/data/call_history.dart` | manual core |
| `app/src/main/java/com/example/lachancuocgoi/data/CallHistoryDao.kt` | `lib/data/call_history_dao.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/data/TranscriptSaver.kt` | `lib/data/transcript_saver.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/data/VocabularyRepository.kt` | `lib/data/vocabulary_repository.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/MainActivity.kt` | `lib/main_activity.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/MainApplication.kt` | `lib/main_application.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/MainViewModel.kt` | `lib/main_view_model.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/receiver/CallReceiver.kt` | `lib/receiver/call_receiver.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/RiskLevel.kt` | `lib/risk_level.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/services/BackgroundMonitoringService.kt` | `lib/services/background_monitoring_service.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/services/CallScreeningServiceImpl.kt` | `lib/services/call_screening_service_impl.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/services/ConnectivityMonitor.kt` | `lib/services/connectivity_monitor.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/services/CreatorMediaProjectionService.kt` | `lib/services/creator_media_projection_service.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/services/SpeechToTextManager.kt` | `lib/services/speech_to_text_manager.dart` | manual core |
| `app/src/main/java/com/example/lachancuocgoi/services/SttEngine.kt` | `lib/services/stt_engine.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/services/TranscriptionHub.kt` | `lib/services/transcription_hub.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/services/TransparentTrampolineActivity.kt` | `lib/services/transparent_trampoline_activity.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/services/UnifiedAccessibilityService.kt` | `lib/services/unified_accessibility_service.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/services/VoskSttManager.kt` | `lib/services/vosk_stt_manager.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/ui/components/CircularWaveformVisualizer.kt` | `lib/ui/components/circular_waveform_visualizer.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/ui/components/ComposeOverlayLifecycleOwner.kt` | `lib/ui/components/compose_overlay_lifecycle_owner.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/ui/components/WaveformVisualizer.kt` | `lib/ui/components/waveform_visualizer.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/ui/HistoryPage/HistoryPage.kt` | `lib/ui/history_page/history_page.dart` | manual core |
| `app/src/main/java/com/example/lachancuocgoi/ui/HistoryPage/HistoryViewModel.kt` | `lib/ui/history_page/history_view_model.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/ui/HistoryPage/ItemHistory/HistoryItemCard.kt` | `lib/ui/history_page/item_history/history_item_card.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/ui/HomePage/HomePage.kt` | `lib/ui/home_page/home_page.dart` | manual core |
| `app/src/main/java/com/example/lachancuocgoi/ui/HomePage/HomeViewModel.kt` | `lib/ui/home_page/home_view_model.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/ui/HomePage/InstructDialog/InstructDialog.kt` | `lib/ui/home_page/instruct_dialog/instruct_dialog.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/ui/HomePage/RightsDialog/PermissionPrompts.kt` | `lib/ui/home_page/rights_dialog/permission_prompts.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/ui/HomePage/RightsDialog/PermissionsTab.kt` | `lib/ui/home_page/rights_dialog/permissions_tab.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/ui/HomePage/RightsDialog/PermissionUtils.kt` | `lib/ui/home_page/rights_dialog/permission_utils.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/ui/HomePage/RightsDialog/RightsDialog.kt` | `lib/ui/home_page/rights_dialog/rights_dialog.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/ui/HomePage/SettingsDialog/AnalysisMode.kt` | `lib/ui/home_page/settings_dialog/analysis_mode.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/ui/HomePage/SettingsDialog/DeveloperModeManager.kt` | `lib/ui/home_page/settings_dialog/developer_mode_manager.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/ui/HomePage/SettingsDialog/DevPasswordDialog.kt` | `lib/ui/home_page/settings_dialog/dev_password_dialog.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/ui/HomePage/SettingsDialog/SettingsDialog.kt` | `lib/ui/home_page/settings_dialog/settings_dialog.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/ui/HomePage/SettingsDialog/SettingsState.kt` | `lib/ui/home_page/settings_dialog/settings_state.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/ui/HomePage/SettingsDialog/SettingsTab.kt` | `lib/ui/home_page/settings_dialog/settings_tab.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/ui/MonitoringPage/AlertHistorySection.kt` | `lib/ui/monitoring_page/alert_history_section.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/ui/MonitoringPage/AudioWaveform.kt` | `lib/ui/monitoring_page/audio_waveform.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/ui/MonitoringPage/LiveConversation.kt` | `lib/ui/monitoring_page/live_conversation.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/ui/MonitoringPage/MonitoringPage.kt` | `lib/ui/monitoring_page/monitoring_page.dart` | manual core |
| `app/src/main/java/com/example/lachancuocgoi/ui/MonitoringPage/MonitoringViewModel.kt` | `lib/ui/monitoring_page/monitoring_view_model.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/ui/MonitoringPage/SaveNoteFile.kt` | `lib/ui/monitoring_page/save_note_file.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/ui/MonitoringPage/Warning/OrangeWarning.kt` | `lib/ui/monitoring_page/warning/orange_warning.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/ui/MonitoringPage/Warning/RedWarning.kt` | `lib/ui/monitoring_page/warning/red_warning.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/ui/MonitoringPage/Warning/Warning.kt` | `lib/ui/monitoring_page/warning/warning.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/ui/OverlayManager.kt` | `lib/ui/overlay_manager.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/ui/ResultPage/ResultPage.kt` | `lib/ui/result_page/result_page.dart` | manual core |
| `app/src/main/java/com/example/lachancuocgoi/ui/ResultPage/ResultViewModel.kt` | `lib/ui/result_page/result_view_model.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/ui/SimulationPage/SimulationPage.kt` | `lib/ui/simulation_page/simulation_page.dart` | manual core |
| `app/src/main/java/com/example/lachancuocgoi/ui/SimulationPage/SimulationViewModel.kt` | `lib/ui/simulation_page/simulation_view_model.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/ui/theme/Color.kt` | `lib/ui/theme/color.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/ui/theme/Shape.kt` | `lib/ui/theme/shape.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/ui/theme/Spacing.kt` | `lib/ui/theme/spacing.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/ui/theme/Theme.kt` | `lib/ui/theme/theme.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/ui/theme/Type.kt` | `lib/ui/theme/type.dart` | parity stub |
| `app/src/main/java/com/example/lachancuocgoi/ui/TipsLessonPage/TipsLessonPage.kt` | `lib/ui/tips_lesson_page/tips_lesson_page.dart` | manual core |
| `app/src/test/java/com/example/lachancuocgoi/Analysis/AnalysisCoordinatorTest.kt` | `test/analysis/analysis_coordinator_test.dart` | parity stub |
| `app/src/test/java/com/example/lachancuocgoi/Analysis/L1/L1AnalyzerTest.kt` | `test/analysis/l1/l1_analyzer_test.dart` | parity stub |
| `app/src/test/java/com/example/lachancuocgoi/Analysis/L2/GDetection/GDetectionEngineTest.kt` | `test/analysis/l2/g_detection/g_detection_engine_test.dart` | parity stub |
| `app/src/test/java/com/example/lachancuocgoi/ExampleUnitTest.kt` | `test/example_unit_test.dart` | parity stub |

## Cây source Flutter dự kiến

```text
|-- pubspec.yaml
|-- android
|   `-- app
|       `-- src
|           `-- main
|               |-- AndroidManifest.xml
|               `-- kotlin
|                   `-- com
|                       `-- lachancuocgoi
|                           `-- MainActivity.kt
|-- integration_test
|   |-- example_instrumented_test.dart
|   `-- analysis
|       `-- l2
|           `-- intent
|               `-- tf_lite_intent_classifier_test.dart
|-- lib
|   |-- main.dart
|   |-- main_activity.dart
|   |-- main_application.dart
|   |-- main_view_model.dart
|   |-- risk_level.dart
|   |-- analysis
|   |   |-- analysis_coordinator.dart
|   |   |-- analysis_level.dart
|   |   |-- analysis_mode.dart
|   |   |-- analysis_mode_policy.dart
|   |   |-- analysis_result.dart
|   |   |-- analyzer.dart
|   |   |-- choose_analysis.dart
|   |   |-- health_check.dart
|   |   |-- common
|   |   |   |-- fuzzy_matcher.dart
|   |   |   `-- text_normalizer.dart
|   |   |-- l1
|   |   |   |-- l1_analysis.dart
|   |   |   `-- l1_result.dart
|   |   |-- l2
|   |   |   |-- l2_analysis.dart
|   |   |   |-- l2_result.dart
|   |   |   |-- g_detection
|   |   |   |   |-- g_detection_engine.dart
|   |   |   |   |-- g_flash.dart
|   |   |   |   |-- g_models.dart
|   |   |   |   |-- g_pattern_matcher.dart
|   |   |   |   |-- g_thinking.dart
|   |   |   |   |-- risk_scenarios_master_model.dart
|   |   |   |   |-- scenario_matcher.dart
|   |   |   |   `-- sentence_matcher.dart
|   |   |   |-- intent
|   |   |   |   |-- scam_intent_extensions.dart
|   |   |   |   |-- tf_lite_intent_classifier.dart
|   |   |   |   `-- tflite_intent_classifier.dart
|   |   |   |-- safety
|   |   |   |   `-- safety_filter.dart
|   |   |   `-- wfsa
|   |   |       |-- scam_graph_builder.dart
|   |   |       `-- wfsa_engine.dart
|   |   `-- l3
|   |       |-- gemini_summarizer.dart
|   |       |-- l3_analysis.dart
|   |       |-- prompt_builder.dart
|   |       `-- core
|   |           |-- api_key_obfuscator.dart
|   |           |-- api_key_provider.dart
|   |           |-- gemini_chat_session.dart
|   |           |-- gemini_client.dart
|   |           |-- gemini_config.dart
|   |           |-- gemini_metrics.dart
|   |           |-- gemini_response.dart
|   |           |-- key_health_tracker.dart
|   |           |-- pii_stripper.dart
|   |           `-- response_cache.dart
|   |-- app
|   |   |-- lachancuocgoi_app.dart
|   |   |-- router.dart
|   |   `-- settings_controller.dart
|   |-- audio
|   |   `-- creator_audio_capture_manager.dart
|   |-- core
|   |   `-- risk_level.dart
|   |-- data
|   |   |-- alert_history_entry.dart
|   |   |-- app_database.dart
|   |   |-- call_history.dart
|   |   |-- call_history_dao.dart
|   |   |-- transcript_saver.dart
|   |   `-- vocabulary_repository.dart
|   |-- receiver
|   |   `-- call_receiver.dart
|   |-- services
|   |   |-- background_monitoring_service.dart
|   |   |-- call_screening_service_impl.dart
|   |   |-- connectivity_monitor.dart
|   |   |-- creator_media_projection_service.dart
|   |   |-- native_call_shield_bridge.dart
|   |   |-- speech_to_text_manager.dart
|   |   |-- stt_engine.dart
|   |   |-- transcription_hub.dart
|   |   |-- transparent_trampoline_activity.dart
|   |   |-- unified_accessibility_service.dart
|   |   `-- vosk_stt_manager.dart
|   `-- ui
|       |-- overlay_manager.dart
|       |-- components
|       |   |-- circular_waveform_visualizer.dart
|       |   |-- compose_overlay_lifecycle_owner.dart
|       |   `-- waveform_visualizer.dart
|       |-- history_page
|       |   |-- history_page.dart
|       |   |-- history_view_model.dart
|       |   `-- item_history
|       |       `-- history_item_card.dart
|       |-- home_page
|       |   |-- home_page.dart
|       |   |-- home_view_model.dart
|       |   |-- instruct_dialog
|       |   |   `-- instruct_dialog.dart
|       |   |-- rights_dialog
|       |   |   |-- permission_prompts.dart
|       |   |   |-- permission_utils.dart
|       |   |   |-- permissions_tab.dart
|       |   |   `-- rights_dialog.dart
|       |   `-- settings_dialog
|       |       |-- analysis_mode.dart
|       |       |-- dev_password_dialog.dart
|       |       |-- developer_mode_manager.dart
|       |       |-- settings_dialog.dart
|       |       |-- settings_state.dart
|       |       `-- settings_tab.dart
|       |-- monitoring_page
|       |   |-- alert_history_section.dart
|       |   |-- audio_waveform.dart
|       |   |-- live_conversation.dart
|       |   |-- monitoring_controller.dart
|       |   |-- monitoring_page.dart
|       |   |-- monitoring_view_model.dart
|       |   |-- save_note_file.dart
|       |   `-- warning
|       |       |-- orange_warning.dart
|       |       |-- red_warning.dart
|       |       `-- warning.dart
|       |-- result_page
|       |   |-- result_page.dart
|       |   `-- result_view_model.dart
|       |-- simulation_page
|       |   |-- simulation_page.dart
|       |   `-- simulation_view_model.dart
|       |-- theme
|       |   |-- app_theme.dart
|       |   |-- color.dart
|       |   |-- shape.dart
|       |   |-- spacing.dart
|       |   |-- theme.dart
|       |   `-- type.dart
|       `-- tips_lesson_page
|           `-- tips_lesson_page.dart
`-- test
    |-- example_unit_test.dart
    `-- analysis
        |-- analysis_coordinator_test.dart
        |-- l1
        |   `-- l1_analyzer_test.dart
        `-- l2
            `-- g_detection
                `-- g_detection_engine_test.dart
```

## Source code dự kiến

### 1. `pubspec.yaml`

~~~yaml
name: lachancuocgoi_flutter
description: Flutter port dự kiến của dự án La Chắn Cuộc Gọi.
publish_to: "none"
version: 1.3.0+8

environment:
  sdk: ">=3.4.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  collection: ^1.18.0
  cupertino_icons: ^1.0.8
  flutter_riverpod: ^2.5.1
  go_router: ^14.2.0
  google_generative_ai: ^0.4.6
  http: ^1.2.2
  path: ^1.9.0
  path_provider: ^2.1.4
  permission_handler: ^11.3.1
  shared_preferences: ^2.3.2
  sqflite: ^2.3.3
  speech_to_text: ^6.6.2
  tflite_flutter: ^0.11.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0

flutter:
  uses-material-design: true
  assets:
    - assets/logo.png
    - assets/ghitav3.tflite
    - assets/vocab.txt
    - assets/bigram_corrections.json
    - assets/context_rules.json
    - assets/phrase_patterns.json
    - assets/risk_model_sentences.json
    - assets/risk_model_situation.json
    - assets/risk_model_vocabulary.json
    - assets/risk_scenarios_master.json
    - assets/safety_keywords.json
    - assets/scoring_config.json
    - assets/situation_test.json
    - assets/slang_config.json
    - assets/tier_config.json
    - assets/model-vn/
~~~

### 2. `lib/main.dart`

~~~dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/lachancuocgoi_app.dart';
import 'data/app_database.dart';
import 'services/native_call_shield_bridge.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await AppDatabase.open();
  final nativeBridge = NativeCallShieldBridge.instance;
  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        nativeBridgeProvider.overrideWithValue(nativeBridge),
      ],
      child: const LachancuocgoiApp(),
    ),
  );
}
~~~

### 3. `lib/app/lachancuocgoi_app.dart`

~~~dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/theme/app_theme.dart';
import 'router.dart';
import 'settings_controller.dart';

class LachancuocgoiApp extends ConsumerWidget {
  const LachancuocgoiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'La chan cuoc goi',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.isDarkTheme ? ThemeMode.dark : ThemeMode.light,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
~~~

### 4. `lib/app/router.dart`

~~~dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../ui/history_page/history_page.dart';
import '../ui/home_page/home_page.dart';
import '../ui/monitoring_page/monitoring_page.dart';
import '../ui/result_page/result_page.dart';
import '../ui/simulation_page/simulation_page.dart';
import '../ui/tips_lesson_page/tips_lesson_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomePage()),
      GoRoute(path: '/simulation', builder: (context, state) => const SimulationPage()),
      GoRoute(
        path: '/monitoring',
        builder: (context, state) => MonitoringPage(
          simulatedScenarioTitle: state.uri.queryParameters['simulatedScenarioTitle'],
        ),
      ),
      GoRoute(
        path: '/result/:historyId',
        builder: (context, state) => ResultPage(
          historyId: int.tryParse(state.pathParameters['historyId'] ?? ''),
        ),
      ),
      GoRoute(path: '/history', builder: (context, state) => const HistoryPage()),
      GoRoute(path: '/tips_lesson', builder: (context, state) => const TipsLessonPage()),
    ],
  );
});
~~~

### 5. `lib/app/settings_controller.dart`

~~~dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../analysis/analysis_mode.dart';

class SettingsState {
  const SettingsState({
    required this.isDarkTheme,
    required this.analysisMode,
    required this.audioBoost,
    required this.autoEnableSpeakerphone,
  });

  final bool isDarkTheme;
  final AnalysisMode analysisMode;
  final bool audioBoost;
  final bool autoEnableSpeakerphone;

  SettingsState copyWith({
    bool? isDarkTheme,
    AnalysisMode? analysisMode,
    bool? audioBoost,
    bool? autoEnableSpeakerphone,
  }) {
    return SettingsState(
      isDarkTheme: isDarkTheme ?? this.isDarkTheme,
      analysisMode: analysisMode ?? this.analysisMode,
      audioBoost: audioBoost ?? this.audioBoost,
      autoEnableSpeakerphone: autoEnableSpeakerphone ?? this.autoEnableSpeakerphone,
    );
  }
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, SettingsState>(SettingsController.new);

class SettingsController extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    _load();
    return const SettingsState(
      isDarkTheme: false,
      analysisMode: AnalysisMode.gDetection,
      audioBoost: false,
      autoEnableSpeakerphone: false,
    );
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = SettingsState(
      isDarkTheme: prefs.getBool('IS_DARK_THEME') ?? false,
      analysisMode: AnalysisModeX.fromName(
        prefs.getString('ANALYSIS_MODE'),
        fallback: AnalysisMode.gDetection,
      ),
      audioBoost: prefs.getBool('AUDIO_BOOST') ?? false,
      autoEnableSpeakerphone: prefs.getBool('AUTO_ENABLE_SPEAKERPHONE') ?? false,
    );
  }

  Future<void> update(SettingsState next) async {
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('IS_DARK_THEME', next.isDarkTheme);
    await prefs.setString('ANALYSIS_MODE', next.analysisMode.storageName);
    await prefs.setBool('AUDIO_BOOST', next.audioBoost);
    await prefs.setBool('AUTO_ENABLE_SPEAKERPHONE', next.autoEnableSpeakerphone);
  }
}
~~~

### 6. `lib/core/risk_level.dart`

~~~dart
import 'package:flutter/material.dart';

enum RiskLevel {
  green('An toan', Colors.green),
  yellow('Chu y', Colors.yellow),
  orange('Co nguy co', Color(0xFFFFA500)),
  red('Nguy hiem', Colors.red);

  const RiskLevel(this.vietnameseName, this.color);

  final String vietnameseName;
  final Color color;

  int get level => index;

  RiskLevel deescalate() {
    return switch (this) {
      RiskLevel.red => RiskLevel.orange,
      RiskLevel.orange => RiskLevel.yellow,
      RiskLevel.yellow => RiskLevel.green,
      RiskLevel.green => RiskLevel.green,
    };
  }

  static RiskLevel fromInt(int value) {
    return switch (value) {
      3 => RiskLevel.red,
      2 => RiskLevel.orange,
      1 => RiskLevel.yellow,
      _ => RiskLevel.green,
    };
  }

  static RiskLevel fromString(String? value) {
    return switch (value?.toUpperCase()) {
      'RED' => RiskLevel.red,
      'ORANGE' => RiskLevel.orange,
      'YELLOW' => RiskLevel.yellow,
      _ => RiskLevel.green,
    };
  }
}
~~~

### 7. `lib/analysis/analysis_mode.dart`

~~~dart
enum AnalysisMode {
  normal,
  gDetection,
  geminiApi;

  String get storageName {
    return switch (this) {
      AnalysisMode.normal => 'NORMAL',
      AnalysisMode.gDetection => 'GDetection',
      AnalysisMode.geminiApi => 'GEMINI_API',
    };
  }
}

extension AnalysisModeX on AnalysisMode {
  static AnalysisMode fromName(String? value, {AnalysisMode fallback = AnalysisMode.gDetection}) {
    return switch (value) {
      'NORMAL' => AnalysisMode.normal,
      'GDetection' => AnalysisMode.gDetection,
      'GEMINI_API' => AnalysisMode.geminiApi,
      _ => fallback,
    };
  }
}
~~~

### 8. `lib/analysis/analysis_level.dart`

~~~dart
sealed class AnalysisLevel {
  const AnalysisLevel(this.id, this.displayName);
  final String id;
  final String displayName;

  static const l1 = AnalysisLevelValue('L1', 'Cap 1');
  static const l2 = AnalysisLevelValue('L2', 'Cap 2');
  static const l2Ai = AnalysisLevelValue('L2AI', 'Cap 2 AI');
  static const l2Fused = AnalysisLevelValue('L2Fused', 'Cap 2 hop nhat');
  static const l3 = AnalysisLevelValue('L3', 'Cap 3 Gemini');
}

class AnalysisLevelValue extends AnalysisLevel {
  const AnalysisLevelValue(super.id, super.displayName);
}
~~~

### 9. `lib/analysis/analysis_result.dart`

~~~dart
import '../core/risk_level.dart';
import 'analysis_level.dart';

class KeywordMatch {
  const KeywordMatch({
    required this.keyword,
    required this.level,
    required this.category,
    this.startIndex = -1,
    this.endIndex = -1,
  });

  final String keyword;
  final RiskLevel level;
  final String category;
  final int startIndex;
  final int endIndex;

  @override
  bool operator ==(Object other) {
    return other is KeywordMatch &&
        other.keyword == keyword &&
        other.category == category &&
        other.startIndex == startIndex &&
        other.endIndex == endIndex;
  }

  @override
  int get hashCode => Object.hash(keyword, category, startIndex, endIndex);
}

class AnalysisResult {
  const AnalysisResult({
    required this.overallRiskLevel,
    required this.matches,
    this.reason,
    this.analysisLevel = AnalysisLevel.l1,
    this.alertEnabled = false,
    this.confidence = -1,
    this.modelName,
    this.isError = false,
  });

  final RiskLevel overallRiskLevel;
  final List<KeywordMatch> matches;
  final String? reason;
  final AnalysisLevel analysisLevel;
  final bool alertEnabled;
  final double confidence;
  final String? modelName;
  final bool isError;

  AnalysisResult copyWith({
    RiskLevel? overallRiskLevel,
    List<KeywordMatch>? matches,
    String? reason,
    AnalysisLevel? analysisLevel,
    bool? alertEnabled,
    double? confidence,
    String? modelName,
    bool? isError,
  }) {
    return AnalysisResult(
      overallRiskLevel: overallRiskLevel ?? this.overallRiskLevel,
      matches: matches ?? this.matches,
      reason: reason ?? this.reason,
      analysisLevel: analysisLevel ?? this.analysisLevel,
      alertEnabled: alertEnabled ?? this.alertEnabled,
      confidence: confidence ?? this.confidence,
      modelName: modelName ?? this.modelName,
      isError: isError ?? this.isError,
    );
  }
}
~~~

### 10. `lib/analysis/analyzer.dart`

~~~dart
import 'analysis_level.dart';
import 'analysis_result.dart';
import 'health_check.dart';

abstract interface class Analyzer implements HealthCheckable {
  AnalysisLevel get level;
  Future<void> initialize();
  bool get isReady;
  void resetSession();
  int get processedTextLength;
  void syncProcessedTextLength(int length);
  AnalysisResult get lastResult;
}
~~~

### 11. `lib/analysis/health_check.dart`

~~~dart
enum HealthStatus { healthy, degraded, down }

class HealthReport {
  const HealthReport(this.status, this.component, this.message);
  final HealthStatus status;
  final String component;
  final String message;
}

abstract interface class HealthCheckable {
  HealthReport healthCheck();
}
~~~

### 12. `lib/analysis/analysis_mode_policy.dart`

~~~dart
import 'analysis_mode.dart';

class AnalysisRuntimeState {
  const AnalysisRuntimeState({
    required this.selectedMode,
    required this.effectiveMode,
    required this.networkAvailable,
    required this.isFallbackActive,
  });

  final AnalysisMode selectedMode;
  final AnalysisMode effectiveMode;
  final bool networkAvailable;
  final bool isFallbackActive;
}

class AnalysisModePolicy {
  const AnalysisModePolicy._();

  static AnalysisMode resolveEffectiveMode(AnalysisMode selectedMode, bool networkAvailable) {
    if (selectedMode == AnalysisMode.geminiApi && !networkAvailable) {
      return AnalysisMode.gDetection;
    }
    return selectedMode;
  }

  static AnalysisRuntimeState createRuntimeState(AnalysisMode selectedMode, bool networkAvailable) {
    final effective = resolveEffectiveMode(selectedMode, networkAvailable);
    return AnalysisRuntimeState(
      selectedMode: selectedMode,
      effectiveMode: effective,
      networkAvailable: networkAvailable,
      isFallbackActive: selectedMode == AnalysisMode.geminiApi && effective != AnalysisMode.geminiApi,
    );
  }
}
~~~

### 13. `lib/analysis/analysis_coordinator.dart`

~~~dart
import '../core/risk_level.dart';
import 'analysis_level.dart';
import 'analysis_mode.dart';
import 'analysis_result.dart';
import 'analyzer.dart';
import 'health_check.dart';
import 'l1/l1_analysis.dart';
import 'l2/g_detection/g_detection_engine.dart';
import 'l2/intent/tflite_intent_classifier.dart';
import 'l2/l2_analysis.dart';
import 'l3/l3_analysis.dart';

class AnalysisCoordinator {
  AnalysisCoordinator({
    required L1Analyzer l1Analyzer,
    required L2Analyzer l2Analyzer,
    required L3Analyzer l3Analyzer,
  })  : _l1Analyzer = l1Analyzer,
        _l2Analyzer = l2Analyzer,
        _l3Analyzer = l3Analyzer;

  factory AnalysisCoordinator.defaultInstance() {
    return AnalysisCoordinator(
      l1Analyzer: L1Analyzer(),
      l2Analyzer: L2Analyzer(
        gDetectionEngine: GDetectionEngine(),
        intentClassifier: TFLiteIntentClassifier(),
      ),
      l3Analyzer: L3Analyzer(),
    );
  }

  final L1Analyzer _l1Analyzer;
  final L2Analyzer _l2Analyzer;
  final L3Analyzer _l3Analyzer;
  AnalysisMode _compatibilityMode = AnalysisMode.normal;

  Analyzer _analyzerFor(AnalysisMode mode) {
    return switch (mode) {
      AnalysisMode.normal => _l1Analyzer,
      AnalysisMode.gDetection => _l2Analyzer,
      AnalysisMode.geminiApi => _l3Analyzer,
    };
  }

  Future<AnalysisResult> analyze(String text, AnalysisMode mode, {String? fullText}) async {
    _compatibilityMode = mode;
    if (mode == AnalysisMode.gDetection && !_l2Analyzer.isReady) {
      await _l2Analyzer.initialize();
      if (!_l2Analyzer.isReady) {
        return const AnalysisResult(
          overallRiskLevel: RiskLevel.green,
          matches: [],
          reason: 'Dang khoi tao L2',
          analysisLevel: AnalysisLevel.l2,
        );
      }
    }
    return switch (mode) {
      AnalysisMode.normal => _l1Analyzer.analyzeStream(fullText ?? text),
      AnalysisMode.gDetection => _l2Analyzer.analyze(text, fullText ?? text),
      AnalysisMode.geminiApi => _l3Analyzer.analyze(text),
    };
  }

  Future<AnalysisResult> analyzeIncremental(String fullText, AnalysisMode mode) async {
    _compatibilityMode = mode;
    final processed = getProcessedTextLength(mode);
    if (fullText.length <= processed) {
      return _defaultResultFor(mode);
    }

    final deltaLength = fullText.length - processed;
    final last = getLastResult(mode);
    if (mode == AnalysisMode.geminiApi) {
      final minDelta = _adaptiveMinDelta(last.overallRiskLevel);
      if (deltaLength < minDelta) {
        return last.overallRiskLevel.index >= RiskLevel.orange.index
            ? last.copyWith(alertEnabled: false)
            : last;
      }
    }

    return analyze(fullText.substring(processed), mode, fullText: fullText);
  }

  void reset() {
    for (final mode in AnalysisMode.values) {
      resetMode(mode);
    }
    _compatibilityMode = AnalysisMode.normal;
  }

  void resetMode(AnalysisMode mode) => _analyzerFor(mode).resetSession();
  int getProcessedTextLength(AnalysisMode mode) => _analyzerFor(mode).processedTextLength;
  AnalysisResult getLastResult(AnalysisMode mode) => _analyzerFor(mode).lastResult;
  void syncProcessedTextLength(AnalysisMode mode, int length) => _analyzerFor(mode).syncProcessedTextLength(length);
  void createL3Session({int initialProcessedTextLength = 0}) => _l3Analyzer.createSession(initialProcessedTextLength);
  Future<AnalysisResult?> analyzeIncrementalL3(String fullText) => _l3Analyzer.analyzeIncremental(fullText);
  void closeL3Session({bool resetProgress = false}) => _l3Analyzer.closeSession();

  Map<String, HealthReport> runAllHealthChecks() {
    return {
      for (final analyzer in [_l1Analyzer, _l2Analyzer, _l3Analyzer])
        analyzer.level.id: analyzer.healthCheck(),
    };
  }

  int _adaptiveMinDelta(RiskLevel level) {
    return switch (level) {
      RiskLevel.red => 20,
      RiskLevel.orange => 30,
      _ => 50,
    };
  }

  AnalysisResult _defaultResultFor(AnalysisMode mode) {
    final level = switch (mode) {
      AnalysisMode.normal => AnalysisLevel.l1,
      AnalysisMode.gDetection => AnalysisLevel.l2,
      AnalysisMode.geminiApi => AnalysisLevel.l3,
    };
    return AnalysisResult(overallRiskLevel: RiskLevel.green, matches: const [], analysisLevel: level);
  }

  int get compatibilityProcessedTextLength => getProcessedTextLength(_compatibilityMode);
}
~~~

### 14. `lib/analysis/common/text_normalizer.dart`

~~~dart
enum NoiseMode { remove, space, keep }

class TextNormalizer {
  TextNormalizer._();

  static final Map<String, String> _slangMap = {};
  static final RegExp _noiseChars = RegExp(r'[^\p{L}\p{N}\s]', unicode: true);
  static final Map<String, String> _phoneticMap = {
    'đ': 'd',
    'Đ': 'D',
  };

  static void loadSlangConfig(Map<String, String> config) {
    _slangMap
      ..clear()
      ..addAll(config.map((key, value) => MapEntry(normalize(key, applySlang: false), normalize(value, applySlang: false))));
  }

  static String normalize(
    String input, {
    bool lowercase = true,
    bool stripDiacritics = true,
    bool applySlang = true,
    NoiseMode noiseMode = NoiseMode.space,
  }) {
    var result = input.trim();
    if (lowercase) result = result.toLowerCase();
    for (final entry in _phoneticMap.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    if (stripDiacritics) {
      result = _stripVietnameseAccents(result);
    }
    if (noiseMode == NoiseMode.remove) {
      result = result.replaceAll(_noiseChars, '');
    } else if (noiseMode == NoiseMode.space) {
      result = result.replaceAll(_noiseChars, ' ');
    }
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (applySlang && _slangMap.isNotEmpty) {
      final words = result.split(' ').map((word) => _slangMap[word] ?? word);
      result = words.join(' ');
    }
    return result;
  }

  static List<String> tokenize(String text, {bool applySlang = true}) {
    final normalized = normalize(text, applySlang: applySlang);
    if (normalized.isEmpty) return const [];
    return normalized.split(' ').where((token) => token.isNotEmpty).toList();
  }

  static String _stripVietnameseAccents(String value) {
    const source =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹ';
    const target =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyy';
    var output = value;
    for (var i = 0; i < source.length; i++) {
      output = output.replaceAll(source[i], target[i]);
      output = output.replaceAll(source[i].toUpperCase(), target[i].toUpperCase());
    }
    return output;
  }
}
~~~

### 15. `lib/analysis/common/fuzzy_matcher.dart`

~~~dart
class FuzzyMatcher {
  FuzzyMatcher._();

  static int damerauLevenshtein(String a, String b, {int maxDistance = 2}) {
    if ((a.length - b.length).abs() > maxDistance) return maxDistance + 1;
    final dp = List.generate(a.length + 1, (i) => List<int>.filled(b.length + 1, 0));
    for (var i = 0; i <= a.length; i++) dp[i][0] = i;
    for (var j = 0; j <= b.length; j++) dp[0][j] = j;
    for (var i = 1; i <= a.length; i++) {
      var rowMin = maxDistance + 1;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        var value = [
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
        if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
          value = value < dp[i - 2][j - 2] + 1 ? value : dp[i - 2][j - 2] + 1;
        }
        dp[i][j] = value;
        if (value < rowMin) rowMin = value;
      }
      if (rowMin > maxDistance) return maxDistance + 1;
    }
    return dp[a.length][b.length];
  }

  static String? findClosest(String token, Iterable<String> candidates, {int maxDistance = 2}) {
    String? best;
    var bestDistance = maxDistance + 1;
    for (final candidate in candidates) {
      final distance = damerauLevenshtein(token, candidate, maxDistance: maxDistance);
      if (distance < bestDistance) {
        best = candidate;
        bestDistance = distance;
      }
    }
    return bestDistance <= maxDistance ? best : null;
  }
}
~~~

### 16. `lib/analysis/l1/l1_analysis.dart`

~~~dart
import 'dart:convert';

import 'package:flutter/services.dart';

import '../../core/risk_level.dart';
import '../analysis_level.dart';
import '../analysis_result.dart';
import '../analyzer.dart';
import '../common/fuzzy_matcher.dart';
import '../common/text_normalizer.dart';
import '../health_check.dart';

class L1Analyzer implements Analyzer {
  final Map<List<String>, KeywordMatch> _phrases = {};
  final Set<String> _singleTokenKeywords = {};
  int _processedWordCount = 0;
  AnalysisResult _lastResult = const AnalysisResult(
    overallRiskLevel: RiskLevel.green,
    matches: [],
    analysisLevel: AnalysisLevel.l1,
  );
  bool _ready = false;

  @override
  AnalysisLevel get level => AnalysisLevel.l1;

  @override
  bool get isReady => _ready;

  @override
  int get processedTextLength => _processedWordCount;

  @override
  AnalysisResult get lastResult => _lastResult;

  @override
  Future<void> initialize() async {
    if (_ready) return;
    final raw = await rootBundle.loadString('assets/risk_model_vocabulary.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    for (final risk in (json['riskLevels'] as List? ?? const [])) {
      final level = RiskLevel.fromInt((risk['level'] as num?)?.toInt() ?? 0);
      final threats = risk['threats'] as Map<String, dynamic>? ?? const {};
      final keywords = <String>[
        ...((risk['keywords'] as List?) ?? const []).cast<String>(),
        for (final values in threats.values) ...((values as List?) ?? const []).cast<String>(),
      ];
      for (final keyword in keywords) {
        final tokens = TextNormalizer.tokenize(keyword);
        if (tokens.isEmpty) continue;
        _phrases[tokens] = KeywordMatch(keyword: keyword, level: level, category: _categoryOf(threats, keyword));
        if (tokens.length == 1 && tokens.first.length >= 5) _singleTokenKeywords.add(tokens.first);
      }
    }
    _ready = true;
  }

  Future<AnalysisResult> analyzeStream(String fullTranscript) async {
    await initialize();
    final tokens = TextNormalizer.tokenize(fullTranscript);
    if (tokens.length <= _processedWordCount) return _lastResult;
    final matches = _findMatches(tokens);
    _processedWordCount = tokens.length;
    _lastResult = _parse(matches, tokens.length);
    return _lastResult;
  }

  Set<KeywordMatch> _findMatches(List<String> tokens) {
    final matches = <KeywordMatch>{};
    for (var i = 0; i < tokens.length; i++) {
      for (final entry in _phrases.entries) {
        final phrase = entry.key;
        if (i + phrase.length > tokens.length) continue;
        final window = tokens.sublist(i, i + phrase.length);
        if (_sameTokens(window, phrase)) {
          matches.add(KeywordMatch(
            keyword: entry.value.keyword,
            level: entry.value.level,
            category: entry.value.category,
            startIndex: i,
            endIndex: i + phrase.length - 1,
          ));
        }
      }
      if (tokens[i].length >= 5) {
        final fuzzy = FuzzyMatcher.findClosest(tokens[i], _singleTokenKeywords, maxDistance: 1);
        if (fuzzy != null) {
          final entry = _phrases.entries.firstWhere((e) => e.key.length == 1 && e.key.first == fuzzy).value;
          matches.add(KeywordMatch(keyword: entry.keyword, level: entry.level, category: entry.category, startIndex: i, endIndex: i));
        }
      }
    }
    return matches;
  }

  AnalysisResult _parse(Set<KeywordMatch> matches, int totalTokens) {
    if (matches.isEmpty) {
      return const AnalysisResult(overallRiskLevel: RiskLevel.green, matches: [], analysisLevel: AnalysisLevel.l1);
    }
    final highest = matches.map((m) => m.level).reduce((a, b) => a.index >= b.index ? a : b);
    final categoryGroups = <String, int>{};
    for (final match in matches) {
      categoryGroups[match.category] = (categoryGroups[match.category] ?? 0) + 1;
    }
    final reason = 'Phat hien ${matches.length} dau hieu, nhom manh nhat: ${categoryGroups.entries.first.key}';
    return AnalysisResult(
      overallRiskLevel: highest,
      matches: matches.toList()..sort((a, b) => b.level.index.compareTo(a.level.index)),
      reason: reason,
      analysisLevel: AnalysisLevel.l1,
      alertEnabled: highest.index >= RiskLevel.orange.index,
      confidence: (matches.length / totalTokens.clamp(1, 100)).clamp(0.0, 1.0),
    );
  }

  bool _sameTokens(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  String _categoryOf(Map<String, dynamic> threats, String keyword) {
    for (final entry in threats.entries) {
      final values = (entry.value as List?)?.cast<String>() ?? const [];
      if (values.contains(keyword)) return entry.key;
    }
    return 'Chung';
  }

  @override
  HealthReport healthCheck() => _ready
      ? const HealthReport(HealthStatus.healthy, 'L1', 'L1 da load vocabulary')
      : const HealthReport(HealthStatus.degraded, 'L1', 'L1 chua khoi tao');

  @override
  void resetSession() {
    _processedWordCount = 0;
    _lastResult = const AnalysisResult(overallRiskLevel: RiskLevel.green, matches: [], analysisLevel: AnalysisLevel.l1);
  }

  @override
  void syncProcessedTextLength(int length) => _processedWordCount = length.clamp(0, 1 << 31);
}
~~~

### 17. `lib/analysis/l2/intent/tflite_intent_classifier.dart`

~~~dart
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../../core/risk_level.dart';

enum ScamIntent {
  authPoliceLawsuit,
  taxGovApp,
  telecomLock,
  techSupportHijack,
  hospitalEmergency,
  virtualKidnapping,
  ceoFraudB2b,
  socialDeepfakeLoan,
  romanceScam,
  sextortionBlackmail,
  charityDonation,
  investmentScam,
  jobTaskScam,
  giftLottery,
  gamblingPrediction,
  immigrationVisaScam,
  bankCardFraud,
  deliveryCod,
  fakeSubscription,
  blackCreditTerror,
  recoveryScam,
  genericScam,
  safe;
}

class IntentPrediction {
  const IntentPrediction(this.intent, this.confidence);
  final ScamIntent intent;
  final double confidence;
}

extension ScamIntentText on ScamIntent {
  String get displayName => name;
  String get description => this == ScamIntent.safe ? 'Hoi thoai an toan' : 'Nhom rui ro ${name}';

  RiskLevel riskLevel(double confidence) {
    if (this == ScamIntent.safe) return RiskLevel.green;
    if (confidence >= 0.8) return RiskLevel.red;
    if (confidence >= 0.62) return RiskLevel.orange;
    return RiskLevel.yellow;
  }
}

class TFLiteIntentClassifier {
  static const _modelPath = 'assets/ghitav3.tflite';
  static const _vocabPath = 'assets/vocab.txt';
  static const _maxSeqLen = 256;

  Interpreter? _interpreter;
  final Map<String, int> _vocab = {};
  bool _ready = false;

  bool get isReady => _ready;

  Future<void> initialize() async {
    if (_ready) return;
    final vocabRaw = await rootBundle.loadString(_vocabPath);
    final lines = vocabRaw.split('\n');
    for (var i = 0; i < lines.length; i++) {
      _vocab[lines[i].trim()] = i;
    }
    _interpreter = await Interpreter.fromAsset(_modelPath.replaceFirst('assets/', ''));
    _ready = true;
  }

  Future<List<IntentPrediction>> predictIntent(String transcript) async {
    if (!_ready) throw StateError('TFLite model chua san sang');
    if (transcript.trim().isEmpty) return const [];
    final tokens = _tokenize(_normalizeVietnamese(transcript));
    final input = _buildBertInputs(tokens);
    final logits = List<double>.filled(ScamIntent.values.length, 0);

    // Wiring cu the tuy thuoc shape exported cua ghitav3.tflite.
    // Voi parity Android: input_ids, attention_mask, token_type_ids -> logits [1,23].
    _interpreter!.runForMultipleInputs([
      [input.inputIds],
      [input.attentionMask],
      [input.tokenTypeIds],
    ], {
      0: [logits],
    });

    final probs = _softmax(logits);
    return [
      for (var i = 0; i < ScamIntent.values.length; i++) IntentPrediction(ScamIntent.values[i], probs[i]),
    ]..sort((a, b) => b.confidence.compareTo(a.confidence));
  }

  String _normalizeVietnamese(String text) {
    return text.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  List<String> _tokenize(String text) {
    final result = <String>[];
    for (final word in text.split(' ')) {
      if (word.isEmpty) continue;
      result.add(_vocab.containsKey(word) ? word : '[UNK]');
    }
    return result;
  }

  _BertInput _buildBertInputs(List<String> tokens) {
    final clsId = _vocab['[CLS]'] ?? 101;
    final sepId = _vocab['[SEP]'] ?? 102;
    final padId = _vocab['[PAD]'] ?? 0;
    final unkId = _vocab['[UNK]'] ?? 100;
    final maxTokens = _maxSeqLen - 2;
    final truncated = tokens.length <= maxTokens ? tokens : [...tokens.take(50), ...tokens.skip(tokens.length - (maxTokens - 50))];
    final inputIds = List<int>.filled(_maxSeqLen, padId);
    final attention = List<int>.filled(_maxSeqLen, 0);
    final tokenTypes = List<int>.filled(_maxSeqLen, 0);
    inputIds[0] = clsId;
    attention[0] = 1;
    for (var i = 0; i < truncated.length; i++) {
      inputIds[i + 1] = _vocab[truncated[i]] ?? unkId;
      attention[i + 1] = 1;
    }
    final sepPos = truncated.length + 1;
    inputIds[sepPos] = sepId;
    attention[sepPos] = 1;
    return _BertInput(inputIds, attention, tokenTypes);
  }

  List<double> _softmax(List<double> logits) {
    final maxLogit = logits.reduce(max);
    final exps = logits.map((value) => exp(value - maxLogit)).toList();
    final sum = exps.fold<double>(0, (a, b) => a + b);
    return exps.map((value) => value / sum).toList();
  }
}

class _BertInput {
  const _BertInput(this.inputIds, this.attentionMask, this.tokenTypeIds);
  final List<int> inputIds;
  final List<int> attentionMask;
  final List<int> tokenTypeIds;
}
~~~

### 18. `lib/analysis/l2/l2_analysis.dart`

~~~dart
import '../../core/risk_level.dart';
import '../analysis_level.dart';
import '../analysis_result.dart';
import '../analyzer.dart';
import '../health_check.dart';
import 'g_detection/g_detection_engine.dart';
import 'intent/tflite_intent_classifier.dart';
import 'safety/safety_filter.dart';
import 'wfsa/wfsa_engine.dart';

class L2Analyzer implements Analyzer {
  L2Analyzer({required this.gDetectionEngine, required this.intentClassifier});

  final GDetectionEngine gDetectionEngine;
  final TFLiteIntentClassifier intentClassifier;
  final WfsaEngine wfsaEngine = WfsaEngine.defaultGraphs();
  int _processedTextLength = 0;
  AnalysisResult _lastResult = const AnalysisResult(
    overallRiskLevel: RiskLevel.green,
    matches: [],
    analysisLevel: AnalysisLevel.l2,
  );

  @override
  AnalysisLevel get level => AnalysisLevel.l2;

  @override
  bool get isReady => gDetectionEngine.isEngineReady;

  @override
  int get processedTextLength => _processedTextLength;

  @override
  AnalysisResult get lastResult => _lastResult;

  @override
  Future<void> initialize() async {
    await Future.wait([gDetectionEngine.initialize(), intentClassifier.initialize()]);
  }

  Future<AnalysisResult> analyze(String incrementalText, String fullText) async {
    if (!isReady || fullText.trim().isEmpty) return _lastResult;

    final futures = await Future.wait<Object>([
      _predictIntentSafely(fullText),
      gDetectionEngine.performFullAnalysis(fullText),
    ]);
    final intents = futures[0] as List<IntentPrediction>;
    final gResult = futures[1] as GResult;
    final parsed = gResult.toAnalysisResult();

    var wfsaScore = wfsaEngine.analyzeSegment(incrementalText, intents.take(1).toList());
    wfsaScore *= SafetyFilter.calculateSafetyDiscount(fullText);
    final wfsaRisk = wfsaScore >= 50 ? RiskLevel.red : wfsaScore >= 20 ? RiskLevel.yellow : RiskLevel.green;

    final topIntent = intents.isEmpty ? null : intents.first;
    if (topIntent != null && topIntent.intent != ScamIntent.safe && topIntent.confidence >= 0.80) {
      final intentRisk = topIntent.intent.riskLevel(topIntent.confidence);
      _lastResult = AnalysisResult(
        overallRiskLevel: intentRisk.index >= parsed.overallRiskLevel.index ? intentRisk : parsed.overallRiskLevel,
        matches: [
          KeywordMatch(keyword: topIntent.intent.displayName, level: intentRisk, category: 'Luong 1 AI'),
          ...parsed.matches,
        ],
        reason: '${topIntent.intent.displayName} - ${topIntent.intent.description}',
        analysisLevel: AnalysisLevel.l2Ai,
        alertEnabled: intentRisk != RiskLevel.green,
        confidence: topIntent.confidence,
      );
    } else {
      final finalLevel = wfsaRisk.index > parsed.overallRiskLevel.index ? wfsaRisk : parsed.overallRiskLevel;
      _lastResult = parsed.copyWith(
        overallRiskLevel: finalLevel,
        analysisLevel: AnalysisLevel.l2,
        alertEnabled: parsed.alertEnabled || wfsaRisk.index > RiskLevel.green.index,
      );
    }

    _processedTextLength = fullText.length;
    return _lastResult;
  }

  Future<List<IntentPrediction>> _predictIntentSafely(String text) async {
    if (!intentClassifier.isReady) return const [];
    try {
      return intentClassifier.predictIntent(text);
    } catch (_) {
      return const [];
    }
  }

  @override
  HealthReport healthCheck() {
    if (!gDetectionEngine.isEngineReady) {
      return const HealthReport(HealthStatus.down, 'L2', 'GDetection chua san sang');
    }
    if (!intentClassifier.isReady) {
      return const HealthReport(HealthStatus.degraded, 'L2', 'TFLite chua san sang, dung GDetection/WFSA');
    }
    return const HealthReport(HealthStatus.healthy, 'L2', 'L2 san sang');
  }

  @override
  void resetSession() {
    wfsaEngine.resetSession();
    _processedTextLength = 0;
    _lastResult = const AnalysisResult(overallRiskLevel: RiskLevel.green, matches: [], analysisLevel: AnalysisLevel.l2);
  }

  @override
  void syncProcessedTextLength(int length) => _processedTextLength = length.clamp(0, 1 << 31);
}
~~~

### 19. `lib/analysis/l2/g_detection/g_detection_engine.dart`

~~~dart
import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../core/risk_level.dart';
import '../../analysis_level.dart';
import '../../analysis_result.dart';
import '../../common/text_normalizer.dart';

class GResult {
  const GResult({
    required this.riskLevel,
    required this.reason,
    this.allMatchedKeywords = const {},
    this.confirmedSituation,
    this.alertEnabled = false,
    this.confidence = -1,
  });

  final RiskLevel riskLevel;
  final String reason;
  final Set<KeywordMatch> allMatchedKeywords;
  final String? confirmedSituation;
  final bool alertEnabled;
  final double confidence;

  AnalysisResult toAnalysisResult() {
    final evidence = [...allMatchedKeywords];
    if (confirmedSituation != null) {
      evidence.insert(0, KeywordMatch(keyword: confirmedSituation!, level: RiskLevel.red, category: 'Chu de lua dao'));
    }
    evidence.sort((a, b) => b.level.index.compareTo(a.level.index));
    return AnalysisResult(
      overallRiskLevel: riskLevel,
      matches: evidence,
      reason: reason,
      analysisLevel: AnalysisLevel.l2,
      alertEnabled: alertEnabled,
      confidence: confidence,
    );
  }
}

class GDetectionEngine {
  final Map<List<String>, KeywordMatch> _keywords = {};
  bool _ready = false;

  bool get isEngineReady => _ready;

  Future<void> initialize() async {
    if (_ready) return;
    final vocabRaw = await rootBundle.loadString('assets/risk_model_vocabulary.json');
    final vocab = jsonDecode(vocabRaw) as Map<String, dynamic>;
    for (final risk in (vocab['riskLevels'] as List? ?? const [])) {
      final level = RiskLevel.fromInt((risk['level'] as num?)?.toInt() ?? 0);
      final threats = risk['threats'] as Map<String, dynamic>? ?? const {};
      for (final entry in threats.entries) {
        for (final keyword in (entry.value as List? ?? const [])) {
          final tokens = TextNormalizer.tokenize(keyword.toString());
          if (tokens.isNotEmpty) {
            _keywords[tokens] = KeywordMatch(keyword: tokens.join(' '), level: level, category: entry.key);
          }
        }
      }
    }
    _ready = true;
  }

  Future<GResult> performFullAnalysis(String text) async {
    await initialize();
    final tokens = TextNormalizer.tokenize(text);
    final matches = <KeywordMatch>{};
    for (var i = 0; i < tokens.length; i++) {
      for (final entry in _keywords.entries) {
        final phrase = entry.key;
        if (i + phrase.length > tokens.length) continue;
        final window = tokens.sublist(i, i + phrase.length);
        if (_same(window, phrase)) {
          matches.add(KeywordMatch(
            keyword: entry.value.keyword,
            level: entry.value.level,
            category: entry.value.category,
            startIndex: i,
            endIndex: i + phrase.length - 1,
          ));
        }
      }
    }
    if (matches.isEmpty) {
      return const GResult(riskLevel: RiskLevel.green, reason: 'Khong phat hien dau hieu rui ro');
    }
    final highest = matches.map((e) => e.level).reduce((a, b) => a.index >= b.index ? a : b);
    final tier3 = matches.any((m) => m.category.toLowerCase().contains('otp') || m.category.toLowerCase().contains('tai khoan'));
    final level = tier3 ? RiskLevel.red : highest;
    return GResult(
      riskLevel: level,
      reason: level == RiskLevel.red ? 'Canh bao: dau hieu lua dao nguy hiem' : 'Phat hien dau hieu can chu y',
      allMatchedKeywords: matches,
      confirmedSituation: level.index >= RiskLevel.orange.index ? 'Chu de nhay cam' : null,
      alertEnabled: level != RiskLevel.green,
      confidence: matches.length / tokens.length.clamp(1, 100),
    );
  }

  bool _same(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
~~~

### 20. `lib/analysis/l2/safety/safety_filter.dart`

~~~dart
class SafetyFilter {
  const SafetyFilter._();

  static double calculateSafetyDiscount(String text) {
    final lower = text.toLowerCase();
    final safeSignals = [
      'toi se ra ngan hang kiem tra',
      'toi khong cung cap ma otp',
      'toi se goi tong dai',
      'cam on toi khong co nhu cau',
    ];
    if (safeSignals.any(lower.contains)) return 0.5;
    return 1.0;
  }
}
~~~

### 21. `lib/analysis/l2/wfsa/wfsa_engine.dart`

~~~dart
import '../intent/tflite_intent_classifier.dart';

class WfsaEngine {
  WfsaEngine(this.graphs);
  factory WfsaEngine.defaultGraphs() => WfsaEngine(const []);

  final List<Object> graphs;
  String? activeScenarioName;
  int? activeScenarioStage;

  double analyzeSegment(String segment, List<IntentPrediction> intents) {
    final lower = segment.toLowerCase();
    var score = 0.0;
    if (lower.contains('otp') || lower.contains('ma xac minh')) score += 50;
    if (lower.contains('chuyen tien') || lower.contains('tai khoan')) score += 25;
    if (intents.any((p) => p.intent != ScamIntent.safe && p.confidence >= 0.5)) score += 20;
    return score;
  }

  void resetSession() {
    activeScenarioName = null;
    activeScenarioStage = null;
  }
}
~~~

### 22. `lib/analysis/l3/core/pii_stripper.dart`

~~~dart
class PiiRedaction {
  const PiiRedaction(this.text, this.tokens);
  final String text;
  final Map<String, String> tokens;
}

class PiiStripper {
  PiiStripper._();

  static PiiRedaction redactPII(String originalText) {
    if (originalText.trim().isEmpty) return PiiRedaction(originalText, const {});
    var text = originalText;
    final tokens = <String, String>{};
    var counter = 0;

    String replaceMatches(RegExp regex, String prefix) {
      return text.replaceAllMapped(regex, (match) {
        counter += 1;
        final token = '[${prefix}_$counter]';
        tokens[token] = match.group(0)!;
        return token;
      });
    }

    text = replaceMatches(RegExp(r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b', caseSensitive: false), 'EMAIL');
    text = replaceMatches(RegExp(r'(?<!\w)(?:\+84|84|0)(?:[\s.-]?\d){8,10}\b'), 'SO_DIEN_THOAI');
    text = replaceMatches(RegExp(r'\b(?:\d[\s.-]?){5,17}\d\b'), 'SO_NHAY_CAM');
    return PiiRedaction(text, tokens);
  }

  static String restorePII(String redactedText, Map<String, String> tokens) {
    var restored = redactedText;
    for (final entry in tokens.entries) {
      restored = restored.replaceAll(entry.key, entry.value);
    }
    return restored;
  }
}
~~~

### 23. `lib/analysis/l3/core/gemini_client.dart`

~~~dart
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiConfig {
  const GeminiConfig({
    this.temperature = 0.1,
    this.topK = 20,
    this.topP = 0.8,
    this.timeout = const Duration(seconds: 20),
  });

  final double temperature;
  final int topK;
  final double topP;
  final Duration timeout;
}

abstract interface class ApiKeyProvider {
  List<String> getApiKeys();
}

class GeminiClient {
  GeminiClient({
    required this.apiKeyProvider,
    this.config = const GeminiConfig(),
  });

  final ApiKeyProvider apiKeyProvider;
  final GeminiConfig config;
  DateTime _lastCall = DateTime.fromMillisecondsSinceEpoch(0);

  Future<T> query<T>(String prompt, T Function(String text, String modelName) parser) async {
    final keys = apiKeyProvider.getApiKeys();
    if (keys.isEmpty) throw StateError('No Gemini API keys configured');
    final wait = const Duration(seconds: 1) - DateTime.now().difference(_lastCall);
    if (!wait.isNegative) await Future<void>.delayed(wait);
    _lastCall = DateTime.now();

    final models = ['gemini-3.1-flash-lite', 'gemini-2.5-flash-lite', 'gemini-3-flash', 'gemini-2.5-flash'];
    Object? lastError;
    for (final key in keys) {
      for (final modelName in models) {
        try {
          final model = GenerativeModel(
            model: modelName,
            apiKey: key,
            generationConfig: GenerationConfig(
              temperature: config.temperature,
              topK: config.topK,
              topP: config.topP,
              responseMimeType: 'application/json',
            ),
          );
          final response = await model.generateContent([Content.text(prompt)]).timeout(config.timeout);
          final text = response.text;
          if (text == null || text.trim().isEmpty) throw StateError('Empty Gemini response');
          return parser(text, modelName);
        } catch (error) {
          lastError = error;
        }
      }
    }
    throw StateError('All Gemini keys/models failed: $lastError');
  }
}
~~~

### 24. `lib/analysis/l3/l3_analysis.dart`

~~~dart
import 'dart:convert';

import '../../core/risk_level.dart';
import '../analysis_level.dart';
import '../analysis_result.dart';
import '../analyzer.dart';
import '../health_check.dart';
import 'core/gemini_client.dart';
import 'core/pii_stripper.dart';
import 'prompt_builder.dart';

class L3Analyzer implements Analyzer {
  L3Analyzer({GeminiClient? geminiClient}) : _geminiClient = geminiClient;

  final GeminiClient? _geminiClient;
  int _processedTextLength = 0;
  RiskLevel _maxRiskLevel = RiskLevel.green;
  int _consecutiveGreenCount = 0;

  @override
  AnalysisLevel get level => AnalysisLevel.l3;

  @override
  bool get isReady => _geminiClient != null;

  @override
  int get processedTextLength => _processedTextLength;

  @override
  AnalysisResult get lastResult => const AnalysisResult(overallRiskLevel: RiskLevel.green, matches: [], analysisLevel: AnalysisLevel.l3);

  @override
  Future<void> initialize() async {}

  Future<AnalysisResult> analyze(String text) async {
    if (text.trim().split(RegExp(r'\s+')).length < 3) {
      return const AnalysisResult(overallRiskLevel: RiskLevel.green, matches: [], reason: 'Noi dung qua ngan', analysisLevel: AnalysisLevel.l3);
    }
    final redaction = PiiStripper.redactPII(text);
    final prompt = PromptBuilder.buildAnalysisPrompt(redaction.text);
    try {
      return await _geminiClient!.query(prompt, (responseText, modelName) {
        return _parseResponse(PiiStripper.restorePII(responseText, redaction.tokens), modelName);
      });
    } catch (error) {
      return AnalysisResult(
        overallRiskLevel: RiskLevel.green,
        matches: const [],
        reason: 'API Error: $error',
        analysisLevel: AnalysisLevel.l3,
        isError: true,
      );
    }
  }

  void createSession(int initialProcessedTextLength) {
    _processedTextLength = initialProcessedTextLength.clamp(0, 1 << 31);
    _maxRiskLevel = RiskLevel.green;
    _consecutiveGreenCount = 0;
  }

  Future<AnalysisResult?> analyzeIncremental(String fullText) async {
    final newLen = fullText.length - _processedTextLength;
    if (newLen < 40) return null;
    final newText = fullText.substring(_processedTextLength);
    if (!_isSentenceBoundary(newText) && newLen < 200) return null;
    final result = await analyze(newText);
    if (!result.isError) _processedTextLength = fullText.length;
    return result;
  }

  void closeSession() => resetSession();

  AnalysisResult _parseResponse(String raw, String modelName) {
    final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(raw);
    final data = jsonDecode(jsonMatch?.group(0) ?? raw) as Map<String, dynamic>;
    final risk = RiskLevel.fromString(data['level']?.toString());
    var finalRisk = risk;
    if (risk == RiskLevel.green) {
      _consecutiveGreenCount += 1;
      if (_consecutiveGreenCount >= 3) {
        _maxRiskLevel = _maxRiskLevel.deescalate();
        _consecutiveGreenCount = 0;
      }
      finalRisk = _maxRiskLevel;
    } else {
      _consecutiveGreenCount = 0;
      if (risk.index > _maxRiskLevel.index) _maxRiskLevel = risk;
    }
    final label = data['label']?.toString();
    final reason = [if (label != null && label.isNotEmpty) '[$label]', data['reason'], data['recommendation']].whereType<Object>().join(' ');
    return AnalysisResult(
      overallRiskLevel: finalRisk,
      matches: label == null || label.isEmpty ? const [] : [KeywordMatch(keyword: label, level: finalRisk, category: 'L3 Gemini')],
      reason: reason,
      analysisLevel: AnalysisLevel.l3,
      confidence: _confidence(data),
      modelName: modelName,
      alertEnabled: finalRisk.index >= RiskLevel.orange.index,
    );
  }

  double _confidence(Map<String, dynamic> data) {
    var value = 0.0;
    if (['green', 'yellow', 'orange', 'red'].contains(data['level']?.toString().toLowerCase())) value += 0.3;
    if ((data['reason']?.toString() ?? '').isNotEmpty) value += 0.3;
    if ((data['label']?.toString() ?? '').isNotEmpty) value += 0.2;
    if ((data['recommendation']?.toString() ?? '').isNotEmpty) value += 0.2;
    return value.clamp(0.0, 1.0);
  }

  bool _isSentenceBoundary(String text) {
    final trimmed = text.trimRight();
    if (trimmed.isEmpty) return false;
    if ('.?!\n;:'.contains(trimmed[trimmed.length - 1]) || trimmed.endsWith('...')) return true;
    final lower = trimmed.toLowerCase();
    return [' a', ' nha', ' nhe', ' vay', ' roi', ' di', ' nhe'].any(lower.endsWith);
  }

  @override
  HealthReport healthCheck() => isReady
      ? const HealthReport(HealthStatus.healthy, 'L3', 'Gemini client san sang')
      : const HealthReport(HealthStatus.down, 'L3', 'Chua cau hinh Gemini client');

  @override
  void resetSession() {
    _processedTextLength = 0;
    _maxRiskLevel = RiskLevel.green;
    _consecutiveGreenCount = 0;
  }

  @override
  void syncProcessedTextLength(int length) => _processedTextLength = length.clamp(0, 1 << 31);
}
~~~

### 25. `lib/analysis/l3/prompt_builder.dart`

~~~dart
class PromptBuilder {
  PromptBuilder._();

  static String buildAnalysisPrompt(String text) {
    return '''
Ban la bo loc lua dao cuoc goi tieng Viet. Tra ve JSON duy nhat:
{"level":"green|yellow|orange|red","label":"...","reason":"...","recommendation":"..."}

Transcript:
$text
''';
  }

  static String buildIncrementalPrompt(String newText, bool isFirstMessage) {
    return isFirstMessage
        ? buildAnalysisPrompt(newText)
        : 'Tiep tuc phan tich doan transcript moi va tra ve JSON nhu schema cu:\n$newText';
  }
}
~~~

### 26. `lib/data/alert_history_entry.dart`

~~~dart
import 'package:flutter/material.dart';

class AlertHistoryEntry {
  const AlertHistoryEntry({
    required this.timestamp,
    required this.analysisLevel,
    required this.riskLevel,
    required this.alertCount,
    required this.displayedReason,
    this.allReasons,
  });

  final int timestamp;
  final String analysisLevel;
  final String riskLevel;
  final int alertCount;
  final String displayedReason;
  final List<String>? allReasons;

  factory AlertHistoryEntry.fromJson(Map<String, dynamic> json) => AlertHistoryEntry(
        timestamp: (json['timestamp'] as num).toInt(),
        analysisLevel: json['analysisLevel'] as String,
        riskLevel: json['riskLevel'] as String,
        alertCount: (json['alertCount'] as num).toInt(),
        displayedReason: json['displayedReason'] as String,
        allReasons: (json['allReasons'] as List?)?.cast<String>(),
      );

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp,
        'analysisLevel': analysisLevel,
        'riskLevel': riskLevel,
        'alertCount': alertCount,
        'displayedReason': displayedReason,
        'allReasons': allReasons,
      };

  Color get color => riskLevel == 'RED' ? const Color(0xFFD32F2F) : const Color(0xFFFF9800);
}
~~~

### 27. `lib/data/call_history.dart`

~~~dart
import 'dart:convert';

import 'alert_history_entry.dart';

class CallHistory {
  const CallHistory({
    this.id,
    required this.dateTime,
    required this.riskLevel,
    required this.summary,
    required this.duration,
    required this.flagCount,
    required this.transcript,
    this.audioPath,
    this.analysisResult,
    this.analysisType,
    this.alertHistory,
  });

  final int? id;
  final String dateTime;
  final String riskLevel;
  final String summary;
  final String duration;
  final int flagCount;
  final String transcript;
  final String? audioPath;
  final String? analysisResult;
  final String? analysisType;
  final String? alertHistory;

  List<AlertHistoryEntry> getAlertHistoryList() {
    if (alertHistory == null || alertHistory!.trim().isEmpty) return const [];
    final list = jsonDecode(alertHistory!) as List<dynamic>;
    return list.cast<Map<String, dynamic>>().map(AlertHistoryEntry.fromJson).toList();
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'dateTime': dateTime,
        'riskLevel': riskLevel,
        'summary': summary,
        'duration': duration,
        'flagCount': flagCount,
        'transcript': transcript,
        'audioPath': audioPath,
        'analysisResult': analysisResult,
        'analysisType': analysisType,
        'alert_history': alertHistory,
      };

  factory CallHistory.fromMap(Map<String, Object?> map) => CallHistory(
        id: map['id'] as int?,
        dateTime: map['dateTime'] as String,
        riskLevel: map['riskLevel'] as String,
        summary: map['summary'] as String,
        duration: map['duration'] as String,
        flagCount: map['flagCount'] as int,
        transcript: map['transcript'] as String,
        audioPath: map['audioPath'] as String?,
        analysisResult: map['analysisResult'] as String?,
        analysisType: map['analysisType'] as String?,
        alertHistory: map['alert_history'] as String?,
      );

  static String alertHistoryToJson(List<AlertHistoryEntry> history) {
    return jsonEncode(history.map((entry) => entry.toJson()).toList());
  }
}
~~~

### 28. `lib/data/app_database.dart`

~~~dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'call_history.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) => throw UnimplementedError());

class AppDatabase {
  AppDatabase._(this.db);
  final Database db;

  static Future<AppDatabase> open() async {
    final path = join(await getDatabasesPath(), 'call_shield_database.db');
    final database = await openDatabase(
      path,
      version: 5,
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE call_history(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  dateTime TEXT NOT NULL,
  riskLevel TEXT NOT NULL,
  summary TEXT NOT NULL,
  duration TEXT NOT NULL,
  flagCount INTEGER NOT NULL,
  transcript TEXT NOT NULL,
  audioPath TEXT,
  analysisResult TEXT,
  analysisType TEXT,
  alert_history TEXT
)
''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 5) {
          await db.execute('ALTER TABLE call_history ADD COLUMN alert_history TEXT');
        }
      },
    );
    return AppDatabase._(database);
  }

  Future<int> insert(CallHistory item) => db.insert('call_history', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  Future<List<CallHistory>> getAll() async {
    final rows = await db.query('call_history', orderBy: 'id DESC');
    return rows.map(CallHistory.fromMap).toList();
  }

  Future<CallHistory?> getById(int id) async {
    final rows = await db.query('call_history', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : CallHistory.fromMap(rows.first);
  }

  Future<void> deleteAll() => db.delete('call_history');
  Future<void> deleteById(int id) => db.delete('call_history', where: 'id = ?', whereArgs: [id]);
}
~~~

### 29. `lib/services/native_call_shield_bridge.dart`

~~~dart
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final nativeBridgeProvider = Provider<NativeCallShieldBridge>((ref) => NativeCallShieldBridge.instance);

class NativeCallShieldBridge {
  NativeCallShieldBridge._();
  static final instance = NativeCallShieldBridge._();

  static const _method = MethodChannel('lachancuocgoi/native');
  static const _transcriptEvents = EventChannel('lachancuocgoi/transcript');
  static const _callEvents = EventChannel('lachancuocgoi/call_events');

  Stream<String> get transcriptStream => _transcriptEvents.receiveBroadcastStream().cast<String>();
  Stream<Map<dynamic, dynamic>> get callEvents => _callEvents.receiveBroadcastStream().cast<Map<dynamic, dynamic>>();

  Future<void> requestCallScreeningRole() => _method.invokeMethod('requestCallScreeningRole');
  Future<void> requestOverlayPermission() => _method.invokeMethod('requestOverlayPermission');
  Future<void> requestAccessibilitySettings() => _method.invokeMethod('requestAccessibilitySettings');
  Future<void> startBackgroundMonitoring({String? phoneNumber}) => _method.invokeMethod('startBackgroundMonitoring', {'phoneNumber': phoneNumber});
  Future<void> stopBackgroundMonitoring() => _method.invokeMethod('stopBackgroundMonitoring');
  Future<void> showRedAlert(String reason) => _method.invokeMethod('showRedAlert', {'reason': reason});
  Future<void> showOrangeAlert(String reason) => _method.invokeMethod('showOrangeAlert', {'reason': reason});
  Future<Map<dynamic, dynamic>> permissionSnapshot() async => _method.invokeMethod('permissionSnapshot');
}
~~~

### 30. `lib/services/speech_to_text_manager.dart`

~~~dart
import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart';

class SpeechToTextManager {
  final SpeechToText _speech = SpeechToText();
  final _fullTranscript = StreamController<String>.broadcast();
  final _rms = StreamController<double>.broadcast();
  String _cumulative = '';
  bool _shouldListen = false;

  Stream<String> get fullTranscriptFlow => _fullTranscript.stream;
  Stream<double> get rmsDbFlow => _rms.stream;

  Future<void> startListening() async {
    _shouldListen = true;
    final available = await _speech.initialize();
    if (!available) return;
    await _speech.listen(
      localeId: 'vi_VN',
      partialResults: true,
      onResult: (result) {
        final text = result.recognizedWords;
        if (text.isEmpty) return;
        if (result.finalResult) {
          _cumulative = _appendWithOverlapDetection(_cumulative, text);
          _fullTranscript.add(_cumulative);
          if (_shouldListen) startListening();
        } else {
          _fullTranscript.add(_cumulative.isEmpty ? text : '$_cumulative\n$text');
        }
      },
      onSoundLevelChange: _rms.add,
    );
  }

  Future<void> stopListening() async {
    _shouldListen = false;
    await _speech.stop();
  }

  void clearTranscript() {
    _cumulative = '';
    _fullTranscript.add('');
  }

  String _appendWithOverlapDetection(String existing, String next) {
    if (existing.trim().isEmpty) return next;
    final existingWords = existing.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    final newWords = next.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    var bestOverlap = 0;
    final maxCheck = [existingWords.length, newWords.length, 6].reduce((a, b) => a < b ? a : b);
    for (var len = 1; len <= maxCheck; len++) {
      if (existingWords.skip(existingWords.length - len).join(' ').toLowerCase() == newWords.take(len).join(' ').toLowerCase()) {
        bestOverlap = len;
      }
    }
    final deduped = newWords.skip(bestOverlap).join(' ');
    return deduped.isEmpty ? existing : '$existing\n$deduped';
  }
}
~~~

### 31. `lib/ui/home_page/home_page.dart`

~~~dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('La chan cuoc goi'),
        actions: [
          IconButton(onPressed: () => context.push('/history'), icon: const Icon(Icons.history)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.settings)),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            FilledButton.icon(
              onPressed: () => context.push('/monitoring'),
              icon: const Icon(Icons.shield),
              label: const Text('Bat dau giam sat'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push('/simulation'),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Mo phong tinh huong'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push('/tips_lesson'),
              icon: const Icon(Icons.info_outline),
              label: const Text('Meo phong tranh'),
            ),
          ],
        ),
      ),
    );
  }
}
~~~

### 32. `lib/ui/monitoring_page/monitoring_controller.dart`

~~~dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../analysis/analysis_coordinator.dart';
import '../../analysis/analysis_mode.dart';
import '../../analysis/analysis_result.dart';
import '../../core/risk_level.dart';
import '../../services/speech_to_text_manager.dart';

class MonitoringState {
  const MonitoringState({
    this.transcript = '',
    this.result = const AnalysisResult(overallRiskLevel: RiskLevel.green, matches: []),
    this.isListening = false,
    this.elapsedSeconds = 0,
    this.amplitudes = const [],
  });

  final String transcript;
  final AnalysisResult result;
  final bool isListening;
  final int elapsedSeconds;
  final List<double> amplitudes;

  MonitoringState copyWith({
    String? transcript,
    AnalysisResult? result,
    bool? isListening,
    int? elapsedSeconds,
    List<double>? amplitudes,
  }) {
    return MonitoringState(
      transcript: transcript ?? this.transcript,
      result: result ?? this.result,
      isListening: isListening ?? this.isListening,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      amplitudes: amplitudes ?? this.amplitudes,
    );
  }
}

final monitoringControllerProvider =
    AutoDisposeNotifierProvider<MonitoringController, MonitoringState>(MonitoringController.new);

class MonitoringController extends AutoDisposeNotifier<MonitoringState> {
  final _stt = SpeechToTextManager();
  final _analysis = AnalysisCoordinator.defaultInstance();
  StreamSubscription<String>? _transcriptSub;
  Timer? _timer;

  @override
  MonitoringState build() {
    ref.onDispose(stop);
    return const MonitoringState();
  }

  Future<void> start({AnalysisMode mode = AnalysisMode.gDetection}) async {
    state = state.copyWith(isListening: true);
    await _analysis.initializeForMode(mode);
    await _stt.startListening();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
    });
    _transcriptSub = _stt.fullTranscriptFlow.listen((text) async {
      state = state.copyWith(transcript: text);
      if (text.trim().isEmpty) return;
      final result = await _analysis.analyzeIncremental(text, mode);
      state = state.copyWith(result: result);
    });
  }

  Future<void> stop() async {
    _timer?.cancel();
    await _transcriptSub?.cancel();
    await _stt.stopListening();
    state = state.copyWith(isListening: false);
  }
}

extension on AnalysisCoordinator {
  Future<void> initializeForMode(AnalysisMode mode) async {
    if (mode == AnalysisMode.geminiApi) createL3Session();
  }
}
~~~

### 33. `lib/ui/monitoring_page/monitoring_page.dart`

~~~dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/risk_level.dart';
import 'monitoring_controller.dart';

class MonitoringPage extends ConsumerWidget {
  const MonitoringPage({super.key, this.simulatedScenarioTitle});

  final String? simulatedScenarioTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(monitoringControllerProvider);
    final controller = ref.read(monitoringControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Giam sat cuoc goi')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _RiskBanner(level: state.result.overallRiskLevel, reason: state.result.reason),
          const SizedBox(height: 16),
          Text('Thoi gian: ${state.elapsedSeconds}s', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          TextField(
            minLines: 8,
            maxLines: 12,
            readOnly: true,
            controller: TextEditingController(text: state.transcript),
            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Transcript truc tiep'),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.icon(
                onPressed: state.isListening ? null : () => controller.start(),
                icon: const Icon(Icons.mic),
                label: const Text('Bat dau'),
              ),
              OutlinedButton.icon(
                onPressed: state.isListening ? controller.stop : null,
                icon: const Icon(Icons.stop),
                label: const Text('Dung va luu'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RiskBanner extends StatelessWidget {
  const _RiskBanner({required this.level, this.reason});
  final RiskLevel level;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: level.color.withOpacity(0.14), borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text('${level.vietnameseName}\n${reason ?? ''}'),
      ),
    );
  }
}
~~~

### 34. `lib/ui/history_page/history_page.dart`

~~~dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_database.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Lich su')),
      body: FutureBuilder(
        future: db.getAll(),
        builder: (context, snapshot) {
          final items = snapshot.data ?? const [];
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                title: Text(item.summary),
                subtitle: Text('${item.dateTime} - ${item.duration}'),
                trailing: Text(item.riskLevel),
                onTap: () => context.push('/result/${item.id}'),
              );
            },
          );
        },
      ),
    );
  }
}
~~~

### 35. `lib/ui/result_page/result_page.dart`

~~~dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_database.dart';

class ResultPage extends ConsumerWidget {
  const ResultPage({super.key, required this.historyId});
  final int? historyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ket qua phan tich')),
      body: FutureBuilder(
        future: historyId == null ? Future.value(null) : db.getById(historyId!),
        builder: (context, snapshot) {
          final item = snapshot.data;
          if (item == null) return const Center(child: Text('Khong tim thay lich su'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(item.riskLevel, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(item.summary),
              const SizedBox(height: 16),
              Text(item.transcript),
            ],
          );
        },
      ),
    );
  }
}
~~~

### 36. `lib/ui/simulation_page/simulation_page.dart`

~~~dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SimulationScenarioData {
  const SimulationScenarioData({
    required this.title,
    required this.category,
    required this.riskLevel,
  });

  final String title;
  final String category;
  final String riskLevel;
}

class SimulationPage extends StatelessWidget {
  const SimulationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scenarios = const [
      SimulationScenarioData(title: 'Gia danh cong an', category: 'Gia danh', riskLevel: 'RED'),
      SimulationScenarioData(title: 'Nhan hang COD', category: 'Giao hang', riskLevel: 'YELLOW'),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Mo phong')),
      body: ListView.builder(
        itemCount: scenarios.length,
        itemBuilder: (context, index) {
          final item = scenarios[index];
          return ListTile(
            title: Text(item.title),
            subtitle: Text(item.category),
            trailing: Text(item.riskLevel),
            onTap: () => context.push('/monitoring?simulatedScenarioTitle=${Uri.encodeQueryComponent(item.title)}'),
          );
        },
      ),
    );
  }
}
~~~

### 37. `lib/ui/tips_lesson_page/tips_lesson_page.dart`

~~~dart
import 'package:flutter/material.dart';

class TipsLessonPage extends StatelessWidget {
  const TipsLessonPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tips = const [
      'Khong cung cap ma OTP, mat khau, CCCD qua dien thoai.',
      'Khong chuyen tien khi bi thuc ep gap.',
      'Goi lai tong dai chinh thuc de xac minh.',
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Meo phong tranh')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: tips.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) => Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(tips[index]),
          ),
        ),
      ),
    );
  }
}
~~~

### 38. `lib/ui/theme/app_theme.dart`

~~~dart
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static final light = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF1257C0),
      brightness: Brightness.light,
    ),
    useMaterial3: true,
  );

  static final dark = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFADC6FF),
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
  );
}
~~~

### 39. `android/app/src/main/AndroidManifest.xml`

~~~xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.VIBRATE" />
    <uses-permission android:name="android.permission.READ_PHONE_STATE" />
    <uses-permission android:name="android.permission.READ_CALL_LOG" />
    <uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />

    <application
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        android:label="La chan cuoc goi">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTask"
            android:theme="@style/LaunchTheme">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <service android:name=".services.UnifiedAccessibilityService"
            android:exported="true"
            android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE">
            <intent-filter>
                <action android:name="android.accessibilityservice.AccessibilityService" />
            </intent-filter>
            <meta-data android:name="android.accessibilityservice" android:resource="@xml/unified_accessibility_config" />
        </service>

        <service
            android:name=".services.BackgroundMonitoringService"
            android:enabled="true"
            android:exported="false"
            android:foregroundServiceType="microphone|mediaProjection" />

        <service
            android:name=".services.CallScreeningServiceImpl"
            android:permission="android.permission.BIND_CALL_SCREENING_SERVICE"
            android:exported="true">
            <intent-filter>
                <action android:name="android.telecom.CallScreeningService" />
            </intent-filter>
        </service>

        <receiver
            android:name=".receiver.CallReceiver"
            android:enabled="true"
            android:permission="android.permission.READ_PHONE_STATE"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.PHONE_STATE" />
            </intent-filter>
        </receiver>
    </application>
</manifest>
~~~

### 40. `android/app/src/main/kotlin/com/lachancuocgoi/MainActivity.kt`

~~~kotlin
package com.lachancuocgoi

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "lachancuocgoi/native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestOverlayPermission" -> {
                        startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName")))
                        result.success(null)
                    }
                    "startBackgroundMonitoring" -> {
                        val intent = Intent(this, services.BackgroundMonitoringService::class.java).apply {
                            action = services.BackgroundMonitoringService.ACTION_START
                            putExtra("PHONE_NUMBER", call.argument<String>("phoneNumber"))
                        }
                        startForegroundService(intent)
                        result.success(null)
                    }
                    "stopBackgroundMonitoring" -> {
                        val intent = Intent(this, services.BackgroundMonitoringService::class.java).apply {
                            action = services.BackgroundMonitoringService.ACTION_STOP
                        }
                        startService(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
~~~

### 41. `integration_test/analysis/l2/intent/tf_lite_intent_classifier_test.dart`

~~~dart
// Parity stub generated from `app/src/androidTest/java/com/example/lachancuocgoi/Analysis/L2/Intent/TFLiteIntentClassifierTest.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - class TFLiteIntentClassifierTest
// - fun setUp
// - val appContext
// - fun tearDown
// - fun testClassifierInitialization
// - val predictions
// - val topPrediction
// - fun testScamIntentDetection
// - val predictions

class TfLiteIntentClassifierTestPort {
  const TfLiteIntentClassifierTestPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/androidTest/java/com/example/lachancuocgoi/Analysis/L2/Intent/TFLiteIntentClassifierTest.kt');
  }
}
~~~

### 42. `integration_test/example_instrumented_test.dart`

~~~dart
// Parity stub generated from `app/src/androidTest/java/com/example/lachancuocgoi/ExampleInstrumentedTest.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - class ExampleInstrumentedTest
// - fun useAppContext
// - val appContext

class ExampleInstrumentedTestPort {
  const ExampleInstrumentedTestPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/androidTest/java/com/example/lachancuocgoi/ExampleInstrumentedTest.kt');
  }
}
~~~

### 43. `lib/analysis/choose_analysis.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/Analysis/ChooseAnalysis.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - object ChooseAnalysis
// - suspend fun analyzeL1
// - suspend fun analyzeL2
// - suspend fun analyzeL3

class ChooseAnalysisPort {
  const ChooseAnalysisPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/Analysis/ChooseAnalysis.kt');
  }
}
~~~

### 44. `lib/analysis/l1/l1_result.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/Analysis/L1/L1Result.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - object L1ResultParser
// - val CRITICAL_KEYWORDS
// - fun containsCriticalKeyword
// - fun parse
// - val result
// - val matchedKeywords
// - val categoryGroups
// - val significantCategories
// - data class CatScore
// - val catScores
// - val maxLevel
// - val weight
// - val bestScore
// - val hasCriticalKeyword
// - val adjustedRiskLevel
// - val reason
// - val confidence
// - val result
// - fun calculateConfidence
// - var conf
// - val proportion

class L1ResultPort {
  const L1ResultPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/Analysis/L1/L1Result.kt');
  }
}
~~~

### 45. `lib/analysis/l2/g_detection/g_flash.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/Analysis/L2/GDetection/GFlash.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - object GFlash
// - fun loadSlangConfig
// - fun tokenize

class GFlashPort {
  const GFlashPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/Analysis/L2/GDetection/GFlash.kt');
  }
}
~~~

### 46. `lib/analysis/l2/g_detection/g_models.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/Analysis/L2/GDetection/GModels.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - data class GResult
// - val riskLevel
// - val reason
// - val allMatchedKeywords
// - val confirmedSituation
// - val matchedPatterns
// - val riskScore
// - val sentenceMatch
// - val mostLikelyScenario
// - val alertEnabled
// - data class RiskScore
// - val keywordScore
// - val topicScore
// - val patternScore
// - val contextScore
// - val sentenceScore
// - val scenarioScore
// - val finalScore
// - data class SituationMatchResult
// - val confirmedSituationName
// - val allMatchedSituations
// - data class SentenceMatch
// - val sentence
// - val level
// - val isSafe
// - data class ScenarioMatch
// - val scenarioId
// - val situationName
// - val similarityScore
// - val group
// - val level
// - data class KeywordTrieData
// - val riskLevel
// - val category
// - val originalKeyword
// - class TrieNode
// - val children
// - var keywordData
// - data class RiskModelVocabulary
// - data class RiskLevelData

class GModelsPort {
  const GModelsPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/Analysis/L2/GDetection/GModels.kt');
  }
}
~~~

### 47. `lib/analysis/l2/g_detection/g_pattern_matcher.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/Analysis/L2/GDetection/GPatternMatcher.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - object GPatternMatcher
// - val normalizedKeywordCache
// - fun normalizeKeyword
// - fun matchPatterns
// - val results
// - val matchesByIndex
// - val capturedElements
// - fun matchSinglePattern
// - val firstElement
// - fun matchRemainingSequence
// - val targetElement
// - val searchStart
// - val searchEnd
// - fun checkElementAt
// - val normalizedSingle
// - val normalizedTokens
// - val matchesHere

class GPatternMatcherPort {
  const GPatternMatcherPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/Analysis/L2/GDetection/GPatternMatcher.kt');
  }
}
~~~

### 48. `lib/analysis/l2/g_detection/g_thinking.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/Analysis/L2/GDetection/GThinking.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - object GThinking
// - var TIER1_TOPICS
// - var TIER2_URGENCY
// - var TIER3_PII
// - fun loadTierConfig
// - fun normalize
// - fun isTierConfigLoaded
// - fun matchesWholeWord
// - val idx
// - val leftBoundary
// - val rightBoundary
// - fun analyze
// - val level
// - val tier3Matches
// - val token
// - val tier2Matches
// - val token
// - val tier1Matches
// - val token
// - val hasTier3
// - val hasTier2
// - val hasTier1
// - val tier1Count
// - val tier2Count
// - val baseHighestKeywordRisk
// - val totalPatternScore
// - val strongestPatternScore
// - var tieredLevel
// - var tieredReason
// - val SCENARIO_ALERT_THRESHOLD
// - val hasGoodScenarioMatch
// - var finalLevel
// - var finalReason
// - val scenarioLevel
// - val isCharity
// - val patternLevel
// - val updatedKeywords
// - var newLevel
// - val highestKeywordRisk
// - val keywordScoreRaw

class GThinkingPort {
  const GThinkingPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/Analysis/L2/GDetection/GThinking.kt');
  }
}
~~~

### 49. `lib/analysis/l2/g_detection/risk_scenarios_master_model.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/Analysis/L2/GDetection/RiskScenariosMasterModel.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - data class RiskScenariosMaster
// - val title
// - val version
// - val description
// - val scenarios
// - data class MasterScenario
// - val id
// - val source
// - val name
// - val description
// - val category
// - data class L2AnalysisHints

class RiskScenariosMasterModelPort {
  const RiskScenariosMasterModelPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/Analysis/L2/GDetection/RiskScenariosMasterModel.kt');
  }
}
~~~

### 50. `lib/analysis/l2/g_detection/scenario_matcher.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/Analysis/L2/GDetection/ScenarioMatcher.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - class ScenarioMatcher
// - val tokenToScenarios
// - val scenarioData
// - var initialized
// - data class ScenarioInfo
// - val name
// - val category
// - val level
// - val triggerPhrases
// - val contextPhrases
// - val triggerBigrams
// - val contextBigrams
// - val hints
// - val hasRequiredContext
// - val avgPhraseLength
// - fun ensureInitialized
// - val triggerPhrasesTokenized
// - val contextPhrasesTokenized
// - val triggerPhrasesTokens
// - val contextPhrasesTokens
// - val triggerBigrams
// - val contextBigrams
// - val allPhraseSizes
// - val avgPhraseLength
// - fun match
// - val transcriptSet
// - val transcriptBigrams
// - val candidateScenarios
// - var bestMatch
// - var maxScore
// - val info
// - val bestTrigger
// - val bestContext
// - val triggerPhraseSize
// - val contextPhraseSize
// - val maxPossibleWeight
// - val currentWeight
// - var score
// - val dynamicThreshold
// - fun findBestPhraseMatchWithBigram

class ScenarioMatcherPort {
  const ScenarioMatcherPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/Analysis/L2/GDetection/ScenarioMatcher.kt');
  }
}
~~~

### 51. `lib/analysis/l2/g_detection/sentence_matcher.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/Analysis/L2/GDetection/SentenceMatcher.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - class SentenceMatcher
// - val safeSentenceTrie
// - val threatSentenceTrieByLevel
// - var initialized
// - val maxSkipTokens
// - fun ensureInitialized
// - val level
// - val tokens
// - val trie
// - val tokens
// - fun insertIntoTrie
// - var node
// - fun match
// - val riskLevels
// - val trie
// - fun searchInTrieFuzzy
// - var longestMatch
// - val result
// - fun searchRecursive
// - var bestMatch
// - val token
// - val childResult
// - val nextToken
// - val skipResult
// - class TrieNode
// - val children
// - var sentence

class SentenceMatcherPort {
  const SentenceMatcherPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/Analysis/L2/GDetection/SentenceMatcher.kt');
  }
}
~~~

### 52. `lib/analysis/l2/intent/scam_intent_extensions.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/Analysis/L2/Intent/ScamIntentExtensions.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - fun ScamIntent
// - fun ScamIntent
// - fun ScamIntent
// - fun ScamIntent
// - val baseLevel

class ScamIntentExtensionsPort {
  const ScamIntentExtensionsPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/Analysis/L2/Intent/ScamIntentExtensions.kt');
  }
}
~~~

### 53. `lib/analysis/l2/intent/tf_lite_intent_classifier.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/Analysis/L2/Intent/TFLiteIntentClassifier.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - enum class ScamIntent
// - data class IntentPrediction
// - val intent
// - val confidence
// - class TFLiteIntentClassifier
// - val INTENT_LABELS
// - var interpreter
// - val vocab
// - var isReady
// - var hasAttemptedInit
// - val inputIdsBuf
// - val maskBuf
// - val typeIdsBuf
// - var outputBuf
// - var outScale
// - var outZeroPoint
// - var isUint8
// - var isInt8
// - val logits
// - val probabilities
// - val inputs
// - val outputs
// - var lastInputHash
// - var lastInputLength
// - var cachedResult
// - val CACHE_CHANGE_THRESHOLD
// - fun initialize
// - fun isReady
// - fun loadResources
// - val initTask
// - fun loadVocab
// - fun loadModel
// - val fileDescriptor
// - val inputStream
// - val fileChannel
// - val startOffset
// - val declaredLength
// - val modelBuffer
// - val options
// - val outputTensor

class TfLiteIntentClassifierPort {
  const TfLiteIntentClassifierPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/Analysis/L2/Intent/TFLiteIntentClassifier.kt');
  }
}
~~~

### 54. `lib/analysis/l2/l2_result.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/Analysis/L2/L2Result.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - object L2ResultParser
// - fun parse
// - val allEvidence
// - val topicMatch
// - val sortedMatches

class L2ResultPort {
  const L2ResultPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/Analysis/L2/L2Result.kt');
  }
}
~~~

### 55. `lib/analysis/l2/wfsa/scam_graph_builder.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/Analysis/L2/WFSA/ScamGraphBuilder.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - object ScamGraphBuilder
// - fun buildDefaultGraphs
// - fun buildPoliceImpersonationGraph
// - val s0
// - val s1
// - val s2
// - val s3
// - val s4
// - fun buildVNeidScamGraph
// - val s0
// - val s1
// - val s2
// - val s3
// - val s4
// - fun buildTelecomLockGraph
// - val s0
// - val s1
// - val s2
// - val s3
// - fun buildTechSupportHijackGraph
// - val s0
// - val s1
// - val s2
// - val s3
// - val s4
// - fun buildVirtualKidnappingGraph
// - val s0
// - val s1
// - val s2
// - fun buildSocialDeepfakeLoanGraph
// - val s0
// - val s1
// - val s2
// - val s3
// - fun buildInvestmentScamGraph
// - val s0
// - val s1
// - val s2
// - val s3
// - fun buildJobTaskScamGraph

class ScamGraphBuilderPort {
  const ScamGraphBuilderPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/Analysis/L2/WFSA/ScamGraphBuilder.kt');
  }
}
~~~

### 56. `lib/analysis/l3/core/api_key_obfuscator.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/Analysis/L3/core/ApiKeyObfuscator.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - object ApiKeyObfuscator
// - fun decode
// - val decodedBytes
// - val result
// - fun encode
// - val rawBytes
// - val result

class ApiKeyObfuscatorPort {
  const ApiKeyObfuscatorPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/Analysis/L3/core/ApiKeyObfuscator.kt');
  }
}
~~~

### 57. `lib/analysis/l3/core/api_key_provider.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/Analysis/L3/core/ApiKeyProvider.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - interface ApiKeyProvider
// - fun getApiKeys
// - fun getKeyCount
// - class BuildConfigApiKeyProvider
// - val keys

class ApiKeyProviderPort {
  const ApiKeyProviderPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/Analysis/L3/core/ApiKeyProvider.kt');
  }
}
~~~

### 58. `lib/analysis/l3/core/gemini_chat_session.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/Analysis/L3/core/GeminiChatSession.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - class GeminiChatSession
// - val apiKeyProvider
// - val config
// - val keyHealthTracker
// - var currentChat
// - var currentKeyIndex
// - var currentModelIndex
// - var hasNotifiedAllExhausted
// - val fallbackModels
// - val conversationHistory
// - var safeHistory
// - val sessionLock
// - var lastCallTime
// - val startTime
// - val keys
// - val activeIndices
// - val bestKey
// - val otherKeys
// - var lastError
// - var firstKeyAttempted
// - val modelName
// - val response
// - val responseText
// - val parsed
// - val latency
// - val msg
// - val isQuotaError
// - val isAuthError
// - fun close
// - fun createNewChat
// - val keys
// - val apiKey
// - val genConfig
// - val model
// - suspend fun applyRateLimit
// - val now
// - val timeSinceLastCall
// - val waitTime

class GeminiChatSessionPort {
  const GeminiChatSessionPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/Analysis/L3/core/GeminiChatSession.kt');
  }
}
~~~

### 59. `lib/analysis/l3/core/gemini_config.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/Analysis/L3/core/GeminiConfig.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - data class GeminiConfig
// - val modelName
// - val temperature
// - val topK
// - val topP
// - val timeoutMs
// - val responseMimeType
// - fun forAnalysis
// - fun forSummarization

class GeminiConfigPort {
  const GeminiConfigPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/Analysis/L3/core/GeminiConfig.kt');
  }
}
~~~

### 60. `lib/analysis/l3/core/gemini_metrics.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/Analysis/L3/core/GeminiMetrics.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - object GeminiMetrics
// - val totalCalls
// - val successCalls
// - val failureCalls
// - val cacheHits
// - val cacheMisses
// - val totalLatency
// - val callsPerKey
// - val errorsPerKey
// - fun recordCall
// - fun recordCacheHit
// - fun recordCacheMiss
// - fun getSnapshot
// - val calls
// - val hits
// - val misses
// - val totalRequests
// - val keySummary
// - val errors
// - fun reset
// - data class KeyMetricSummary
// - val index
// - val calls
// - val errors
// - val errorRate
// - data class MetricsSnapshot
// - val totalApiCalls
// - val successCalls
// - val failureCalls
// - val cacheHits
// - val cacheMisses
// - val averageLatencyMs
// - val cacheHitRate
// - val perKeyMetrics
// - val successRate
// - val failureRate
// - val keyLines

class GeminiMetricsPort {
  const GeminiMetricsPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/Analysis/L3/core/GeminiMetrics.kt');
  }
}
~~~

### 61. `lib/analysis/l3/core/gemini_response.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/Analysis/L3/core/GeminiResponse.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - data class AnalysisResponse
// - val level
// - val label
// - val reason
// - val recommendation

class GeminiResponsePort {
  const GeminiResponsePort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/Analysis/L3/core/GeminiResponse.kt');
  }
}
~~~

### 62. `lib/analysis/l3/core/key_health_tracker.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/Analysis/L3/core/KeyHealthTracker.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - class KeyHealthTracker
// - enum class KeyStatus
// - data class KeyHealth
// - val index
// - val status
// - val consecutiveErrors
// - val cooldownUntilMs
// - val lastErrorTimeMs
// - val lastErrorMessage
// - val keyStatuses
// - val keyConsecutiveErrors
// - val keyCooldownUntil
// - val keyLastErrorTime
// - val keyLastErrorMsg
// - var preferredKeyIndex
// - fun markQuotaExceeded
// - val cooldownUntil
// - fun markInvalid
// - fun markSuccess
// - fun markError
// - val errors
// - val count
// - fun getAvailableKeyIndex
// - val keys
// - val idx
// - fun getActiveKeyIndices
// - val keys
// - val status
// - fun hasActiveKeys
// - fun areAllKeysDown
// - fun getHealthSummary
// - val keys
// - fun recoverCooldownKeysIfNeeded
// - val now
// - val iterator
// - val entry
// - val idx
// - val oldStatus
// - fun nextMidnightMs
// - val cal

class KeyHealthTrackerPort {
  const KeyHealthTrackerPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/Analysis/L3/core/KeyHealthTracker.kt');
  }
}
~~~

### 63. `lib/analysis/l3/core/response_cache.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/Analysis/L3/core/ResponseCache.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - class ResponseCache
// - val maxSize
// - val cache
// - fun getTtlForRisk
// - fun get
// - val hashedKey
// - val entry
// - val ttl
// - val now
// - fun put
// - val hashedKey
// - val ttl
// - fun hashKey
// - val normalized
// - val bytes
// - fun getStats
// - fun clear
// - data class CacheEntry
// - val value
// - val timestamp
// - val ttlMs
// - data class CacheStats
// - val size
// - val maxSize
// - val usagePercent

class ResponseCachePort {
  const ResponseCachePort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/Analysis/L3/core/ResponseCache.kt');
  }
}
~~~

### 64. `lib/analysis/l3/gemini_summarizer.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/Analysis/L3/GeminiSummarizer.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - class GeminiSummarizer
// - val apiKeyProvider
// - val keyHealthTracker
// - val geminiClient
// - suspend fun summarize
// - val trimmed
// - val wordCount
// - val prompt
// - val result
// - fun createPrompt

class GeminiSummarizerPort {
  const GeminiSummarizerPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/Analysis/L3/GeminiSummarizer.kt');
  }
}
~~~

### 65. `lib/audio/creator_audio_capture_manager.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/audio/CreatorAudioCaptureManager.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - object CreatorAudioCaptureManager
// - val BUFFER_SIZE
// - val _state
// - val state
// - val _amplitudeFlow
// - val amplitudeFlow
// - val _creatorTranscriptFlow
// - val creatorTranscriptFlow
// - fun emitAmplitude
// - fun updateTranscript
// - fun startCapture
// - fun stopCapture
// - fun startCaptureInternal
// - val captureConfig
// - val builder
// - val record
// - enum class CaptureState

class CreatorAudioCaptureManagerPort {
  const CreatorAudioCaptureManagerPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/audio/CreatorAudioCaptureManager.kt');
  }
}
~~~

### 66. `lib/data/call_history_dao.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/data/CallHistoryDao.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - interface CallHistoryDao
// - suspend fun insert
// - fun getAll
// - fun getById
// - suspend fun deleteAll
// - suspend fun deleteById
// - suspend fun updateRiskLevel
// - suspend fun getByIdSync
// - suspend fun update

class CallHistoryDaoPort {
  const CallHistoryDaoPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/data/CallHistoryDao.kt');
  }
}
~~~

### 67. `lib/data/transcript_saver.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/data/TranscriptSaver.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - object TranscriptSaver
// - fun prepareTranscriptForLocalStorage
// - fun saveTranscript
// - val timestamp
// - val fileName
// - val directory
// - val file

class TranscriptSaverPort {
  const TranscriptSaverPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/data/TranscriptSaver.kt');
  }
}
~~~

### 68. `lib/data/vocabulary_repository.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/data/VocabularyRepository.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - data class RiskModelSentences
// - object VocabularyRepository
// - fun getSituationSentences
// - val inputStream
// - val model

class VocabularyRepositoryPort {
  const VocabularyRepositoryPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/data/VocabularyRepository.kt');
  }
}
~~~

### 69. `lib/main_activity.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/MainActivity.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - class MainActivity
// - val mainViewModel
// - val _intentFlow
// - val intentFlow
// - val permissionPrefs
// - val settingsLauncher
// - val requestRoleLauncher
// - fun openAppSettings
// - val intent
// - val requestPermissionLauncher
// - val requestPhonePermissionsLauncher
// - val readPhoneStateGranted
// - val readCallLogGranted
// - fun requestCallScreeningRole
// - val roleManager
// - val intent
// - fun requestCallLogPermission
// - fun requestRecordAudioPermission
// - fun requestDrawOverlayPermission
// - val intent
// - fun requestNotificationsPermission
// - fun requestForegroundServicePermission
// - val database
// - val db
// - fun checkAndRequestInitialPermissions
// - val phonePermissionRequested
// - val audioPermissionRequested
// - val hasPhoneAccess
// - fun CallShieldApp
// - val navController
// - val systemIsDark
// - val coroutineScope
// - val context
// - val sharedPreferences
// - val savedAnalysisMode
// - val initialAnalysisMode
// - var settingsState
// - var showSettingsDialog
// - var showInstructDialog
// - var showRightsDialog

class MainActivityPort {
  const MainActivityPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/MainActivity.kt');
  }
}
~~~

### 70. `lib/main_application.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/MainApplication.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - class MainApplication

class MainApplicationPort {
  const MainApplicationPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/MainApplication.kt');
  }
}
~~~

### 71. `lib/main_view_model.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/MainViewModel.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - class MainViewModel
// - val _isReady
// - val isReady
// - val _database
// - val database

class MainViewModelPort {
  const MainViewModelPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/MainViewModel.kt');
  }
}
~~~

### 72. `lib/receiver/call_receiver.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/receiver/CallReceiver.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - class CallReceiver
// - val TAG
// - val notificationManager
// - val state
// - val phoneNumber
// - fun showIncomingCallNotification
// - val notificationManager
// - val channel
// - val monitorIntent
// - val monitorPendingIntent
// - val dismissIntent
// - val dismissPendingIntent
// - val fullScreenIntent
// - val fullScreenPendingIntent
// - val notification

class CallReceiverPort {
  const CallReceiverPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/receiver/CallReceiver.kt');
  }
}
~~~

### 73. `lib/risk_level.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/RiskLevel.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - enum class RiskLevel
// - val level
// - fun deescalate
// - fun fromString
// - fun fromInt

class RiskLevelPort {
  const RiskLevelPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/RiskLevel.kt');
  }
}
~~~

### 74. `lib/services/background_monitoring_service.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/services/BackgroundMonitoringService.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - class BackgroundMonitoringService
// - val serviceJob
// - val serviceScope
// - val finalizationScope
// - var currentTranscript
// - var startTime
// - var monitoringJob
// - var analysisLoopJob
// - var alertLoopJob
// - var connectivityJob
// - var transcriptCollectorJob
// - var phoneNumber
// - var pendingRiskResult
// - var audioFocusRequest
// - var hadAudioFocus
// - var wasSpeakerphoneOn
// - var shouldEnableSpeakerphone
// - var speakerphoneChangedByService
// - var selectedMode
// - var effectiveMode
// - var networkAvailable
// - var isL3FallbackActive
// - var hasShownFallbackAlertForCurrentOutage
// - var lastL3RecoveryAttemptAt
// - val sharedPreferences
// - fun startMonitoring
// - val sharedPreferences
// - val analysisModeName
// - val analysisMode
// - val snapshotTranscript
// - val result
// - val fallbackResult
// - val result
// - suspend fun handleConnectivityChanged
// - val previousState
// - suspend fun tryRecoverL3Session
// - val now
// - val replayStart
// - val warmupResult
// - fun enterL3FallbackMode

class BackgroundMonitoringServicePort {
  const BackgroundMonitoringServicePort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/services/BackgroundMonitoringService.kt');
  }
}
~~~

### 75. `lib/services/call_screening_service_impl.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/services/CallScreeningServiceImpl.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - class CallScreeningServiceImpl
// - val phoneNumber
// - val serviceIntent
// - val activityIntent
// - val response

class CallScreeningServiceImplPort {
  const CallScreeningServiceImplPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/services/CallScreeningServiceImpl.kt');
  }
}
~~~

### 76. `lib/services/connectivity_monitor.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/services/ConnectivityMonitor.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - class ConnectivityMonitor
// - val appContext
// - val connectivityManager
// - val _isNetworkAvailable
// - val isNetworkAvailable
// - var isStarted
// - val networkCallback
// - fun start
// - fun stop
// - fun checkCurrentConnectivity
// - val activeNetwork
// - val capabilities
// - fun publishCurrentStatus

class ConnectivityMonitorPort {
  const ConnectivityMonitorPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/services/ConnectivityMonitor.kt');
  }
}
~~~

### 77. `lib/services/creator_media_projection_service.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/services/CreatorMediaProjectionService.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - class CreatorMediaProjectionService
// - var onMediaProjectionReady
// - val serviceScope
// - var captureJob
// - var analysisJob
// - var devModeWatchdogJob
// - val stopIntent
// - val stopPendingIntent
// - val notification
// - val code
// - val data
// - val mediaProjectionManager
// - val projection
// - fun startAudioLoop
// - val record
// - val buffer
// - val read
// - val amplitude
// - val normalizedRms
// - fun stopAudioLoop
// - fun createNotificationChannel
// - val channel
// - val manager

class CreatorMediaProjectionServicePort {
  const CreatorMediaProjectionServicePort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/services/CreatorMediaProjectionService.kt');
  }
}
~~~

### 78. `lib/services/stt_engine.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/services/SttEngine.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - interface SttEngine
// - fun start
// - fun stop
// - fun destroy
// - val fullTranscriptFlow
// - val textResults
// - val isListening
// - val rmsDbFlow
// - fun clearTranscript
// - val isReady
// - val name

class SttEnginePort {
  const SttEnginePort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/services/SttEngine.kt');
  }
}
~~~

### 79. `lib/services/transcription_hub.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/services/TranscriptionHub.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - object TranscriptionHub
// - val _transcriptFlow
// - val transcriptFlow
// - var fullHistory
// - fun postTranscript
// - val cleanedNewText
// - val cutPoint
// - val safeCutPoint
// - val historyToCompare
// - val wordsHistory
// - val wordsNew
// - var overlapIndex
// - val historySub
// - val newSub
// - val actualNewContent
// - fun reset

class TranscriptionHubPort {
  const TranscriptionHubPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/services/TranscriptionHub.kt');
  }
}
~~~

### 80. `lib/services/transparent_trampoline_activity.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/services/TransparentTrampolineActivity.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - class TransparentTrampolineActivity
// - val serviceIntent

class TransparentTrampolineActivityPort {
  const TransparentTrampolineActivityPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/services/TransparentTrampolineActivity.kt');
  }
}
~~~

### 81. `lib/services/unified_accessibility_service.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/services/UnifiedAccessibilityService.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - class UnifiedAccessibilityService
// - var lastCheckTime
// - var isCallActive
// - var lastServiceStartTime
// - var isNotificationShown
// - val notificationManager
// - val rootNode
// - fun handleCallDetection
// - var detectedApp
// - val windowList
// - val rootNode
// - val appName
// - fun getIncomingCallAppName
// - val packageName
// - val isDialer
// - val incomingKeywords
// - fun answerCallAndStartMonitoring
// - val notificationManager
// - val answerText
// - val answerDescriptions
// - val answered
// - val monitoringIntent
// - fun endCall
// - val endText
// - val endDescriptions
// - val ended
// - fun findAndClick
// - val rootNode
// - val textNodes
// - val clickableNode
// - val clicked
// - val foundIcon
// - val clicked
// - fun findClickableNode
// - var currentNode
// - val parent
// - fun findClickableNodeByDescription
// - val description
// - val clickable
// - val child

class UnifiedAccessibilityServicePort {
  const UnifiedAccessibilityServicePort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/services/UnifiedAccessibilityService.kt');
  }
}
~~~

### 82. `lib/services/vosk_stt_manager.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/services/VoskSttManager.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - sealed class ModelLoadState
// - object Loading
// - data class Ready
// - data class Failed
// - class VoskSttManager
// - var model
// - var recognizer
// - val handler
// - val _creatorTranscriptFlow
// - val creatorTranscriptFlow
// - val _modelLoadState
// - val modelLoadState
// - val _isReady
// - val isReady
// - val _isProcessing
// - val isProcessing
// - var cumulativeTranscript
// - var retryCount
// - fun initModel
// - val remaining
// - fun retryLoad
// - fun processAudioBuffer
// - val isFinal
// - val resultJson
// - val recognizedText
// - val partialJson
// - val partialText
// - val currentPreview
// - fun extractText
// - val jsonObject
// - val isModelReady
// - fun resetTranscript
// - fun destroy

class VoskSttManagerPort {
  const VoskSttManagerPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/services/VoskSttManager.kt');
  }
}
~~~

### 83. `lib/ui/components/circular_waveform_visualizer.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/ui/components/CircularWaveformVisualizer.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - fun CircularWaveformVisualizer
// - val targetNormalized
// - val currentAmplitude
// - val infiniteTransition
// - val phase
// - val cx
// - val cy
// - val w
// - val h
// - val maxRadius
// - val paintAlpha
// - val dynamicRadius
// - val rippleCount
// - val ripplePhase
// - val normalizedPhase
// - val rippleRadius
// - val rippleAlpha

class CircularWaveformVisualizerPort {
  const CircularWaveformVisualizerPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/ui/components/CircularWaveformVisualizer.kt');
  }
}
~~~

### 84. `lib/ui/components/compose_overlay_lifecycle_owner.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/ui/components/ComposeOverlayLifecycleOwner.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - class ComposeOverlayLifecycleOwner
// - var mLifecycleRegistry
// - var mSavedStateRegistryController
// - val store
// - fun handleLifecycleEvent
// - fun performRestore

class ComposeOverlayLifecycleOwnerPort {
  const ComposeOverlayLifecycleOwnerPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/ui/components/ComposeOverlayLifecycleOwner.kt');
  }
}
~~~

### 85. `lib/ui/components/waveform_visualizer.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/ui/components/WaveformVisualizer.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - fun WaveformVisualizer
// - val barCount
// - val magnitudes
// - val targetNormalized
// - val w
// - val h
// - val totalBarWidth
// - val gap
// - val barWidth
// - val centerY
// - val maxAmplitude
// - val x
// - var safeAmplitude
// - val barHeight

class WaveformVisualizerPort {
  const WaveformVisualizerPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/ui/components/WaveformVisualizer.kt');
  }
}
~~~

### 86. `lib/ui/history_page/history_view_model.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/ui/HistoryPage/HistoryViewModel.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - class HistoryViewModel
// - val _rawSearchQuery
// - val searchQuery
// - val filteredHistoryItems
// - fun updateSearchQuery
// - fun deleteItem
// - fun deleteAll
// - class HistoryViewModelFactory
// - val dao

class HistoryViewModelPort {
  const HistoryViewModelPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/ui/HistoryPage/HistoryViewModel.kt');
  }
}
~~~

### 87. `lib/ui/history_page/item_history/history_item_card.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/ui/HistoryPage/ItemHistory/HistoryItemCard.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - fun HistoryItemCard
// - val riskLevel
// - val riskColor
// - val analysisLabel

class HistoryItemCardPort {
  const HistoryItemCardPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/ui/HistoryPage/ItemHistory/HistoryItemCard.kt');
  }
}
~~~

### 88. `lib/ui/home_page/home_view_model.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/ui/HomePage/HomeViewModel.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - data class HomeUiState
// - val isRecordAudioGranted
// - val isCallCaptionEnabled
// - val isCallDetectionEnabled
// - val isCallScreeningEnabled
// - class HomeViewModel
// - val _uiState
// - val uiState
// - fun checkPermissions

class HomeViewModelPort {
  const HomeViewModelPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/ui/HomePage/HomeViewModel.kt');
  }
}
~~~

### 89. `lib/ui/home_page/instruct_dialog/instruct_dialog.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/ui/HomePage/InstructDialog/InstructDialog.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - fun InstructDialog
// - fun PrincipleOfOperationTab
// - val principles

class InstructDialogPort {
  const InstructDialogPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/ui/HomePage/InstructDialog/InstructDialog.kt');
  }
}
~~~

### 90. `lib/ui/home_page/rights_dialog/permission_prompts.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/ui/HomePage/RightsDialog/PermissionPrompts.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - fun PermissionPrompts
// - val allGranted
// - fun MiniPermissionCard

class PermissionPromptsPort {
  const PermissionPromptsPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/ui/HomePage/RightsDialog/PermissionPrompts.kt');
  }
}
~~~

### 91. `lib/ui/home_page/rights_dialog/permissions_tab.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/ui/HomePage/RightsDialog/PermissionsTab.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - data class PermissionItemUi
// - val icon
// - val granted
// - val onClick
// - fun PermissionsTab
// - val context
// - val lifecycleOwner
// - var isRecordAudioGranted
// - var isAccessibilityProtectionEnabled
// - var isCallScreeningHeld
// - var isDrawOverlayGranted
// - var isNotificationsGranted
// - var hasPhoneCallAccess
// - var isForegroundServiceGranted
// - fun refreshPermissionStates
// - val permissionLauncher
// - val settingsLauncher
// - val observer
// - val essentialPermissions
// - val supportingPermissions
// - val essentialGrantedCount
// - val supportingGrantedCount
// - fun PermissionReadinessCard
// - val essentialProgress
// - val isReady
// - fun PermissionSection
// - fun PermissionItemCard
// - val containerColor
// - val borderColor
// - val iconBackground
// - val iconTint
// - fun PermissionCard
// - val containerColor
// - val borderColor
// - val iconBackground
// - val iconTint
// - fun PermissionStatusBadge
// - val containerColor
// - val textColor

class PermissionsTabPort {
  const PermissionsTabPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/ui/HomePage/RightsDialog/PermissionsTab.kt');
  }
}
~~~

### 92. `lib/ui/home_page/rights_dialog/permission_utils.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/ui/HomePage/RightsDialog/PermissionUtils.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - object PermissionUtils
// - fun hasPhoneCallAccess
// - val hasPhonePerm
// - val hasCallLogPerm
// - fun isCallScreeningRoleHeld
// - val roleManager
// - fun isDrawOverlayGranted
// - fun isRecordAudioGranted
// - fun isStoragePermissionGranted
// - fun isForegroundServiceGranted
// - fun isCallDetectionEnabled
// - fun isCallCaptionEnabled
// - fun isAccessibilityProtectionEnabled
// - fun isSpecificAccessibilityServiceEnabled
// - val am
// - val enabledServices
// - val enabledServiceInfo
// - val componentName
// - val enabledServicesSetting
// - val colonSplitter
// - val componentNameString
// - fun isNotificationsGranted
// - fun isCallLogGranted

class PermissionUtilsPort {
  const PermissionUtilsPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/ui/HomePage/RightsDialog/PermissionUtils.kt');
  }
}
~~~

### 93. `lib/ui/home_page/rights_dialog/rights_dialog.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/ui/HomePage/RightsDialog/RightsDialog.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - fun RightsDialog

class RightsDialogPort {
  const RightsDialogPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/ui/HomePage/RightsDialog/RightsDialog.kt');
  }
}
~~~

### 94. `lib/ui/home_page/settings_dialog/analysis_mode.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/ui/HomePage/SettingsDialog/AnalysisMode.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - enum class AnalysisMode
// - fun AnalysisSensitivitySetting
// - val options
// - val textColor

class AnalysisModePort {
  const AnalysisModePort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/ui/HomePage/SettingsDialog/AnalysisMode.kt');
  }
}
~~~

### 95. `lib/ui/home_page/settings_dialog/developer_mode_manager.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/ui/HomePage/SettingsDialog/DeveloperModeManager.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - object DeveloperModeManager
// - var tapCount
// - var lastTapTime
// - var deactivateTapCount
// - var lastDeactivateTapTime
// - var devModeActivatedAt
// - val isActive
// - sealed class TapResult
// - object Nothing
// - object ShowPassword
// - object Deactivated
// - fun onTitleTap
// - val now
// - fun currentTapCount
// - fun verifyPassword
// - fun activateDevMode
// - fun isDevModeActive
// - val active
// - fun remainingSeconds
// - val elapsed
// - fun deactivateDevMode

class DeveloperModeManagerPort {
  const DeveloperModeManagerPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/ui/HomePage/SettingsDialog/DeveloperModeManager.kt');
  }
}
~~~

### 96. `lib/ui/home_page/settings_dialog/dev_password_dialog.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/ui/HomePage/SettingsDialog/DevPasswordDialog.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - fun DevPasswordDialog
// - var password
// - var showPassword
// - var hasError
// - fun attempt

class DevPasswordDialogPort {
  const DevPasswordDialogPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/ui/HomePage/SettingsDialog/DevPasswordDialog.kt');
  }
}
~~~

### 97. `lib/ui/home_page/settings_dialog/settings_dialog.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/ui/HomePage/SettingsDialog/SettingsDialog.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - fun SettingsDialog
// - var showDevPasswordDialog
// - val isDevActive

class SettingsDialogPort {
  const SettingsDialogPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/ui/HomePage/SettingsDialog/SettingsDialog.kt');
  }
}
~~~

### 98. `lib/ui/home_page/settings_dialog/settings_state.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/ui/HomePage/SettingsDialog/SettingsState.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - data class SettingsState
// - val isDarkTheme
// - val analysisMode
// - val audioBoost
// - val creatorAudioCapture

class SettingsStatePort {
  const SettingsStatePort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/ui/HomePage/SettingsDialog/SettingsState.kt');
  }
}
~~~

### 99. `lib/ui/home_page/settings_dialog/settings_tab.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/ui/HomePage/SettingsDialog/SettingsTab.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - fun SettingsTab
// - val isDarkTheme
// - val themeIcon
// - val themeTitle
// - val themeDescription
// - val isDevActive
// - fun SettingToggleCard

class SettingsTabPort {
  const SettingsTabPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/ui/HomePage/SettingsDialog/SettingsTab.kt');
  }
}
~~~

### 100. `lib/ui/monitoring_page/alert_history_section.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/ui/MonitoringPage/AlertHistorySection.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - fun AlertHistorySection
// - fun AlertHistoryCard

class AlertHistorySectionPort {
  const AlertHistorySectionPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/ui/MonitoringPage/AlertHistorySection.kt');
  }
}
~~~

### 101. `lib/ui/monitoring_page/audio_waveform.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/ui/MonitoringPage/AudioWaveform.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - fun AudioWaveform
// - val infiniteTransition
// - val alpha
// - val barWidth
// - val maxAmplitude
// - val x
// - val amplitudeValue
// - fun formatElapsedTime
// - val minutes
// - val remainingSeconds

class AudioWaveformPort {
  const AudioWaveformPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/ui/MonitoringPage/AudioWaveform.kt');
  }
}
~~~

### 102. `lib/ui/monitoring_page/live_conversation.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/ui/MonitoringPage/LiveConversation.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - fun LiveConversation
// - val listState
// - val cleanTranscript
// - val annotatedTranscript
// - val keyword
// - var startIndex
// - val endIndex

class LiveConversationPort {
  const LiveConversationPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/ui/MonitoringPage/LiveConversation.kt');
  }
}
~~~

### 103. `lib/ui/monitoring_page/monitoring_view_model.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/ui/MonitoringPage/MonitoringViewModel.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - data class AlertInfo
// - data class QueuedAlert
// - val info
// - val analysisLevel
// - val timestamp
// - class MonitoringViewModel
// - val TAG
// - val speechToTextManager
// - val analysisCoordinator
// - val connectivityMonitor
// - var isStopping
// - var originalVoiceCallVolume
// - var creatorAmplitudeJob
// - var creatorTextJob
// - var isSimulationMode
// - var simulationJob
// - var originalSettingsBeforeSimulation
// - var originalSettingsBeforeFallback
// - var hasShownFallbackAlertForCurrentOutage
// - var lastL3RecoveryAttemptAt
// - val l1AlertQueue
// - val l2AlertQueue
// - var hasShownFirstL1Alert
// - var hasShownFirstL2Alert
// - var l1BatchJob
// - var l2BatchJob
// - var l1LastQueueTime
// - var l2LastQueueTime
// - val supervisorJob
// - val currentAlertHistory
// - val _currentSettings
// - val _selectedMode
// - val selectedMode
// - val _effectiveMode
// - val effectiveMode
// - val _networkAvailable
// - val networkAvailable
// - val _isFallbackActive
// - val isFallbackActive
// - val _transcript

class MonitoringViewModelPort {
  const MonitoringViewModelPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/ui/MonitoringPage/MonitoringViewModel.kt');
  }
}
~~~

### 104. `lib/ui/monitoring_page/save_note_file.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/ui/MonitoringPage/SaveNoteFile.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - No top-level declarations detected

class SaveNoteFilePort {
  const SaveNoteFilePort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/ui/MonitoringPage/SaveNoteFile.kt');
  }
}
~~~

### 105. `lib/ui/monitoring_page/warning/orange_warning.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/ui/MonitoringPage/Warning/OrangeWarning.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - fun OrangeWarning
// - val orangeColor
// - var toneGenerator

class OrangeWarningPort {
  const OrangeWarningPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/ui/MonitoringPage/Warning/OrangeWarning.kt');
  }
}
~~~

### 106. `lib/ui/monitoring_page/warning/red_warning.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/ui/MonitoringPage/Warning/RedWarning.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - fun RedWarning
// - val context
// - var vibrator
// - var toneGenerator
// - val vibrationPattern

class RedWarningPort {
  const RedWarningPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/ui/MonitoringPage/Warning/RedWarning.kt');
  }
}
~~~

### 107. `lib/ui/monitoring_page/warning/warning.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/ui/MonitoringPage/Warning/Warning.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - No top-level declarations detected

class WarningPort {
  const WarningPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/ui/MonitoringPage/Warning/Warning.kt');
  }
}
~~~

### 108. `lib/ui/overlay_manager.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/ui/OverlayManager.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - object OverlayManager
// - var windowManager
// - var alertOverlayView
// - var monitoringOverlayView
// - var incomingCallOverlayView
// - var rmsValue
// - var rmsTick
// - var monitoringStartTime
// - fun getWindowManager
// - fun createComposeOverlay
// - val wm
// - val composeView
// - val lifecycleOwner
// - fun showRedAlert
// - fun showOrangeAlert
// - fun showAlert
// - val params
// - var visible
// - fun removeAlertOverlay
// - fun showIncomingCallOverlay
// - val params
// - var visible
// - val monitorIntent
// - fun removeIncomingCallOverlay
// - fun showMonitoringOverlay
// - val params
// - var currentTime
// - val millis
// - val seconds
// - val timeString
// - fun updateWaveform
// - fun stopMonitoring
// - val stopIntent
// - fun hideMonitoringOverlay
// - fun vibrate
// - val vibrator
// - val vibratorManager
// - fun removeAll

class OverlayManagerPort {
  const OverlayManagerPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/ui/OverlayManager.kt');
  }
}
~~~

### 109. `lib/ui/result_page/result_view_model.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/ui/ResultPage/ResultViewModel.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - class ResultViewModel
// - val callHistoryDao
// - val _alertHistory
// - val alertHistory
// - val _isSaving
// - val isSaving
// - val _saveResult
// - val saveResult
// - fun clearSaveResult
// - fun processAlertHistory
// - val list
// - fun saveTranscript
// - val fileName
// - val contentValues
// - val resolver
// - val uri
// - class ResultViewModelFactory
// - val callHistoryDao

class ResultViewModelPort {
  const ResultViewModelPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/ui/ResultPage/ResultViewModel.kt');
  }
}
~~~

### 110. `lib/ui/simulation_page/simulation_view_model.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/ui/SimulationPage/SimulationViewModel.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - val NORMAL_MODE_TITLES
// - data class SimulationUiState
// - val scenarios
// - val categories
// - val filteredScenarios
// - val searchQuery
// - val selectedCategory
// - val isDevMode
// - class SimulationViewModel
// - val allScenarios
// - val _searchQuery
// - val searchQuery
// - val _selectedCategory
// - val selectedCategory
// - val _isDevMode
// - val _uiState
// - val uiState
// - val sourceList
// - val categories
// - val filtered
// - val matchesSearch
// - val matchesCategory
// - fun loadData
// - val type
// - val loaded
// - val safeLoaded
// - fun updateSearchQuery
// - fun updateSelectedCategory
// - fun updateDevMode

class SimulationViewModelPort {
  const SimulationViewModelPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/ui/SimulationPage/SimulationViewModel.kt');
  }
}
~~~

### 111. `lib/ui/theme/color.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/ui/theme/Color.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - val LightPrimary
// - val LightOnPrimary
// - val LightPrimaryContainer
// - val LightOnPrimaryContainer
// - val LightSecondary
// - val LightOnSecondary
// - val LightSecondaryContainer
// - val LightOnSecondaryContainer
// - val LightTertiary
// - val LightOnTertiary
// - val LightBackground
// - val LightOnBackground
// - val LightSurface
// - val LightOnSurface
// - val LightSurfaceVariant
// - val LightOnSurfaceVariant
// - val LightOutline
// - val LightError
// - val LightOnError
// - val LightErrorContainer
// - val LightOnErrorContainer
// - val LightWarningContainer
// - val LightOnWarningContainer
// - val DarkPrimary
// - val DarkOnPrimary
// - val DarkPrimaryContainer
// - val DarkOnPrimaryContainer
// - val DarkSecondary
// - val DarkOnSecondary
// - val DarkSecondaryContainer
// - val DarkOnSecondaryContainer
// - val DarkTertiary
// - val DarkOnTertiary
// - val DarkBackground
// - val DarkOnBackground
// - val DarkSurface
// - val DarkOnSurface
// - val DarkSurfaceVariant
// - val DarkOnSurfaceVariant
// - val DarkOutline

class ColorPort {
  const ColorPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/ui/theme/Color.kt');
  }
}
~~~

### 112. `lib/ui/theme/shape.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/ui/theme/Shape.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - val AppShapes

class ShapePort {
  const ShapePort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/ui/theme/Shape.kt');
  }
}
~~~

### 113. `lib/ui/theme/spacing.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/ui/theme/Spacing.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - object AppSpacing
// - val Xxxs
// - val Xxs
// - val Xs
// - val Sm
// - val Md
// - val Lg
// - val Xl

class SpacingPort {
  const SpacingPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/ui/theme/Spacing.kt');
  }
}
~~~

### 114. `lib/ui/theme/theme.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/ui/theme/Theme.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - val DarkColorScheme
// - val LightColorScheme
// - fun LachancuocgoiTheme
// - val colorScheme
// - val view
// - val context
// - val window

class ThemePort {
  const ThemePort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/ui/theme/Theme.kt');
  }
}
~~~

### 115. `lib/ui/theme/type.dart`

~~~dart
// Parity stub generated from `app/src/main/java/com/example/lachancuocgoi/ui/theme/Type.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - val Typography

class TypePort {
  const TypePort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/main/java/com/example/lachancuocgoi/ui/theme/Type.kt');
  }
}
~~~

### 116. `test/analysis/analysis_coordinator_test.dart`

~~~dart
// Parity stub generated from `app/src/test/java/com/example/lachancuocgoi/Analysis/AnalysisCoordinatorTest.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - class AnalysisCoordinatorTest
// - fun setup
// - val l1Field
// - val l2Field
// - val l3Field
// - fun testAnalyzeIncremental_Windowing
// - val text1
// - val text2
// - fun testAnalyzeIncremental_L3_Threshold
// - val textShort
// - val result
// - val textLong
// - fun testReset

class AnalysisCoordinatorTestPort {
  const AnalysisCoordinatorTestPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/test/java/com/example/lachancuocgoi/Analysis/AnalysisCoordinatorTest.kt');
  }
}
~~~

### 117. `test/analysis/l1/l1_analyzer_test.dart`

~~~dart
// Parity stub generated from `app/src/test/java/com/example/lachancuocgoi/Analysis/L1/L1AnalyzerTest.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - class L1AnalyzerTest
// - val testVocabularyJson
// - fun setup
// - fun testAnalyze_MatchSingleKeyword
// - val text
// - val result
// - fun testAnalyze_MatchMultipleKeywords
// - val text
// - val result
// - fun testAnalyze_NormalKeyword
// - val text
// - val result
// - fun testAnalyze_NoMatch
// - val text
// - val result
// - fun testAnalyze_Normalization
// - val text
// - val result

class L1AnalyzerTestPort {
  const L1AnalyzerTestPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/test/java/com/example/lachancuocgoi/Analysis/L1/L1AnalyzerTest.kt');
  }
}
~~~

### 118. `test/analysis/l2/g_detection/g_detection_engine_test.dart`

~~~dart
// Parity stub generated from `app/src/test/java/com/example/lachancuocgoi/Analysis/L2/GDetection/GDetectionEngineTest.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - class GDetectionEngineTest
// - val vocabularyJson
// - val scoringConfigJson
// - val patternsJson
// - val masterScenariosJson
// - val sentencesJson
// - val slangJson
// - fun setup
// - val content
// - fun testPerformFullAnalysis_BasicMatch
// - var retries
// - val text
// - val result
// - fun testPerformFullAnalysis_PatternMatch
// - var retries
// - val text
// - val result
// - fun testPerformFullAnalysis_ScenarioMatch
// - var retries
// - val text
// - val result
// - fun testPerformFullAnalysis_SafeText
// - var retries
// - val text
// - val result

class GDetectionEngineTestPort {
  const GDetectionEngineTestPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/test/java/com/example/lachancuocgoi/Analysis/L2/GDetection/GDetectionEngineTest.kt');
  }
}
~~~

### 119. `test/example_unit_test.dart`

~~~dart
// Parity stub generated from `app/src/test/java/com/example/lachancuocgoi/ExampleUnitTest.kt`.
// This file keeps the Flutter tree aligned with the Kotlin source.
// Original declarations:
// - class ExampleUnitTest
// - fun addition_isCorrect

class ExampleUnitTestPort {
  const ExampleUnitTestPort();

  Never notPortedYet() {
    throw UnimplementedError('Port logic from app/src/test/java/com/example/lachancuocgoi/ExampleUnitTest.kt');
  }
}
~~~

## Asset parity

Copy tu Android sang Flutter `assets/`: `ghitav3.tflite`, `vocab.txt`, cac JSON runtime (`risk_model_vocabulary.json`, `risk_model_sentences.json`, `risk_model_situation.json`, `risk_scenarios_master.json`, `phrase_patterns.json`, `scoring_config.json`, `tier_config.json`, `slang_config.json`, `safety_keywords.json`, `bigram_corrections.json`, `situation_test.json`), `logo.png`, va thu muc Vosk `model-vn/`.

## Native Android parity

Cac file native service hien co nen duoc dua vao Flutter Android module gan nhu nguyen logic: `BackgroundMonitoringService`, `UnifiedAccessibilityService`, `CallScreeningServiceImpl`, `TransparentTrampolineActivity`, `CreatorMediaProjectionService`, `CallReceiver`, `OverlayManager` phien ban native hoac MethodChannel wrapper. Dart khong thay the cac API he thong nay.