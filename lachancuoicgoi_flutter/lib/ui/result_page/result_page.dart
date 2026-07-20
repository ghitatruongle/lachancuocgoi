import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../analysis/analysis_result.dart';
import '../../analysis/l3/core/pii_stripper.dart';
import '../../core/analysis_availability.dart';
import '../../core/risk_level.dart';
import '../../data/app_database.dart';
import '../../data/call_history.dart';
import '../home_page/settings_dialog.dart';
import '../monitoring_page/alert_history_section.dart';
import '../theme/app_theme.dart';
import '../theme/risk_level_colors.dart';

final _callHistoryFutureProvider = FutureProvider.family<CallHistory?, int>((
  ref,
  historyId,
) async {
  final db = await ref.watch(appDatabaseFutureProvider.future);
  return db.getById(historyId);
});

/// Parses an analysis payload written by older or current app versions.
/// Malformed/partially migrated JSON is treated as unavailable, never as a
/// green assessment.
AnalysisResult? parseStoredAnalysisResult(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    final map = decoded.cast<String, Object?>();
    if (map['overallRiskLevel'] is! String) return null;
    return AnalysisResult.fromJson(map);
  } on Object {
    return null;
  }
}

AnalysisAvailability availabilityForHistoryItem(
  CallHistory item,
  AnalysisResult? analysis,
) {
  return AnalysisAvailability.fromStoredSession(
    recordingError: item.recordingError,
    hasTranscript: item.transcript.trim().isNotEmpty,
    analysisCompleted: analysis != null && !analysis.isError,
  );
}

String historyStatusLabel(
  CallHistory item,
  AnalysisAvailability availability,
  RiskLevel risk,
) {
  if (availability.canShowRisk) return risk.vietnameseName;
  return switch (item.recordingErrorEnum) {
    RecordingError.killed => 'Phiên bị gián đoạn',
    RecordingError.partial => 'Kết quả chưa hoàn chỉnh',
    _ => availability.vietnameseName,
  };
}

/// Creates privacy-safe text for the normal share action. Full transcript is
/// appended only after the caller has obtained explicit confirmation.
String buildHistoryShareText(
  CallHistory item, {
  required String statusLabel,
  bool includeTranscript = false,
}) {
  String safeSummary;
  try {
    final availability = availabilityForHistoryItem(
      item,
      parseStoredAnalysisResult(item.analysisResult),
    );
    final summary = availability.canShowRisk
        ? item.summary
        : availability.guidance;
    safeSummary = PIIStripper.redactPII(summary).redactedText;
  } on Object {
    safeSummary = 'Nội dung đã được ẩn để bảo vệ quyền riêng tư.';
  }
  final buffer = StringBuffer()
    ..writeln('Lá chắn cuộc gọi - Kết quả phân tích:')
    ..writeln('Đánh giá: $statusLabel')
    ..write('Tóm tắt: $safeSummary');
  if (includeTranscript) {
    final transcript = item.transcript.trim().isEmpty
        ? 'Không có dữ liệu'
        : item.transcript.replaceAll('+', ' ');
    buffer
      ..writeln()
      ..writeln('-------')
      ..writeln('Nội dung cuộc gọi:')
      ..write(transcript);
  }
  return buffer.toString();
}

class ResultPage extends ConsumerWidget {
  const ResultPage({super.key, required this.historyId});

  final int historyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncItem = ref.watch(_callHistoryFutureProvider(historyId));
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return asyncItem.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Quay lại',
            onPressed: () => context.go('/'),
          ),
          title: const Text('Kết quả phân tích'),
        ),
        body: Center(child: Text('Lỗi: $e')),
      ),
      data: (item) {
        if (item == null) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Quay lại',
                onPressed: () => context.go('/'),
              ),
              title: const Text('Kết quả phân tích'),
            ),
            body: const Center(child: Text('Không tìm thấy dữ liệu.')),
          );
        }

        final risk = RiskLevel.fromString(item.riskLevel);
        final analysis = parseStoredAnalysisResult(item.analysisResult);
        final availability = availabilityForHistoryItem(item, analysis);
        final riskColor = availability.canShowRisk ? risk.color : cs.outline;
        final statusLabel = historyStatusLabel(item, availability, risk);
        final displaySummary = availability.canShowRisk
            ? item.summary
            : availability.guidance;

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Quay lại',
              onPressed: () => context.go('/'),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lá chắn cuộc gọi',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text('Phát hiện Lừa đảo & Bạo lực', style: tt.bodySmall),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                tooltip: 'Cài đặt',
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const SettingsDialog(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.share),
                tooltip: 'Chia sẻ',
                onPressed: () => _shareSummary(item, statusLabel),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kết quả phân tích',
                  style: tt.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // ── Analysis Summary Card ──
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        Container(width: 4, color: riskColor),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Đánh giá',
                                      style: tt.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.share, size: 20),
                                      tooltip: 'Chia sẻ đánh giá',
                                      onPressed: () =>
                                          _shareSummary(item, statusLabel),
                                    ),
                                  ],
                                ),
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
                                    statusLabel,
                                    style: TextStyle(
                                      color: riskColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(displaySummary, style: tt.bodyMedium),
                                if (!availability.canShowRisk) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Không thể kết luận cuộc gọi an toàn từ '
                                    'dữ liệu hiện có.',
                                    style: tt.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.sm),

                if (analysis != null && availability.canShowRisk) ...[
                  _AnalysisDetailsCard(analysis: analysis),
                  const SizedBox(height: AppSpacing.sm),
                ],

                // ── Recording Card ──
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bản ghi âm',
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'File ghi âm không được lưu lại nhằm bảo vệ quyền riêng tư.',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.sm),

                // ── Transcript Card ──
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                'Nội dung cuộc gọi (Bản lưu cục bộ)',
                                style: tt.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.share, size: 20),
                              tooltip: 'Chia sẻ nội dung',
                              onPressed: item.transcript.trim().isEmpty
                                  ? null
                                  : () => _confirmAndShareTranscript(
                                      context,
                                      item,
                                      statusLabel,
                                    ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SelectableText(
                            item.transcript.isEmpty
                                ? '${availability.vietnameseName}. '
                                      '${availability.guidance}'
                                : item.transcript,
                            style: tt.bodyMedium?.copyWith(
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.sm),

                // ── Alert history ──
                AlertHistorySection(alertHistory: item.getAlertHistoryList()),

                const SizedBox(height: AppSpacing.lg),

                // ── Bottom buttons ──
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => context.go('/'),
                        child: const Text('Màn hình chính'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => context.push('/history'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                        ),
                        child: const Text('Xem lịch sử'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        );
      },
    );
  }

  void _shareSummary(CallHistory item, String statusLabel) {
    SharePlus.instance.share(
      ShareParams(text: buildHistoryShareText(item, statusLabel: statusLabel)),
    );
  }

  Future<void> _confirmAndShareTranscript(
    BuildContext context,
    CallHistory item,
    String statusLabel,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Chia sẻ toàn bộ nội dung?'),
        content: const Text(
          'Nội dung cuộc gọi có thể chứa số điện thoại, tài khoản hoặc thông '
          'tin riêng tư. Chỉ chia sẻ khi bạn hiểu và chấp nhận rủi ro này.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Thêm nội dung cuộc gọi'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await SharePlus.instance.share(
      ShareParams(
        text: buildHistoryShareText(
          item,
          statusLabel: statusLabel,
          includeTranscript: true,
        ),
      ),
    );
  }
}

class _AnalysisDetailsCard extends StatelessWidget {
  const _AnalysisDetailsCard({required this.analysis});

  final AnalysisResult analysis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = analysis.matches
        .map((match) => match.category.trim())
        .where((value) => value.isNotEmpty && value != 'Unknown')
        .toSet()
        .toList();
    final evidence = analysis.matches
        .map((match) => match.keyword.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    final source = [
      analysis.analysisLevel.id.toUpperCase(),
      if (analysis.modelName?.trim().isNotEmpty ?? false)
        analysis.modelName!.trim(),
    ].join(' • ');
    final confidence = analysis.confidence >= 0
        ? (analysis.confidence <= 1
              ? analysis.confidence * 100
              : analysis.confidence)
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chi tiết phân tích',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text('Nguồn phân tích: $source'),
            if (confidence != null)
              Text('Độ tin cậy: ${confidence.toStringAsFixed(0)}%'),
            if (analysis.isFallback)
              Text(
                'Đã dùng bộ phân tích dự phòng.',
                style: TextStyle(color: theme.colorScheme.tertiary),
              ),
            if (categories.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Chiến thuật được phát hiện',
                style: theme.textTheme.labelLarge,
              ),
              Text(categories.join(', ')),
            ],
            if (evidence.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Bằng chứng', style: theme.textTheme.labelLarge),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: evidence
                    .take(8)
                    .map((value) => Chip(label: Text(value)))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
