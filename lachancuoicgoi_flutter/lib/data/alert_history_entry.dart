import 'package:flutter/material.dart';

class AlertHistoryEntry {
  const AlertHistoryEntry({
    required this.timestamp,
    required this.analysisLevel,
    required this.riskLevel,
    required this.alertCount,
    required this.displayedReason,
    this.allReasons,
  });

  final int timestamp;
  final String analysisLevel;
  final String riskLevel;
  final int alertCount;
  final String displayedReason;
  final List<String>? allReasons;

  factory AlertHistoryEntry.fromJson(Map<String, Object?> json) {
    return AlertHistoryEntry(
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
      analysisLevel: json['analysisLevel'] as String? ?? '',
      riskLevel: json['riskLevel'] as String? ?? 'GREEN',
      alertCount: (json['alertCount'] as num?)?.toInt() ?? 1,
      displayedReason: json['displayedReason'] as String? ?? '',
      allReasons: (json['allReasons'] as List?)?.whereType<String>().toList(),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'timestamp': timestamp,
      'analysisLevel': analysisLevel,
      'riskLevel': riskLevel,
      'alertCount': alertCount,
      'displayedReason': displayedReason,
      'allReasons': allReasons,
    };
  }

  String getFormattedTime() {
    final time = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${_pad(time.hour)}:${_pad(time.minute)}:${_pad(time.second)}';
  }

  Color getRiskLevelColor() {
    return switch (riskLevel.toUpperCase()) {
      'RED' => const Color(0xFFD32F2F),
      'ORANGE' => const Color(0xFFFF9800),
      _ => const Color(0xFF9E9E9E),
    };
  }

  String getRiskLevelIcon() {
    return switch (riskLevel.toUpperCase()) {
      'RED' => 'red',
      'ORANGE' => 'orange',
      _ => 'neutral',
    };
  }

  static String _pad(int value) => value.toString().padLeft(2, '0');
}
