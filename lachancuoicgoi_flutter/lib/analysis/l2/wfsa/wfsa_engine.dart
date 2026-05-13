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

class WfsaEngine {
  WfsaEngine(this.graphs) {
    resetSession();
  }

  static const int segmentCountThreshold = 3;

  final List<ScenarioGraph> graphs;
  final Map<String, double> _graphScores = <String, double>{};
  final Map<String, String> _currentSessionStates = <String, String>{};
  final Map<String, int> _segmentsSinceLastTrigger = <String, int>{};

  String? activeScenarioName;
  int? activeScenarioStage;

  void resetSession() {
    _currentSessionStates.clear();
    _graphScores.clear();
    _segmentsSinceLastTrigger.clear();
    for (final graph in graphs) {
      _currentSessionStates[graph.graphId] = graph.initialStateId;
      _graphScores[graph.graphId] = 0;
      _segmentsSinceLastTrigger[graph.graphId] = 0;
    }
    activeScenarioName = null;
    activeScenarioStage = null;
  }

  double analyzeSegment(
    String newTranscript,
    List<IntentPrediction> intentPredictions,
  ) {
    final normalizedTokens = GFlash.tokenize(newTranscript).toSet();
    if (normalizedTokens.isEmpty) return currentRiskScore;

    final dominantIntents = intentPredictions
        .where((prediction) => prediction.confidence > 0.6)
        .map((prediction) => prediction.intent)
        .toSet();

    for (final graph in graphs) {
      final graphId = graph.graphId;
      final currentScore = _graphScores[graphId] ?? 0;
      final segmentsSinceLast = _segmentsSinceLastTrigger[graphId] ?? 0;

      if (currentScore > 0) {
        final baseDecay = _decayForGraph(graphId);
        final effectiveDecay = segmentsSinceLast >= segmentCountThreshold
            ? baseDecay * 0.85
            : baseDecay;
        final newScore = currentScore * effectiveDecay;
        _graphScores[graphId] = newScore < 1.0 ? 0 : newScore;
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
          _currentSessionStates[graphId] = transition.targetStateId;
          final targetState = graph.states[transition.targetStateId];
          if (targetState != null) {
            final scoreIncrease = 10.0 * targetState.stage.weightMultiplier;
            _graphScores[graphId] =
                ((_graphScores[graphId] ?? 0) + scoreIncrease)
                    .clamp(0.0, 100.0)
                    .toDouble();
            _segmentsSinceLastTrigger[graphId] = 0;
          }
          break;
        }
      }
    }

    _updateActiveScenario();
    return currentRiskScore;
  }

  double get currentRiskScore {
    var maxScore = 0.0;
    for (final score in _graphScores.values) {
      if (score > maxScore) maxScore = score;
    }
    // Normalize score to 0-100 range for consistent risk level calculation
    return (maxScore / 100.0).clamp(0.0, 1.0) * 100.0;
  }

  double _decayForGraph(String graphId) {
    if (graphId.startsWith('G_POLICE') ||
        graphId.startsWith('G_KIDNAP') ||
        graphId.startsWith('G_SEXTORT')) {
      return 0.95;
    }
    if (graphId.startsWith('G_CHARITY') ||
        graphId.startsWith('G_GENERIC') ||
        graphId.startsWith('G_GAMBLE')) {
      return 0.80;
    }
    return 0.90;
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
