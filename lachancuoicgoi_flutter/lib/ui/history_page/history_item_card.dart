import 'package:flutter/material.dart';

import '../../core/risk_level.dart';
import '../../data/call_history.dart';

/// History item card matching Kotlin HistoryItemCard.kt
class HistoryItemCard extends StatelessWidget {
  const HistoryItemCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  final CallHistory item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final riskLevel = RiskLevel.fromString(item.riskLevel);

    final riskColor = switch (riskLevel) {
      RiskLevel.green => const Color(0xFF4CAF50),
      RiskLevel.yellow => const Color(0xFFFFEB3B),
      RiskLevel.orange => const Color(0xFFFF9800),
      RiskLevel.red => const Color(0xFFF44336),
    };

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
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
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: riskColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: Text(
                              riskLevel.vietnameseName,
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

                      // Summary
                      Text(
                        item.summary,
                        style: tt.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // Duration + flag count
                      Text(
                        '${item.duration} • ${item.flagCount} dấu hiệu',
                        style: tt.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 4),

                      // Analysis type chip
                      ActionChip(
                        label: Text(item.analysisType ?? 'Không phân tích'),
                        onPressed: () {},
                        backgroundColor: item.analysisType == null
                            ? cs.surfaceContainerHighest.withValues(alpha: 0.5)
                            : null,
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
}
