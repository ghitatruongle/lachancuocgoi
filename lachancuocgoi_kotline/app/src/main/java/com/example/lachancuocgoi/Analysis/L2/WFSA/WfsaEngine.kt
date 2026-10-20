package com.example.lachancuocgoi.Analysis.L2.WFSA

import android.util.Log
import com.example.lachancuocgoi.Analysis.L2.GDetection.GFlash
import com.example.lachancuocgoi.Analysis.L2.Intent.IntentPrediction
import com.example.lachancuocgoi.Analysis.L2.Intent.ScamIntent

enum class ScamStage(val weightMultiplier: Double) {
    STAGE_1_INTRODUCTION(1.0),
    STAGE_2_BAITING_THREAT(1.5),
    STAGE_3_URGENCY(2.0),
    STAGE_4_COMMAND(3.0)
}

data class StateNode(
    val id: String,
    val description: String,
    val stage: ScamStage
)

data class Transition(
    val triggerPhrases: List<String>,
    val targetStateId: String,
    val requiredIntent: ScamIntent? = null
) {

    val normalizedTriggerSets: List<Set<String>> by lazy {
        triggerPhrases.map { phrase ->
            GFlash.tokenize(phrase).toSet()
        }.filter { it.isNotEmpty() }
    }
}

data class ScenarioGraph(
    val graphId: String,
    val name: String,
    val states: Map<String, StateNode>,
    val transitions: Map<String, List<Transition>>,
    val initialStateId: String
)

class WfsaEngine(private val graphs: List<ScenarioGraph>) {
    private val TAG = "WfsaEngine"

    private val graphScores = mutableMapOf<String, Double>()
    private val currentSessionStates = mutableMapOf<String, String>()

    private val segmentCountThreshold = 3
    private val perGraphSegmentsSinceLastTrigger = mutableMapOf<String, Int>()

    var activeScenarioName: String? = null
        private set
    var activeScenarioStage: Int? = null
        private set

    init {
        resetSession()
    }

    fun resetSession() {
        currentSessionStates.clear()
        graphScores.clear()
        perGraphSegmentsSinceLastTrigger.clear()
        graphs.forEach { graph ->
            currentSessionStates[graph.graphId] = graph.initialStateId
            graphScores[graph.graphId] = 0.0
            perGraphSegmentsSinceLastTrigger[graph.graphId] = 0
        }
        activeScenarioName = null
        activeScenarioStage = null
        Log.i(TAG, "WFSA Session Reset. Tracking ${graphs.size} scenarios.")
    }

    private fun getDecayForGraph(graphId: String): Double {
        return when {
            graphId.startsWith("G_POLICE") || graphId.startsWith("G_KIDNAP") ||
            graphId.startsWith("G_SEXTORT") -> 0.95
            graphId.startsWith("G_CHARITY") || graphId.startsWith("G_GENERIC") ||
            graphId.startsWith("G_GAMBLE") -> 0.80
            else -> 0.90
        }
    }

    fun analyzeSegment(newTranscript: String, intentPredictions: List<IntentPrediction>): Double {

        val normalizedTokens = GFlash.tokenize(newTranscript).toSet()
        if (normalizedTokens.isEmpty()) {
            return getCurrentRiskScore()
        }

        val dominantIntents = intentPredictions.filter { it.confidence > 0.6f }.map { it.intent }

        graphs.forEach { graph ->
            val graphId = graph.graphId
            val currentScore = graphScores[graphId] ?: 0.0
            val segmentsSinceLastTrigger = perGraphSegmentsSinceLastTrigger[graphId] ?: 0

            if (currentScore > 0) {
                val baseDecay = getDecayForGraph(graphId)
                val effectiveDecay = if (segmentsSinceLastTrigger >= segmentCountThreshold) {
                    baseDecay * 0.85
                } else {
                    baseDecay
                }
                val newScore = currentScore * effectiveDecay
                graphScores[graphId] = if (newScore < 1.0) 0.0 else newScore
            }
            perGraphSegmentsSinceLastTrigger[graphId] = segmentsSinceLastTrigger + 1

            val currentStateId = currentSessionStates[graphId] ?: graph.initialStateId
            val possibleTransitions = graph.transitions[currentStateId] ?: emptyList()

            for (transition in possibleTransitions) {

                val hasPhraseMatch = transition.normalizedTriggerSets.any { triggerTokens ->
                    triggerTokens.all { it in normalizedTokens }
                }

                val hasIntentMatch = transition.requiredIntent != null && dominantIntents.contains(transition.requiredIntent)

                if (hasPhraseMatch || hasIntentMatch) {
                    currentSessionStates[graphId] = transition.targetStateId
                    val targetState = graph.states[transition.targetStateId]

                    if (targetState != null) {
                        val triggerType = if (hasIntentMatch) "Intent:${transition.requiredIntent}" else "Phrase"
                        Log.w(TAG, "WFSA Transition [$triggerType]: $currentStateId -> ${targetState.id} (Stage: ${targetState.stage.name}) [${graph.name}]")
                        val scoreIncrease = 10.0 * targetState.stage.weightMultiplier
                        graphScores[graphId] = ((graphScores[graphId] ?: 0.0) + scoreIncrease).coerceAtMost(100.0)
                        perGraphSegmentsSinceLastTrigger[graphId] = 0
                    }
                    break
                }
            }
        }

        val bestGraph = graphScores.maxByOrNull { it.value }
        if (bestGraph != null && bestGraph.value > 0) {
            val graph = graphs.find { it.graphId == bestGraph.key }
            activeScenarioName = graph?.name
            val currentState = currentSessionStates[bestGraph.key]
            val stateNode = graph?.states?.get(currentState)
            activeScenarioStage = stateNode?.stage?.ordinal?.plus(1)
        } else {
            activeScenarioName = null
            activeScenarioStage = null
        }

        val maxScore = getCurrentRiskScore()
        if (maxScore > 0) {
            Log.d(TAG, "Current Max Risk Score: $maxScore (from ${bestGraph?.key ?: "none"})")
        }

        return maxScore
    }

    fun getCurrentRiskScore(): Double = graphScores.values.maxOrNull() ?: 0.0
}
