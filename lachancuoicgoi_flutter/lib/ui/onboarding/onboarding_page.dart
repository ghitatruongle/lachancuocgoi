import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/settings_controller.dart';
import '../../services/permission_controller.dart';
import '../theme/app_theme.dart';

/// First-run explanation and minimum-permission setup.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  bool _isRequesting = false;
  bool _exitScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(permissionControllerProvider.notifier).refresh();
      if (mounted) _tryExitWhenReady();
    });
  }

  Future<void> _completeAndGoHome() async {
    final router = GoRouter.of(context);
    await ref.read(settingsControllerProvider.notifier).completeOnboarding();
    if (mounted) router.go('/');
  }

  void _tryExitWhenReady() {
    if (_exitScheduled || !mounted) return;
    if (!ref.read(permissionControllerProvider).essentialGranted) return;
    _exitScheduled = true;
    unawaited(_completeAndGoHome());
  }

  Future<void> _requestCorePermissions() async {
    setState(() => _isRequesting = true);
    try {
      await ref
          .read(permissionControllerProvider.notifier)
          .requestCapabilityGroup(
            PermissionCapabilityGroup.coreProtection,
            context,
          );
      if (!mounted) return;
      await ref
          .read(permissionControllerProvider.notifier)
          .requestCapabilityGroup(
            PermissionCapabilityGroup.enhancedProtection,
            context,
          );
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final permissionState = ref.watch(permissionControllerProvider);
    final groups = ref.watch(capabilityGroupsProvider);

    ref.listen<PermissionState>(permissionControllerProvider, (previous, next) {
      if (next.essentialGranted && previous?.essentialGranted != true) {
        _tryExitWhenReady();
      }
    });

    if (permissionState.essentialGranted) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cấp quyền'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  LinearProgressIndicator(
                    value: permissionState.essentialProgress,
                    backgroundColor: cs.surfaceContainerHighest,
                    color: cs.primary,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    '${permissionState.grantedCount}/${permissionState.totalPermissions} quyền đã cấp',
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Image.asset(
                    'assets/logo.png',
                    width: 72,
                    height: 72,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.security_outlined,
                      size: 72,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Bảo vệ cuộc gọi của bạn',
                    style: tt.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Ứng dụng cần các quyền sau để giám sát và phát hiện lừa đảo trong cuộc gọi.',
                    style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Chỉ nhóm cốt lõi là bắt buộc; các khả năng nâng cao luôn là lựa chọn của bạn.',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Danh sách quyền cần thiết:',
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  for (final group in groups) _CapabilityCard(status: group),
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border(top: BorderSide(color: cs.outlineVariant)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isRequesting
                            ? null
                            : _requestCorePermissions,
                        icon: _isRequesting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.auto_fix_high),
                        label: Text(
                          _isRequesting
                              ? 'Đang cấp quyền...'
                              : 'Bắt đầu cấp quyền',
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _completeAndGoHome,
                      child: const Text('Bỏ qua (không khuyến khích)'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({required this.status});

  final CapabilityGroupStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  status.isGranted
                      ? Icons.check_circle
                      : status.group.isRequired
                      ? Icons.shield_outlined
                      : Icons.add_circle_outline,
                  color: status.isGranted
                      ? const Color(0xFF4CAF50)
                      : status.group.isRequired
                      ? cs.primary
                      : cs.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    status.group.title,
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  status.group.isRequired ? 'Bắt buộc' : 'Tùy chọn',
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(status.group.description, style: tt.bodySmall),
            for (final permission in status.missingPermissions)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xxs),
                child: Text(permission),
              ),
          ],
        ),
      ),
    );
  }
}
