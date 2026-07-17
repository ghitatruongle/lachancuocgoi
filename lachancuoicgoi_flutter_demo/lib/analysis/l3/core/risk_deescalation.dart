import '../../../core/risk_level.dart';

// ─── Risk De-escalation Machine ────────────────────────────────────────
//
// Tracks the maximum risk level seen in a session and implements a
// de-escalation policy: 3 consecutive green results de-escalate from
// yellow (but not from orange/red during active scam).
//
// Extracted from [L3Analyzer] to make the de-escalation logic testable
// in isolation and to remove side effects from the response parsing path.

class RiskDeescalationMachine {
  RiskLevel _maxRiskLevel = RiskLevel.green;
  int _consecutiveGreenCount = 0;

  /// The highest risk level observed in this session.
  RiskLevel get maxRiskLevel => _maxRiskLevel;

  /// Number of consecutive green results since the last non-green.
  int get consecutiveGreenCount => _consecutiveGreenCount;

  /// Processes a raw [riskLevel] from the LLM response and returns the
  /// final risk level after applying de-escalation rules.
  ///
  /// The returned level may differ from the input if de-escalation applies.
  RiskLevel process(RiskLevel riskLevel) {
    if (riskLevel == RiskLevel.green) {
      _consecutiveGreenCount++;
      // Only de-escalate from yellow, not from orange/red during active scam
      if (_consecutiveGreenCount >= 3 &&
          _maxRiskLevel.index > RiskLevel.green.index &&
          _maxRiskLevel.index <= RiskLevel.yellow.index) {
        _maxRiskLevel = _maxRiskLevel.deescalate();
        _consecutiveGreenCount = 0;
      }
      return _maxRiskLevel;
    } else {
      _consecutiveGreenCount = 0;
      if (riskLevel.index > _maxRiskLevel.index) {
        _maxRiskLevel = riskLevel;
      }
      return riskLevel;
    }
  }

  /// Resets all de-escalation state for a new session.
  void reset() {
    _maxRiskLevel = RiskLevel.green;
    _consecutiveGreenCount = 0;
  }
}
