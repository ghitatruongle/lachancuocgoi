import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform_capabilities.dart';
import '../../services/permission_controller.dart';
import '../theme/app_theme.dart';
import 'instruct_dialog.dart';
import 'rights_dialog.dart';
import 'settings_dialog.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  /// Prevents showing the permission dialog more than once per app session.
  bool _hasCheckedPermissions = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRequestPermissions();
    });
  }

  void _checkAndRequestPermissions() {
    if (_hasCheckedPermissions) return;
    _hasCheckedPermissions = true;

    // Bug #7 fix: only auto-show permission dialog on Android/iOS where native
    // permissions are relevant. On Web/Desktop, permission_handler may throw
    // MissingPluginException and the dialog shows confusing states.
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }

    final permState = ref.read(permissionControllerProvider);
    if (!permState.essentialGranted) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const RightsDialog(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final permissionState = ref.watch(permissionControllerProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: l10n.settings,
            onPressed: () => _showSettingsDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.shield_outlined),
            tooltip: l10n.permissions,
            onPressed: () => _showRightsDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.info_outlined),
            tooltip: l10n.instructions,
            onPressed: () => _showInstructDialog(context),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            sliver: SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                children: [
                  const Spacer(flex: 1),

                  if (PlatformCapabilities.current.isDemoMode) ...[
                    _DemoModeBanner(cs: cs, tt: tt),
                    const SizedBox(height: AppSpacing.sm),
                    _FeatureMatrixCard(cs: cs, tt: tt),
                    const SizedBox(height: AppSpacing.sm),
                  ],

                  // ── Hero card ──
                  Semantics(
                    label: l10n.appInfoSemantic,
                    child: Card(
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
                            Image.asset(
                              'assets/logo.png',
                              width: 80,
                              height: 80,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(
                                    Icons.shield_outlined,
                                    size: 64,
                                    color: cs.primary,
                                  ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              l10n.appTitle,
                              style: tt.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              l10n.homeSubtitle,
                              style: tt.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
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
                        Icon(
                          Icons.info_outlined,
                          size: 16,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Flexible(
                          child: Text(
                            l10n.homeLiveCaptionTip,
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
                    child: Semantics(
                      button: true,
                      label: l10n.startMonitoringSemantic,
                      child: ElevatedButton(
                        // Demo platforms: allow open monitoring (scripted STT).
                        // Android: require microphone.
                        onPressed:
                            PlatformCapabilities.current.isDemoMode ||
                                permissionState.snapshot.recordAudio
                            ? () => context.push('/monitoring')
                            : null,
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
                              l10n.startMonitoring,
                              style: tt.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: cs.onPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Bug #4 fix: show a warning when recordAudio is granted
                  // (button enabled) but other critical permissions are still
                  // missing. Previously the user would enter monitoring with
                  // no feedback that overlay alerts, accessibility transcription,
                  // or call-screening auto-start would be non-functional.
                  if (permissionState.snapshot.recordAudio &&
                      (!permissionState.snapshot.overlay ||
                          !permissionState.snapshot.accessibility ||
                          !permissionState.snapshot.callScreening))
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 14,
                            color: cs.error,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              l10n.homePermissionWarning,
                              style: tt.bodySmall?.copyWith(color: cs.error),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: AppSpacing.sm),

                  // ── Two sub-buttons row ──
                  Row(
                    children: [
                      Expanded(
                        child: _QuickActionCard(
                          icon: Icons.science_outlined,
                          label: l10n.simulationMode,
                          onTap: () => context.push('/simulation'),
                          colorScheme: cs,
                          textTheme: tt,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: _QuickActionCard(
                          icon: Icons.history_outlined,
                          label: l10n.history,
                          onTap: () => context.push('/history'),
                          colorScheme: cs,
                          textTheme: tt,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xs),

                  // ── Tips lesson button ──
                  Semantics(
                    button: true,
                    label: l10n.antiScamTips,
                    child: Material(
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
                              Icon(
                                Icons.lightbulb_outlined,
                                size: 24,
                                color: cs.tertiary,
                              ),
                              const SizedBox(width: AppSpacing.xxs),
                              Text(
                                l10n.antiScamTips,
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
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog<void>(context: context, builder: (_) => const SettingsDialog());
  }

  void _showRightsDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const RightsDialog(),
    );
  }

  void _showInstructDialog(BuildContext context) {
    showDialog<void>(context: context, builder: (_) => const InstructDialog());
  }
}

class _DemoModeBanner extends StatelessWidget {
  const _DemoModeBanner({required this.cs, required this.tt});

  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      label: l10n.demoModeSemantic,
      child: Material(
        color: cs.tertiaryContainer,
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.science_outlined, color: cs.onTertiaryContainer),
              const SizedBox(width: AppSpacing.xxs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.demoMode,
                      style: tt.titleSmall?.copyWith(
                        color: cs.onTertiaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      l10n.demoModeDescription,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onTertiaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureMatrixCard extends StatelessWidget {
  const _FeatureMatrixCard({required this.cs, required this.tt});

  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final caps = PlatformCapabilities.current;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.featuresOnThisDevice,
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xxs),
            for (final row in caps.featureMatrix)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      row.supported ? Icons.check_circle : Icons.cancel,
                      size: 16,
                      color: row.supported ? cs.tertiary : cs.outline,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(row.label, style: tt.bodySmall)),
                  ],
                ),
              ),
          ],
        ),
      ),
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
    return Semantics(
      button: true,
      label: label,
      child: Material(
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
      ),
    );
  }
}
