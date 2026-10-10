/*
 * 胶囊输入框（对齐 Web 端 CapsuleInput）。
 *
 * Web 端实现：h-12 px-5 rounded-full bg-gray-100/60，聚焦时保持底色不变；
 * 可选前缀图标（Material Icons 线性风格）、可选尾部明文/密文切换按钮。
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
    this.prefixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.enabled = true,
    this.focusNode,
  });

  final TextEditingController controller;
  final String hint;

  /// 前缀图标名（Material Icons）。
  final IconData? prefixIcon;

  /// 是否密文展示；为 true 时自动追加明/密文切换按钮。
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final bool hasToggle = obscureText;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (BuildContext context, TextEditingValue value, _) {
        final bool showToggle = hasToggle && value.text.isNotEmpty;
        return _CapsuleField(
          controller: controller,
          hint: hint,
          prefixIcon: prefixIcon,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          enabled: enabled,
          focusNode: focusNode,
          showToggle: showToggle,
        );
      },
    );
  }
}

class _CapsuleField extends StatefulWidget {
  const _CapsuleField({
    required this.controller,
    required this.hint,
    required this.showToggle,
    this.prefixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.enabled = true,
    this.focusNode,
  });

  final TextEditingController controller;
  final String hint;
  final bool showToggle;
  final IconData? prefixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final FocusNode? focusNode;

  @override
  State<_CapsuleField> createState() => _CapsuleFieldState();
}

class _CapsuleFieldState extends State<_CapsuleField> {
  late bool _obscured = widget.obscureText;

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
      child: Row(
        children: <Widget>[
          if (widget.prefixIcon != null) ...<Widget>[
            Icon(widget.prefixIcon, size: 18, color: PortenColor.gray400),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              enabled: widget.enabled,
              obscureText: _obscured,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              onSubmitted: widget.onSubmitted,
              cursorColor: PortenColor.gray900,
              style: PortenTypography.base.copyWith(
                color: PortenColor.gray900,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: widget.hint,
                hintStyle: PortenTypography.base.copyWith(
                  color: PortenColor.gray400,
                ),
              ),
            ),
          ),
          if (widget.showToggle)
            GestureDetector(
              onTap: () => setState(() => _obscured = !_obscured),
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  _obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 18,
                  color: PortenColor.gray400,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
