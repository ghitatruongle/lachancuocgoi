import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import '../../../core/asset_loader.dart';
import '../../../core/logger.dart';
import 'g_flash.dart';
import 'g_models.dart';
import 'g_thinking.dart';
import 'scenario_matcher.dart';
import 'sentence_matcher.dart';

/// Loads and parses the L2/G-Detection JSON assets.
///
/// Extracted from `GDetectionEngine` (Sprint 3, Cluster A). Owns the
/// `AssetLoader` / `GDetectionAssetProvider` source pair, the isolate-aware
/// JSON decoder, and the per-file config parsers. The engine constructs this
/// collaborator and delegates all I/O + parsing to it; the loader never
/// mutates engine state — it returns parsed domain objects (or applies global
/// side-effects like [GFlash.loadSlangConfig] / [GThinking.loadTierConfig]).
class GDetectionAssetLoader {
  GDetectionAssetLoader({
    AssetLoader? assetLoader,
    AppLogger? logger,
    FutureOr<String> Function(String fileName)? assetProvider,
  }) : _assetLoader = assetLoader,
       _logger = logger,
       _assetProvider = assetProvider;

  static const int _isolateDecodeThreshold = 10 * 1024;

  final AssetLoader? _assetLoader;
  final AppLogger? _logger;
  FutureOr<String> Function(String fileName)? _assetProvider;

  /// Swaps the asset source and signals that the next load is stale. Mirrors
  /// the engine's `setAssetProvider` so the public API stays unchanged.
  void setAssetProvider(FutureOr<String> Function(String fileName) provider) {
    _assetProvider = provider;
  }

  /// Loads `slang_config.json` and pushes it into the global [GFlash] state.
  /// On failure, resets slang to empty (the engine treats slang as best-effort).
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
      _logger?.warning('[GDetectionAssetLoader] Failed to load $fileName: $e');
      GFlash.loadSlangConfig(const <String, String>{});
    }
  }

  /// Loads `scoring_config.json` into a [ScoringConfig]. Returns the default
  /// config on failure so the engine can keep scoring with safe fallbacks.
  Future<ScoringConfig> loadScoringConfig(String fileName) async {
    try {
      return ScoringConfig.fromJson(await loadJsonMap(fileName));
    } on Object catch (e) {
      _logger?.warning('[GDetectionAssetLoader] Failed to load $fileName: $e');
      return const ScoringConfig();
    }
  }

  /// Loads `tier_config.json` and pushes the tier sets into [GThinking].
  /// On failure, resets all tiers to empty (defensive).
  Future<void> loadTierConfig(String fileName) async {
    try {
      final config = TierConfig.fromJson(await loadJsonMap(fileName));
      GThinking.loadTierConfig(
        tier1: (config.tier1Topics ?? const <String>[]).toSet(),
        tier2: (config.tier2Urgency ?? const <String>[]).toSet(),
        tier3: (config.tier3Pii ?? const <String>[]).toSet(),
      );
    } on Object catch (e) {
      _logger?.warning('[GDetectionAssetLoader] Failed to load $fileName: $e');
      GThinking.loadTierConfig(
        tier1: const <String>{},
        tier2: const <String>{},
        tier3: const <String>{},
      );
    }
  }

  /// Loads `phrase_patterns.json` into a list of [ScamPattern]s. Returns an
  /// empty list on failure (no patterns → only keyword/trie evidence applies).
  Future<List<ScamPattern>> loadPatterns(String fileName) async {
    try {
      final config = PatternConfigDTO.fromJson(await loadJsonMap(fileName));
      return config.patterns?.map((pattern) => pattern.toDomain()).toList() ??
          const <ScamPattern>[];
    } on Object catch (e) {
      _logger?.warning('[GDetectionAssetLoader] Failed to load $fileName: $e');
      return const <ScamPattern>[];
    }
  }

  /// Loads `risk_scenarios_master.json` into a [ScenarioMatcher]. Returns
  /// `null` on failure (engine skips scenario matching when null).
  Future<ScenarioMatcher?> loadSituationMatcher(String fileName) async {
    try {
      final masterModel = RiskScenariosMaster.fromJson(
        await loadJsonMap(fileName),
      );
      return ScenarioMatcher(masterModel);
    } on Object catch (e) {
      _logger?.warning('[GDetectionAssetLoader] Failed to load $fileName: $e');
      return null;
    }
  }

  /// Loads `risk_model_sentences.json` into a [SentenceMatcher]. Returns
  /// `null` on failure (engine skips sentence matching when null).
  Future<SentenceMatcher?> loadSentenceMatcher(String fileName) async {
    try {
      final sentencesModel = RiskModelSentences.fromJson(
        await loadJsonMap(fileName),
      );
      return SentenceMatcher(sentencesModel);
    } on Object catch (e) {
      _logger?.warning('[GDetectionAssetLoader] Failed to load $fileName: $e');
      return null;
    }
  }

  /// Fetches [fileName] as raw text using the injected provider, falling back
  /// to the asset bundle (`assets/<fileName>`) when no provider is set.
  Future<String> loadString(String fileName) async {
    final provider = _assetProvider;
    if (provider != null) {
      return await provider(fileName);
    }
    if (_assetLoader == null) {
      throw StateError('AssetLoader is null. Phải cung cấp AssetLoader hoặc provider cho $fileName.');
    }
    return _assetLoader.loadString('assets/$fileName');
  }

  /// Loads [fileName] and decodes it as a JSON object. Large files (> 10KB)
  /// are decoded on a background isolate via [Isolate.run] to avoid frame jank
  /// during L2 init; small files decode inline to skip isolate spawn cost.
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

/// Top-level để dùng được với [Isolate.run] — decode JSON trên isolate riêng.
Object? _decodeJsonString(String text) => jsonDecode(text);
