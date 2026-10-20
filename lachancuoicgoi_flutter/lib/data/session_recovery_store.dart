library;

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SessionSnapshot {
  const SessionSnapshot({
    required this.phoneNumber,
    required this.transcript,
    required this.elapsedSeconds,
    required this.riskLevel,
    required this.analysisResultJson,
    required this.recordingError,
    required this.startedAt,
  });

  final String phoneNumber;

  final String transcript;

  final int elapsedSeconds;

  final String? riskLevel;

  final String? analysisResultJson;

  final String? recordingError;

  final DateTime startedAt;

  Map<String, Object?> toJson() => {
    'phoneNumber': phoneNumber,
    'transcript': transcript,
    'elapsedSeconds': elapsedSeconds,
    'riskLevel': riskLevel,
    'analysisResultJson': analysisResultJson,
    'recordingError': recordingError,
    'startedAtIso': startedAt.toIso8601String(),
  };

  factory SessionSnapshot.fromJson(Map<String, Object?> json) {
    return SessionSnapshot(
      phoneNumber: (json['phoneNumber'] as String?) ?? '',
      transcript: (json['transcript'] as String?) ?? '',
      elapsedSeconds: (json['elapsedSeconds'] as num?)?.toInt() ?? 0,
      riskLevel: json['riskLevel'] as String?,
      analysisResultJson: json['analysisResultJson'] as String?,
      recordingError: json['recordingError'] as String?,
      startedAt:
          DateTime.tryParse(json['startedAtIso'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

abstract final class SessionRecoveryStore {
  static const String _key = 'live_session_snapshot_v1';

  static Future<void> save(SessionSnapshot snapshot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(snapshot.toJson()));
    } on Exception {
      assert(true);
    }
  }

  static Future<SessionSnapshot?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return SessionSnapshot.fromJson(decoded.cast<String, Object?>());
    } on FormatException {
      await clear();
      return null;
    } on Exception {
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } on Exception catch (e) {
      assert(() {
        // ignore: avoid_print
        print('[SessionRecoveryStore] Failed to clear snapshot: $e');
        return true;
      }());
    }
  }

  static const Duration maxAge = Duration(minutes: 30);
}
