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
    this.recordingError,
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

  /// Why no transcript was captured, or null if everything was fine.
  /// Sprint 1 (A7): distinguishes "we never heard anything" (noAudio) from
  /// "we heard something but the engine failed" (sttFailed). The schema
  /// reserves the value `partial` for future use (e.g. session ended before
  /// the first final result was committed).
  final String? recordingError;

  /// Sentinel object to distinguish "not passed" from "explicitly null".
  static const _null = Object();

  CallHistory copyWith({
    int? id,
    String? dateTime,
    String? riskLevel,
    String? summary,
    String? duration,
    int? flagCount,
    String? transcript,
    Object? audioPath = _null,
    Object? analysisResult = _null,
    Object? analysisType = _null,
    Object? alertHistory = _null,
    Object? recordingError = _null,
  }) {
    return CallHistory(
      id: id ?? this.id,
      dateTime: dateTime ?? this.dateTime,
      riskLevel: riskLevel ?? this.riskLevel,
      summary: summary ?? this.summary,
      duration: duration ?? this.duration,
      flagCount: flagCount ?? this.flagCount,
      transcript: transcript ?? this.transcript,
      audioPath: identical(audioPath, _null)
          ? this.audioPath
          : audioPath as String?,
      analysisResult: identical(analysisResult, _null)
          ? this.analysisResult
          : analysisResult as String?,
      analysisType: identical(analysisType, _null)
          ? this.analysisType
          : analysisType as String?,
      alertHistory: identical(alertHistory, _null)
          ? this.alertHistory
          : alertHistory as String?,
      recordingError: identical(recordingError, _null)
          ? this.recordingError
          : recordingError as String?,
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
      'recordingError': recordingError,
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
      recordingError: map['recordingError'] as String?,
    );
  }

  static String alertHistoryToJson(List<AlertHistoryEntry> history) {
    return jsonEncode(history.map((entry) => entry.toJson()).toList());
  }
}
