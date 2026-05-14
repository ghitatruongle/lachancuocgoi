import 'g_flash.dart';
import 'g_models.dart';

class ScenarioMatcher {
  ScenarioMatcher(this.masterModel);

  final RiskScenariosMaster masterModel;
  final Map<String, Set<String>> _tokenToScenarios = <String, Set<String>>{};
  final Map<String, _ScenarioInfo> _scenarioData = <String, _ScenarioInfo>{};
  bool _initialized = false;

  void _ensureInitialized() {
    if (_initialized) return;

    for (final scenario in masterModel.scenarios ?? const <MasterScenario>[]) {
      final triggerPhrasesTokenized =
          (scenario.triggerPhrases ?? const <String>[])
              .map(GFlash.tokenize)
              .where((tokens) => tokens.isNotEmpty)
              .toList();
      final contextPhrasesTokenized =
          (scenario.requiredContext ?? const <String>[])
              .map(GFlash.tokenize)
              .where((tokens) => tokens.isNotEmpty)
              .toList();

      final triggerPhrasesTokens = triggerPhrasesTokenized
          .map((tokens) => tokens.toSet())
          .toList();
      final contextPhrasesTokens = contextPhrasesTokenized
          .map((tokens) => tokens.toSet())
          .toList();
      final triggerBigrams = triggerPhrasesTokenized
          .map(_toBigrams)
          .toList(growable: false);
      final contextBigrams = contextPhrasesTokenized
          .map(_toBigrams)
          .toList(growable: false);
      final allPhraseSizes = (triggerPhrasesTokens + contextPhrasesTokens).map(
        (set) => set.length,
      );
      final avgPhraseLength = allPhraseSizes.isNotEmpty
          ? allPhraseSizes.reduce((a, b) => a + b) / allPhraseSizes.length
          : 1.0;

      _scenarioData[scenario.id] = _ScenarioInfo(
        name: scenario.name,
        category: scenario.category,
        level: scenario.riskLevel,
        triggerPhrases: triggerPhrasesTokens,
        contextPhrases: contextPhrasesTokens,
        triggerBigrams: triggerBigrams,
        contextBigrams: contextBigrams,
        hints: scenario.l2AnalysisHints,
        hasRequiredContext: contextPhrasesTokens.isNotEmpty,
        avgPhraseLength: avgPhraseLength,
      );

      for (final token
          in (triggerPhrasesTokenized + contextPhrasesTokenized).expand(
            (tokens) => tokens,
          )) {
        _tokenToScenarios.putIfAbsent(token, () => <String>{}).add(scenario.id);
      }
    }

    _initialized = true;
  }

  ScenarioMatch? match(List<String> transcriptTokens) {
    _ensureInitialized();
    if (transcriptTokens.isEmpty) return null;

    final transcriptSet = transcriptTokens.toSet();
    final transcriptBigrams = _toBigrams(transcriptTokens);
    final candidateCounts = <String, int>{};

    for (final token in transcriptSet) {
      for (final scenarioId in _tokenToScenarios[token] ?? const <String>{}) {
        candidateCounts[scenarioId] = (candidateCounts[scenarioId] ?? 0) + 1;
      }
    }

    final candidateScenarios = candidateCounts.entries
        .where((entry) => entry.value >= 2)
        .map((entry) => entry.key);
    ScenarioMatch? bestMatch;
    var maxScore = 0.0;

    for (final scenarioId in candidateScenarios) {
      final info = _scenarioData[scenarioId];
      if (info == null) continue;

      final bestTrigger = _findBestPhraseMatchWithBigram(
        transcriptSet,
        transcriptBigrams,
        info.triggerPhrases,
        info.triggerBigrams,
      );
      final bestContext = _findBestPhraseMatchWithBigram(
        transcriptSet,
        transcriptBigrams,
        info.contextPhrases,
        info.contextBigrams,
      );

      if (info.hasRequiredContext && bestContext.score <= 0) continue;

      final triggerPhraseSize = bestTrigger.phraseSize > 0
          ? bestTrigger.phraseSize.toDouble()
          : _minPhraseSize(info.triggerPhrases);
      final contextPhraseSize = bestContext.phraseSize > 0
          ? bestContext.phraseSize.toDouble()
          : _minPhraseSize(info.contextPhrases);
      final maxPossibleWeight = (triggerPhraseSize * 2.0) + contextPhraseSize;
      if (maxPossibleWeight <= 0) continue;

      final currentWeight = (bestTrigger.score * 2.0) + bestContext.score;
      var score = (currentWeight / maxPossibleWeight).clamp(0.0, 1.0);
      final hints = info.hints;
      if (hints != null && score > 0.3) {
        score = _applyHintBonus(score, hints);
      }

      final dynamicThreshold = switch (info.avgPhraseLength) {
        >= 4.0 => 0.35,
        >= 3.0 => 0.42,
        _ => 0.55,
      };
      if (score > dynamicThreshold && score > maxScore) {
        maxScore = score;
        bestMatch = ScenarioMatch(
          scenarioId: _javaStringHash(scenarioId),
          situationName: info.name,
          similarityScore: score,
          group: info.category,
          level: info.level,
        );
      }
    }

    return bestMatch;
  }

  static Set<String> _toBigrams(List<String> tokens) {
    final result = <String>{};
    for (var i = 0; i < tokens.length - 1; i++) {
      result.add('${tokens[i]} ${tokens[i + 1]}');
    }
    return result;
  }

  static double _minPhraseSize(List<Set<String>> phrases) {
    if (phrases.isEmpty) return 0;
    return phrases
        .map((phrase) => phrase.length)
        .reduce((a, b) => a < b ? a : b)
        .toDouble();
  }

  static _PhraseMatch _findBestPhraseMatchWithBigram(
    Set<String> transcriptSet,
    Set<String> transcriptBigrams,
    List<Set<String>> phrases,
    List<Set<String>> phraseBigrams,
  ) {
    if (phrases.isEmpty) return const _PhraseMatch(0, 0);

    var bestScore = 0.0;
    var bestPhraseSize = 0;

    for (var idx = 0; idx < phrases.length; idx++) {
      final phrase = phrases[idx];
      if (phrase.isEmpty) continue;

      final unigramMatched = transcriptSet.intersection(phrase).length;
      final unigramRatio = unigramMatched / phrase.length;
      final effectiveUnigramRatio = phrase.length >= 3 && unigramRatio >= 0.75
          ? (unigramRatio * 1.15).clamp(0.0, 1.0)
          : unigramRatio;

      final bigrams = idx < phraseBigrams.length
          ? phraseBigrams[idx]
          : const <String>{};
      final bigramScore = bigrams.isNotEmpty
          ? transcriptBigrams.intersection(bigrams).length / bigrams.length
          : effectiveUnigramRatio;
      final combinedScore = effectiveUnigramRatio * 0.7 + bigramScore * 0.3;

      if (combinedScore > bestScore) {
        bestScore = combinedScore;
        bestPhraseSize = phrase.length;
      }
    }

    return _PhraseMatch(bestScore * bestPhraseSize, bestPhraseSize);
  }

  static double _applyHintBonus(double baseScore, L2AnalysisHints hints) {
    var bonus = 0.0;
    if (hints.authorityClaim == true) bonus += 0.05;
    if (hints.financialRequest == true) bonus += 0.05;
    switch (hints.urgencyLevel?.toLowerCase()) {
      case 'critical':
        bonus += 0.08;
      case 'high':
        bonus += 0.05;
      case 'medium':
        bonus += 0.02;
    }
    return (baseScore + bonus).clamp(0.0, 1.0);
  }

  static int _javaStringHash(String value) {
    var hash = 0;
    for (final codeUnit in value.codeUnits) {
      hash = (31 * hash + codeUnit) & 0xFFFFFFFF;
    }
    return hash >= 0x80000000 ? hash - 0x100000000 : hash;
  }
}

class _ScenarioInfo {
  const _ScenarioInfo({
    required this.name,
    required this.category,
    required this.level,
    required this.triggerPhrases,
    required this.contextPhrases,
    required this.triggerBigrams,
    required this.contextBigrams,
    required this.hints,
    required this.hasRequiredContext,
    required this.avgPhraseLength,
  });

  final String name;
  final String? category;
  final int level;
  final List<Set<String>> triggerPhrases;
  final List<Set<String>> contextPhrases;
  final List<Set<String>> triggerBigrams;
  final List<Set<String>> contextBigrams;
  final L2AnalysisHints? hints;
  final bool hasRequiredContext;
  final double avgPhraseLength;
}

class _PhraseMatch {
  const _PhraseMatch(this.score, this.phraseSize);

  final double score;
  final int phraseSize;
}
