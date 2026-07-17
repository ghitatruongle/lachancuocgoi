import 'package:flutter/material.dart';

/// A search text field with rounded borders and an optional clear button.
///
/// Replaces the duplicated search-field scaffolding in history and simulation
/// pages (Sprint 5.2 — Pattern F): `prefixIcon: Icon(Icons.search)`, a clear
/// `IconButton` that appears when [value] is non-empty, and three
/// `circular(24)` outline borders (border / enabled / focused).
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    this.controller,
    this.focusNode,
    this.value,
    this.hintText = 'Tìm kiếm...',
    this.onChanged,
    this.onClear,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;

  /// Current query value, used to decide whether to show the clear button when
  /// no [controller] is supplied.
  final String? value;

  final String hintText;
  final ValueChanged<String>? onChanged;

  /// Called when the user taps the clear button. Defaults to clearing via the
  /// controller (if present) or forwarding an empty string to [onChanged].
  final VoidCallback? onClear;

  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final showClear =
        value?.isNotEmpty == true || controller?.text.isNotEmpty == true;
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(24));

    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: showClear
            ? IconButton(
                tooltip: 'Xóa tìm kiếm',
                icon: const Icon(Icons.close),
                onPressed:
                    onClear ??
                    () {
                      controller?.clear();
                      onChanged?.call('');
                    },
              )
            : null,
        border: border,
        enabledBorder: border,
        focusedBorder: border,
      ),
    );
  }
}
