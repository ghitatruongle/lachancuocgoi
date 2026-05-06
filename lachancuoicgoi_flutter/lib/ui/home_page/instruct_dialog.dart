import 'package:flutter/material.dart';

class InstructDialog extends StatelessWidget {
  const InstructDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Hướng dẫn sử dụng'),
      content: const _PrincipleOfOperationTab(),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đã hiểu'),
        ),
      ],
    );
  }
}

class _PrincipleOfOperationTab extends StatelessWidget {
  const _PrincipleOfOperationTab();

  static const _principles = [
    (
      icon: Icons.volume_up,
      title: 'Bước 1: Bật Loa Ngoài',
      description:
          'Bật loa ngoài giúp ứng dụng thu được âm thanh từ cả hai phía thông qua microphone để phân tích.',
    ),
    (
      icon: Icons.mic,
      title: 'Bước 2: Phân Tích Âm Thanh',
      description:
          'Ứng dụng sẽ lắng nghe và phân tích cuộc hội thoại theo thời gian thực.',
    ),
    (
      icon: Icons.notifications_active,
      title: 'Bước 3: Gửi Cảnh Báo',
      description:
          'Nếu phát hiện dấu hiệu lừa đảo, ứng dụng sẽ rung hoặc phát chuông để cảnh báo bạn.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          for (final p in _principles) ...[
            ListTile(
              leading: Icon(p.icon),
              title: Text(p.title),
              subtitle: Text(p.description),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
