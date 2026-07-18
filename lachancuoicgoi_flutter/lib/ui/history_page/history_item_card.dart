import 'dart:convert';

import 'package:flutter/material.dart';

import '../../analysis/analysis_result.dart';
import '../../core/analysis_availability.dart';
import '../../core/risk_level.dart';
import '../../data/call_history.dart';
import '../theme/risk_level_colors.dart';

/// History item card matching Kotlin HistoryItemCard.kt
class HistoryItemCard extends StatelessWidget {
  const HistoryItemCard({super.key, required this.item, required this.onTap});

  final CallHistory item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final riskLevel = RiskLevel.fromString(item.riskLevel);
    final availability = AnalysisAvailability.fromStoredSession(
      recordingError: item.recordingError,
      hasTranscript: item.transcript.trim().isNotEmpty,
      analysisCompleted: _hasValidAnalysis(item.analysisResult),
    );
    final riskColor = availability.canShowRisk ? riskLevel.color : cs.outline;
    final statusLabel = _statusLabel(item.recordingErrorEnum, availability);
    // Keep the saved summary visible for legacy/corrupt analysis JSON. Risk is
    // still hidden when availability is insufficient, but replacing the
    // summary would discard the only useful content older records contain.
    final savedSummary = item.summary.trim();
    final summaryClaimsSafe =
        !availability.canShowRisk &&
        savedSummary.toLowerCase() ==
            RiskLevel.green.vietnameseName.toLowerCase();
    final displayedSummary = savedSummary.isNotEmpty && !summaryClaimsSafe
        ? item.summary
        : 'Không thể đưa ra kết luận từ dữ liệu hiện có.';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: cs.surfaceContainerHighest,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Risk color bar
              Container(width: 4, color: riskColor),

              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date + risk badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(item.dateTime, style: tt.bodySmall),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: riskColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: Text(
                              availability.canShowRisk
                                  ? riskLevel.vietnameseName
                                  : statusLabel,
                              style: TextStyle(
                                color: riskColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      if (!availability.canShowRisk) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                availability.guidance,
                                style: tt.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],

                      // Summary — wrap in Semantics so screen reader reads
                      // the full text even when visually truncated.
                      Semantics(
                        label: displayedSummary,
                        child: Text(
                          displayedSummary,
                          style: tt.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Duration + flag count
                      Text(
                        '${item.duration} • ${item.flagCount} dấu hiệu',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Analysis type static label
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: item.analysisType == null
                              ? cs.surfaceContainerHighest.withValues(
                                  alpha: 0.5,
                                )
                              : cs.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: cs.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          item.analysisType ?? 'Không phân tích',
                          style: tt.labelSmall?.copyWith(
                            color: item.analysisType == null
                                ? cs.onSurfaceVariant.withValues(alpha: 0.7)
                                : cs.onSecondaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static bool _hasValidAnalysis(String? raw) {
    if (raw == null || raw.trim().isEmpty) return false;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['overallRiskLevel'] == null) return false;
      final result = AnalysisResult.fromJson(decoded.cast<String, Object?>());
      return !result.isError;
    } on Object {
      return false;
    }
  }

  static String _statusLabel(
    RecordingError? error,
    AnalysisAvailability availability,
  ) => switch (error) {
    RecordingError.killed => 'Phiên bị gián đoạn',
    RecordingError.partial => 'Kết quả chưa hoàn chỉnh',
    _ => availability.vietnameseName,
  };
}
