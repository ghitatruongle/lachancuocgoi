import '../intent/scam_intent.dart';
import 'wfsa_engine.dart';

part 'scam_graph_authority_scenarios.dart';
part 'scam_graph_social_scenarios.dart';
part 'scam_graph_financial_scenarios.dart';
part 'scam_graph_investment_scenarios.dart';
part 'scam_graph_romance_scenarios.dart';

/// Builds the default set of [ScenarioGraph] definitions used by the WFSA
/// engine.
///
/// The 24+ scam scenarios are split across five part-files by category:
/// - [scam_graph_authority_scenarios.dart] — police, VNeID, telecom, tech
///   support, hospital (5 scenarios).
/// - [scam_graph_social_scenarios.dart] — kidnap, CEO, deepfake, romance,
///   sextortion, charity, investment, job, lottery, gambling, visa
///   (11 scenarios).
/// - [scam_graph_financial_scenarios.dart] — bank, shipper, subscription,
///   black credit, recovery, generic, ecommerce, crypto (8 scenarios).
/// - [scam_graph_investment_scenarios.dart] — Wave 6: forex, crypto,
///   MLM, job scam, stock, ICO, skincare MLM, Ponzi (8 scenarios).
/// - [scam_graph_romance_scenarios.dart] — Wave 6: dating, gift card,
///   investment together, emergency, passport, customs (6 scenarios).
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
      initialStateId: states.first.id,
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
