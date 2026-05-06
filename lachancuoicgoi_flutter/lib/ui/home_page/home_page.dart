import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import 'instruct_dialog.dart';
import 'rights_dialog.dart';
import 'settings_dialog.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lá chắn cuộc gọi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Cài đặt',
            onPressed: () => _showSettingsDialog(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.shield_outlined),
            tooltip: 'Quyền',
            onPressed: () => _showRightsDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.info_outlined),
            tooltip: 'Hướng dẫn',
            onPressed: () => _showInstructDialog(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          children: [
            const Spacer(flex: 1),

            // ── Hero card ──
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.xl,
                  horizontal: AppSpacing.sm,
                ),
                child: Column(
                  children: [
                    Icon(Icons.shield_outlined,
                        size: 64, color: cs.primary),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Lá chắn cuộc gọi',
                      style:
                          tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Phân tích cuộc gọi theo thời gian thực để phát hiện lừa đảo.',
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(flex: 2),

            // ── Info card ──
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xxs,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outlined,
                      size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.xxs),
                  Flexible(
                    child: Text(
                      'Khuyên dùng: Bật Phụ đề trực tiếp để bảo vệ tốt nhất',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            // ── Start monitoring button ──
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => context.push('/monitoring'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 6,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shield_outlined, size: 24),
                    const SizedBox(width: AppSpacing.xxs),
                    Text(
                      'Bắt đầu giám sát',
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            // ── Two sub-buttons row ──
            Row(
              children: [
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.science_outlined,
                    label: 'Chế độ giả lập',
                    onTap: () => context.push('/simulation'),
                    colorScheme: cs,
                    textTheme: tt,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.history_outlined,
                    label: 'Lịch sử',
                    onTap: () => context.push('/history'),
                    colorScheme: cs,
                    textTheme: tt,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xs),

            // ── Tips lesson button ──
            Material(
              color: cs.tertiaryContainer.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: cs.tertiary.withValues(alpha: 0.3),
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => context.push('/tips_lesson'),
                child: SizedBox(
                  height: 64,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lightbulb_outlined,
                          size: 24, color: cs.tertiary),
                      const SizedBox(width: AppSpacing.xxs),
                      Text(
                        'Mẹo chống lừa đảo',
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.tertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsDialog(BuildContext context, WidgetRef _) {
    showDialog(
      context: context,
      builder: (_) => const SettingsDialog(),
    );
  }

  void _showRightsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const RightsDialog(),
    );
  }

  void _showInstructDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const InstructDialog(),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.colorScheme,
    required this.textTheme,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          height: 72,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: colorScheme.primary),
              const SizedBox(height: 2),
              Text(
                label,
                style: textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
