import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/risk_level.dart';
import '../../data/app_database.dart';
import '../../data/call_history.dart';
import '../home_page/settings_dialog.dart';
import '../monitoring_page/alert_history_section.dart';
import '../theme/app_theme.dart';

final _callHistoryFutureProvider = FutureProvider.family<CallHistory?, int>((
  ref,
  historyId,
) async {
  final db = await ref.watch(appDatabaseFutureProvider.future);
  return db.getById(historyId);
});

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
                onPressed: () => context.go('/'),
              ),
              title: const Text('Kết quả phân tích'),
            ),
            body: const Center(child: Text('Không tìm thấy dữ liệu.')),
          );
        }

        final risk = RiskLevel.fromString(item.riskLevel);
        final riskColor = switch (risk) {
          RiskLevel.green => const Color(0xFF4CAF50),
          RiskLevel.yellow => const Color(0xFFFFEB3B),
          RiskLevel.orange => const Color(0xFFFF9800),
          RiskLevel.red => const Color(0xFFF44336),
        };

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
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
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const SettingsDialog(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.share),
                tooltip: 'Chia sẻ',
                onPressed: () {
                  final transcript = item.transcript.isEmpty
                      ? 'Không có dữ liệu'
                      : item.transcript.replaceAll('+', ' ');
                  final shareText =
                      'Lá chắn cuộc gọi - Kết quả phân tích:\n'
                      'Đánh giá: ${risk.vietnameseName}\n'
                      'Tóm tắt: ${item.summary}\n'
                      '-------\n'
                      'Nội dung cuộc gọi:\n'
                      '$transcript';
                  SharePlus.instance.share(ShareParams(text: shareText));
                },
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
                                      onPressed: () {
                                        SharePlus.instance.share(
                                          ShareParams(
                                            text:
                                                'Lá chắn cuộc gọi - Đánh giá: '
                                                '${risk.vietnameseName}\n'
                                                'Tóm tắt: ${item.summary}',
                                          ),
                                        );
                                      },
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
                                    risk.vietnameseName,
                                    style: TextStyle(
                                      color: riskColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(item.summary, style: tt.bodyMedium),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.sm),

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
                              onPressed: () {
                                final content = item.transcript.isEmpty
                                    ? 'Không có dữ liệu âm thanh.'
                                    : item.transcript.replaceAll('+', ' ');
                                SharePlus.instance.share(
                                  ShareParams(
                                    text: 'Nội dung cuộc gọi:\n$content',
                                  ),
                                );
                              },
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
                                ? 'Không có nội dung.'
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
}
