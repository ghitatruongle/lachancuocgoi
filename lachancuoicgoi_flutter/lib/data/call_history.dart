import 'dart:convert';

import 'alert_history_entry.dart';

class CallHistory {
  const CallHistory({
    this.id = 0,
    required this.dateTime,
    required this.riskLevel,
    required this.summary,
    required this.duration,
    required this.flagCount,
    required this.transcript,
    this.audioPath,
    this.analysisResult,
    this.analysisType,
    this.alertHistory,
  });

  final int id;
  final String dateTime;
  final String riskLevel;
  final String summary;
  final String duration;
  final int flagCount;
  final String transcript;
  final String? audioPath;
  final String? analysisResult;
  final String? analysisType;
  final String? alertHistory;

  CallHistory copyWith({
    int? id,
    String? dateTime,
    String? riskLevel,
    String? summary,
    String? duration,
    int? flagCount,
    String? transcript,
    String? audioPath,
    String? analysisResult,
    String? analysisType,
    String? alertHistory,
  }) {
    return CallHistory(
      id: id ?? this.id,
      dateTime: dateTime ?? this.dateTime,
      riskLevel: riskLevel ?? this.riskLevel,
      summary: summary ?? this.summary,
      duration: duration ?? this.duration,
      flagCount: flagCount ?? this.flagCount,
      transcript: transcript ?? this.transcript,
      audioPath: audioPath ?? this.audioPath,
      analysisResult: analysisResult ?? this.analysisResult,
      analysisType: analysisType ?? this.analysisType,
      alertHistory: alertHistory ?? this.alertHistory,
    );
  }

  List<AlertHistoryEntry> getAlertHistoryList() {
    if (alertHistory == null || alertHistory!.trim().isEmpty) {
      return const [];
    }

    try {
      final raw = jsonDecode(alertHistory!);
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((entry) =>
              AlertHistoryEntry.fromJson(entry.cast<String, Object?>()))
          .toList();
    } on FormatException {
      return const [];
    } on TypeError {
      return const [];
    }
  }

  Map<String, Object?> toMap({bool includeId = true}) {
    return {
      if (includeId && id > 0) 'id': id,
      'dateTime': dateTime,
      'riskLevel': riskLevel,
      'summary': summary,
      'duration': duration,
      'flagCount': flagCount,
      'transcript': transcript,
      'audioPath': audioPath,
      'analysisResult': analysisResult,
      'analysisType': analysisType,
      'alert_history': alertHistory,
    };
  }

  factory CallHistory.fromMap(Map<String, Object?> map) {
    return CallHistory(
      id: (map['id'] as num?)?.toInt() ?? 0,
      dateTime: map['dateTime'] as String? ?? '',
      riskLevel: map['riskLevel'] as String? ?? 'GREEN',
      summary: map['summary'] as String? ?? '',
      duration: map['duration'] as String? ?? '',
      flagCount: (map['flagCount'] as num?)?.toInt() ?? 0,
      transcript: map['transcript'] as String? ?? '',
      audioPath: map['audioPath'] as String?,
      analysisResult: map['analysisResult'] as String?,
      analysisType: map['analysisType'] as String?,
      alertHistory: map['alert_history'] as String?,
    );
  }

  static String alertHistoryToJson(List<AlertHistoryEntry> history) {
    return jsonEncode(history.map((entry) => entry.toJson()).toList());
  }
}
