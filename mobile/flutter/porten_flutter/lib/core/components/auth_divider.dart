/*
 * 认证页分隔行（对齐 Web 端 AuthDivider + .fade-divider）。
 *
 * Web 端实现：左右两条 1px 渐变淡出线（transparent → gray-300/30 → transparent），
 * 中央文字包在白色圆角背景里，形成「线穿文字」的视觉。
 */

import 'package:flutter/material.dart';

import '../design/porten_colors.dart';
import '../design/porten_typography.dart';

/// 认证页「其他方式」分隔行。
class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Expanded(child: _FadeLine()),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: PortenColor.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: PortenTypography.xs.copyWith(color: PortenColor.gray400),
          ),
        ),
        const Expanded(child: _FadeLine()),
      ],
    );
  }
}

class _FadeLine extends StatelessWidget {
  const _FadeLine();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              PortenColor.gray300.withValues(alpha: 0),
              PortenColor.gray300.withValues(alpha: 0.3),
              PortenColor.gray300.withValues(alpha: 0),
            ],
            stops: const <double>[0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }
}
