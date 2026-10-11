/*
 * 胶囊输入框（100% 对齐 Web 端 CapsuleInput.tsx）。
 *
 * Web 端实现：w-full h-12 px-5 rounded-full bg-gray-100/60，
 * text-gray-900、placeholder:text-gray-400、无图标无尾部控件；
 * 聚焦时 focus:bg-gray-100/80（透明度 0.6 → 0.8，200ms 过渡）。
 */

import 'package:flutter/material.dart';

import '../design/porten_colors.dart';
import '../design/porten_typography.dart';

/// 胶囊输入框。
class CapsuleInput extends StatefulWidget {
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
  State<CapsuleInput> createState() => _CapsuleInputState();
}

class _CapsuleInputState extends State<CapsuleInput> {
  FocusNode? _ownFocusNode;
  bool _focused = false;

  /// 外部注入优先；未注入则自建（对齐 Web 端 focus 伪类）。
  FocusNode get _effectiveNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  void _handleFocusChange() {
    final bool focused = _effectiveNode.hasFocus;
    if (focused != _focused) {
      setState(() => _focused = focused);
    }
  }

  @override
  void initState() {
    super.initState();
    _effectiveNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(CapsuleInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_handleFocusChange);
      _effectiveNode.addListener(_handleFocusChange);
      _handleFocusChange();
    }
  }

  @override
  void dispose() {
    _effectiveNode.removeListener(_handleFocusChange);
    _ownFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // bg-gray-100/60 → focus:bg-gray-100/80（透明度 0.6 → 0.8）
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: PortenColor.gray100.withValues(alpha: _focused ? 0.8 : 0.6),
        borderRadius: BorderRadius.circular(24),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _effectiveNode,
        enabled: widget.enabled,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        maxLength: widget.maxLength,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        cursorColor: PortenColor.gray900,
        // isCollapsed 模式下文本默认顶对齐——显式居中（修复文本贴顶歪斜）
        textAlignVertical: TextAlignVertical.center,
        style: PortenTypography.base.copyWith(color: PortenColor.gray900),
        decoration: InputDecoration(
          // isCollapsed 模式下文本/占位符贴顶（多轮 textAlignVertical 均无效），
          // 改用 isDense + 垂直 contentPadding 强制在 48px 内居中（久验可靠）。
          isDense: true,
          border: InputBorder.none,
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
          hintText: widget.hint,
          hintStyle:
              PortenTypography.base.copyWith(color: PortenColor.gray400),
        ),
      ),
    );
  }
}
