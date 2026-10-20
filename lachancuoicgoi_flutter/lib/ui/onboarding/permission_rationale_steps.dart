import 'package:flutter/material.dart';

class PermissionRationaleStep {
  const PermissionRationaleStep({
    required this.title,
    required this.body,
    required this.icon,
    this.isOptional = false,
  });

  final String title;
  final String body;
  final IconData icon;
  final bool isOptional;
}

List<PermissionRationaleStep> defaultPermissionRationaleSteps() {
  return const <PermissionRationaleStep>[
    PermissionRationaleStep(
      title: 'Micro để nghe cuộc gọi',
      body:
          'Ứng dụng cần micro để chuyển lời nói thành chữ ngay trên máy. '
          'Không bật micro thì không giám sát được cuộc gọi thật.',
      icon: Icons.mic,
    ),
    PermissionRationaleStep(
      title: 'Cửa sổ cảnh báo',
      body:
          'Quyền hiển thị trên ứng dụng khác giúp hiện cảnh báo đỏ/cam '
          'khi phát hiện dấu hiệu lừa đảo, kể cả khi bạn đang nghe máy.',
      icon: Icons.branding_watermark,
    ),
    PermissionRationaleStep(
      title: 'Lọc cuộc gọi (tuỳ chọn)',
      body:
          'Call Screening giúp chặn số đã biết là lừa đảo. '
          'Bạn có thể bỏ qua và vẫn dùng phân tích nội dung cuộc gọi.',
      icon: Icons.phone_callback,
      isOptional: true,
    ),
    PermissionRationaleStep(
      title: 'Hỗ trợ điều khiển cuộc gọi (tắt mặc định)',
      body:
          'Quyền trợ năng chỉ cần nếu bạn muốn app hỗ trợ nghe/cúp máy. '
          'Mặc định TẮT để an toàn hơn. Giám sát vẫn chạy không cần quyền này.',
      icon: Icons.accessibility_new,
      isOptional: true,
    ),
    PermissionRationaleStep(
      title: 'Phân tích đám mây (tuỳ chọn)',
      body:
          'Chỉ khi bạn đồng ý, bản chữ đã gỡ thông tin nhạy cảm mới gửi '
          'Gemini để phân tích sâu. Không đồng ý thì app vẫn chạy L1+L2 offline.',
      icon: Icons.cloud_outlined,
      isOptional: true,
    ),
  ];
}

class PermissionRationalePager extends StatelessWidget {
  const PermissionRationalePager({
    super.key,
    required this.steps,
    required this.index,
    required this.onNext,
    required this.onBack,
    required this.onSkipOptional,
    required this.onFinish,
  });

  final List<PermissionRationaleStep> steps;
  final int index;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSkipOptional;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final step = steps[index];
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isLast = index >= steps.length - 1;

    return Semantics(
      label: '${step.title}. Bước ${index + 1} trên ${steps.length}',
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(step.icon, size: 64, color: cs.primary),
            const SizedBox(height: 24),
            Text(
              step.title,
              style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              step.body,
              style: tt.bodyLarge?.copyWith(height: 1.4, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            if (step.isOptional) ...[
              const SizedBox(height: 12),
              Text(
                'Bước này có thể bỏ qua.',
                style: tt.bodyMedium?.copyWith(color: cs.outline),
                textAlign: TextAlign.center,
              ),
            ],
            const Spacer(),
            Row(
              children: [
                if (index > 0)
                  TextButton(onPressed: onBack, child: const Text('Quay lại')),
                const Spacer(),
                if (step.isOptional && !isLast)
                  TextButton(
                    onPressed: onSkipOptional,
                    child: const Text('Bỏ qua'),
                  ),
                FilledButton(
                  onPressed: isLast ? onFinish : onNext,
                  child: Text(isLast ? 'Xong' : 'Tiếp'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
