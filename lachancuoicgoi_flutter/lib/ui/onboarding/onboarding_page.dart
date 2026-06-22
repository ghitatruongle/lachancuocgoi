import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/permission_controller.dart';
import '../theme/app_theme.dart';

/// Onboarding screen that guides users through permission granting.
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
      if (!mounted) return;
      _tryExitWhenAllGranted();
    });
  }

  Future<void> _persistOnboardingAndGoHome() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    if (!mounted) return;
    context.go('/');
  }

  void _tryExitWhenAllGranted() {
    if (_exitScheduled || !mounted) return;
    if (!ref.read(permissionControllerProvider).allGranted) return;
    _exitScheduled = true;
    unawaited(_persistOnboardingAndGoHome());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    ref.listen<PermissionState>(permissionControllerProvider, (prev, next) {
      if (!next.allGranted) return;
      if (prev?.allGranted == true) return;
      _tryExitWhenAllGranted();
    });
    final state = ref.watch(permissionControllerProvider);

    if (state.allGranted) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final missingPermissions = ref.watch(missingPermissionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cấp quyền'),
        automaticallyImplyLeading: false,
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            sliver: SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                children: [
                  const SizedBox(height: AppSpacing.lg),

                  // Progress indicator
                  LinearProgressIndicator(
                    value: state.progress,
                    backgroundColor: cs.surfaceContainerHighest,
                    color: cs.primary,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${state.grantedCount}/${state.totalPermissions} quyền đã cấp',
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),

                  const Spacer(flex: 1),

                  // Icon and title
                  Image.asset(
                    'assets/logo.png',
                    width: 80,
                    height: 80,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.security_outlined,
                      size: 80,
                      color: state.allGranted ? const Color(0xFF4CAF50) : cs.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Bảo vệ cuộc gọi của bạn',
                    style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Ứng dụng cần các quyền sau để giám sát và phát hiện lừa đảo trong cuộc gọi.',
                    style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),

                  const Spacer(flex: 2),

                  // Permission checklist
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Danh sách quyền cần thiết:',
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          ...missingPermissions.map(
                            (perm) => Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.xxs,
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.circle, size: 8, color: cs.error),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Text(perm, style: tt.bodyMedium),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (missingPermissions.isEmpty)
                            Text(
                              'Tất cả quyền đã được cấp!',
                              style: tt.bodyMedium?.copyWith(
                                color: const Color(0xFF4CAF50),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(flex: 1),

                  // Action buttons
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isRequesting ? null : _requestPermissions,
                      icon: _isRequesting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_fix_high),
                      label: Text(
                        _isRequesting ? 'Đang cấp quyền...' : 'Bắt đầu cấp quyền',
                        style: tt.titleMedium?.copyWith(color: cs.onPrimary),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  TextButton(
                    onPressed: () async {
                      // Mark onboarding as completed/skipped
                      final router = GoRouter.of(context);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('onboarding_completed', true);
                      if (mounted) {
                        router.go('/');
                      }
                    },
                    child: Text(
                      'Bỏ qua (không khuyến khích)',
                      style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _requestPermissions() async {
    setState(() => _isRequesting = true);
    try {
      await ref
          .read(permissionControllerProvider.notifier)
          .requestAllPermissions(context);
    } finally {
      if (mounted) {
        setState(() => _isRequesting = false);
      }
    }
  }
}
