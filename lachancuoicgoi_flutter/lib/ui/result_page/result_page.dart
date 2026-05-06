import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/risk_level.dart';
import '../../data/app_database.dart';
import '../../data/call_history.dart';

final resultHistoryProvider = FutureProvider.family<CallHistory?, int>((
  ref,
  historyId,
) {
  return ref.watch(appDatabaseProvider).getById(historyId);
});

class ResultPage extends ConsumerWidget {
  const ResultPage({super.key, this.historyId});

  final int? historyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = historyId;
    return Scaffold(
      appBar: AppBar(title: const Text('Kết quả phân tích')),
      body: id == null
          ? const _ResultMessage(message: 'Không tìm thấy mã lịch sử')
          : ref.watch(resultHistoryProvider(id)).when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) =>
                    _ResultMessage(message: 'Không đọc được lịch sử: $error'),
                data: (history) => history == null
                    ? const _ResultMessage(message: 'Không tìm thấy lịch sử')
                    : _ResultContent(history: history),
              ),
    );
  }
}

class _ResultContent extends StatelessWidget {
  const _ResultContent({required this.history});

  final CallHistory history;

  @override
  Widget build(BuildContext context) {
    final riskLevel = RiskLevel.fromString(history.riskLevel);
    final alerts = history.getAlertHistoryList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: riskLevel.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      riskLevel.vietnameseName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _InfoLine(label: 'Thời gian', value: history.dateTime),
              _InfoLine(label: 'Thời lượng', value: history.duration),
              _InfoLine(label: 'Số cảnh báo', value: '${history.flagCount}'),
              if ((history.analysisType ?? '').isNotEmpty)
                _InfoLine(label: 'Cấp phân tích', value: history.analysisType!),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tóm tắt', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(history.summary),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Transcript',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                history.transcript.isEmpty
                    ? 'Không có transcript'
                    : history.transcript,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lịch sử cảnh báo',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (alerts.isEmpty)
                const Text('Chưa có cảnh báo')
              else
                for (final alert in alerts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${alert.getFormattedTime()} - ${alert.analysisLevel} - '
                      '${alert.displayedReason}',
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class _ResultMessage extends StatelessWidget {
  const _ResultMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
