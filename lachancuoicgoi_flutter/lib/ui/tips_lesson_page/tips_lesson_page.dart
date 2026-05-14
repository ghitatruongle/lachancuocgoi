import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

class TipsLessonPage extends StatelessWidget {
  const TipsLessonPage({super.key});

  static const _tips = [
    _TipData(
      number: 1,
      emoji: '📞',
      title: 'Xác minh danh tính người gọi',
      description:
          'Luôn xác minh danh tính người gọi thông qua kênh chính thức. Cơ quan chức năng không bao giờ gọi qua số cá nhân hoặc yêu cầu thông tin tài khoản qua điện thoại.',
      severity: _TipSeverity.high,
    ),
    _TipData(
      number: 2,
      emoji: '⏱️',
      title: 'Không hành động gấp gáp',
      description:
          'Kẻ lừa đảo thường tạo áp lực thời gian. Hãy bình tĩnh, không chuyển tiền hoặc cung cấp thông tin khi bị hối thúc.',
      severity: _TipSeverity.high,
    ),
    _TipData(
      number: 3,
      emoji: '🔐',
      title: 'Bảo vệ thông tin cá nhân',
      description:
          'Không chia sẻ mã OTP, số CCCD, số tài khoản ngân hàng hay mật khẩu qua điện thoại với bất kỳ ai.',
      severity: _TipSeverity.high,
    ),
    _TipData(
      number: 4,
      emoji: '🏛️',
      title: 'Nhận diện giả mạo cơ quan',
      description:
          'Công an, Viện kiểm sát, Tòa án không bao giờ làm việc qua điện thoại, không yêu cầu cài ứng dụng lạ hay chuyển tiền "để xác minh".',
      severity: _TipSeverity.high,
    ),
    _TipData(
      number: 5,
      emoji: '💰',
      title: 'Cảnh giác với lời hứa sinh lời',
      description:
          'Các dự án đầu tư "lợi nhuận cao, không rủi ro" qua mạng xã hội, nhóm Telegram/Zalo hầu hết là lừa đảo.',
      severity: _TipSeverity.medium,
    ),
    _TipData(
      number: 6,
      emoji: '🔗',
      title: 'Không bấm link lạ',
      description:
          'Đường link giả mạo ngân hàng, cơ quan nhà nước rất tinh vi. Luôn truy cập trực tiếp website chính thức.',
      severity: _TipSeverity.medium,
    ),
    _TipData(
      number: 7,
      emoji: '👥',
      title: 'Hỏi ý kiến người thân',
      description:
          'Trước khi quyết định chuyển tiền hoặc chia sẻ thông tin, hãy tham khảo ý kiến của người thân hoặc bạn bè.',
      severity: _TipSeverity.medium,
    ),
    _TipData(
      number: 8,
      emoji: '📱',
      title: 'Sử dụng công cụ hỗ trợ',
      description:
          'Bật "Lá chắn cuộc gọi" mỗi khi nhận cuộc gọi từ số lạ. Ứng dụng giúp phát hiện dấu hiệu lừa đảo theo thời gian thực.',
      severity: _TipSeverity.medium,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: Row(
          children: [
            Icon(Icons.lightbulb_outlined, color: cs.tertiary),
            const SizedBox(width: 8),
            const Text('Mẹo chống lừa đảo'),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.sm),
        children: [
          Text(
            'Những kiến thức cần biết để tự bảo vệ mình và gia đình trước các chiêu trò lừa đảo qua điện thoại.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final tip in _tips)
            _TipCard(tip: tip),
        ],
      ),
    );
  }
}

// ─── Data ──────────────────────────────────────────────────────────────
enum _TipSeverity { high, medium }

class _TipData {
  const _TipData({
    required this.number,
    required this.emoji,
    required this.title,
    required this.description,
    required this.severity,
  });
  final int number;
  final String emoji;
  final String title;
  final String description;
  final _TipSeverity severity;
}

// ─── Tip Card ──────────────────────────────────────────────────────────
class _TipCard extends StatelessWidget {
  const _TipCard({required this.tip});
  final _TipData tip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final cardColor = tip.severity == _TipSeverity.high
        ? cs.errorContainer.withOpacity(0.3)
        : cs.tertiaryContainer.withOpacity(0.3);

    final accentColor = tip.severity == _TipSeverity.high
        ? cs.error
        : cs.tertiary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: cardColor,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Number circle
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withOpacity(0.15),
                ),
                child: Center(
                  child: Text(
                    '${tip.number}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(tip.emoji, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            tip.title,
                            style: tt.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tip.description,
                      style: tt.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
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
