import 'package:flutter/material.dart';

import '../../data/alert_history_entry.dart';

/// Alert history section used in both MonitoringPage and ResultPage.
class AlertHistorySection extends StatelessWidget {
  const AlertHistorySection({
    super.key,
    required this.alertHistory,
  });

  final List<AlertHistoryEntry> alertHistory;

  @override
  Widget build(BuildContext context) {
    if (alertHistory.isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '⚠️ LỊCH SỬ CẢNH BÁO',
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Divider(color: cs.outlineVariant),
        const SizedBox(height: 12),
        for (var i = 0; i < alertHistory.length; i++) ...[
          _AlertHistoryCard(
            entry: alertHistory[alertHistory.length - 1 - i],
          ),
          if (i < alertHistory.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _AlertHistoryCard extends StatelessWidget {
  const _AlertHistoryCard({required this.entry});

  final AlertHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final riskColor = entry.getRiskLevelColor();

    return Card(
      color: riskColor.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      _riskIcon(entry.riskLevel),
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      entry.getFormattedTime(),
                      style: tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (entry.alertCount > 1) ...[
              Text(
                '${entry.alertCount} cảnh báo • Mức cao nhất: ${entry.riskLevel}',
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(entry.displayedReason, style: tt.bodyMedium),
            if (entry.allReasons != null && entry.allReasons!.length > 1) ...[
              const SizedBox(height: 6),
              Text(
                'Chi tiết: ${entry.allReasons!.take(3).join(", ")}${entry.allReasons!.length > 3 ? "..." : ""}',
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                  height: 16 / 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _riskIcon(String riskLevel) {
    return switch (riskLevel.toUpperCase()) {
      'RED' => '🔴',
      'ORANGE' => '🟠',
      _ => '⚪',
    };
  }
}
