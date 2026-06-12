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
    /**
     * [A2] Pre-tokenized trigger phrases using GFlash for consistent matching.
     * Lazy initialized on first access
     */
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
    
    // [C1] Per-graph scoring thay vì global accumulation
    private val graphScores = mutableMapOf<String, Double>()
    private val currentSessionStates = mutableMapOf<String, String>()

    // Decay: mỗi segment, score cũ nhân với decayFactor (< 1.0) để giảm ảnh hưởng trigger cũ
    private val segmentCountThreshold = 3  // Sau 3 segment không có trigger mới, bắt đầu decay nhanh hơn
    private val perGraphSegmentsSinceLastTrigger = mutableMapOf<String, Int>()

    // [C1] Track active scenario for UI reporting
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

    /**
     * [C2] Adaptive decay — kịch bản nguy hiểm decay chậm hơn.
     */
    private fun getDecayForGraph(graphId: String): Double {
        return when {
            graphId.startsWith("G_POLICE") || graphId.startsWith("G_KIDNAP") || 
            graphId.startsWith("G_SEXTORT") -> 0.95 // Slow decay cho kịch bản nguy hiểm nhất
            graphId.startsWith("G_CHARITY") || graphId.startsWith("G_GENERIC") || 
            graphId.startsWith("G_GAMBLE") -> 0.80 // Fast decay cho kịch bản ít nguy hiểm
            else -> 0.90 // Default
        }
    }

    /**
     * [A2+C1+C2] Phân tích đoạn văn bản mới dựa trên đồ thị trạng thái và ý định (Intents).
     * 
     * Cải tiến:
     * - A2: Dùng GFlash tokenization thay vì raw string contains
     * - C1: Per-graph scoring (MAX) thay vì global accumulation (SUM)
     * - C2: Adaptive decay theo mức nguy hiểm của scenario
     *
     * @param newTranscript Đoạn văn bản mới được thêm vào từ stream.
     * @param intentPredictions Các ý định nhận diện được từ TFLite (GĐ2).
     * @return Điểm rủi ro tích lũy hiện tại (Risk Score) = MAX of all graphs.
     */
    fun analyzeSegment(newTranscript: String, intentPredictions: List<IntentPrediction>): Double {
        // [A2] Dùng GFlash tokenization thay vì raw lowercase
        val normalizedTokens = GFlash.tokenize(newTranscript).toSet()
        if (normalizedTokens.isEmpty()) {
            return getCurrentRiskScore()
        }

        // Trích xuất intent có độ tin cậy cao (chuẩn bị cho GĐ3 tích hợp)
        val dominantIntents = intentPredictions.filter { it.confidence > 0.6f }.map { it.intent }

        // [C1] Per-graph decay + scoring
        graphs.forEach { graph ->
            val graphId = graph.graphId
            val currentScore = graphScores[graphId] ?: 0.0
            val segmentsSinceLastTrigger = perGraphSegmentsSinceLastTrigger[graphId] ?: 0

            // Decay score cũ trước khi xử lý segment mới
            if (currentScore > 0) {
                val baseDecay = getDecayForGraph(graphId)
                val effectiveDecay = if (segmentsSinceLastTrigger >= segmentCountThreshold) {
                    baseDecay * 0.85  // Decay nhanh hơn khi lâu không có trigger
                } else {
                    baseDecay
                }
                val newScore = currentScore * effectiveDecay
                graphScores[graphId] = if (newScore < 1.0) 0.0 else newScore
            }
            perGraphSegmentsSinceLastTrigger[graphId] = segmentsSinceLastTrigger + 1

            // Check transitions
            val currentStateId = currentSessionStates[graphId] ?: graph.initialStateId
            val possibleTransitions = graph.transitions[currentStateId] ?: emptyList()

            for (transition in possibleTransitions) {
                // [A2] Dùng pre-tokenized trigger sets thay vì raw contains
                val hasPhraseMatch = transition.normalizedTriggerSets.any { triggerTokens ->
                    triggerTokens.all { it in normalizedTokens }
                }
                
                val hasIntentMatch = transition.requiredIntent != null && dominantIntents.contains(transition.requiredIntent)

                // Điều kiện chuyển trạng thái: Có từ khóa HOẶC đúng loại ý định (Intent)
                if (hasPhraseMatch || hasIntentMatch) {
                    currentSessionStates[graphId] = transition.targetStateId
                    val targetState = graph.states[transition.targetStateId]
                    
                    if (targetState != null) {
                        val triggerType = if (hasIntentMatch) "Intent:${transition.requiredIntent}" else "Phrase"
                        Log.w(TAG, "WFSA Transition [$triggerType]: $currentStateId -> ${targetState.id} (Stage: ${targetState.stage.name}) [${graph.name}]")
                        val scoreIncrease = 10.0 * targetState.stage.weightMultiplier
                        graphScores[graphId] = ((graphScores[graphId] ?: 0.0) + scoreIncrease).coerceAtMost(100.0)
                        perGraphSegmentsSinceLastTrigger[graphId] = 0  // Reset counter khi có trigger mới
                    }
                    break
                }
            }
        }

        // [C1] Update active scenario info for UI
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
    
    // [C1] MAX of all graph scores thay vì single accumulated score
    fun getCurrentRiskScore(): Double = graphScores.values.maxOrNull() ?: 0.0
}
