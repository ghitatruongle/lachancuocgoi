import '../../../core/risk_level.dart';

class RiskDeescalationMachine {
  RiskLevel _maxRiskLevel = RiskLevel.green;
  int _consecutiveGreenCount = 0;

  RiskLevel get maxRiskLevel => _maxRiskLevel;

  int get consecutiveGreenCount => _consecutiveGreenCount;

  RiskLevel process(RiskLevel riskLevel) {
    if (riskLevel == RiskLevel.green) {
      _consecutiveGreenCount++;

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

  void reset() {
    _maxRiskLevel = RiskLevel.green;
    _consecutiveGreenCount = 0;
  }
}
