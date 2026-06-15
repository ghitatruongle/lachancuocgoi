import 'package:flutter/material.dart';

enum RiskLevel {
  green('An toàn', Colors.green),
  yellow('Chú ý', Colors.yellow),
  orange('Nguy cơ', Color(0xFFFFA500)),
  red('Nguy hiểm', Colors.red);

  const RiskLevel(this.vietnameseName, this.color);

  final String vietnameseName;
  final Color color;

  int get level => index;

  String get storageName => name.toUpperCase();

  bool get shouldAlert => index >= RiskLevel.orange.index;

  RiskLevel deescalate() {
    return switch (this) {
      RiskLevel.red => RiskLevel.orange,
      RiskLevel.orange => RiskLevel.yellow,
      RiskLevel.yellow => RiskLevel.green,
      RiskLevel.green => RiskLevel.green,
    };
  }

  static RiskLevel fromInt(int value) {
    return switch (value) {
      3 => RiskLevel.red,
      2 => RiskLevel.orange,
      1 => RiskLevel.yellow,
      _ => RiskLevel.green,
    };
  }

  static RiskLevel fromString(String? value) {
    final normalized = value?.trim().toUpperCase();
    return switch (normalized) {
      null || '' => RiskLevel.green,
      'RED' => RiskLevel.red,
      'ORANGE' => RiskLevel.orange,
      'YELLOW' => RiskLevel.yellow,
      'GREEN' => RiskLevel.green,
      'NGUY HIỂM' => RiskLevel.red,
      'NGUY HIEM' => RiskLevel.red,
      'NGUY CƠ' => RiskLevel.orange,
      'NGUY CO' => RiskLevel.orange,
      'CÓ NGUY CƠ' => RiskLevel.orange,
      'CO NGUY CO' => RiskLevel.orange,
      'CHÚ Ý' => RiskLevel.yellow,
      'CHU Y' => RiskLevel.yellow,
      'AN TOÀN' => RiskLevel.green,
      'AN TOAN' => RiskLevel.green,
      _ => _unknownRiskLevel(normalized),
    };
  }

  /// Conservative fallback for unrecognized risk level strings.
  /// Logs a warning and returns [RiskLevel.orange] to be safe in a
  /// security-focused app (better to over-warn than silently pass).
  static RiskLevel _unknownRiskLevel(String? original) {
    debugPrint('RiskLevel.fromString: unknown value "$original", defaulting to orange');
    return RiskLevel.orange;
  }
}
