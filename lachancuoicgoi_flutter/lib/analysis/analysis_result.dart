import '../core/risk_level.dart';
import 'analysis_level.dart';

class KeywordMatch {
  const KeywordMatch({
    required this.keyword,
    required this.level,
    required this.category,
    this.startIndex = -1,
    this.endIndex = -1,
    this.isFuzzy = false,
  });

  final String keyword;
  final RiskLevel level;
  final String category;
  final int startIndex;
  final int endIndex;
  final bool isFuzzy;

  KeywordMatch copyWith({
    String? keyword,
    RiskLevel? level,
    String? category,
    int? startIndex,
    int? endIndex,
    bool? isFuzzy,
  }) {
    return KeywordMatch(
      keyword: keyword ?? this.keyword,
      level: level ?? this.level,
      category: category ?? this.category,
      startIndex: startIndex ?? this.startIndex,
      endIndex: endIndex ?? this.endIndex,
      isFuzzy: isFuzzy ?? this.isFuzzy,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'keyword': keyword,
      'level': level.storageName,
      'category': category,
      'startIndex': startIndex,
      'endIndex': endIndex,
      'isFuzzy': isFuzzy,
    };
  }

  factory KeywordMatch.fromJson(Map<String, Object?> json) {
    return KeywordMatch(
      keyword: json['keyword'] as String? ?? '',
      level: RiskLevel.fromString(json['level'] as String?),
      category: json['category'] as String? ?? 'Unknown',
      startIndex: (json['startIndex'] as num?)?.toInt() ?? -1,
      endIndex: (json['endIndex'] as num?)?.toInt() ?? -1,
      isFuzzy: json['isFuzzy'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is KeywordMatch &&
        other.keyword == keyword &&
        other.level == level &&
        other.category == category &&
        other.startIndex == startIndex &&
        other.endIndex == endIndex &&
        other.isFuzzy == isFuzzy;
  }

  @override
  int get hashCode => Object.hash(
        keyword,
        level,
        category,
        startIndex,
        endIndex,
        isFuzzy,
      );
}

class AnalysisResult {
  const AnalysisResult({
    required this.overallRiskLevel,
    required this.matches,
    this.reason,
    this.analysisLevel = AnalysisLevel.l1,
    this.alertEnabled = false,
    this.confidence = -1,
    this.modelName,
    this.isError = false,
  });

  final RiskLevel overallRiskLevel;
  final List<KeywordMatch> matches;
  final String? reason;
  final AnalysisLevel analysisLevel;
  final bool alertEnabled;
  final double confidence;
  final String? modelName;
  final bool isError;

  AnalysisResult copyWith({
    RiskLevel? overallRiskLevel,
    List<KeywordMatch>? matches,
    String? reason,
    AnalysisLevel? analysisLevel,
    bool? alertEnabled,
    double? confidence,
    String? modelName,
    bool? isError,
  }) {
    return AnalysisResult(
      overallRiskLevel: overallRiskLevel ?? this.overallRiskLevel,
      matches: matches ?? this.matches,
      reason: reason ?? this.reason,
      analysisLevel: analysisLevel ?? this.analysisLevel,
      alertEnabled: alertEnabled ?? this.alertEnabled,
      confidence: confidence ?? this.confidence,
      modelName: modelName ?? this.modelName,
      isError: isError ?? this.isError,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'overallRiskLevel': overallRiskLevel.storageName,
      'matches': matches.map((match) => match.toJson()).toList(),
      'reason': reason,
      'analysisLevel': analysisLevel.id,
      'alertEnabled': alertEnabled,
      'confidence': confidence,
      'modelName': modelName,
      'isError': isError,
    };
  }

  factory AnalysisResult.fromJson(Map<String, Object?> json) {
    final rawMatches = json['matches'];
    return AnalysisResult(
      overallRiskLevel:
          RiskLevel.fromString(json['overallRiskLevel'] as String?),
      matches: rawMatches is List
          ? rawMatches
              .whereType<Map>()
              .map((match) =>
                  KeywordMatch.fromJson(match.cast<String, Object?>()))
              .toList()
          : const [],
      reason: json['reason'] as String?,
      analysisLevel: AnalysisLevel.fromId(json['analysisLevel'] as String?),
      alertEnabled: json['alertEnabled'] as bool? ?? false,
      confidence: (json['confidence'] as num?)?.toDouble() ?? -1,
      modelName: json['modelName'] as String?,
      isError: json['isError'] as bool? ?? false,
    );
  }
}
