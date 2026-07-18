import 'package:flutter/material.dart';

import '../../../analysis/analysis_mode.dart';
import '../../theme/app_theme.dart';

/// Analysis mode selection card (normal / gDetection / gemini / parallel).
class AnalysisSection extends StatelessWidget {
  const AnalysisSection({
    super.key,
    required this.selectedMode,
    required this.cloudConsentGranted,
    required this.onModeSelected,
  });

  final AnalysisMode selectedMode;
  final bool cloudConsentGranted;
  final ValueChanged<AnalysisMode> onModeSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chế độ phân tích',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.xxs),
            for (final mode in AnalysisMode.values) ...[
              Builder(
                builder: (context) {
                  final usesCloud =
                      mode == AnalysisMode.geminiApi ||
                      mode == AnalysisMode.parallel;
                  final enabled = !usesCloud || cloudConsentGranted;
                  return ListTile(
                    title: Text(mode.title),
                    subtitle: Text(
                      enabled
                          ? mode.description
                          : '${mode.description} · Cần đồng ý phân tích đám mây',
                    ),
                    leading: Icon(
                      mode == selectedMode
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: mode == selectedMode
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    trailing: enabled ? null : const Icon(Icons.lock_outline),
                    enabled: enabled,
                    onTap: enabled ? () => onModeSelected(mode) : null,
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
