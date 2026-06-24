/// Sprint 2 (B5): persists a snapshot of the live monitoring session
/// every 5 seconds so that if the OS kills the process mid-call, the
/// recovered session can still be written to `CallHistory` on next app
/// start (with `recordingError = 'killed'`).
///
/// Backed by `SharedPreferences` because:
/// - the snapshot is tiny (< 1 KB),
/// - we already initialise SharedPreferences in `main.dart`,
/// - it survives both uninstall-clear-data and process kills,
/// - the key is namespaced (`live_session_snapshot_v1`) so an upgrade
///   that changes the schema can bump to `v2` and ignore `v1`.
///
/// NOTE: the [CallHistory.recordingError] field's allowed values
/// (`'noAudio' | 'sttFailed' | 'partial'`) are documented in
/// `lib/data/call_history.dart`. The `'killed'` value is added by Sprint 2
/// (B5) — see the B5 spec in the task brief.
library;

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/risk_level.dart';

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

  /// Raw phone number string (may be empty if the call had no caller-id).
  final String phoneNumber;

  /// Transcript text captured at snapshot time.
  final String transcript;

  /// Elapsed seconds since monitoring started.
  final int elapsedSeconds;

  /// Storage name of the [RiskLevel] (e.g. `RED`, `ORANGE`).
  final String? riskLevel;

  /// JSON-encoded `AnalysisResult` (nullable — snapshot may have been
  /// taken before the first analysis completed).
  final String? analysisResultJson;

  /// Mirrors the [CallHistory.recordingError] field. Sprint 2 (B5)
  /// introduces the new value `'killed'` to mean "the app process was
  /// killed by the OS before endSession() could run".
  final String? recordingError;

  /// When this session was first started. Used to ignore stale snapshots
  /// (older than 30 min) on next app launch.
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
  /// Bump this if the on-disk format ever changes incompatibly so old
  /// snapshots are ignored instead of crashing the app.
  static const String _key = 'live_session_snapshot_v1';

  /// Save a snapshot of the live session. Safe to call on every timer
  /// tick — the write is debounced internally by SharedPreferences
  /// (it already batches writes through the same channel).
  static Future<void> save(SessionSnapshot snapshot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(snapshot.toJson()));
    } on Exception {
      // Never crash the monitoring loop because persistence failed.
    }
  }

  /// Load the most recent snapshot, or `null` if there isn't one.
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

  /// Remove the snapshot (called on successful endSession or when the
  /// snapshot is too old to be useful).
  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } on Exception {
      // ignore
    }
  }

  /// How old a snapshot can be before we ignore it. 30 min covers any
  /// reasonable user pause but rejects "yesterday's crashed session"
  /// when the user re-opens the app the next day.
  static const Duration maxAge = Duration(minutes: 30);
}
