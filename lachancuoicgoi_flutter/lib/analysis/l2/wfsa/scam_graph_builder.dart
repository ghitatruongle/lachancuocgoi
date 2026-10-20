import '../intent/scam_intent.dart';
import 'wfsa_engine.dart';

part 'scam_graph_authority_scenarios.dart';
part 'scam_graph_social_scenarios.dart';
part 'scam_graph_financial_scenarios.dart';
part 'scam_graph_investment_scenarios.dart';
part 'scam_graph_romance_scenarios.dart';

class ScamGraphBuilder {
  ScamGraphBuilder._();

  static List<ScenarioGraph> buildDefaultGraphs() {
    return <ScenarioGraph>[
      ..._authorityScenarios(),
      ..._socialScenarios(),
      ..._financialScenarios(),
      ..._investmentScenarios(),
      ..._romanceScenarios(),
    ];
  }

  static ScenarioGraph _linear({
    required String id,
    required String name,
    required List<_StateSpec> states,
    required List<_TriggerSpec> triggers,
  }) {
    final edges = <_EdgeSpec>[];
    for (var i = 0; i < triggers.length; i++) {
      edges.add(_e(i, i + 1, triggers[i].phrases, triggers[i].requiredIntent));
    }
    return _build(id, name, states, edges);
  }

  static ScenarioGraph _build(
    String id,
    String name,
    List<_StateSpec> stateSpecs,
    List<_EdgeSpec> edgeSpecs,
  ) {
    final states = <StateNode>[
      for (final state in stateSpecs)
        StateNode(
          id: state.id,
          description: state.description,
          stage: state.stage,
        ),
    ];
    final transitions = <String, List<Transition>>{};
    for (final edge in edgeSpecs) {
      transitions
          .putIfAbsent(states[edge.from].id, () => <Transition>[])
          .add(
            Transition(
              triggerPhrases: edge.phrases,
              targetStateId: states[edge.to].id,
              requiredIntent: edge.requiredIntent,
            ),
          );
    }
    return ScenarioGraph(
      graphId: id,
      name: name,
      states: <String, StateNode>{for (final state in states) state.id: state},
      transitions: transitions,
      initialStateId: states.isNotEmpty
          ? states.first.id
          : throw ArgumentError(
              'Cannot build scam graph "$id" with empty states list.',
            ),
    );
  }

  static _StateSpec _s(String id, String description, ScamStage stage) {
    return _StateSpec(id, description, stage);
  }

  static _TriggerSpec _tr(List<String> phrases, [ScamIntent? intent]) {
    return _TriggerSpec(phrases, intent);
  }

  static _EdgeSpec _e(
    int from,
    int to,
    List<String> phrases, [
    ScamIntent? intent,
  ]) {
    return _EdgeSpec(from, to, phrases, intent);
  }
}

class _StateSpec {
  const _StateSpec(this.id, this.description, this.stage);

  final String id;
  final String description;
  final ScamStage stage;
}

class _TriggerSpec {
  const _TriggerSpec(this.phrases, this.requiredIntent);

  final List<String> phrases;
  final ScamIntent? requiredIntent;
}

class _EdgeSpec {
  const _EdgeSpec(this.from, this.to, this.phrases, this.requiredIntent);

  final int from;
  final int to;
  final List<String> phrases;
  final ScamIntent? requiredIntent;
}
