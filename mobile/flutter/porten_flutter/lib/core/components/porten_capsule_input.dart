/*
 * 胶囊输入框（100% 对齐 Web 端 CapsuleInput.tsx）。
 *
 * Web 端实现：w-full h-12 px-5 rounded-full bg-gray-100/60，
 * text-gray-900、placeholder:text-gray-400、无图标无尾部控件。
 */

import 'package:flutter/material.dart';

import '../design/porten_colors.dart';
import '../design/porten_typography.dart';

/// 胶囊输入框。
class CapsuleInput extends StatelessWidget {
  const CapsuleInput({
    super.key,
    required this.controller,
    required this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.maxLength,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.focusNode,
  });

  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        // bg-gray-100/60：gray100 #F3F4F6 叠加 60% 透明度。
        color: PortenColor.gray100.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        maxLength: maxLength,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        cursorColor: PortenColor.gray900,
        style: PortenTypography.base.copyWith(color: PortenColor.gray900),
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          counterText: '',
          hintText: hint,
          hintStyle:
              PortenTypography.base.copyWith(color: PortenColor.gray400),
        ),
      ),
    );
  }
}
