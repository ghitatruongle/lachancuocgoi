import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/permission/permission_manager.dart';

/// Dialog hiển thị trạng thái các quyền và hướng dẫn người dùng cấp quyền
class RightsDialog extends StatelessWidget {
  const RightsDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final permissionManager = Provider.of<PermissionManager>(context);

    return AlertDialog(
      title: const Text(
        'Cấp quyền cần thiết',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ứng dụng cần các quyền sau để hoạt động đúng chức năng bảo vệ cuộc gọi:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            
            // Accessibility Permission
            _buildPermissionTile(
              context,
              icon: Icons.accessibility,
              title: 'Quyền Trợ năng (Accessibility)',
              description: 'Để đọc nội dung cuộc gọi đến và đi',
              isGranted: permissionManager.hasAccessibility,
              onRequest: () => permissionManager.requestAccessibility(),
            ),
            const Divider(),
            
            // Overlay Permission
            _buildPermissionTile(
              context,
              icon: Icons.layers,
              title: 'Quyền Hiển thị trên ứng dụng khác',
              description: 'Để hiển thị cảnh báo khi có cuộc gọi lừa đảo',
              isGranted: permissionManager.hasOverlay,
              onRequest: () => permissionManager.requestOverlay(),
            ),
            const Divider(),
            
            // Notification Permission
            _buildPermissionTile(
              context,
              icon: Icons.notifications,
              title: 'Quyền Thông báo',
              description: 'Để gửi cảnh báo về các cuộc gọi đáng ngờ',
              isGranted: permissionManager.hasNotification,
              onRequest: () => permissionManager.requestNotification(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
        ElevatedButton(
          onPressed: permissionManager.isAllGranted
              ? () => Navigator.of(context).pop()
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: permissionManager.isAllGranted
                ? Colors.green
                : Colors.grey,
          ),
          child: const Text('Hoàn tất'),
        ),
      ],
    );
  }

  Widget _buildPermissionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
    required VoidCallback onRequest,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: isGranted ? Colors.green : Colors.orange,
          size: 28,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  if (isGranted)
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    )
                  else
                    const Icon(
                      Icons.error_outline,
                      color: Colors.orange,
                      size: 20,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              if (!isGranted)
                ElevatedButton(
                  onPressed: onRequest,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 36),
                  ),
                  child: const Text('Cấp quyền'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
