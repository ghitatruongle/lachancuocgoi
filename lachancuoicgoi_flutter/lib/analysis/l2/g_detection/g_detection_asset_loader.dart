import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import '../../../core/asset_loader.dart';
import '../../../core/noop_asset_loader.dart';
import '../../../core/logger.dart';
import '../../fallback_tracker.dart';
import 'g_flash.dart';
import 'g_models.dart';
import 'g_thinking.dart';
import 'scenario_matcher.dart';
import 'sentence_matcher.dart';

class GDetectionAssetLoader {
  GDetectionAssetLoader({
    AssetLoader? assetLoader,
    AppLogger? logger,
    FutureOr<String> Function(String fileName)? assetProvider,
  }) : _assetLoader = assetLoader ?? const NoopAssetLoader(),
       _logger = logger,
       _assetProvider = assetProvider;

  static const int _isolateDecodeThreshold = 10 * 1024;

  final AssetLoader _assetLoader;
  final AppLogger? _logger;
  FutureOr<String> Function(String fileName)? _assetProvider;

  void setAssetProvider(FutureOr<String> Function(String fileName) provider) {
    _assetProvider = provider;
  }

  Future<void> loadSlangMap(String fileName) async {
    try {
      final decoded = await loadJsonMap(fileName);
      final slangMap = decoded['slang_map'];
      if (slangMap is Map) {
        GFlash.loadSlangConfig(
          slangMap.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ),
        );
      }
    } on Object catch (e) {
      FallbackTracker.instance.increment('g_detection_assets');
      _logger?.warning('[GDetectionAssetLoader] Failed to load $fileName: $e');
      GFlash.loadSlangConfig(const <String, String>{});
    }
  }

  Future<ScoringConfig> loadScoringConfig(String fileName) async {
    try {
      return ScoringConfig.fromJson(await loadJsonMap(fileName));
    } on Object catch (e) {
      FallbackTracker.instance.increment('g_detection_assets');
      _logger?.warning('[GDetectionAssetLoader] Failed to load $fileName: $e');
      return const ScoringConfig();
    }
  }

  Future<void> loadTierConfig(String fileName) async {
    try {
      final config = TierConfig.fromJson(await loadJsonMap(fileName));
      GThinking.loadTierConfig(
        tier1: (config.tier1Topics ?? const <String>[]).toSet(),
        tier2: (config.tier2Urgency ?? const <String>[]).toSet(),
        tier3: (config.tier3Pii ?? const <String>[]).toSet(),
      );
    } on Object catch (e) {
      FallbackTracker.instance.increment('g_detection_assets');
      _logger?.warning('[GDetectionAssetLoader] Failed to load $fileName: $e');
      GThinking.loadTierConfig(
        tier1: const <String>{},
        tier2: const <String>{},
        tier3: const <String>{},
      );
    }
  }

  Future<List<ScamPattern>> loadPatterns(String fileName) async {
    try {
      final config = PatternConfigDTO.fromJson(await loadJsonMap(fileName));
      return config.patterns?.map((pattern) => pattern.toDomain()).toList() ??
          const <ScamPattern>[];
    } on Object catch (e) {
      FallbackTracker.instance.increment('g_detection_assets');
      _logger?.warning('[GDetectionAssetLoader] Failed to load $fileName: $e');
      return const <ScamPattern>[];
    }
  }

  Future<ScenarioMatcher?> loadSituationMatcher(String fileName) async {
    try {
      final masterModel = RiskScenariosMaster.fromJson(
        await loadJsonMap(fileName),
      );
      return ScenarioMatcher(masterModel);
    } on Object catch (e) {
      FallbackTracker.instance.increment('g_detection_assets');
      _logger?.warning('[GDetectionAssetLoader] Failed to load $fileName: $e');
      return null;
    }
  }

  Future<SentenceMatcher?> loadSentenceMatcher(String fileName) async {
    try {
      final sentencesModel = RiskModelSentences.fromJson(
        await loadJsonMap(fileName),
      );
      return SentenceMatcher(sentencesModel);
    } on Object catch (e) {
      FallbackTracker.instance.increment('g_detection_assets');
      _logger?.warning('[GDetectionAssetLoader] Failed to load $fileName: $e');
      return null;
    }
  }

  Future<String> loadString(String fileName) async {
    final provider = _assetProvider;
    if (provider != null) {
      return await provider(fileName);
    }

    return _assetLoader.loadString('assets/$fileName');
  }

  Future<Map<String, Object?>> loadJsonMap(String fileName) async {
    final text = await loadString(fileName);
    final decoded = text.length > _isolateDecodeThreshold
        ? await Isolate.run(() => _decodeJsonString(text))
        : _decodeJsonString(text);
    if (decoded is! Map) {
      throw const FormatException('Expected JSON object');
    }
    return decoded.cast<String, Object?>();
  }
}

Object? _decodeJsonString(String text) => jsonDecode(text);
