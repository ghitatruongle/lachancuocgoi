import 'dart:developer' as developer;

enum RiskLevel {
  green('An toàn', 0xFF4CAF50),
  yellow('Chú ý', 0xFFFFEB3B),
  orange('Nguy cơ', 0xFFFFA500),
  red('Nguy hiểm', 0xFFF44336);

  const RiskLevel(this.vietnameseName, this.colorValue);

  final String vietnameseName;

  final int colorValue;

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

  static RiskLevel _unknownRiskLevel(String? original) {
    developer.log(
      'RiskLevel.fromString: unknown value "$original", defaulting to orange',
    );
    return RiskLevel.orange;
  }
}
