import 'package:flutter/material.dart';

/// Shows a confirm/cancel dialog and returns `true` if the user confirmed.
///
/// Replaces the duplicated confirm-delete `AlertDialog` scaffolding in the
/// history page (Sprint 5.2 — Pattern G). [confirmLabel] defaults to `'Xóa'`
/// and [isDestructive] to `true`, matching the existing delete flows; callers
/// can pass a non-destructive label (e.g. `'Xác nhận'`) for other confirmations.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Xóa',
  String cancelLabel = 'Quay lại',
  bool isDestructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: isDestructive
              ? TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                )
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
