import 'package:flutter/material.dart';

import '../../core/risk_level.dart';

extension RiskLevelColorX on RiskLevel {
  Color get color => Color(colorValue);
}
