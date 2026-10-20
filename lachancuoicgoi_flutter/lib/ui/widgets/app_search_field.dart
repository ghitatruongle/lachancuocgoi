import 'package:flutter/material.dart';

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

  final String? value;

  final String hintText;
  final ValueChanged<String>? onChanged;

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
