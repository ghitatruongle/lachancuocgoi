import '../g_detection/g_flash.dart';
import '../intent/scam_intent.dart';

enum ScamStage {
  stage1Introduction(1.0),
  stage2BaitingThreat(1.5),
  stage3Urgency(2.0),
  stage4Command(3.0);

  const ScamStage(this.weightMultiplier);

  final double weightMultiplier;
}

class StateNode {
  const StateNode({
    required this.id,
    required this.description,
    required this.stage,
  });

  final String id;
  final String description;
  final ScamStage stage;
}

class Transition {
  Transition({
    required this.triggerPhrases,
    required this.targetStateId,
    this.requiredIntent,
  });

  final List<String> triggerPhrases;
  final String targetStateId;
  final ScamIntent? requiredIntent;

  late final List<Set<String>> normalizedTriggerSets = triggerPhrases
      .map((phrase) => GFlash.tokenize(phrase).toSet())
      .where((tokens) => tokens.isNotEmpty)
      .toList();
}

class ScenarioGraph {
  const ScenarioGraph({
    required this.graphId,
    required this.name,
    required this.states,
    required this.transitions,
    required this.initialStateId,
  });

  final String graphId;
  final String name;
  final Map<String, StateNode> states;
  final Map<String, List<Transition>> transitions;
  final String initialStateId;
}

/// Records a single state transition for timeline analysis.
class TransitionRecord {
  const TransitionRecord({
    required this.graphId,
    required this.fromStateId,
    required this.toStateId,
    required this.scoreAfter,
    required this.stage,
    required this.segmentIndex,
  });

  final String graphId;
  final String fromStateId;
  final String toStateId;
  final double scoreAfter;
  final ScamStage stage;
  final int segmentIndex;
}

class WfsaEngine {
  WfsaEngine(this.graphs) {
    resetSession();
  }

  final List<ScenarioGraph> graphs;
  final Map<String, double> _graphScores = <String, double>{};
  final Map<String, String> _currentSessionStates = <String, String>{};
  final Map<String, int> _segmentsSinceLastTrigger = <String, int>{};

  /// Session timeline: ordered list of all transitions across all graphs.
  final List<TransitionRecord> _transitionHistory = [];

  /// Read-only access to the transition timeline for analysis.
  List<TransitionRecord> get transitionHistory =>
      List<TransitionRecord>.unmodifiable(_transitionHistory);

  /// Monotonically increasing segment counter for timeline tracking.
  int _segmentIndex = 0;

  /// Tracks how many characters of the transcript have been analyzed.
  int _analyzedTextLength = 0;

  String? activeScenarioName;
  int? activeScenarioStage;

  void resetSession() {
    _currentSessionStates.clear();
    _graphScores.clear();
    _segmentsSinceLastTrigger.clear();
    _transitionHistory.clear();
    _segmentIndex = 0;
    _analyzedTextLength = 0;
    for (final graph in graphs) {
      _currentSessionStates[graph.graphId] = graph.initialStateId;
      _graphScores[graph.graphId] = 0;
      _segmentsSinceLastTrigger[graph.graphId] = 0;
    }
    activeScenarioName = null;
    activeScenarioStage = null;
  }

  /// Incremental analysis: only tokenize the delta portion of [fullText]
  /// that hasn't been analyzed yet.
  double analyzeIncremental(
    String fullText,
    List<IntentPrediction> intentPredictions,
  ) {
    if (fullText.length < _analyzedTextLength) {
      _analyzedTextLength = 0;
    }
    if (fullText.length <= _analyzedTextLength) {
      return currentRiskScore;
    }
    final deltaText = fullText.substring(_analyzedTextLength);
    _analyzedTextLength = fullText.length;
    return analyzeSegment(deltaText, intentPredictions);
  }

  double analyzeSegment(
    String newTranscript,
    List<IntentPrediction> intentPredictions,
  ) {
    final normalizedTokens = GFlash.tokenize(newTranscript).toSet();
    if (normalizedTokens.isEmpty) return currentRiskScore;

    _segmentIndex++;

    final dominantIntents = intentPredictions
        .where((prediction) => prediction.confidence > 0.6)
        .map((prediction) => prediction.intent)
        .toSet();

    for (final graph in graphs) {
      final graphId = graph.graphId;
      final currentScore = _graphScores[graphId] ?? 0;
      final segmentsSinceLast = _segmentsSinceLastTrigger[graphId] ?? 0;

      // --- Adaptive decay: slower at higher stages (scammer deep in scenario) ---
      if (currentScore > 0) {
        final currentStateId =
            _currentSessionStates[graphId] ?? graph.initialStateId;
        final currentState = graph.states[currentStateId];
        final currentStage = currentState?.stage ?? ScamStage.stage1Introduction;
        final baseDecay = _decayForGraph(graphId);
        final adaptiveDecay = _adaptiveDecay(baseDecay, currentStage);
        final newScore = currentScore * adaptiveDecay;
        _graphScores[graphId] = newScore < _minScoreFloor ? 0.0 : newScore;
      }
      _segmentsSinceLastTrigger[graphId] = segmentsSinceLast + 1;

      final currentStateId =
          _currentSessionStates[graphId] ?? graph.initialStateId;
      final possibleTransitions =
          graph.transitions[currentStateId] ?? const <Transition>[];

      for (final transition in possibleTransitions) {
        final hasPhraseMatch = transition.normalizedTriggerSets.any(
          (triggerTokens) =>
              triggerTokens.every((token) => normalizedTokens.contains(token)),
        );
        final requiredIntent = transition.requiredIntent;
        final hasIntentMatch =
            requiredIntent != null && dominantIntents.contains(requiredIntent);

        if (hasPhraseMatch || hasIntentMatch) {
          final fromStateId = currentStateId;
          _currentSessionStates[graphId] = transition.targetStateId;
          final targetState = graph.states[transition.targetStateId];
          if (targetState != null) {
            var scoreIncrease = 10.0 * targetState.stage.weightMultiplier;

            // --- Intent-boost: double score when TFLite intent confirms ---
            if (hasIntentMatch && hasPhraseMatch) {
              scoreIncrease *= _intentBoostFactor;
            }

            _graphScores[graphId] =
                ((_graphScores[graphId] ?? 0) + scoreIncrease)
                    .clamp(0.0, 100.0)
                    .toDouble();
            _segmentsSinceLastTrigger[graphId] = 0;

            // --- Session timeline tracking ---
            _transitionHistory.add(TransitionRecord(
              graphId: graphId,
              fromStateId: fromStateId,
              toStateId: transition.targetStateId,
              scoreAfter: _graphScores[graphId]!,
              stage: targetState.stage,
              segmentIndex: _segmentIndex,
            ));
          }
          break;
        }
      }
    }

    // --- Cross-graph correlation bonus ---
    _applyCrossGraphBonus();

    _updateActiveScenario();
    return currentRiskScore;
  }

  double get currentRiskScore {
    var maxScore = 0.0;
    for (final score in _graphScores.values) {
      if (score > maxScore) maxScore = score;
    }
    return maxScore;
  }

  /// Minimum score floor: once decay brings score below this, it resets to 0.
  static const double _minScoreFloor = 2.0;

  /// Intent boost multiplier when both phrase + intent match a transition.
  static const double _intentBoostFactor = 1.5;

  /// Cross-graph bonus per additional active graph (2+ graphs = compound scam).
  static const double _crossGraphBonusPerGraph = 5.0;

  /// Minimum score to count a graph as "active" for cross-graph correlation.
  static const double _crossGraphActiveThreshold = 10.0;

  /// Adaptive decay: at higher stages (3-4), decay is slower to preserve
  /// strong scam signals. At stage 1, decay is faster to reduce stale signals.
  double _adaptiveDecay(double baseDecay, ScamStage stage) {
    return switch (stage) {
      ScamStage.stage1Introduction => baseDecay * 0.98, // faster decay
      ScamStage.stage2BaitingThreat => baseDecay, // normal decay
      ScamStage.stage3Urgency => baseDecay * 1.003, // slower decay
      ScamStage.stage4Command => baseDecay * 1.005, // very slow decay
    };
  }

  /// If 2+ graphs are active (score > threshold), apply compound scam bonus.
  void _applyCrossGraphBonus() {
    final activeCount = _graphScores.values
        .where((s) => s >= _crossGraphActiveThreshold)
        .length;
    if (activeCount >= 2) {
      final bonus = (activeCount - 1) * _crossGraphBonusPerGraph;
      // Apply bonus to the graph with the highest score
      MapEntry<String, double>? best;
      for (final entry in _graphScores.entries) {
        if (best == null || entry.value > best.value) {
          best = entry;
        }
      }
      if (best != null && best.value > 0) {
        _graphScores[best.key] =
            (best.value + bonus).clamp(0.0, 100.0).toDouble();
      }
    }
  }

  double _decayForGraph(String graphId) {
    // High-danger scenarios: very slow decay
    if (graphId.startsWith('G_POLICE') ||
        graphId.startsWith('G_KIDNAP') ||
        graphId.startsWith('G_SEXTORT') ||
        graphId.startsWith('G_BANK')) {
      return 0.995;
    }
    // Medium-danger scenarios
    if (graphId.startsWith('G_TECH') ||
        graphId.startsWith('G_HOSPITAL') ||
        graphId.startsWith('G_VNEID') ||
        graphId.startsWith('G_TELECOM') ||
        graphId.startsWith('G_CEO') ||
        graphId.startsWith('G_DEEPFAKE') ||
        graphId.startsWith('G_CREDIT') ||
        graphId.startsWith('G_CRYPTO')) {
      return 0.99;
    }
    // Low-danger / generic scenarios
    if (graphId.startsWith('G_CHARITY') ||
        graphId.startsWith('G_GENERIC') ||
        graphId.startsWith('G_GAMBLE') ||
        graphId.startsWith('G_ECOMMERCE')) {
      return 0.97;
    }
    return 0.98;
  }

  void _updateActiveScenario() {
    MapEntry<String, double>? bestEntry;
    for (final entry in _graphScores.entries) {
      if (bestEntry == null || entry.value > bestEntry.value) {
        bestEntry = entry;
      }
    }

    if (bestEntry == null || bestEntry.value <= 0) {
      activeScenarioName = null;
      activeScenarioStage = null;
      return;
    }

    ScenarioGraph? graph;
    for (final candidate in graphs) {
      if (candidate.graphId == bestEntry.key) {
        graph = candidate;
        break;
      }
    }
    activeScenarioName = graph?.name;
    final currentStateId = _currentSessionStates[bestEntry.key];
    final stateNode = graph?.states[currentStateId];
    activeScenarioStage = stateNode == null ? null : stateNode.stage.index + 1;
  }
}
